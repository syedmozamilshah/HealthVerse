using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.NotificationModel;
using first_api.Entities.PatientModel;
using first_api.Entities.UserModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;

namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]

    public class DoctorController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<AppointmentModel> _appointments;
        private readonly IMongoCollection<User> _users;
        private readonly IMongoCollection<PatientModel> _patient;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly CloudinaryService _cloudinaryService;

        private readonly SlotsHelperService _slotsHelperService = new SlotsHelperService();


        public DoctorController(MongodbService mongoDbService, CloudinaryService cloudinaryService)
        {
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _appointments = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _patient = mongoDbService.Database?.GetCollection<PatientModel>("patient")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _slotsHelperService = new SlotsHelperService();
            _cloudinaryService = cloudinaryService;
        }

        // M-2 USED FOR DOCTOR PROFILE MANAGEMENT

        [HttpGet("get/profile")]
        public async Task<IActionResult> GetProfile()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);
            DoctorResponse response = new DoctorResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Invalid user identity. Please log out and log back in.";
                return Unauthorized(response);
            }
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var userCursor = await _doctors.FindAsync(filter);
                var user = await userCursor.FirstOrDefaultAsync();

                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = $"Doctor profile not found for userId: {userId}";
                    return StatusCode(404, response);
                }
                response.IsSuccess = true;
                response.Message = "user fetched";
                response.doctor = user;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // M-2 USED FOR UPDATING OF DOCTOR PROFILE MANAGEMENT
        [HttpPost("profile/update")]
        public async Task<IActionResult> UpdateUser([FromForm] UpdateDoctorDtos profile, [FromServices] CloudinaryService cloudinaryService)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            DoctorResponse response = new DoctorResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Invalid user identity. Please log out and log back in.";
                return Unauthorized(response);
            }
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var user = _doctors.Find(filter).FirstOrDefault();

                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found ";
                    return StatusCode(404, response);
                }
                Console.WriteLine(profile.LicenceNumber);
                if (profile.LicenceNumber != "")
                {
                    user.LicenceNumber = profile.LicenceNumber;
                }
                if (profile.Speciality != "")
                {
                    user.Speciality = profile.Speciality;
                }
                if (profile.ClinicInfo.Location != "")
                {
                    user.ClinicInfo.Location = profile.ClinicInfo.Location;
                }
                if (profile.Specialization != "")
                {
                    user.Specialization = profile.Specialization;
                }
                if (profile.Experience != "")
                {
                    user.Experience = profile.Experience;
                }
                if (profile.AvailableTimeMorning.StartTime != user.AvailableTimeMorning.StartTime)
                {
                    user.AvailableTimeMorning.StartTime = profile.AvailableTimeMorning.StartTime;
                }
                if (profile.AvailableTimeMorning.EndTime != user.AvailableTimeMorning.EndTime)
                {
                    user.AvailableTimeMorning.EndTime = profile.AvailableTimeMorning.EndTime;
                }
                if (profile.DailyAvailabilities != null && profile.DailyAvailabilities.Count > 0)
                {
                    foreach (var day in profile.DailyAvailabilities)
                    {
                        day.Slots = _slotsHelperService.GenerateSlots(day.StartTime, day.EndTime);
                    }

                    user.DailyAvailabilities = profile.DailyAvailabilities;
                }

                if (profile.Fee != "")
                {
                    user.Fee = profile.Fee;
                }
                if (profile.Speciality != "")
                {
                    user.Experience = profile.Experience;
                }
                user.IsAvailable = profile.IsAvailable;
                Console.WriteLine($"user: checking user profile image");
                if (profile.ImageUrl != null)
                {
                    Console.WriteLine($"profile image: {profile.ImageUrl}");
                    var imageUrl = await cloudinaryService.UploadImageAsync(profile.ImageUrl);
                    if (!string.IsNullOrEmpty(imageUrl))
                        user.ImageUrl = imageUrl;
                }

                await _doctors.ReplaceOneAsync(filter, user);
                response.IsSuccess = true;
                response.Message = "User update" + userId;
                response.ImageUrl = user.ImageUrl;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

// --------------------------------------------------------------------------------------------------------------------------


