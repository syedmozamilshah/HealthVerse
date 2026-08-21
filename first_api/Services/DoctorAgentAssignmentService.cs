using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AgentAssignmentModel;
using first_api.Entities.DoctorModel;
using MongoDB.Bson;
using MongoDB.Driver;

namespace first_api.Services
{
    // Centralized transition engine for doctor agent assignments.
    public class DoctorAgentAssignmentService
    {
        private readonly IMongoCollection<DoctorAgentAssignment> _assignments;
        private readonly IMongoCollection<DoctorAgentAssignmentSettings> _settings;
        private readonly IMongoCollection<DoctorAgentAssignmentEvent> _events;
        private readonly IMongoCollection<Doctor> _doctors;

        public DoctorAgentAssignmentService(MongodbService mongoDbService)
        {
            _assignments = mongoDbService.Database!.GetCollection<DoctorAgentAssignment>("doctor_agent_assignments");
            _settings = mongoDbService.Database!.GetCollection<DoctorAgentAssignmentSettings>("doctor_agent_assignment_settings");
            _events = mongoDbService.Database!.GetCollection<DoctorAgentAssignmentEvent>("doctor_agent_assignment_events");
            _doctors = mongoDbService.Database!.GetCollection<Doctor>("doctor");
        }

        // Get global settings (singleton). Creates default if missing.
        public async Task<DoctorAgentAssignmentSettings> GetSettingsAsync()
        {
            var settings = await _settings.Find(_ => true).FirstOrDefaultAsync();
            if (settings == null)
            {
                settings = new DoctorAgentAssignmentSettings
                {
                    Id = ObjectId.GenerateNewId().ToString(),
                    GlobalMode = "Auto",
                    EnforceSubscriptionGate = true,
                    BlockAutoOnArchived = true,
                    UpdatedAt = DateTime.UtcNow
                };
                await _settings.InsertOneAsync(settings);
            }
            return settings;
        }

        // Update global mode (Auto/Manual). Not retroactive on existing rows.
        public async Task<DoctorAgentAssignmentSettings> UpdateSettingsAsync(string globalMode, string adminId)
        {
            var settings = await GetSettingsAsync();
            var update = Builders<DoctorAgentAssignmentSettings>.Update
                .Set(s => s.GlobalMode, globalMode)
                .Set(s => s.UpdatedByAdminId, adminId)
                .Set(s => s.UpdatedAt, DateTime.UtcNow);

            await _settings.UpdateOneAsync(s => s.Id == settings.Id, update);
            settings.GlobalMode = globalMode;
            settings.UpdatedByAdminId = adminId;
            return settings;
        }

        // Called when a doctor verification is approved (first or re-verification).
        // Reads global mode and creates assignment accordingly.
        public async Task<AssignmentOutcome> HandleDoctorVerificationApprovedAsync(
            string doctorId, string doctorName, string specialization, string triggeredBy)
        {
            var settings = await GetSettingsAsync();

            if (settings.GlobalMode == "Auto")
            {
                return await TryCreateAutoActiveAssignmentAsync(
                    doctorId, doctorName, specialization, triggeredBy);
            }
            else
            {
                return await CreateManualPendingAssignmentRequestAsync(
                    doctorId, doctorName, specialization, triggeredBy);
            }
        }

        // Auto mode: create Active assignment only if no blocking assignment exists and subscription is eligible.
        public async Task<AssignmentOutcome> TryCreateAutoActiveAssignmentAsync(
            string doctorId, string doctorName, string specialization, string triggeredBy)
        {
            // Guard: no existing Active, Paused, or Archived assignment
            var blocking = await _assignments.Find(a =>
                a.DoctorId == doctorId &&
                (a.Status == "Active" || a.Status == "Paused" || a.Status == "Archived")
            ).FirstOrDefaultAsync();

            if (blocking != null)
            {
                return new AssignmentOutcome
                {
                    AssignmentStatus = blocking.Status,
                    AssignmentMessage = $"Auto assignment skipped: doctor already has a {blocking.Status} assignment."
                };
            }

            // Guard: subscription eligibility
            var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
            if (!IsSubscriptionEligible(doctor))
            {
                // Still create the assignment as Pending with auto mode so admin can see it
                var pendingAssignment = await CreateAssignmentAsync(
                    doctorId, doctorName, specialization,
                    "Auto", "Pending", "AutoVerificationApproval", triggeredBy);

                return new AssignmentOutcome
                {
                    AssignmentStatus = "Pending",
                    AssignmentMessage = "Verification approved but subscription not active or period ended. Assignment created as Pending."
                };
            }

            // Create Active assignment
            var assignment = await CreateAssignmentAsync(
                doctorId, doctorName, specialization,
                "Auto", "Active", "AutoVerificationApproval", triggeredBy);

            return new AssignmentOutcome
            {
                AssignmentStatus = "Active",
                AssignmentMessage = "AI Agent assigned automatically upon verification approval."
            };
        }

