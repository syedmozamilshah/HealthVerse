using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities;
using first_api.Entities.DoctorModel;
using first_api.Entities.UserModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using first_api.Entities.StripeModel;

using MongoDB.Driver;


// M-4 USED FOR SHOWING THE DOCTOR TO PATIENT ON THE BASIS OF SPECIALITY, AVAILABILITY AND ACTIVE SUBSCRIPTION

namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DoctorBasicInfoController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;

        private readonly IMongoCollection<DoctorSubscription> _subscriptions;


        public DoctorBasicInfoController(MongodbService mongoDbService)
        {
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _subscriptions = mongoDbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions")!;
        }

        [HttpGet("available/{speciality}")]
        public async Task<IActionResult> GetDoctors(string speciality)
        {
            DoctorResponse response = new DoctorResponse();

            try
            {
                DateTime now = DateTime.UtcNow;
                DateTime today = now.Date;

                Console.WriteLine("========== GetDoctors START ==========");
                Console.WriteLine($"Speciality: {speciality}");
                Console.WriteLine($"UTC Now: {now}");
                Console.WriteLine($"Today (UTC): {today}");

                //Fetch doctors
                var doctorList = await _doctors.Find(d =>
                    d.IsAvailable &&
                    d.IsVerified &&
                    d.Speciality.ToLower() == speciality.ToLower()
                ).ToListAsync();

                Console.WriteLine($"Doctors found (basic filter): {doctorList.Count}");

                if (!doctorList.Any())
                {
                    Console.WriteLine("No doctors after basic filter");

                    response.IsSuccess = true;
                    response.Message = "No doctors available at this time";
                    response.doctorDtos = new List<DoctorDtos>();
                    return Ok(response);
                }

                foreach (var d in doctorList)
                {
                    Console.WriteLine($"Doctor: {d.Id} | {d.Name ?? "N/A"} | Speciality={d.Speciality}");
                }

                // Fetch active subscriptions
                var activeSubscriptions = await _subscriptions.Find(s =>
                    // s.SubscriptionStatus.ToLower() == "active" &&
                    // s.NextPaymentDate >= now &&
                    s.IsPaymentCurrent &&
                    s.CurrentPeriodStart <= now &&
                    s.CurrentPeriodEnd >= now 
                    // s.CanceledAt == null
                ).ToListAsync();

                Console.WriteLine($"Active subscriptions found: {activeSubscriptions.Count}");

                foreach (var s in activeSubscriptions)
                {
                    Console.WriteLine($"Subscription → DoctorId={s.DoctorId}, Status={s.SubscriptionStatus}, PeriodEnd={s.CurrentPeriodEnd}");
                }

                var activeDoctorIds = activeSubscriptions
                    .Select(s => s.DoctorId.ToString())
                    .ToHashSet();

                //  Match doctors with subscriptions
                var subscribedDoctors = doctorList
                    .Where(d => activeDoctorIds.Contains(d.Id))
                    .ToList();

                Console.WriteLine($"Doctors with active subscription: {subscribedDoctors.Count}");

                if (!subscribedDoctors.Any())
                {
                    Console.WriteLine("No doctors matched active subscriptions");

                    response.IsSuccess = true;
                    response.Message = "No doctors available at this time";
                    response.doctorDtos = new List<DoctorDtos>();
                    return Ok(response);
                }

                //  Filter by availability
                var filteredDoctors = subscribedDoctors.Where(doc =>
                {
                    Console.WriteLine($"Checking availability for Doctor: {doc.Id}");

                    if (doc.DailyAvailabilities == null || doc.DailyAvailabilities.Count == 0)
                    {
                        Console.WriteLine("  → No daily availabilities set (ACCEPTED)");
                        return true;
                    }

                    return doc.DailyAvailabilities.Any(day =>
                    {
                        Console.WriteLine($"  Day: {day.Date.Date}");

                        if (day.Date.Date < today)
                        {
                            Console.WriteLine("    Past day");
                            return false;
                        }

                        if (day.Slots == null || day.Slots.Count == 0)
                        {
                            Console.WriteLine("    No slots defined (ACCEPTED)");
                            return true;
                        }

                        var freeSlots = day.Slots.Count(s => !s.IsBooked);
                        Console.WriteLine($"    Slots: {day.Slots.Count}, Free: {freeSlots}");

                        return freeSlots > 0;
                    });
                }).ToList();

                Console.WriteLine($"Doctors after availability filter: {filteredDoctors.Count}");

                if (!filteredDoctors.Any())
                {
                    Console.WriteLine("No doctors with valid future availability");

                    response.IsSuccess = true;
                    response.Message = "No doctors available at this time";
                    response.doctorDtos = new List<DoctorDtos>();
                    return Ok(response);
                }

                // Fetch users
                var userIds = filteredDoctors.Select(d => d.PersonalInfoId).ToList();
                var usersList = await _users.Find(u => userIds.Contains(u.Id)).ToListAsync();

                Console.WriteLine($"Users fetched: {usersList.Count}");

                // Build DTO
                var result = (from doc in filteredDoctors
                            join user in usersList on doc.PersonalInfoId equals user.Id
                            select new DoctorDtos
                            {
                                Id = doc.Id,
                                FirstName = user.FirstName,
                                LastName = user.LastName,
                                Email = user.Email,
                                WhatsappNo = user.WhatsappNo,
                                IsAvailable = doc.IsAvailable,
                                Speciality = doc.Speciality,
                                Experience = doc.Experience,
                                Fee = doc.Fee,
                                ImageUrl = doc.ImageUrl,
                                Specialization = doc.Specialization,
                                ClinicLocation = doc.ClinicInfo.Location,
                                MorningStartTime = doc.AvailableTimeMorning?.StartTime.ToString("HH:mm") ?? "",
                                MorningEndTime = doc.AvailableTimeMorning?.EndTime.ToString("HH:mm") ?? "",
                                DailyAvailabilities = doc.DailyAvailabilities ?? new List<DayAvailability>()
                            }).ToList();

                Console.WriteLine($"Final doctor DTO count: {result.Count}");
                Console.WriteLine("========== GetDoctors END ==========");

                response.IsSuccess = true;
                response.Message = "Following are the lists";
                response.doctorDtos = result;
                return Ok(response);
            }
            catch (Exception ex)
            {
                Console.WriteLine("EXCEPTION in GetDoctors");
                Console.WriteLine(ex);

                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        [HttpGet("get/{id}")]
        public async Task<IActionResult> GetDoctorById(string id)
        {
            DoctorResponse response = new DoctorResponse();
            try
            {
                var doctor = await _doctors.Find(d => d.Id == id).FirstOrDefaultAsync();
                if (doctor == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Doctor not found";
                    return StatusCode(404, response);
                }

                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();
                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User details not found";
                    return StatusCode(404, response);
                }

                var doctorDto = new DoctorDtos
                {
                    Id = doctor.Id,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    Email = user.Email,
                    WhatsappNo = user.WhatsappNo,
                    IsAvailable = doctor.IsAvailable,
                    Speciality = doctor.Speciality,
                    Experience = doctor.Experience,
                    Fee = doctor.Fee,
                    ImageUrl = doctor.ImageUrl,
                    Specialization = doctor.Specialization,
                    ClinicLocation = doctor.ClinicInfo.Location,
                    MorningStartTime = doctor.AvailableTimeMorning.StartTime.ToString("HH:mm"),
                    MorningEndTime = doctor.AvailableTimeMorning.EndTime.ToString("HH:mm"),
                    DailyAvailabilities = doctor.DailyAvailabilities ?? new List<DayAvailability>()
                };

                response.IsSuccess = true;
                response.Message = "Doctor details fetched";
                response.doctorDtos = new List<DoctorDtos> { doctorDto };
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Debug endpoint to list all doctors
        [HttpGet("all")]
        public async Task<IActionResult> GetAllDoctors()
        {
            try
            {
                if (_doctors == null)
                {
                    return Ok(new { count = 0, message = "Doctor collection not found", doctors = new List<object>() });
                }
                
                var allDoctors = await _doctors.Find(_ => true).ToListAsync();
                
                if (allDoctors == null || !allDoctors.Any())
                {
                    return Ok(new { count = 0, message = "No doctors in database", doctors = new List<object>() });
                }
                
                var result = allDoctors.Select(d => new {
                    d.Id,
                    d.Speciality,
                    d.IsAvailable,
                    d.IsVerified,
                    d.HasPaidFirstSubscription,
                    d.SubscriptionStatus,
                    d.AvailabilityDate,
                    MorningStart = d.AvailableTimeMorning?.StartTime,
                    MorningEnd = d.AvailableTimeMorning?.EndTime
                }).ToList();
                
                return Ok(new { count = result.Count, doctors = result });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message, stack = ex.StackTrace });
            }
        }
    }
}