// M-8 USED FOR DOCTOR TO GET APPOINTMENTS
        [HttpGet("get/appointments")]
        public async Task<IActionResult> GetAppointments()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine(userId);
            Console.WriteLine(email);
            AppointmentDtosResponse response = new AppointmentDtosResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Invalid user identity. Please log out and log back in.";
                return Unauthorized(response);
            }
            try
            {
                System.Console.WriteLine(userId);

                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var userCursor = await _doctors.FindAsync(filter);
                var user = await userCursor.FirstOrDefaultAsync();
                Console.WriteLine(user.LicenceNumber);

                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found ";
                    Console.WriteLine("not geettting the urser");
                    return StatusCode(404, response);
                }
                Console.WriteLine($"Filter DoctorId: {user.Id}");


                var appointmentFilter = Builders<AppointmentModel>.Filter.Eq(x => x.DoctorId, user.Id);
                var appointmentCursor = await _appointments.FindAsync(appointmentFilter);
                var appointments = await appointmentCursor.ToListAsync();
                System.Console.WriteLine(appointments.Count);
                System.Console.WriteLine("got the appointments");
                
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
                
                if (appointments.Count == 0)
                {
                    response.IsSuccess = true;
                    response.Message = "No appointments found";
                    Console.WriteLine("no users found");
                    response.AppointmentDtos = new List<AppointmentModelDtos>();
                    return StatusCode(200, response);
                }
                var appointmentDtos = new List<AppointmentModelDtos>();

                foreach (var appointment in appointments)
                {
                    Console.WriteLine($"Processing appointment ID: {appointment.Id}");
                    Console.WriteLine($"Appointment data: Diagnosis={appointment.Diagnosis}, Status={appointment.Status}");
                    Console.WriteLine($"Symptoms count: {appointment.Symptoms?.Count ?? 0}");
                    Console.WriteLine($"Prescriptions count: {appointment.Prescriptions?.Count ?? 0}");

                    var dto = new AppointmentModelDtos
                    {
                        Id = appointment.Id,
                        Diagnosis = appointment.Diagnosis,
                        AssignedDoctor = appointment.AssignedDoctor,
                        AppointmentDate = appointment.AppointmentDate,
                        LastVisitDate = appointment.LastVisitDate,
                        DoctorId = appointment.DoctorId,
                        PatientId = appointment.PatientId,
                        Status = appointment.Status,
                        SlotStartTime = appointment.SlotStartTime,
                        SlotEndTime = appointment.SlotEndTime,
                        Symptoms = appointment.Symptoms ?? new List<Symptoms>(),
                        Prescriptions = appointment.Prescriptions ?? new List<Prescription>(),
                        Users = new UserDto()
                    };

                    Console.WriteLine(dto.Id);
                    System.Console.WriteLine(appointment.PatientId);

                    // find patient
                    var patientFilter = Builders<User>.Filter.Eq(x => x.Id, appointment.PatientId);
                    var patientCursor = await _users.FindAsync(patientFilter);
                    var patient = await patientCursor.FirstOrDefaultAsync();

                    if (patient != null)
                    {
                        System.Console.WriteLine("patient found");
                        System.Console.WriteLine(patient.FirstName);
                        System.Console.WriteLine(patient);
                        dto.Users.Id = patient.Id;
                        dto.Users.LastName = patient.LastName;
                        dto.Users.FirstName = patient.FirstName;
                        dto.Users.ProfileImage = patient.ProfileImage;

                        System.Console.WriteLine(dto.Users.FirstName);
                        System.Console.WriteLine("patient assigned to dto");
                    }

                    appointmentDtos.Add(dto);
                    System.Console.WriteLine("appointment processed");
                    System.Console.WriteLine(appointmentDtos[0].Users.FirstName);
                    System.Console.WriteLine(appointmentDtos[0].Users.ProfileImage);
                    System.Console.WriteLine("done");
                }

                response.IsSuccess = true;
                response.Message = "appointments fetched";
                response.AppointmentDtos = appointmentDtos;
                Console.WriteLine(response.AppointmentDtos[0].LastVisitDate);
                return StatusCode(200, response);

            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                Console.WriteLine($"Exception details: {ex}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return StatusCode(500, response);
            }
        }


        [HttpGet("get/patient/{id}")]
        public async Task<ActionResult<User?>> GetById(string id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            Console.WriteLine($"GetById called with id: {id}");
            Console.WriteLine($"User ID from token: {userId}");

            PatientDtoResponse response = new PatientDtoResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Invalid user identity";
                return Unauthorized(response);
            }

            try
            {
                Console.WriteLine($"Looking for patient with PersonalInfoId: {id}");
                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, id);
                var patientCursor = await _patient.FindAsync(filter);
                var patient = await patientCursor.FirstOrDefaultAsync();

                if (patient == null)
                {
                    Console.WriteLine($"Patient not found for PersonalInfoId: {id}");
                    response.IsSuccess = false;
                    response.Message = $"Patient not found for ID: {id}";
                    return StatusCode(404, response);
                }

                Console.WriteLine($"Patient found: {patient.Id}, PersonalInfoId: {patient.PersonalInfoId}");

                var userFilter = Builders<User>.Filter.Eq(x => x.Id, patient.PersonalInfoId);
                var userCursor = await _users.FindAsync(userFilter);
                var user = await userCursor.FirstOrDefaultAsync();

                if (user == null)
                {
                    Console.WriteLine($"User not found for ID: {patient.PersonalInfoId}");
                    response.IsSuccess = false;
                    response.Message = "User details not found";
                    return StatusCode(404, response);
                }

                Console.WriteLine($"User found: {user.FirstName} {user.LastName}");

                response.IsSuccess = true;
                response.Message = "user fetched";
                response.Data = new PatientDtos
                {
                    Id = patient.PersonalInfoId,
                    History = patient.History,
                    InitialConditions = patient.InitialConditions,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    Gender = user.Gender,
                    BloodGroup = user.BloodGroup
                };

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Exception in GetById: {ex.Message}");
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Phase 5: Enqueue missed-appointment notifications for BOTH patient and doctor (idempotent via RelatedId)
        private async Task EnqueueMissedAppointmentNotificationsAsync(AppointmentModel appt)
        {
            try
            {
                var relatedId = $"appt-miss:{appt.Id}";

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
                    UserId = doctor?.PersonalInfoId ?? appt.DoctorId,
                    Type = "appointment_missed",
                    RelatedId = relatedId + ":doctor",
                    Payload = payloadDoctor,
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending"
                };

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

    }
}