        // Manual mode: always create Pending record.
        public async Task<AssignmentOutcome> CreateManualPendingAssignmentRequestAsync(
            string doctorId, string doctorName, string specialization, string triggeredBy)
        {
            var existing = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Pending" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (existing != null)
            {
                return new AssignmentOutcome
                {
                    AssignmentStatus = "Pending",
                    AssignmentMessage = "Pending assignment already exists. Waiting for admin approval."
                };
            }

            // Guard: no Active assignment
            var active = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Active" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (active != null)
            {
                return new AssignmentOutcome
                {
                    AssignmentStatus = "Active",
                    AssignmentMessage = "Doctor already has an active assignment."
                };
            }

            var assignment = await CreateAssignmentAsync(
                doctorId, doctorName, specialization,
                "Manual", "Pending", "ManualVerificationApproval", triggeredBy);

            return new AssignmentOutcome
            {
                AssignmentStatus = "Pending",
                AssignmentMessage = "Assignment created as Pending. Awaiting admin approval."
            };
        }

        // Admin approves a Pending assignment  active. 
        // Blocked if subscription inactive.
        public async Task<(bool Success, string Message)> ApprovePendingAsync(string doctorId, string adminId)
        {
            var assignment = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Pending" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (assignment == null)
                return (false, "No pending assignment found for this doctor.");

            // Guard: subscription eligibility
            var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
            if (!IsSubscriptionEligible(doctor))
                return (false, "Cannot approve: doctor's subscription is not active or period has ended.");

            // Guard: single active invariant
            var existingActive = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Active" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (existingActive != null)
                return (false, "Doctor already has an active assignment. Cannot approve another.");

            var oldStatus = assignment.Status;
            var update = Builders<DoctorAgentAssignment>.Update
                .Set(a => a.Status, "Active")
                .Set(a => a.ApprovedAt, DateTime.UtcNow)
                .Set(a => a.ApprovedByAdminId, adminId)
                .Set(a => a.LastStatusChangedAt, DateTime.UtcNow)
                .Set(a => a.IsSubscriptionEligible, true)
                .Set(a => a.SubscriptionStatusAtLastValidation, doctor?.SubscriptionStatus ?? "")
                .Set(a => a.UpdatedAt, DateTime.UtcNow)
                .Inc(a => a.Version, 1);

            await _assignments.UpdateOneAsync(a => a.Id == assignment.Id, update);

            await EmitEventAsync(doctorId, assignment.Id, "Approved", oldStatus, "Active", adminId, "AdminAction");

            return (true, "Assignment approved successfully. Doctor now has Active AI Agent access.");
        }

        // Admin pauses an Active assignment: Paused.
        public async Task<(bool Success, string Message)> PauseActiveAsync(string doctorId, string adminId, string reason = "")
        {
            var assignment = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Active" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (assignment == null)
                return (false, "No active assignment found for this doctor.");

            var oldStatus = assignment.Status;
            var update = Builders<DoctorAgentAssignment>.Update
                .Set(a => a.Status, "Paused")
                .Set(a => a.PauseReason, reason)
                .Set(a => a.LastStatusChangedAt, DateTime.UtcNow)
                .Set(a => a.UpdatedAt, DateTime.UtcNow)
                .Inc(a => a.Version, 1);

            await _assignments.UpdateOneAsync(a => a.Id == assignment.Id, update);

            await EmitEventAsync(doctorId, assignment.Id, "Paused", oldStatus, "Paused", adminId, "AdminAction");

            return (true, "Assignment paused successfully.");
        }

