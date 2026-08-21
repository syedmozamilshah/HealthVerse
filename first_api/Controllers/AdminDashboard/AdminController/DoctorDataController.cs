using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using first_api.Entities.DoctorModel;
using first_api.Entities.UserModel;


// M-9 USED IN DOCTOR ACTIVITY TRACKING
namespace first_api.Controllers.AdminController
{
    [Route("api/admin/[controller]")]
    [ApiController]
    [Authorize]
    public class DoctorDataController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;

        public DoctorDataController(MongodbService mongoDbService)
        {
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
        }

        [HttpGet("info")]
        public async Task<IActionResult> GetDoctorInfo()
        {
            try
            {
                var doctors = await _doctors.Find(_ => true).ToListAsync();

                var doctorInfo = new List<object>();

                foreach (var doctor in doctors)
                {
                    var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();

                    if (user != null)
                    {
                        doctorInfo.Add(new
                        {
                            id = user.Id,
                            doctorId = doctor.Id,
                            name = $"{user.FirstName} {user.LastName}",
                            email = user.Email,
                            accountStatus = user.AccountStatus ?? (doctor.IsVerified ? "Active" : "Pending")
                        });
                    }
                }

                return Ok(new
                {
                    isSuccess = true,
                    data = doctorInfo
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching doctor info: " + ex.Message
                });
            }
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetDoctorCount()
        {
            try
            {
                var totalCount = await _doctors.CountDocumentsAsync(_ => true);
                var verifiedCount = await _doctors.CountDocumentsAsync(d => d.IsVerified == true);
                var unverifiedCount = await _doctors.CountDocumentsAsync(d => d.IsVerified == false);

                return Ok(new
                {
                    isSuccess = true,
                    data = new
                    {
                        totalDoctors = totalCount,
                        verifiedDoctors = verifiedCount,
                        unverifiedDoctors = unverifiedCount
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching doctor count: " + ex.Message
                });
            }
        }

        [HttpGet("details")]
        public async Task<IActionResult> GetDoctorDetails([FromQuery] string email)
        {
            try
            {
                if (string.IsNullOrEmpty(email))
                {
                    return BadRequest(new
                    {
                        isSuccess = false,
                        message = "Email is required"
                    });
                }

                var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync();

                if (user == null)
                {
                    return NotFound(new
                    {
                        isSuccess = false,
                        message = "User not found"
                    });
                }

                var doctor = await _doctors.Find(d => d.PersonalInfoId == user.Id).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return NotFound(new
                    {
                        isSuccess = false,
                        message = "Doctor not found"
                    });
                }

                return Ok(new
                {
                    isSuccess = true,
                    data = new
                    {
                        licenceNumber = doctor.LicenceNumber,
                        renewalDate = doctor.RenewalDate,
                        speciality = doctor.Speciality,
                        isAvailable = doctor.IsAvailable,
                        clinicInfo = doctor.ClinicInfo,
                        experience = doctor.Experience,
                        fee = doctor.Fee,
                        specialization = doctor.Specialization
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching doctor details: " + ex.Message
                });
            }
        }
    }
}
