using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using first_api.Entities.ChatModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.PatientModel;
using first_api.Entities.UserModel;
using first_api.Hubs;
using first_api.Entities.NotificationModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using MongoDB.Driver;

// M-4 Appointment creation and session management with real-time notifications, and n8n integration
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class AppointmentController : ControllerBase
    {
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly NotificationService _notificationService;

        // M-4
        private readonly IMongoCollection<AppointmentModel> _appointmentCollection;
        private readonly IMongoCollection<AppointmentConfirmation> _confirmationCollection;

        // --------
        private readonly IMongoCollection<ChatModel> _chatCollection;
        private readonly IMongoCollection<Doctor> _doctorCollection;
        private readonly IMongoCollection<PatientModel> _patientModel;
        private readonly IMongoCollection<User> _users;
        private readonly IHubContext<AppointmentHub> _hubContext;

        public AppointmentController(MongodbService mongoDbService, IHubContext<AppointmentHub> hubContext, NotificationService notificationService)
        {
            _appointmentCollection = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
            _confirmationCollection = mongoDbService.Database?.GetCollection<AppointmentConfirmation>("appointment_confirmations")!;
            _chatCollection = mongoDbService.Database?.GetCollection<ChatModel>("chats")!;
            _doctorCollection = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _patientModel = mongoDbService.Database?.GetCollection<PatientModel>("patient")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _hubContext = hubContext;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _notificationService = notificationService;
        }

        [HttpPost("create")]
        public async Task<IActionResult> CreateAppointment([FromBody] AppointmentModel appointment)
        {

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);
            AppointmentDtosResponse response = new AppointmentDtosResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }
            if (appointment == null)
            {
                return BadRequest(new { Status = false, Message = "Invalid appointment data." });
            }

            try
            {
                Console.WriteLine($"=== Appointment Creation Started ===");
                Console.WriteLine($"Incoming DoctorId: {appointment.DoctorId}");
                Console.WriteLine($"Incoming PatientId: {appointment.PatientId}");
                Console.WriteLine($"Incoming AppointmentDate: {appointment.AppointmentDate} (Kind: {appointment.AppointmentDate.Kind})");
                Console.WriteLine($"Incoming SlotStartTime: {appointment.SlotStartTime} (Kind: {appointment.SlotStartTime?.Kind})");
                Console.WriteLine($"Incoming SlotEndTime: {appointment.SlotEndTime} (Kind: {appointment.SlotEndTime?.Kind})");
                
                // Get the doctor to check specialty
                var doctor = await _doctorCollection.Find(d => d.Id == appointment.DoctorId).FirstOrDefaultAsync();
                if (doctor == null)
                {
                    Console.WriteLine($"Doctor not found with ID: {appointment.DoctorId}");
                    return NotFound(new { Status = false, Message = "Doctor not found." });
                }
                Console.WriteLine($"Doctor found: {doctor.Id}, Specialty: {doctor.Speciality}");

                var appointmentDateOnly = appointment.AppointmentDate.Date;

                // CHECK 1: Check if user already has an appointment with any doctor of same specialty on this day
                var doctorsOfSameSpecialty = await _doctorCollection
                    .Find(d => d.Speciality == doctor.Speciality)
                    .ToListAsync();
                var doctorIdsOfSameSpecialty = doctorsOfSameSpecialty.Select(d => d.Id).ToList();

                var existingAppointmentWithSpecialty = await _appointmentCollection
                    .Find(a => a.PatientId == appointment.PatientId 
                           && doctorIdsOfSameSpecialty.Contains(a.DoctorId)
                           && a.AppointmentDate.Date == appointmentDateOnly
                           && a.Status != "Cancelled")
                    .FirstOrDefaultAsync();

                if (existingAppointmentWithSpecialty != null)
                {
                    return BadRequest(new { 
                        Status = false, 
                        Message = $"You already have an appointment with a {doctor.Speciality} on {appointmentDateOnly:MMMM dd, yyyy}. You can only book one appointment per specialty per day." 
                    });
                }

                // CHECK 2: Check if the slot is already booked by another user
                var dayAvailability = doctor.DailyAvailabilities?.FirstOrDefault(d => d.Date.Date == appointmentDateOnly);
                if (dayAvailability != null && appointment.SlotStartTime.HasValue)
                {
                    var requestedSlot = dayAvailability.Slots?.FirstOrDefault(s => 
                        s.StartTime.Hour == appointment.SlotStartTime.Value.Hour && 
                        s.StartTime.Minute == appointment.SlotStartTime.Value.Minute);
                    if (requestedSlot != null && requestedSlot.IsBooked)
                    {
                        return BadRequest(new { 
                            Status = false, 
                            Message = "This time slot is already booked. Please select another available slot." 
                        });
                    }
                }

                // All checks passed, create the appointment
                Console.WriteLine($"Creating appointment - DoctorId: {appointment.DoctorId}, PatientId: {appointment.PatientId}");
                Console.WriteLine($"Appointment Date: {appointment.AppointmentDate}, Status: {appointment.Status}");
                await _appointmentCollection.InsertOneAsync(appointment);
                Console.WriteLine($"Appointment created with ID: {appointment.Id}");

                // Check if there's an existing chat for this patient-doctor pair
                var existingChat = await _chatCollection
                    .Find(c => c.PatientId == appointment.PatientId && c.DoctorId == appointment.DoctorId)
                    .SortByDescending(c => c.UpdatedAt)
                    .FirstOrDefaultAsync();

                // Only create new chat if no existing chat exists
                if (existingChat == null)
                {
                    var chatModel = new ChatModel
                    {
                        PatientId = appointment.PatientId,
                        DoctorId = appointment.DoctorId,
                        Title = $"Chat for Appointment on {appointment.AppointmentDate:MMMM dd, yyyy}",
                        Date = DateTime.UtcNow,
                        Chats = new List<Chat>()
                    };
                    await _chatCollection.InsertOneAsync(chatModel);
                }

                // Update the slot as booked
                if (doctor.DailyAvailabilities != null && appointment.SlotStartTime.HasValue)
                {
                    Console.WriteLine($"=== Updating Slot as Booked ===");
                    Console.WriteLine($"Looking for date: {appointmentDateOnly}, Slot time: {appointment.SlotStartTime.Value}");
                    
                    bool slotUpdated = false;
                    
                    // Iterate through each day and update the matching slot
                    for (int i = 0; i < doctor.DailyAvailabilities.Count; i++)
                    {
                        var day = doctor.DailyAvailabilities[i];
                        Console.WriteLine($"Checking day: {day.Date.Date}");
                        
                        if (day.Date.Date == appointmentDateOnly && day.Slots != null && day.Slots.Count > 0)
                        {
                            Console.WriteLine($"Found matching date with {day.Slots.Count} slots");
                            
                            for (int j = 0; j < day.Slots.Count; j++)
                            {
                                var slot = day.Slots[j];
                                
                                // Compare full DateTime including date and time
                                var slotTimeUtc = slot.StartTime.ToUniversalTime();
                                var appointmentTimeUtc = appointment.SlotStartTime.Value.ToUniversalTime();
                                
                                Console.WriteLine($"Slot[{j}]: {slot.StartTime} (UTC: {slotTimeUtc}), IsBooked: {slot.IsBooked}");
                                Console.WriteLine($"Looking for: {appointment.SlotStartTime.Value} (UTC: {appointmentTimeUtc})");
                                
                                // Compare date, hour, and minute
                                bool dateMatches = slotTimeUtc.Date == appointmentTimeUtc.Date;
                                bool timeMatches = slotTimeUtc.Hour == appointmentTimeUtc.Hour && 
                                                   slotTimeUtc.Minute == appointmentTimeUtc.Minute;
                                
                                Console.WriteLine($"  Date Match: {dateMatches}, Time Match: {timeMatches}");
                                
                                if (dateMatches && timeMatches && !slot.IsBooked)
                                {
                                    day.Slots[j].IsBooked = true;
                                    day.Slots[j].UserId = appointment.PatientId;
                                    slotUpdated = true;
                                    Console.WriteLine($" SLOT BOOKED! Index {j}, Time: {slot.StartTime}");
                                    break;
                                }
                            }
                            
                            if (slotUpdated) break;
                        }
                    }

                    if (slotUpdated)
                    {
                        var update = Builders<Doctor>.Update.Set(d => d.DailyAvailabilities, doctor.DailyAvailabilities);
                        var updateResult = await _doctorCollection.UpdateOneAsync(d => d.Id == doctor.Id, update);
                        Console.WriteLine($"Database update result - Matched: {updateResult.MatchedCount}, Modified: {updateResult.ModifiedCount}");
                    }
                    else
                    {
                        Console.WriteLine($"WARNING: No matching slot found to update!");
                    }
                }

                // Get patient info for SignalR notification
                var patient = await _users.Find(u => u.Id == appointment.PatientId).FirstOrDefaultAsync();
                var patientName = patient != null ? $"{patient.FirstName} {patient.LastName}" : "Unknown";
                
                // Send real-time notification to doctor's dashboard
                await _hubContext.Clients.Group($"doctor_{appointment.DoctorId}").SendAsync("NewAppointment", new
                {
                    appointmentId = appointment.Id,
                    patientId = appointment.PatientId,
                    patientName = patientName,
                    appointmentDate = appointment.AppointmentDate,
                    slotTime = appointment.SlotStartTime,
                    status = appointment.Status
                });
                Console.WriteLine($"SignalR notification sent to doctor_{appointment.DoctorId}");

                // Send webhook notification to n8n
                try
                {
                    using var httpClient = new HttpClient();
                    var webhookData = new
                    {
                        appointmentId = appointment.Id,
                        patientId = appointment.PatientId,
                        patientName = patientName,
                        patientEmail = patient?.Email ?? "",
                        doctorId = appointment.DoctorId,
                        doctorName = doctor.Name ?? "",
                        appointmentDate = appointment.AppointmentDate,
                        slotStartTime = appointment.SlotStartTime,
                        slotEndTime = appointment.SlotEndTime,
                        status = appointment.Status,
                        createdAt = DateTime.UtcNow
                    };
                    var webhookUrl = "https://n8n-14pv.onrender.com/webhook/891d762b-10e7-4169-a4b6-d528927107f6";
                    var webhookContent = new StringContent(
                        System.Text.Json.JsonSerializer.Serialize(webhookData),
                        System.Text.Encoding.UTF8,
                        "application/json"
                    );
                    var webhookResponse = await httpClient.PostAsync(webhookUrl, webhookContent);
                    Console.WriteLine($"n8n webhook response: {webhookResponse.StatusCode}");
                }
                catch (Exception webhookEx)
                {
                    // Log but don't fail the appointment creation if webhook fails
                    Console.WriteLine($"n8n webhook error (non-critical): {webhookEx.Message}");
                }

                // Enqueue push notifications for patient (confirmation) and doctor (new booking)
                try
                {
                    var patientNotification = new NotificationLog
                    {
                        UserId = appointment.PatientId,
                        Type = "appointment_confirmation",
                        RelatedId = appointment.Id,
                        Payload = System.Text.Json.JsonSerializer.Serialize(new { title = "Appointment Confirmed", body = $"Your appointment on {appointment.AppointmentDate:MMMM dd, yyyy} has been booked." }),
                        ScheduledFor = DateTime.UtcNow,
                        Status = "pending",
                        RetryCount = 0
                    };

                    var doctorNotification = new NotificationLog
                    {
                        UserId = appointment.DoctorId,
                        Type = "new_appointment",
                        RelatedId = appointment.Id,
                        Payload = System.Text.Json.JsonSerializer.Serialize(new { title = "New Appointment", body = $"{patientName} booked an appointment on {appointment.AppointmentDate:MMMM dd, yyyy}." }),
                        ScheduledFor = DateTime.UtcNow,
                        Status = "pending",
                        RetryCount = 0
                    };

                    await _notificationLogs.InsertOneAsync(patientNotification);
                    await _notificationLogs.InsertOneAsync(doctorNotification);

                    // Try process immediately
                    try { await _notificationService.ProcessPendingNotificationsAsync(); } catch { }
                }
                catch (Exception notifyEx)
                {
                    Console.WriteLine($"Enqueue notification error: {notifyEx.Message}");
                }

                return Ok(new { Status = true, Message = "Appointment created successfully.", Data = appointment });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpPost("addInitialCondition")]
        public async Task<IActionResult> uploadAppointment([FromBody] InitialConditionRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);

            AppointmentDtosResponse response = new AppointmentDtosResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }

            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var update = Builders<PatientModel>.Update.Set(d => d.InitialConditions, request.InitialCondition);
                await _patientModel.UpdateOneAsync(filter, update);

                return Ok(new { Status = true, Message = "User condition updated successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpPost("start-session/{appointmentId}")]
        public async Task<IActionResult> StartSession(string appointmentId)
        {
            var doctorUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(doctorUserId))
                return Unauthorized(new { Status = false, Message = "Unauthorized" });

            try
            {
                var doctor = await _doctorCollection.Find(d => d.PersonalInfoId == doctorUserId).FirstOrDefaultAsync();
                if (doctor == null)
                    return NotFound(new { Status = false, Message = "Doctor not found" });

                var appointment = await _appointmentCollection.Find(a => a.Id == appointmentId && a.DoctorId == doctor.Id).FirstOrDefaultAsync();
                if (appointment == null)
                    return NotFound(new { Status = false, Message = "Appointment not found" });

                // Anti-Scam Check 1: Only allow if status is Confirmed (case-insensitive)
                var appointmentStatus = appointment.Status?.Trim();
                if (!string.Equals(appointmentStatus, "Confirmed", StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { Status = false, Message = $"Cannot start session. Current status is {appointment.Status}" });

                // Anti-Scam Check 2: Time validation (ONLY during scheduled window)
                var now = DateTime.UtcNow;
                var appointmentStart = appointment.SlotStartTime ?? appointment.AppointmentDate;
                var appointmentEnd = appointment.SlotEndTime ?? appointmentStart.AddMinutes(30);

                if (now < appointmentStart || now > appointmentEnd)
                    return BadRequest(new
                    {
                        Status = false,
                        Message = "Session can only be started during the scheduled time window.",
                        AppointmentStartUtc = appointmentStart,
                        AppointmentEndUtc = appointmentEnd
                    });

                // Update to In-Progress
                var update = Builders<AppointmentModel>.Update
                    .Set(a => a.Status, "In-Progress")
                    .Set(a => a.SessionStartedAt, DateTime.UtcNow);
                await _appointmentCollection.UpdateOneAsync(a => a.Id == appointmentId, update);

                await _hubContext.Clients.Group($"patient_{appointment.PatientId}").SendAsync("SessionStarted", new { appointmentId, startedAt = DateTime.UtcNow });

                return Ok(new { Status = true, Message = "Session started successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = ex.Message });
            }
        }

        [HttpPost("complete-session/{appointmentId}")]
        public async Task<IActionResult> CompleteSession(string appointmentId)
        {
            var doctorUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(doctorUserId))
                return Unauthorized(new { Status = false, Message = "Unauthorized" });

            try
            {
                var doctor = await _doctorCollection.Find(d => d.PersonalInfoId == doctorUserId).FirstOrDefaultAsync();
                if (doctor == null)
                    return NotFound(new { Status = false, Message = "Doctor not found" });

                var appointment = await _appointmentCollection.Find(a => a.Id == appointmentId && a.DoctorId == doctor.Id).FirstOrDefaultAsync();
                if (appointment == null)
                    return NotFound(new { Status = false, Message = "Appointment not found" });

                // Anti-Scam Check: Must be In-Progress before completing (case-insensitive)
                if (!string.Equals(appointment.Status, "In-Progress", StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { Status = false, Message = $"Cannot complete. Session must be In-Progress first. Current status: {appointment.Status}" });

                // Update to Completed (pending patient confirmation)
                var update = Builders<AppointmentModel>.Update.Set(a => a.Status, "Completed");
                await _appointmentCollection.UpdateOneAsync(a => a.Id == appointmentId, update);

                // Create confirmation record
                var confirmation = new AppointmentConfirmation
                {
                    AppointmentId = appointmentId,
                    PatientId = appointment.PatientId,
                    DoctorId = doctor.Id,
                    CompletionRequestedAt = DateTime.UtcNow,
                    PatientResponse = "Pending"
                };
                await _confirmationCollection.InsertOneAsync(confirmation);

                // Notify patient
                var patient = await _users.Find(u => u.Id == appointment.PatientId).FirstOrDefaultAsync();
                var notification = new NotificationLog
                {
                    UserId = appointment.PatientId,
                    Type = "appointment_completion",
                    RelatedId = appointmentId,
                    Payload = System.Text.Json.JsonSerializer.Serialize(new { title = "Appointment Completed", body = $"Dr. {doctor.Name} has completed your appointment. Please confirm." }),
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending"
                };
                await _notificationLogs.InsertOneAsync(notification);
                try { await _notificationService.ProcessPendingNotificationsAsync(); } catch { }

                await _hubContext.Clients.Group($"patient_{appointment.PatientId}").SendAsync("AppointmentCompleted", new { appointmentId, confirmationId = confirmation.Id });

                return Ok(new { Status = true, Message = "Appointment completed. Waiting for patient confirmation.", ConfirmationId = confirmation.Id });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = ex.Message });
            }
        }

        [HttpPost("patient-confirm/{appointmentId}")]
        public async Task<IActionResult> PatientConfirm(string appointmentId, [FromBody] PatientConfirmationRequest request)
        {
            var patientUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(patientUserId))
                return Unauthorized(new { Status = false, Message = "Unauthorized" });

            try
            {
                var patient = await _users.Find(u => u.Id == patientUserId).FirstOrDefaultAsync();
                if (patient == null)
                    return NotFound(new { Status = false, Message = "Patient not found" });

                var confirmation = await _confirmationCollection.Find(c => c.AppointmentId == appointmentId && c.PatientId == patientUserId).FirstOrDefaultAsync();
                if (confirmation == null)
                    return NotFound(new { Status = false, Message = "No pending confirmation found" });

                if (confirmation.PatientResponse != "Pending")
                    return BadRequest(new { Status = false, Message = "Already responded to this confirmation" });

                // Update confirmation
                var update = Builders<AppointmentConfirmation>.Update
                    .Set(c => c.PatientResponse, request.Response)
                    .Set(c => c.PatientRespondedAt, DateTime.UtcNow)
                    .Set(c => c.DisputeReason, request.DisputeReason ?? string.Empty)
                    .Set(c => c.ResolutionStatus, request.Response == "Disputed" ? "UnderReview" : "Resolved");
                await _confirmationCollection.UpdateOneAsync(c => c.Id == confirmation.Id, update);

                if (request.Response == "Confirmed")
                {
                    var appointmentUpdate = Builders<AppointmentModel>.Update.Set(a => a.CompletionConfirmed, true);
                    await _appointmentCollection.UpdateOneAsync(a => a.Id == appointmentId, appointmentUpdate);
                    return Ok(new { Status = true, Message = "Appointment confirmed successfully" });
                }
                else if (request.Response == "Disputed")
                {
                    // Notify admin about dispute
                    Console.WriteLine($"[DISPUTE] Appointment {appointmentId} disputed by patient. Reason: {request.DisputeReason}");
                    return Ok(new { Status = true, Message = "Dispute registered. Admin will review." });
                }

                return BadRequest(new { Status = false, Message = "Invalid response" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = ex.Message });
            }
        }

        [HttpPost("complete/{patientId}")]
        [Obsolete("Use complete-session endpoint instead")]
        public async Task<IActionResult> CompleteAppointment(string patientId)
        {
            var doctorUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(doctorUserId))
            {
                return Unauthorized(new { Status = false, Message = "Unauthorized" });
            }

            try
            {
                var doctor = await _doctorCollection.Find(d => d.PersonalInfoId == doctorUserId).FirstOrDefaultAsync();
                if (doctor == null)
                {
                    Console.WriteLine($"[CompleteAppointment] Doctor not found for PersonalInfoId: {doctorUserId}");
                    return NotFound(new { Status = false, Message = "Doctor not found" });
                }

                Console.WriteLine($"[CompleteAppointment] DoctorId: {doctor.Id}, PatientId: {patientId}");

                var filter = Builders<AppointmentModel>.Filter.And(
                    Builders<AppointmentModel>.Filter.Eq(a => a.PatientId, patientId),
                    Builders<AppointmentModel>.Filter.Eq(a => a.DoctorId, doctor.Id)
                );

                var appointmentCandidates = await _appointmentCollection.Find(filter).ToListAsync();
                var appointment = appointmentCandidates
                    .FirstOrDefault(a => string.Equals(a.Status, "In-Progress", StringComparison.OrdinalIgnoreCase));
                if (appointment == null)
                {
                    Console.WriteLine($"[CompleteAppointment] No In-Progress appointment found for patient {patientId} with doctor {doctor.Id}.");
                    return NotFound(new { Status = false, Message = "No In-Progress appointment found. Please start the session first." });
                }

                var update = Builders<AppointmentModel>.Update.Set(a => a.Status, "Completed");
                await _appointmentCollection.UpdateOneAsync(filter, update);

                Console.WriteLine($"[CompleteAppointment] Appointment {appointment.Id} marked as Completed for patient {patientId}");

                return Ok(new { Status = true, Message = "Appointment marked as completed" });
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error completing appointment: {ex.Message}");
                return StatusCode(500, new { Status = false, Message = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpPost("start/{patientId}")]
        public async Task<IActionResult> StartAppointmentByPatient(string patientId)
        {
            var doctorUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(doctorUserId))
            {
                return Unauthorized(new { Status = false, Message = "Unauthorized" });
            }

            try
            {
                var doctor = await _doctorCollection.Find(d => d.PersonalInfoId == doctorUserId).FirstOrDefaultAsync();
                if (doctor == null)
                {
                    return NotFound(new { Status = false, Message = "Doctor not found" });
                }

                // Find a confirmed appointment for this doctor and patient (prefer upcoming)
                var appointmentCandidates = await _appointmentCollection
                    .Find(a => a.PatientId == patientId && a.DoctorId == doctor.Id)
                    .SortBy(a => a.AppointmentDate)
                    .ToListAsync();

                var appointment = appointmentCandidates
                    .FirstOrDefault(a => string.Equals(a.Status, "Confirmed", StringComparison.OrdinalIgnoreCase));

                if (appointment == null)
                {
                    return NotFound(new { Status = false, Message = "No confirmed appointment found for this patient" });
                }

                // Time validation: session can only be started within scheduled time window
                var now = DateTime.UtcNow;
                var appointmentStart = appointment.SlotStartTime ?? appointment.AppointmentDate;
                var appointmentEnd = appointment.SlotEndTime ?? appointmentStart.AddMinutes(30);

                if (now < appointmentStart || now > appointmentEnd)
                    return BadRequest(new
                    {
                        Status = false,
                        Message = "Session can only be started during the scheduled time window.",
                        AppointmentStartUtc = appointmentStart,
                        AppointmentEndUtc = appointmentEnd
                    });

                var update = Builders<AppointmentModel>.Update
                    .Set(a => a.Status, "In-Progress")
                    .Set(a => a.SessionStartedAt, DateTime.UtcNow);
                await _appointmentCollection.UpdateOneAsync(a => a.Id == appointment.Id, update);

                await _hubContext.Clients.Group($"patient_{appointment.PatientId}").SendAsync("SessionStarted", new { appointmentId = appointment.Id, startedAt = DateTime.UtcNow });

                return Ok(new { Status = true, Message = "Session started successfully", AppointmentId = appointment.Id });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = ex.Message });
            }
        }

    }
    public class InitialConditionRequest
    {
        public string InitialCondition { get; set; } = string.Empty;
    }

}