        // Admin resumes a Paused assignment: Active.
        // Blocked if subscription inactive.
        public async Task<(bool Success, string Message)> ResumePausedAsync(string doctorId, string adminId)
        {
            var assignment = await _assignments.Find(a =>
                a.DoctorId == doctorId && a.Status == "Paused" && !a.IsArchived
            ).FirstOrDefaultAsync();

            if (assignment == null)
                return (false, "No paused assignment found for this doctor.");

            // Guard: subscription
            var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
            if (!IsSubscriptionEligible(doctor))
                return (false, "Cannot resume: doctor's subscription is not active or period has ended.");

            var oldStatus = assignment.Status;
            var update = Builders<DoctorAgentAssignment>.Update
                .Set(a => a.Status, "Active")
                .Set(a => a.PauseReason, "")
                .Set(a => a.LastStatusChangedAt, DateTime.UtcNow)
                .Set(a => a.IsSubscriptionEligible, true)
                .Set(a => a.SubscriptionStatusAtLastValidation, doctor?.SubscriptionStatus ?? "")
                .Set(a => a.UpdatedAt, DateTime.UtcNow)
                .Inc(a => a.Version, 1);

            await _assignments.UpdateOneAsync(a => a.Id == assignment.Id, update);

            await EmitEventAsync(doctorId, assignment.Id, "Resumed", oldStatus, "Active", adminId, "AdminAction");

            return (true, "Assignment resumed successfully. Doctor now has Active AI Agent access.");
        }

        // Admin archives an assignment : Archived (soft delete).
        public async Task<(bool Success, string Message)> ArchiveAssignmentAsync(string doctorId, string adminId, string reason = "")
        {
            var assignment = await _assignments.Find(a =>
                a.DoctorId == doctorId &&
                (a.Status == "Active" || a.Status == "Paused" || a.Status == "Pending") &&
                !a.IsArchived
            ).FirstOrDefaultAsync();

            if (assignment == null)
                return (false, "No active/paused/pending assignment found for this doctor.");

            var oldStatus = assignment.Status;
            var update = Builders<DoctorAgentAssignment>.Update
                .Set(a => a.Status, "Archived")
                .Set(a => a.IsArchived, true)
                .Set(a => a.ArchiveReason, reason)
                .Set(a => a.LastStatusChangedAt, DateTime.UtcNow)
                .Set(a => a.UpdatedAt, DateTime.UtcNow)
                .Inc(a => a.Version, 1);

            await _assignments.UpdateOneAsync(a => a.Id == assignment.Id, update);

            await EmitEventAsync(doctorId, assignment.Id, "Archived", oldStatus, "Archived", adminId, "AdminAction");

            return (true, "Assignment archived successfully.");
        }

        // Called when a doctor's subscription becomes active (Stripe payment).
        // If mode is Auto and assignment is Pending, auto-activate it.
        public async Task<(bool Activated, string Message)> TryAutoActivatePendingAssignmentAsync(string doctorId)
        {
            try
            {
                var settings = await GetSettingsAsync();

                // Only auto-activate if global mode is Auto
                if (settings.GlobalMode != "Auto")
                    return (false, "Global mode is Manual. Assignment remains Pending for admin approval.");

                // Find a Pending assignment for this doctor
                var assignment = await _assignments.Find(a =>
                    a.DoctorId == doctorId && a.Status == "Pending" && !a.IsArchived
                ).FirstOrDefaultAsync();

                if (assignment == null)
                    return (false, "No pending assignment found for this doctor.");

                // Guard: no existing Active assignment
                var existingActive = await _assignments.Find(a =>
                    a.DoctorId == doctorId && a.Status == "Active" && !a.IsArchived
                ).FirstOrDefaultAsync();

                if (existingActive != null)
                    return (false, "Doctor already has an active assignment.");

                // Verify subscription is now active
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
                if (!IsSubscriptionEligible(doctor))
                    return (false, "Subscription is not active yet or period ended.");

                // Auto-activate the Pending assignment
                var oldStatus = assignment.Status;
                var update = Builders<DoctorAgentAssignment>.Update
                    .Set(a => a.Status, "Active")
                    .Set(a => a.ApprovedAt, DateTime.UtcNow)
                    .Set(a => a.ApprovedByAdminId, "system-auto")
                    .Set(a => a.LastStatusChangedAt, DateTime.UtcNow)
                    .Set(a => a.IsSubscriptionEligible, true)
                    .Set(a => a.SubscriptionStatusAtLastValidation, "active")
                    .Set(a => a.UpdatedAt, DateTime.UtcNow)
                    .Inc(a => a.Version, 1);

                await _assignments.UpdateOneAsync(a => a.Id == assignment.Id, update);

                await EmitEventAsync(doctorId, assignment.Id, "AutoActivated", oldStatus, "Active",
                    "system-auto", "SubscriptionPayment");

                Console.WriteLine($"[AgentAssignment] Auto-activated Pending assignment for doctor {doctorId} after subscription payment.");

                return (true, "Assignment auto-activated after subscription payment.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[AgentAssignment] Error in TryAutoActivatePendingAssignmentAsync for {doctorId}: {ex.Message}");
                return (false, $"Error auto-activating: {ex.Message}");
            }
        }

