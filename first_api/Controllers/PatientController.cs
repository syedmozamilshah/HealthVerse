using System;
using System.Collections.Generic;
using System.Linq;
using System.Globalization;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using first_api.Entities.PatientModel;
using first_api.Entities.UserModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.VitalDto;
using first_api.Entities.NotificationModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

// M-6 VITALS ENTRY FOR PATIENTS
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PatientController : ControllerBase
    {
        private readonly IMongoCollection<PatientModel> _patient;
        private readonly IMongoCollection<AppointmentModel> _appointments;
        private readonly IMongoCollection<User> _users;
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly NotificationService _notificationService;

        public PatientController(MongodbService mongoDbService, NotificationService notificationService)
        {
            _patient = mongoDbService.Database?.GetCollection<PatientModel>("patient")!;
            _appointments = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _notificationService = notificationService;
        }

// M-7 API FOR GETTING THE DATA FROM DATABASE
        [HttpGet("patientAllData")]
        public async Task<IActionResult> GetAllPatientData()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);
            PatientResponse response = new PatientResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }
            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var patientCursor = await _patient.FindAsync(filter);
                var patient = await patientCursor.FirstOrDefaultAsync();

                // Auto-create patient record if it doesn't exist
                if (patient == null)
                {
                    Console.WriteLine($"Creating new patient record for userId: {userId}");
                    patient = new PatientModel
                    {
                        PersonalInfoId = userId,
                        History = "",
                        Vitals = new Vitals
                        {
                            BloodPressure = new List<BloodPressure>(),
                            SugarLevel = new List<SugarLevel>(),
                            LastUpdated = DateTime.Now
                        }
                    };
                    await _patient.InsertOneAsync(patient);
                    Console.WriteLine($"Created patient record for userId: {userId}");
                }
                response.IsSuccess = true;
                response.Message = "user vitals fetched";
                response.Patient = patient;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }


        [HttpGet("patientData")]
        public async Task<IActionResult> GetData()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);
            VitalResponse response = new VitalResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }
            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var patientCursor = await _patient.FindAsync(filter);
                var patient = await patientCursor.FirstOrDefaultAsync();

                // Auto-create patient record if it doesn't exist
                if (patient == null)
                {
                    Console.WriteLine($"Creating new patient record for userId: {userId}");
                    patient = new PatientModel
                    {
                        PersonalInfoId = userId,
                        History = "",
                        InitialConditions = "",
                        Allergy = "",
                        IsVerified = true,
                        Vitals = new Vitals
                        {
                            BloodPressure = new List<BloodPressure>(),
                            SugarLevel = new List<SugarLevel>(),
                            LastUpdated = DateTime.Now
                        }
                    };
                    await _patient.InsertOneAsync(patient);
                }
                response.IsSuccess = true;
                response.Message = "user vitals fetched";
                response.Vitals = patient.Vitals;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        [HttpPost("addVitals")]
        public async Task<IActionResult> AddVitals([FromBody] VitalDtos vitals)
        {
            var currentTime = DateTime.UtcNow;
            Console.WriteLine($"[Vitals Entry] ⏰ Current UTC time: {currentTime:yyyy-MM-dd HH:mm:ss}");
            
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            PatientResponse response = new PatientResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }
            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var patientCursor = await _patient.FindAsync(filter);
                var patient = await patientCursor.FirstOrDefaultAsync();

                if (patient == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found ";
                    return StatusCode(404, response);
                }
                Console.WriteLine(patient.Vitals.BloodPressure);
                Console.WriteLine(patient.Vitals.SugarLevel);
                if (patient.Vitals == null)
                {
                    patient.Vitals = new Vitals();
                }
                patient.Vitals.BloodPressure.Add(new BloodPressure
                {
                    Systolic = vitals.BloodPressure.Systolic,
                    Diastolic = vitals.BloodPressure.Diastolic,
                    Date = vitals.BloodPressure.Date
                });
                patient.Vitals.SugarLevel.Add(new SugarLevel
                {
                    Fasting = vitals.SugarLevel.Fasting,
                    AfterTwoHours = vitals.SugarLevel.AfterTwoHours,
                    Random = vitals.SugarLevel.Random,
                    Date = vitals.SugarLevel.Date
                });
                patient.Vitals.LastUpdated = vitals.SugarLevel.Date;
                patient.Vitals.LastLoggedDate = DateTime.UtcNow.Date;
                Console.WriteLine("added");

                var update = Builders<PatientModel>.Update.Set(x => x.Vitals, patient.Vitals);
                await _patient.UpdateOneAsync(filter, update);

                Console.WriteLine($"[Vitals Entry] ✅ Vitals saved successfully for user {userId}");

                // Send immediate confirmation notification
                Console.WriteLine($"[Vitals Entry] 📤 Sending confirmation notification...");
                await SendVitalsConfirmationNotification(userId);

                response.IsSuccess = true;
                response.Message = "Vitals added successfully";
                response.Patient = patient;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        


        [HttpPost("addBp")]
        public async Task<IActionResult> AddBp([FromBody] BloodPressure bp)
        {
            Console.WriteLine("Bp hit");
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            PatientResponse response = new PatientResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(404, response);
            }

            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var patient = await _patient.Find(filter).FirstOrDefaultAsync();

                // Auto-create patient record if it doesn't exist
                if (patient == null)
                {
                    Console.WriteLine($"Creating new patient record for userId: {userId}");
                    patient = new PatientModel
                    {
                        PersonalInfoId = userId,
                        History = "",
                        InitialConditions = "",
                        Allergy = "",
                        IsVerified = true,
                        Vitals = new Vitals
                        {
                            BloodPressure = new List<BloodPressure>(),
                            SugarLevel = new List<SugarLevel>(),
                            LastUpdated = DateTime.Now
                        }
                    };
                    await _patient.InsertOneAsync(patient);
                }

                patient.Vitals ??= new Vitals
                {
                    BloodPressure = new List<BloodPressure>(),
                    SugarLevel = new List<SugarLevel>(),
                    LastUpdated = DateTime.Now
                };

                patient.Vitals.BloodPressure.Add(new BloodPressure
                {
                    Systolic = bp.Systolic,
                    Diastolic = bp.Diastolic,
                    Date = bp.Date
                });

                patient.Vitals.LastUpdated = DateTime.Now;

                var update = Builders<PatientModel>.Update.Set(x => x.Vitals, patient.Vitals);
                await _patient.UpdateOneAsync(filter, update);

                response.IsSuccess = true;
                response.Message = "Blood pressure added successfully";
                response.Patient = patient;
                return Ok(response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }
        [HttpPost("addSugar")]
        public async Task<IActionResult> AddSugar([FromBody] SugarLevel sugar)
        {
            Console.WriteLine("sugar hit");
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            PatientResponse response = new PatientResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(404, response);
            }

            try
            {
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, userId);
                var patient = await _patient.Find(filter).FirstOrDefaultAsync();

                // Auto-create patient record if it doesn't exist
                if (patient == null)
                {
                    Console.WriteLine($"Creating new patient record for userId: {userId}");
                    patient = new PatientModel
                    {
                        PersonalInfoId = userId,
                        History = "",
                        InitialConditions = "",
                        Allergy = "",
                        IsVerified = true,
                        Vitals = new Vitals
                        {
                            BloodPressure = new List<BloodPressure>(),
                            SugarLevel = new List<SugarLevel>(),
                            LastUpdated = DateTime.Now
                        }
                    };
                    await _patient.InsertOneAsync(patient);
                }

                patient.Vitals ??= new Vitals
                {
                    BloodPressure = new List<BloodPressure>(),
                    SugarLevel = new List<SugarLevel>(),
                    LastUpdated = DateTime.Now
                };

                var existingSugar = patient.Vitals.SugarLevel
                    .FirstOrDefault(s => s.Date.Date == sugar.Date.Date);

                if (existingSugar != null)
                {
                    if (sugar.Fasting.HasValue) existingSugar.Fasting = sugar.Fasting;
                    if (sugar.AfterTwoHours.HasValue) existingSugar.AfterTwoHours = sugar.AfterTwoHours;
                    if (sugar.Random.HasValue) existingSugar.Random = sugar.Random;

                    response.Message = "Sugar level updated successfully";
                }
                else
                {
                    patient.Vitals.SugarLevel.Add(new SugarLevel
                    {
                        Fasting = sugar.Fasting,
                        AfterTwoHours = sugar.AfterTwoHours,
                        Random = sugar.Random,
                        Date = sugar.Date
                    });

                    response.Message = "Sugar level added successfully";
                }

                patient.Vitals.LastUpdated = DateTime.Now;

                var update = Builders<PatientModel>.Update.Set(x => x.Vitals, patient.Vitals);
                await _patient.UpdateOneAsync(filter, update);

                response.IsSuccess = true;
                response.Patient = patient;
                return Ok(response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Get all appointments for the logged-in patient
        [HttpGet("my-appointments")]
        public async Task<IActionResult> GetMyAppointments()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            Console.WriteLine($"GetMyAppointments called for userId: {userId}");

            if (string.IsNullOrWhiteSpace(userId))
            {
                return StatusCode(401, new { isSuccess = false, message = "Unauthorized" });
            }

            try
            {
                // Get all appointments for this patient
                var appointmentFilter = Builders<AppointmentModel>.Filter.Eq(x => x.PatientId, userId);
                var appointments = await _appointments.Find(appointmentFilter)
                    .SortByDescending(a => a.AppointmentDate)
                    .ToListAsync();

                Console.WriteLine($"Found {appointments.Count} appointments for patient {userId}");

                // Auto-mark past pending/confirmed appointments as Missed
                var now = DateTime.UtcNow;
                foreach (var appt in appointments)
                {
                    var statusLower = appt.Status?.ToLowerInvariant() ?? string.Empty;
                    if (statusLower == "pending" || statusLower == "confirmed")
                    {
                        // Check if appointment time has passed
                        var appointmentEndTime = appt.SlotEndTime ?? appt.AppointmentDate.AddHours(1);
                        if (appointmentEndTime < now)
                        {
                            // Mark as Missed
                            var updateFilter = Builders<AppointmentModel>.Filter.Eq(a => a.Id, appt.Id);
                            var update = Builders<AppointmentModel>.Update
                                .Set(a => a.Status, "Missed");
                            await _appointments.UpdateOneAsync(updateFilter, update);
                            appt.Status = "Missed"; // Update local object too
                            Console.WriteLine($"Appointment {appt.Id} marked as Missed (time passed)");

                            // Enqueue missed-appointment notifications for both patient and doctor (Phase 5)
                            await EnqueueMissedAppointmentNotificationsAsync(appt);
                        }
                    }
                }

                var appointmentDtos = new List<PatientAppointmentDto>();

                foreach (var appointment in appointments)
                {
                    // Get doctor info
                    var doctor = await _doctors.Find(d => d.Id == appointment.DoctorId).FirstOrDefaultAsync();
                    Console.WriteLine($"Looking for DoctorId: {appointment.DoctorId}, Found: {doctor != null}, DoctorName: {doctor?.Name}");
                    var doctorUser = doctor != null 
                        ? await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync()
                        : null;

                    var dto = new PatientAppointmentDto
                    {
                        Id = appointment.Id,
                        DoctorId = appointment.DoctorId,
                        DoctorName = doctor?.Name ?? "Unknown Doctor",
                        DoctorSpecialty = doctor?.Speciality ?? "",
                        DoctorImageUrl = doctorUser?.ProfileImage ?? "",
                        AppointmentDate = appointment.AppointmentDate,
                        SlotStartTime = appointment.SlotStartTime,
                        SlotEndTime = appointment.SlotEndTime,
                        Status = appointment.Status,
                        Diagnosis = appointment.Diagnosis,
                        Symptoms = appointment.Symptoms?.Select(s => new SymptomDto 
                        { 
                            Description = s.Description, 
                            Duration = s.Duration 
                        }).ToList() ?? new List<SymptomDto>(),
                        Prescriptions = appointment.Prescriptions?.Select(p => new PrescriptionDto
                        {
                            MedicineName = p.MedicineName,
                            Dosage = p.Dosage,
                            Frequency = p.Frequency,
                            Duration = p.Duration,
                            Instructions = p.Instructions
                        }).ToList() ?? new List<PrescriptionDto>()
                    };

                    appointmentDtos.Add(dto);
                }

                return Ok(new 
                { 
                    isSuccess = true, 
                    message = "Appointments fetched successfully",
                    data = appointmentDtos
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in GetMyAppointments: {ex.Message}");
                return StatusCode(500, new { isSuccess = false, message = $"An error occurred: {ex.Message}" });
            }
        }

        // Phase 5: Enqueue missed-appointment notifications for BOTH patient and doctor (idempotent via RelatedId)
        private async Task EnqueueMissedAppointmentNotificationsAsync(AppointmentModel appt)
        {
            try
            {
                var relatedId = $"appt-miss:{appt.Id}";

                // Load doctor to get a nicer body and get doctor user id for FCM
                var doctor = await _doctors.Find(d => d.Id == appt.DoctorId).FirstOrDefaultAsync();
                var patient = await _patient.Find(p => p.PersonalInfoId == appt.PatientId).FirstOrDefaultAsync();
                var doctorName = doctor?.Name ?? "your doctor";
                var patientName = patient?.Name ?? "patient";

                var payloadPatient = System.Text.Json.JsonSerializer.Serialize(new
                {
                    title = "Missed Appointment",
                    body = $"You missed your appointment with Dr. {doctorName}.",
                    data = new { appointmentId = appt.Id, doctorId = appt.DoctorId }
                });

                var payloadDoctor = System.Text.Json.JsonSerializer.Serialize(new
                {
                    title = "Patient Missed Appointment",
                    body = $"Patient {patientName} missed the scheduled appointment.",
                    data = new { appointmentId = appt.Id, patientId = appt.PatientId }
                });

                var patientLog = new NotificationLog
                {
                    UserId = appt.PatientId,
                    Type = "appointment_missed",
                    RelatedId = relatedId + ":patient",
                    Payload = payloadPatient,
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending"
                };

                var doctorLog = new NotificationLog
                {
                    // NotificationService resolves FCM tokens by user id; doctor table stores PersonalInfoId (user id)
                    UserId = doctor?.PersonalInfoId ?? appt.DoctorId,
                    Type = "appointment_missed",
                    RelatedId = relatedId + ":doctor",
                    Payload = payloadDoctor,
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending"
                };

                // Idempotent inserts
                var existsPatient = await _notificationLogs.Find(n => n.RelatedId == patientLog.RelatedId).FirstOrDefaultAsync();
                if (existsPatient == null) await _notificationLogs.InsertOneAsync(patientLog);

                var existsDoctor = await _notificationLogs.Find(n => n.RelatedId == doctorLog.RelatedId).FirstOrDefaultAsync();
                if (existsDoctor == null) await _notificationLogs.InsertOneAsync(doctorLog);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MissedAppt Notify] error: {ex.Message}");
            }
        }

        private async Task SendVitalsConfirmationNotification(string userId)
        {
            try
            {
                Console.WriteLine($"[Vitals Entry] ⏰ Current UTC time: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}");
                
                // Create immediate notification
                var notification = new NotificationLog
                {
                    UserId = userId,
                    Type = "vitals_confirmation",
                    Status = "pending",
                    ScheduledFor = DateTime.UtcNow,
                    Payload = System.Text.Json.JsonSerializer.Serialize(new 
                    { 
                        title = "Vitals Recorded", 
                        body = "Your vitals have been recorded successfully."
                    })
                };

                await _notificationLogs.InsertOneAsync(notification);
                
                // Process immediately
                Console.WriteLine($"[Vitals Entry] 📤 Sending confirmation notification...");
                await _notificationService.ProcessPendingNotificationsAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Vitals Entry] ❌ Error sending confirmation notification: {ex.Message}");
            }
        }
    }

    // DTOs for patient appointments
    public class PatientAppointmentDto
    {
        public string Id { get; set; } = string.Empty;
        public string DoctorId { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public string DoctorSpecialty { get; set; } = string.Empty;
        public string DoctorImageUrl { get; set; } = string.Empty;
        public DateTime AppointmentDate { get; set; }
        public DateTime? SlotStartTime { get; set; }
        public DateTime? SlotEndTime { get; set; }
        public string Status { get; set; } = string.Empty;
        public string Diagnosis { get; set; } = string.Empty;
        public List<SymptomDto> Symptoms { get; set; } = new();
        public List<PrescriptionDto> Prescriptions { get; set; } = new();
    }

    public class SymptomDto
    {
        public string Description { get; set; } = string.Empty;
        public string Duration { get; set; } = string.Empty;
    }

    public class PrescriptionDto
    {
        public string MedicineName { get; set; } = string.Empty;
        public string Dosage { get; set; } = string.Empty;
        public string Frequency { get; set; } = string.Empty;
        public string Duration { get; set; } = string.Empty;
        public string Instructions { get; set; } = string.Empty;
    }
}