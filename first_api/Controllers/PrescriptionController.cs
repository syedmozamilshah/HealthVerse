 using Microsoft.AspNetCore.Mvc;
using first_api.Data;
using MongoDB.Driver;
using MongoDB.Bson;
using first_api.Entities.PrescriptionModel;
using first_api.Entities.NotificationModel;
using first_api.Entities.UserModel;
using Microsoft.AspNetCore.Authorization;
using first_api.Services;
using FluentEmail.Core;

// M-5 PRESCRIPTION GENERATOR - GENERATION, STORING, APPOINTMENT, HISTORY UPDATE, SUMMARY GENERATION
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PrescriptionController : ControllerBase
    {
        private readonly GeminiService _geminiService;
        private readonly MongodbService _mongodbService;
        private readonly CloudinaryService _cloudinaryService;
        private readonly ILogger<PrescriptionController> _logger;
        // Phase 5: prescription-ready notifications (patient FCM + email)
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly IMongoCollection<User> _users;
        private readonly NotificationService _notificationService;
        private readonly IFluentEmail _fluentEmail;

        public PrescriptionController(
            GeminiService geminiService, 
            MongodbService mongodbService,
            CloudinaryService cloudinaryService,
            ILogger<PrescriptionController> logger,
            NotificationService notificationService,
            IFluentEmail fluentEmail)
        {
            _geminiService = geminiService;
            _mongodbService = mongodbService;
            _cloudinaryService = cloudinaryService;
            _logger = logger;
            _notificationLogs = mongodbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _users = mongodbService.Database?.GetCollection<User>("users")!;
            _notificationService = notificationService;
            _fluentEmail = fluentEmail;
        }

        private async Task NotifyPatientPrescriptionReadyAsync(
            string prescriptionId,
            string patientId,
            string patientName,
            string doctorName,
            string prescriptionUrl)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(patientId)) return;

                var relatedId = $"presc:{prescriptionId}";

                // Queue FCM notification log (picked up by the scheduler/service)
                var payload = System.Text.Json.JsonSerializer.Serialize(new
                {
                    title = "Prescription Ready",
                    body = $"Your prescription from Dr. {doctorName} is ready. Open the app to view it.",
                    data = new
                    {
                        prescriptionId = prescriptionId,
                        prescriptionUrl = prescriptionUrl ?? string.Empty,
                        type = "prescription"
                    }
                });

                var existing = await _notificationLogs.Find(n => n.RelatedId == relatedId).FirstOrDefaultAsync();
                if (existing == null)
                {
                    var log = new NotificationLog
                    {
                        UserId = patientId,
                        Type = "prescription",
                        RelatedId = relatedId,
                        Payload = payload,
                        ScheduledFor = DateTime.UtcNow,
                        Status = "pending"
                    };
                    await _notificationLogs.InsertOneAsync(log);

                    try { await _notificationService.ProcessPendingNotificationsAsync(); } catch { }
                }

                //  Send email via FluentEmail if the patient has an email on file
                try
                {
                    User? patientUser = null;
                    if (ObjectId.TryParse(patientId, out _))
                    {
                        patientUser = await _users.Find(u => u.Id == patientId).FirstOrDefaultAsync();
                    }

                    if (patientUser != null && !string.IsNullOrWhiteSpace(patientUser.Email))
                    {
                        var safeName = string.IsNullOrWhiteSpace(patientName) ? patientUser.FirstName : patientName;
                        var htmlBody = BuildPrescriptionEmailHtml(safeName, doctorName, prescriptionUrl);
                        await _fluentEmail
                            .To(patientUser.Email)
                            .Subject("ðŸ’Š Your HealthVerse Prescription is Ready")
                            .Body(htmlBody, isHtml: true)
                            .SendAsync();
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to email prescription to patient {PatientId}", patientId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "NotifyPatientPrescriptionReadyAsync failed for prescription {PrescriptionId}", prescriptionId);
            }
        }

        private static string BuildPrescriptionEmailHtml(string patientName, string doctorName, string? prescriptionUrl)
        {
            var safePatient = System.Net.WebUtility.HtmlEncode(patientName ?? "Patient");
            var safeDoctor = System.Net.WebUtility.HtmlEncode(doctorName ?? "your doctor");
            var safeUrl = System.Net.WebUtility.HtmlEncode(prescriptionUrl ?? string.Empty);
            var viewBlock = string.IsNullOrWhiteSpace(safeUrl)
                ? string.Empty
                : $"<p style='text-align:center;margin:20px 0;'><a href='{safeUrl}' style='background:#34C759;color:#ffffff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;'>View Prescription</a></p>";

            return $@"<!DOCTYPE html>
<html><head><meta charset='UTF-8'></head>
<body style='margin:0;padding:0;font-family:Arial,Helvetica,sans-serif;background:#f4f4f4;'>
  <table role='presentation' style='width:100%;border-collapse:collapse;'>
    <tr><td align='center' style='padding:24px 12px;'>
      <table role='presentation' style='width:100%;max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 14px rgba(0,0,0,.06);'>
        <tr><td style='background:#34C759;color:#ffffff;padding:20px 24px;'>
          <h2 style='margin:0;font-size:20px;'>HealthVerse</h2>
          <p style='margin:4px 0 0;font-size:14px;opacity:.95;'>Your Digital Health Companion</p>
        </td></tr>
        <tr><td style='padding:24px;color:#212529;'>
          <p style='margin:0 0 12px;'>Hi {safePatient},</p>
          <p style='margin:0 0 12px;'>Your prescription from <strong>Dr. {safeDoctor}</strong> is ready.</p>
          <p style='margin:0 0 12px;'>Open the HealthVerse app to view your medicines and dosage schedule, or tap the button below to view the uploaded prescription.</p>
          {viewBlock}
          <p style='margin:16px 0 0;color:#6c757d;font-size:13px;'>If you have questions about your prescription, please contact your doctor directly.</p>
        </td></tr>
        <tr><td style='background:#f8f9fa;padding:12px 24px;color:#6c757d;font-size:12px;text-align:center;'>
          &copy; HealthVerse
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>";
        }

        // Get Gemini AI service status including available API keys and models
        [HttpGet("ai-status")]
        public IActionResult GetAIServiceStatus()
        {
            try
            {
                var status = _geminiService.GetServiceStatus();
                return Ok(new { success = true, data = status });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting AI service status");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPost("generate")]
        public async Task<IActionResult> GeneratePrescription([FromBody] PrescriptionRequest request)
        {
            try
            {
                _logger.LogInformation("Generating prescription for patient: {PatientName}", request.PatientName);
                
                var prescription = await _geminiService.GeneratePrescriptionAsync(request);
                
                return Ok(new { success = true, data = prescription });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating prescription");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPost("save")]
        public async Task<IActionResult> SavePrescriptionToHistory([FromBody] SavePrescriptionRequest request)
        {
            try
            {
                _logger.LogInformation("Saving prescription to patient history: {PatientId}", request.PatientId);
                
                var patientsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("patient");
                var appointmentsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("appointments");
                
                // Build the history entry
                var date = DateTime.Now.ToString("dd-MM-yyyy");
                var historyEntry = $"\n\n--- Prescription ({date}) ---\n";
                historyEntry += "Diagnosis: " + (request.Diagnosis ?? "") + "\n";
                historyEntry += "Medicines: " + (request.Medicines ?? "") + "\n";
                historyEntry += "Advice: " + request.Advice + "\n";
                historyEntry += "Follow-up: " + request.FollowUp + "\n";
                historyEntry += "Summary: " + request.Summary;

                // PatientId is actually the PersonalInfoId (user's id), not the patient collection's _id
                // First try to find by personal_info_id, if not found try by _id
                var filter = Builders<BsonDocument>.Filter.Eq("personal_info_id", new ObjectId(request.PatientId));
                
                // First, get the current history
                var patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                
                // If not found by personal_info_id, try by _id
                if (patient == null)
                {
                    filter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.PatientId));
                    patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                }
                
                if (patient == null)
                {
                    _logger.LogWarning("Patient not found for ID: {PatientId}", request.PatientId);
                    return NotFound(new { success = false, message = "Patient not found" });
                }

                // Get existing history and prepend new entry so most recent is first
                var existingHistory = patient.Contains("history") ? patient["history"].AsString : "";
                var newHistory = historyEntry + existingHistory;

                var updateHistory = Builders<BsonDocument>.Update.Set("history", newHistory);
                await patientsCollection.UpdateOneAsync(filter, updateHistory);
                _logger.LogInformation("Updated patient history successfully");

                // Update appointment status to "Completed" if AppointmentId is provided
                if (!string.IsNullOrEmpty(request.AppointmentId))
                {
                    var appointmentFilter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.AppointmentId));
                    var appointmentUpdate = Builders<BsonDocument>.Update.Set("status", "Completed");
                    await appointmentsCollection.UpdateOneAsync(appointmentFilter, appointmentUpdate);
                    _logger.LogInformation("Appointment {AppointmentId} status updated to 'Completed'", request.AppointmentId);
                }
                else
                {
                    // Try to find the most recent pending/confirmed/in-progress appointment
                    var filterBuilder = Builders<BsonDocument>.Filter;
                    var pendingFilter = filterBuilder.And(
                        filterBuilder.Eq("patient_id", new ObjectId(request.PatientId)),
                        filterBuilder.Or(
                            filterBuilder.Eq("status", "pending"),
                            filterBuilder.Eq("status", "Pending"),
                            filterBuilder.Eq("status", "confirmed"),
                            filterBuilder.Eq("status", "Confirmed"),
                            filterBuilder.Eq("status", "In-Progress"),
                            filterBuilder.Eq("status", "in-progress")
                        )
                    );
                    
                    if (!string.IsNullOrEmpty(request.DoctorId))
                    {
                        pendingFilter = filterBuilder.And(
                            pendingFilter,
                            filterBuilder.Eq("doctor_id", new ObjectId(request.DoctorId))
                        );
                    }
                    
                    var appointmentUpdate = Builders<BsonDocument>.Update.Set("status", "Completed");
                    var sort = Builders<BsonDocument>.Sort.Descending("appointment_date");
                    var matchingAppointment = await appointmentsCollection.Find(pendingFilter).Sort(sort).FirstOrDefaultAsync();

                    if (matchingAppointment != null)
                    {
                        var updateFilter = Builders<BsonDocument>.Filter.Eq("_id", matchingAppointment["_id"]);
                        await appointmentsCollection.UpdateOneAsync(updateFilter, appointmentUpdate);
                        _logger.LogInformation("Most recent pending/confirmed/in-progress appointment for patient {PatientId} updated to 'Completed'", request.PatientId);
                    }
                }

                return Ok(new { success = true, message = "Prescription saved and appointment marked as completed" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving prescription to history");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Save prescription as image to Cloudinary and store metadata in MongoDB
        [HttpPost("save-image")]
        public async Task<IActionResult> SavePrescriptionImage([FromBody] SavePrescriptionImageRequest request)
        {
            try
            {
                _logger.LogInformation("Saving prescription image for patient: {PatientId}", request.PatientId);

                if (string.IsNullOrEmpty(request.ImageBase64))
                {
                    return BadRequest(new { success = false, message = "Image data is required" });
                }

                // Upload file (image or PDF) to Cloudinary
                var prescriptionDate = DateTime.Now.ToString("dd-MM-yyyy");
                var publicId = $"prescription_{request.PatientId}_{DateTime.Now:yyyyMMddHHmmss}";
                
                var imageUrl = await _cloudinaryService.UploadBase64FileAsync(
                    request.ImageBase64, 
                    "prescriptions", 
                    publicId
                );

                if (string.IsNullOrEmpty(imageUrl))
                {
                    return StatusCode(500, new { success = false, message = "Failed to upload prescription image" });
                }

                // Save prescription document to MongoDB
                var prescriptionsCollection = _mongodbService.Database!.GetCollection<PrescriptionDocument>("prescriptions");
                
                var prescriptionDoc = new PrescriptionDocument
                {
                    PatientId = request.PatientId,
                    DoctorId = request.DoctorId ?? "",
                    DoctorName = request.DoctorName ?? "",
                    DoctorSpecialty = request.DoctorSpecialty ?? "",
                    PatientName = request.PatientName ?? "",
                    PrescriptionUrl = imageUrl,
                    FileType = "image",
                    Diagnosis = request.Diagnosis ?? "",
                    Medicines = request.Medicines ?? "",
                    Advice = request.Advice ?? "",
                    FollowUp = request.FollowUp ?? "",
                    PrescriptionDate = prescriptionDate,
                    CreatedAt = DateTime.Now
                };

                await prescriptionsCollection.InsertOneAsync(prescriptionDoc);

                _logger.LogInformation("Prescription saved successfully with URL: {Url}", imageUrl);

                // Phase 5: notify patient (FCM + email)
                await NotifyPatientPrescriptionReadyAsync(
                    prescriptionDoc.Id,
                    prescriptionDoc.PatientId,
                    prescriptionDoc.PatientName,
                    prescriptionDoc.DoctorName,
                    imageUrl);

                return Ok(new 
                { 
                    success = true, 
                    message = "Prescription saved successfully",
                    data = new 
                    {
                        prescriptionId = prescriptionDoc.Id,
                        prescriptionUrl = imageUrl,
                        prescriptionDate = prescriptionDate
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving prescription image");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Complete prescription workflow: Save image to prescriptions, generate AI summary, save summary to history
        [HttpPost("complete")]
        public async Task<IActionResult> CompletePrescription([FromBody] CompletePrescriptionRequest request)
        {
            try
            {
                _logger.LogInformation("Processing complete prescription for patient: {PatientId}", request.PatientId);

                if (string.IsNullOrEmpty(request.ImageBase64))
                {
                    return BadRequest(new { success = false, message = "Image data is required" });
                }

                var prescriptionDate = DateTime.Now.ToString("dd-MM-yyyy");

                // Step 1: Upload file (image or PDF) to Cloudinary
                var publicId = $"prescription_{request.PatientId}_{DateTime.Now:yyyyMMddHHmmss}";
                var imageUrl = await _cloudinaryService.UploadBase64FileAsync(
                    request.ImageBase64, 
                    "prescriptions", 
                    publicId
                );

                if (string.IsNullOrEmpty(imageUrl))
                {
                    return StatusCode(500, new { success = false, message = "Failed to upload prescription file" });
                }
                _logger.LogInformation("Prescription file uploaded: {Url}", imageUrl);

                // Determine file type
                var fileType = request.ImageBase64?.StartsWith("data:application/pdf") == true ? "pdf" : "image";

                // Step 2: Save prescription to prescriptions collection
                var prescriptionsCollection = _mongodbService.Database!.GetCollection<PrescriptionDocument>("prescriptions");
                var prescriptionDoc = new PrescriptionDocument
                {
                    PatientId = request.PatientId ?? "",
                    DoctorId = request.DoctorId ?? "",
                    DoctorName = request.DoctorName ?? "",
                    DoctorSpecialty = request.DoctorSpecialty ?? "",
                    PatientName = request.PatientName ?? "",
                    PrescriptionUrl = imageUrl,
                    FileType = fileType,
                    Diagnosis = request.Diagnosis ?? "",
                    Medicines = request.Medicines ?? "",
                    Advice = request.Advice ?? "",
                    FollowUp = request.FollowUp ?? "",
                    PrescriptionDate = prescriptionDate,
                    CreatedAt = DateTime.Now
                };
                await prescriptionsCollection.InsertOneAsync(prescriptionDoc);
                _logger.LogInformation("Prescription saved to collection");

                // Phase 5: notify patient (FCM + email) - fire early so notification reaches user even if summary generation fails later
                await NotifyPatientPrescriptionReadyAsync(
                    prescriptionDoc.Id,
                    prescriptionDoc.PatientId,
                    prescriptionDoc.PatientName,
                    prescriptionDoc.DoctorName,
                    imageUrl);

                // Step 3: Generate AI summary using Gemini
                var summaryRequest = new PrescriptionSummaryRequest
                {
                    PatientSymptoms = request.PatientSymptoms,
                    Diagnosis = request.Diagnosis,
                    Medicines = request.Medicines,
                    Tests = request.Tests,
                    Advice = request.Advice,
                    FollowUp = request.FollowUp
                };
                var summary = await _geminiService.GeneratePrescriptionSummaryAsync(summaryRequest);
                _logger.LogInformation("Generated summary: {Summary}", summary);

                // Step 4: Save summary to patient history
                var patientsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("patient");
                var appointmentsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("appointments");

                // Build history entry with summary
                var historyEntry = $"\n\n--- Consultation ({prescriptionDate}) ---\n";
                historyEntry += $"Summary: {summary}\n";

                // Find patient by personal_info_id
                var filter = Builders<BsonDocument>.Filter.Eq("personal_info_id", new ObjectId(request.PatientId));
                var patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                
                if (patient == null)
                {
                    filter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.PatientId));
                    patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                }

                if (patient != null)
                {
                    // Prepend new entry so most recent is first
                    var existingHistory = patient.Contains("history") ? patient["history"].AsString : "";
                    var newHistory = historyEntry + existingHistory;
                    var updateHistory = Builders<BsonDocument>.Update.Set("history", newHistory);
                    await patientsCollection.UpdateOneAsync(filter, updateHistory);
                    _logger.LogInformation("Updated patient history with summary");
                }

                // Step 5: Update appointment status to "completed"
                if (!string.IsNullOrEmpty(request.AppointmentId))
                {
                    var appointmentFilter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.AppointmentId));
                    var appointmentUpdate = Builders<BsonDocument>.Update.Set("status", "completed");
                    await appointmentsCollection.UpdateOneAsync(appointmentFilter, appointmentUpdate);
                    _logger.LogInformation("Appointment status updated to completed");
                }
                else
                {
                    // Try to find today's pending/confirmed appointment
                    var today = DateTime.Now.Date;
                    var tomorrow = today.AddDays(1);
                    var filterBuilder = Builders<BsonDocument>.Filter;
                    var pendingFilter = filterBuilder.And(
                        filterBuilder.Eq("patient_id", new ObjectId(request.PatientId)),
                        filterBuilder.Or(
                            filterBuilder.Eq("status", "pending"),
                            filterBuilder.Eq("status", "Pending"),
                            filterBuilder.Eq("status", "confirmed"),
                            filterBuilder.Eq("status", "Confirmed")
                        ),
                        filterBuilder.Gte("appointment_date", today),
                        filterBuilder.Lt("appointment_date", tomorrow)
                    );
                    
                    if (!string.IsNullOrEmpty(request.DoctorId))
                    {
                        pendingFilter = filterBuilder.And(
                            pendingFilter,
                            filterBuilder.Eq("doctor_id", new ObjectId(request.DoctorId))
                        );
                    }
                    
                    var appointmentUpdate = Builders<BsonDocument>.Update.Set("status", "completed");
                    await appointmentsCollection.UpdateOneAsync(pendingFilter, appointmentUpdate);
                }

                return Ok(new 
                { 
                    success = true, 
                    message = "Prescription completed successfully",
                    data = new 
                    {
                        prescriptionId = prescriptionDoc.Id,
                        prescriptionUrl = imageUrl,
                        prescriptionDate = prescriptionDate,
                        summary = summary
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error completing prescription");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Generate AI summary and save to patient history (called on Confirm & Generate)
        // M-7 CREATE SUMMARY 
        [HttpPost("save-summary")]
        public async Task<IActionResult> SaveSummaryToHistory([FromBody] SaveSummaryRequest request)
        {
            try
            {
                _logger.LogInformation("Generating and saving summary for patient: {PatientId}", request.PatientId);

                var prescriptionDate = DateTime.Now.ToString("dd-MM-yyyy");

                // Step 1: Generate AI summary using Gemini
                var summaryRequest = new PrescriptionSummaryRequest
                {
                    PatientSymptoms = request.PatientSymptoms,
                    Diagnosis = request.Diagnosis,
                    Medicines = request.Medicines,
                    Tests = request.Tests,
                    Advice = request.Advice,
                    FollowUp = request.FollowUp
                };
                var summary = await _geminiService.GeneratePrescriptionSummaryAsync(summaryRequest);
                _logger.LogInformation("Generated summary: {Summary}", summary);

                // Step 2: Save summary to patient history
                var patientsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("patient");

                var historyEntry = $"\n\n--- Consultation ({prescriptionDate}) ---\n";
                historyEntry += $"Summary: {summary}\n";

                var filter = Builders<BsonDocument>.Filter.Eq("personal_info_id", new ObjectId(request.PatientId ?? ""));
                var patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                
                if (patient == null)
                {
                    filter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.PatientId));
                    patient = await patientsCollection.Find(filter).FirstOrDefaultAsync();
                }

                if (patient != null)
                {
                    // Prepend new entry so most recent is first
                    var existingHistory = patient.Contains("history") ? patient["history"].AsString : "";
                    var newHistory = historyEntry + existingHistory;
                    var updateHistory = Builders<BsonDocument>.Update.Set("history", newHistory);
                    await patientsCollection.UpdateOneAsync(filter, updateHistory);
                    _logger.LogInformation("Updated patient history with summary");
                }

                return Ok(new 
                { 
                    success = true, 
                    message = "Summary saved to history",
                    data = new 
                    {
                        summary = summary,
                        date = prescriptionDate
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving summary to history");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Save prescription image and mark appointment complete (called on Send)
        [HttpPost("save-prescription-image")]
        public async Task<IActionResult> SavePrescriptionImageAndComplete([FromBody] SavePrescriptionImageCompleteRequest request)
        {
            try
            {
                _logger.LogInformation("Saving prescription image for patient: {PatientId}", request.PatientId);

                if (string.IsNullOrEmpty(request.ImageBase64))
                {
                    return BadRequest(new { success = false, message = "Image data is required" });
                }

                var prescriptionDate = DateTime.Now.ToString("dd-MM-yyyy");

                // Step 1: Upload file (image or PDF) to Cloudinary
                var publicId = $"prescription_{request.PatientId}_{DateTime.Now:yyyyMMddHHmmss}";
                var imageUrl = await _cloudinaryService.UploadBase64FileAsync(
                    request.ImageBase64, 
                    "prescriptions", 
                    publicId
                );

                if (string.IsNullOrEmpty(imageUrl))
                {
                    return StatusCode(500, new { success = false, message = "Failed to upload prescription file" });
                }
                _logger.LogInformation("Prescription file uploaded: {Url}", imageUrl);

                // Determine file type from base64 data
                var fileType = request.ImageBase64?.StartsWith("data:application/pdf") == true ? "pdf" : "image";

                // Step 2: Save prescription to prescriptions collection
                var prescriptionsCollection = _mongodbService.Database!.GetCollection<PrescriptionDocument>("prescriptions");
                
                // Calculate end dates for medicine items
                var medicineItems = new List<MedicineItem>();
                if (request.MedicineItems != null && request.MedicineItems.Count > 0)
                {
                    foreach (var item in request.MedicineItems)
                    {
                        var morningTimeUtc = string.IsNullOrWhiteSpace(item.MorningTimeUtc) && item.Morning
                            ? "04:00" // 9:00 AM PKT
                            : item.MorningTimeUtc;
                        var afternoonTimeUtc = string.IsNullOrWhiteSpace(item.AfternoonTimeUtc) && item.Afternoon
                            ? "09:00" // 2:00 PM PKT
                            : item.AfternoonTimeUtc;
                        var eveningTimeUtc = string.IsNullOrWhiteSpace(item.EveningTimeUtc) && item.Evening
                            ? "13:00" // 6:00 PM PKT
                            : item.EveningTimeUtc;
                        var nightTimeUtc = string.IsNullOrWhiteSpace(item.NightTimeUtc) && item.Night
                            ? "16:00" // 9:00 PM PKT
                            : item.NightTimeUtc;

                        medicineItems.Add(new MedicineItem
                        {
                            Name = item.Name,
                            Dosage = item.Dosage,
                            Frequency = GetFrequencyDisplay(item.Morning, item.Afternoon, item.Evening, item.Night),
                            DurationDays = item.DurationDays,
                            Morning = item.Morning,
                            MorningTimeUtc = morningTimeUtc ?? string.Empty,
                            Afternoon = item.Afternoon,
                            AfternoonTimeUtc = afternoonTimeUtc ?? string.Empty,
                            Evening = item.Evening,
                            EveningTimeUtc = eveningTimeUtc ?? string.Empty,
                            Night = item.Night,
                            NightTimeUtc = nightTimeUtc ?? string.Empty,
                            StartDate = DateTime.Now,
                            EndDate = DateTime.Now.AddDays(item.DurationDays),
                            Instructions = item.Instructions
                        });
                    }
                }

                var prescriptionDoc = new PrescriptionDocument
                {
                    PatientId = request.PatientId,
                    DoctorId = request.DoctorId ?? "",
                    DoctorName = request.DoctorName ?? "",
                    DoctorSpecialty = request.DoctorSpecialty ?? "",
                    PatientName = request.PatientName ?? "",
                    PrescriptionUrl = imageUrl,
                    FileType = fileType,
                    Diagnosis = request.Diagnosis ?? "",
                    Medicines = request.Medicines ?? "",
                    Advice = request.Advice ?? "",
                    FollowUp = request.FollowUp ?? "",
                    PrescriptionDate = prescriptionDate,
                    CreatedAt = DateTime.Now,
                    MedicineItems = medicineItems,
                    IsActive = medicineItems.Count > 0
                };
                await prescriptionsCollection.InsertOneAsync(prescriptionDoc);
                _logger.LogInformation("Prescription saved to collection with {Count} medicine items", medicineItems.Count);

                // Phase 5: notify patient (FCM + email)
                await NotifyPatientPrescriptionReadyAsync(
                    prescriptionDoc.Id,
                    prescriptionDoc.PatientId,
                    prescriptionDoc.PatientName,
                    prescriptionDoc.DoctorName,
                    imageUrl);

                // Step 3: Update appointment status to "Completed" and add embedded prescription
                var appointmentsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("appointments");
                
                var appointmentPrescriptions = new BsonArray();
                if (medicineItems != null && medicineItems.Count > 0)
                {
                    foreach (var m in medicineItems)
                    {
                        appointmentPrescriptions.Add(new BsonDocument
                        {
                            { "medicine_name", m.Name },
                            { "dosage", m.Dosage },
                            { "frequency", m.Frequency },
                            { "duration", m.DurationDays.ToString() + " Days" },
                            { "instructions", m.Instructions ?? "" }
                        });
                    }
                }
                else if (!string.IsNullOrWhiteSpace(request.Medicines))
                {
                    // Fallback to storing the raw string as one item so it shows up in history
                    appointmentPrescriptions.Add(new BsonDocument
                    {
                        { "medicine_name", request.Medicines },
                        { "dosage", "-" },
                        { "frequency", "-" },
                        { "duration", "-" },
                        { "instructions", "See generated prescription text" }
                    });
                }
                
                // Update Patient History Text
                try
                {
                    var patientsCollection = _mongodbService.Database!.GetCollection<BsonDocument>("patient");
                    var pId = new ObjectId(request.PatientId);
                    var patientFilter = Builders<BsonDocument>.Filter.Or(
                        Builders<BsonDocument>.Filter.Eq("_id", pId),
                        Builders<BsonDocument>.Filter.Eq("personal_info_id", pId)
                    );
                    var patientDoc = await patientsCollection.Find(patientFilter).FirstOrDefaultAsync();

                    if (patientDoc != null)
                    {
                        var historyEntry = $"\n\n--- Consultation ({DateTime.UtcNow:yyyy-MM-dd}) ---\n";
                        historyEntry += $"Diagnosis: {(string.IsNullOrWhiteSpace(request.Diagnosis) ? "-" : request.Diagnosis)}\n";
                        var medsStr = (medicineItems != null && medicineItems.Count > 0)
                            ? string.Join(", ", medicineItems.Select(m => $"{m.Name} ({m.Dosage})"))
                            : request.Medicines ?? "-";
                        historyEntry += $"Medicines: {medsStr}\n";
                        historyEntry += $"Advice: {(string.IsNullOrWhiteSpace(request.Advice) ? "-" : request.Advice)}\n";
                        historyEntry += $"Follow-up: {(string.IsNullOrWhiteSpace(request.FollowUp) ? "-" : request.FollowUp)}\n";

                        var existingHistory = patientDoc.Contains("history") ? patientDoc["history"].AsString : "";
                        var newHistory = historyEntry + existingHistory;

                        var updateHistory = Builders<BsonDocument>.Update.Set("history", newHistory);
                        await patientsCollection.UpdateOneAsync(patientFilter, updateHistory);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error updating patient history: {ex.Message}");
                }

                if (!string.IsNullOrEmpty(request.AppointmentId))
                {
                    var appointmentFilter = Builders<BsonDocument>.Filter.Eq("_id", new ObjectId(request.AppointmentId));
                    var appointmentUpdate = Builders<BsonDocument>.Update
                        .Set("status", "Completed")
                        .Set("diagnosis", request.Diagnosis ?? "")
                        .Set("prescription", appointmentPrescriptions);
                    await appointmentsCollection.UpdateOneAsync(appointmentFilter, appointmentUpdate);
                    _logger.LogInformation("Appointment status updated to completed");
                }
                else
                {
                    // Try to find the most recent pending/confirmed/in-progress appointment
                    var filterBuilder = Builders<BsonDocument>.Filter;
                    var pendingFilter = filterBuilder.And(
                        filterBuilder.Eq("patient_id", new ObjectId(request.PatientId)),
                        filterBuilder.Or(
                            filterBuilder.Eq("status", "pending"),
                            filterBuilder.Eq("status", "Pending"),
                            filterBuilder.Eq("status", "confirmed"),
                            filterBuilder.Eq("status", "Confirmed"),
                            filterBuilder.Eq("status", "In-Progress"),
                            filterBuilder.Eq("status", "in-progress")
                        )
                    );
                    
                    if (!string.IsNullOrEmpty(request.DoctorId))
                    {
                        pendingFilter = filterBuilder.And(
                            pendingFilter,
                            filterBuilder.Eq("doctor_id", new ObjectId(request.DoctorId))
                        );
                    }
                    
                    var appointmentUpdate = Builders<BsonDocument>.Update
                        .Set("status", "Completed")
                        .Set("diagnosis", request.Diagnosis ?? "")
                        .Set("prescription", appointmentPrescriptions);

                    // Update the most recent matching appointment
                    var sort = Builders<BsonDocument>.Sort.Descending("appointment_date");
                    var matchingAppointment = await appointmentsCollection.Find(pendingFilter).Sort(sort).FirstOrDefaultAsync();
                    
                    if (matchingAppointment != null)
                    {
                        var updateFilter = Builders<BsonDocument>.Filter.Eq("_id", matchingAppointment["_id"]);
                        await appointmentsCollection.UpdateOneAsync(updateFilter, appointmentUpdate);
                        _logger.LogInformation("Found and updated matching appointment to Completed with prescriptions");
                    }
                    else 
                    {
                        _logger.LogWarning("Could not find a pending/confirmed/in-progress appointment to update");
                    }
                }

                return Ok(new 
                { 
                    success = true, 
                    message = "Prescription image saved successfully",
                    data = new 
                    {
                        prescriptionId = prescriptionDoc.Id,
                        prescriptionUrl = imageUrl,
                        prescriptionDate = prescriptionDate
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving prescription image");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Get all prescriptions for a patient
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetPatientPrescriptions(string patientId)
        {
            try
            {
                var prescriptionsCollection = _mongodbService.Database!.GetCollection<PrescriptionDocument>("prescriptions");
                
                var filter = Builders<PrescriptionDocument>.Filter.Eq(p => p.PatientId, patientId ?? "");
                var prescriptions = await prescriptionsCollection.Find(filter)
                    .SortByDescending(p => p.CreatedAt)
                    .ToListAsync();

                return Ok(new 
                { 
                    success = true, 
                    data = prescriptions
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching patient prescriptions");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Get all prescriptions for the currently logged-in patient
        [HttpGet("my-prescriptions")]
        [Microsoft.AspNetCore.Authorization.Authorize]
        public async Task<IActionResult> GetMyPrescriptions()
        {
            try
            {
                // Log all claims for debugging
                _logger.LogInformation("=== MY-PRESCRIPTIONS ENDPOINT CALLED ===");
                _logger.LogInformation("User claims:");
                foreach (var claim in User.Claims)
                {
                    _logger.LogInformation("Claim: {Type} = {Value}", claim.Type, claim.Value);
                }

                // Get user ID from JWT token claims - try multiple claim types
                var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                    ?? User.FindFirst("userId")?.Value
                    ?? User.FindFirst("sub")?.Value
                    ?? User.FindFirst("id")?.Value;
                
                _logger.LogInformation("Retrieved userId: {UserId}", userId);
                
                if (string.IsNullOrEmpty(userId))
                {
                    _logger.LogWarning("User ID not found in claims");
                    return Unauthorized(new { success = false, message = "User not authenticated" });
                }

                var prescriptionsCollection = _mongodbService.Database!.GetCollection<PrescriptionDocument>("prescriptions");
                
                // First, check total count of prescriptions in collection
                var totalCount = await prescriptionsCollection.CountDocumentsAsync(Builders<PrescriptionDocument>.Filter.Empty);
                _logger.LogInformation("Total prescriptions in collection: {Count}", totalCount);
                
                // List all unique patient IDs in prescriptions (for debugging)
                var allPrescriptions = await prescriptionsCollection.Find(Builders<PrescriptionDocument>.Filter.Empty).Limit(10).ToListAsync();
                foreach (var p in allPrescriptions!)
                {
                    _logger.LogInformation("Prescription in DB - PatientId: {PatientId}, PatientName: {PatientName}", p.PatientId, p.PatientName);
                }
                
                var filter = Builders<PrescriptionDocument>.Filter.Eq(p => p.PatientId, userId);
                var prescriptions = await prescriptionsCollection.Find(filter)
                    .SortByDescending(p => p.CreatedAt)
                    .ToListAsync();

                _logger.LogInformation("Found {Count} prescriptions for user {UserId}", prescriptions.Count, userId);

                return Ok(new 
                { 
                    success = true, 
                    data = prescriptions
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching user prescriptions");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Helper method to get frequency display from time flags
        private static string GetFrequencyDisplay(bool morning, bool afternoon, bool evening, bool night)
        {
            var timings = new List<string>();
            if (morning) timings.Add("Morning");
            if (afternoon) timings.Add("Afternoon");
            if (evening) timings.Add("Evening");
            if (night) timings.Add("Night");
            return timings.Count > 0 ? string.Join(", ", timings) : "As needed";
        }
    }

    public class SavePrescriptionRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? AppointmentId { get; set; }
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Usage { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string Notes { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public string Summary { get; set; } = "";
    }

    public class CompletePrescriptionRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? PatientSymptoms { get; set; }
        public string? AppointmentId { get; set; }
        public string ImageBase64 { get; set; } = string.Empty;
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
    }

    public class SaveSummaryRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? PatientSymptoms { get; set; }
        public string? AppointmentId { get; set; }
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
    }

    public class SavePrescriptionImageCompleteRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? AppointmentId { get; set; }
        public string ImageBase64 { get; set; } = string.Empty;
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public List<MedicineItemRequest>? MedicineItems { get; set; }
    }

    public class MedicineItemRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Dosage { get; set; } = string.Empty;
        public int DurationDays { get; set; } = 7;
        public bool Morning { get; set; }
        public bool Afternoon { get; set; }
        public bool Evening { get; set; }
        public bool Night { get; set; }
        public string Instructions { get; set; } = string.Empty;
        public string? MorningTimeUtc { get; set; }
        public string? AfternoonTimeUtc { get; set; }
        public string? EveningTimeUtc { get; set; }
        public string? NightTimeUtc { get; set; }
    }
}