        // Final access gate: verified doctor + subscription active + assignment Active.
        // Returns rich response for frontend gating.
        public async Task<AgentAccessResponse> EvaluateAccessAsync(string doctorId)
        {
            var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
            if (doctor == null)
            {
                return new AgentAccessResponse
                {
                    IsSuccess = false,
                    CanAccess = false,
                    DenialReason = "DoctorNotFound",
                    DenialMessage = "Doctor profile not found.",
                    Message = "Doctor profile not found."
                };
            }

            // Check verification
            bool isVerified = doctor.IsVerified && !doctor.IsReVerificationRequired;
            if (!isVerified)
            {
                var reason = doctor.IsReVerificationRequired 
                    ? "ReVerificationPending" 
                    : "NotVerified";
                var msg = doctor.IsReVerificationRequired
                    ? "Re-verification pending. AI Agent access temporarily suspended."
                    : "Verification required to access AI Agent.";

                return new AgentAccessResponse
                {
                    IsSuccess = true,
                    CanAccess = false,
                    DenialReason = reason,
                    DenialMessage = msg,
                    SubscriptionStatus = doctor.SubscriptionStatus,
                    HasPaidFirstSubscription = doctor.HasPaidFirstSubscription,
                    RequiresPayment = false,
                    Message = msg
                };
            }

            // Check subscription
            if (!IsSubscriptionEligible(doctor))
            {
                string subMsg = doctor.SubscriptionStatus == "past_due"
                    ? "Your subscription payment is past due. Please update your payment method."
                    : doctor.SubscriptionStatus == "canceled"
                        ? "Your subscription has been canceled and the period has ended. Please resubscribe to access AI Agent."
                        : "Active subscription required to access AI Agent.";

                return new AgentAccessResponse
                {
                    IsSuccess = true,
                    CanAccess = false,
                    DenialReason = "SubscriptionInactive",
                    DenialMessage = subMsg,
                    SubscriptionStatus = doctor.SubscriptionStatus,
                    HasPaidFirstSubscription = doctor.HasPaidFirstSubscription,
                    RequiresPayment = true,
                    Message = subMsg
                };
            }

            // Check assignment
            var assignment = await _assignments.Find(a =>
                a.DoctorId == doctorId && !a.IsArchived
            ).SortByDescending(a => a.UpdatedAt).FirstOrDefaultAsync();

            if (assignment == null)
            {
                return new AgentAccessResponse
                {
                    IsSuccess = true,
                    CanAccess = false,
                    AssignmentStatus = "None",
                    DenialReason = "NoAssignment",
                    DenialMessage = "No AI Agent assignment found. Please contact admin.",
                    SubscriptionStatus = doctor.SubscriptionStatus,
                    HasPaidFirstSubscription = doctor.HasPaidFirstSubscription,
                    RequiresPayment = false,
                    Message = "No AI Agent assignment found."
                };
            }

            if (assignment.Status == "Active")
            {
                return new AgentAccessResponse
                {
                    IsSuccess = true,
                    CanAccess = true,
                    AssignmentStatus = "Active",
                    AssignmentMode = assignment.Mode,
                    SubscriptionStatus = doctor.SubscriptionStatus,
                    HasPaidFirstSubscription = doctor.HasPaidFirstSubscription,
                    RequiresPayment = false,
                    Message = "Access granted"
                };
            }

            // Non-Active statuses
            string denialReason, denialMessage;
            switch (assignment.Status)
            {
                case "Pending":
                    denialReason = "Pending";
                    denialMessage = "Your AI Agent assignment is pending admin approval.";
                    break;
                case "Paused":
                    denialReason = "Paused";
                    denialMessage = "Your AI Agent access has been temporarily paused by admin.";
                    break;
                case "Archived":
                    denialReason = "Archived";
                    denialMessage = "Your AI Agent assignment has been archived. Please contact admin.";
                    break;
                default:
                    denialReason = "Unknown";
                    denialMessage = "Unable to determine assignment status.";
                    break;
            }

            return new AgentAccessResponse
            {
                IsSuccess = true,
                CanAccess = false,
                AssignmentStatus = assignment.Status,
                AssignmentMode = assignment.Mode,
                DenialReason = denialReason,
                DenialMessage = denialMessage,
                SubscriptionStatus = doctor.SubscriptionStatus,
                HasPaidFirstSubscription = doctor.HasPaidFirstSubscription,
                RequiresPayment = false,
                Message = denialMessage
            };
        }

        // Get assignments filtered by status, mode, and search term.
        public async Task<(List<AssignmentListItemDto> Items, int Total)> GetAssignmentsAsync(
            string? status = null, string? mode = null, string? search = null)
        {
            var filterBuilder = Builders<DoctorAgentAssignment>.Filter;
            var filters = new List<FilterDefinition<DoctorAgentAssignment>>();

            if (!string.IsNullOrEmpty(status))
                filters.Add(filterBuilder.Eq(a => a.Status, status));

            if (!string.IsNullOrEmpty(mode))
                filters.Add(filterBuilder.Eq(a => a.Mode, mode));

            if (!string.IsNullOrEmpty(search))
            {
                var searchFilter = filterBuilder.Or(
                    filterBuilder.Regex(a => a.DoctorNameSnapshot, new BsonRegularExpression(search, "i")),
                    filterBuilder.Regex(a => a.PrimaryAgent, new BsonRegularExpression(search, "i"))
                );
                filters.Add(searchFilter);
            }

            var combinedFilter = filters.Count > 0
                ? filterBuilder.And(filters)
                : filterBuilder.Empty;

            var assignments = await _assignments
                .Find(combinedFilter)
                .SortByDescending(a => a.UpdatedAt)
                .ToListAsync();

            // Enrich with current subscription status
            var items = new List<AssignmentListItemDto>();
            foreach (var a in assignments)
            {
                var doctor = await _doctors.Find(d => d.Id == a.DoctorId).FirstOrDefaultAsync();
                items.Add(new AssignmentListItemDto
                {
                    Id = a.Id,
                    DoctorId = a.DoctorId,
                    DoctorNameSnapshot = a.DoctorNameSnapshot,
                    PrimaryAgent = a.PrimaryAgent,
                    SubAgent = a.SubAgent,
                    Mode = a.Mode,
                    Status = a.Status,
                    IsArchived = a.IsArchived,
                    Source = a.Source,
                    AssignedAt = a.AssignedAt,
                    ApprovedAt = a.ApprovedAt,
                    LastStatusChangedAt = a.LastStatusChangedAt,
                    PauseReason = a.PauseReason,
                    ArchiveReason = a.ArchiveReason,
                    Notes = a.Notes,
                    IsSubscriptionEligible = doctor?.SubscriptionStatus == "active",
                    SubscriptionStatus = doctor?.SubscriptionStatus ?? "none"
                });
            }

            return (items, items.Count);
        }

        // Get pending assignments only.
        public async Task<(List<AssignmentListItemDto> Items, int Total)> GetPendingAssignmentsAsync()
        {
            return await GetAssignmentsAsync(status: "Pending");
        }

        // Get event history for a specific doctor.
        public async Task<List<AssignmentEventDto>> GetHistoryAsync(string doctorId)
        {
            var events = await _events
                .Find(e => e.DoctorId == doctorId)
                .SortByDescending(e => e.CreatedAt)
                .ToListAsync();

            return events.Select(e => new AssignmentEventDto
            {
                Id = e.Id,
                EventType = e.EventType,
                OldStatus = e.OldStatus,
                NewStatus = e.NewStatus,
                TriggeredBy = e.TriggeredBy,
                TriggerSource = e.TriggerSource,
                CreatedAt = e.CreatedAt
            }).ToList();
        }

        private bool IsSubscriptionEligible(Doctor? doctor)
        {
            if (doctor == null) return false;
            
            // Allow access if status is active/trialing
            if (doctor.SubscriptionStatus == "active" || doctor.SubscriptionStatus == "trialing")
                return true;
                
            // Allow access if status is canceled but we are still within the paid period
            if (doctor.SubscriptionStatus == "canceled" && doctor.SubscriptionEndDate.HasValue && doctor.SubscriptionEndDate.Value > DateTime.UtcNow)
                return true;
                
            return false;
        }

        private async Task<DoctorAgentAssignment> CreateAssignmentAsync(
            string doctorId, string doctorName, string specialization,
            string mode, string status, string source, string triggeredBy)
        {
            var (primary, sub) = GetAutoAssignedAgent(specialization);

            var assignment = new DoctorAgentAssignment
            {
                Id = ObjectId.GenerateNewId().ToString(),
                DoctorId = doctorId,
                DoctorNameSnapshot = doctorName,
                PrimaryAgent = primary,
                SubAgent = sub,
                Mode = mode,
                Status = status,
                IsArchived = false,
                Source = source,
                AssignedAt = DateTime.UtcNow,
                LastStatusChangedAt = DateTime.UtcNow,
                IsSubscriptionEligible = status == "Active",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            if (status == "Active")
            {
                assignment.ApprovedAt = DateTime.UtcNow;
            }

            await _assignments.InsertOneAsync(assignment);

            await EmitEventAsync(doctorId, assignment.Id, "Created", "", status, triggeredBy, source);

            return assignment;
        }

        private async Task EmitEventAsync(
            string doctorId, string assignmentId, string eventType,
            string oldStatus, string newStatus, string triggeredBy, string triggerSource)
        {
            var evt = new DoctorAgentAssignmentEvent
            {
                Id = ObjectId.GenerateNewId().ToString(),
                DoctorId = doctorId,
                AssignmentId = assignmentId,
                EventType = eventType,
                OldStatus = oldStatus,
                NewStatus = newStatus,
                TriggeredBy = triggeredBy,
                TriggerSource = triggerSource,
                CreatedAt = DateTime.UtcNow
            };

            await _events.InsertOneAsync(evt);
        }

        // Auto-assign agent based on specialization (same logic as existing AIAgent.razor).
        private (string Primary, string Sub) GetAutoAssignedAgent(string specialization)
        {
            if (string.IsNullOrEmpty(specialization)) return ("Ophthalmologist", "");

            var spec = specialization.ToLower();

            if (spec.Contains("ophthalmolog") || spec.Contains("eye"))
            {
                if (spec.Contains("glaucoma"))
                    return ("Ophthalmologist", "Glaucoma");
                if (spec.Contains("retina") || spec.Contains("diabetic"))
                    return ("Ophthalmologist", "Diabetic Retinopathy");
                return ("Ophthalmologist", "");
            }
            if (spec.Contains("optometr"))
                return ("Optometrist", "");
            if (spec.Contains("optician"))
                return ("Optician", "");
            if (spec.Contains("ocular"))
                return ("Ocularist", "");

            return ("Ophthalmologist", ""); // Default for eye care
        }

        // Create required MongoDB indexes. Call once during startup.
        public async Task EnsureIndexesAsync()
        {
            var assignmentIndexes = new List<CreateIndexModel<DoctorAgentAssignment>>
            {
                new CreateIndexModel<DoctorAgentAssignment>(
                    Builders<DoctorAgentAssignment>.IndexKeys
                        .Ascending(a => a.DoctorId)
                        .Descending(a => a.UpdatedAt)),
                new CreateIndexModel<DoctorAgentAssignment>(
                    Builders<DoctorAgentAssignment>.IndexKeys
                        .Ascending(a => a.Status)
                        .Ascending(a => a.Mode)),
                new CreateIndexModel<DoctorAgentAssignment>(
                    Builders<DoctorAgentAssignment>.IndexKeys
                        .Ascending(a => a.IsArchived)
                        .Descending(a => a.UpdatedAt))
            };
            await _assignments.Indexes.CreateManyAsync(assignmentIndexes);

            // Audit event index
            var eventIndexes = new List<CreateIndexModel<DoctorAgentAssignmentEvent>>
            {
                new CreateIndexModel<DoctorAgentAssignmentEvent>(
                    Builders<DoctorAgentAssignmentEvent>.IndexKeys
                        .Ascending(e => e.DoctorId)
                        .Descending(e => e.CreatedAt))
            };
            await _events.Indexes.CreateManyAsync(eventIndexes);
        }
    }
}
