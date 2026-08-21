using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AgentAssignmentModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.UserModel;
using first_api.Hubs;
using first_api.Services;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using MongoDB.Driver;

// M-9 DOCTOR VERIFICATION CONTROLLER
namespace first_api.Controllers.AdminController
{
    [Route("api/admin/[controller]")]
    [ApiController]
    [Authorize] 
    public class VerificationController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;
        private readonly IHubContext<AppointmentHub> _hubContext;
        private readonly DoctorAgentAssignmentService _assignmentService;

        public VerificationController(
            MongodbService mongoDbService, 
            IHubContext<AppointmentHub> hubContext,
            DoctorAgentAssignmentService assignmentService)
        {
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _hubContext = hubContext;
            _assignmentService = assignmentService;
        }

        // Get all pending verification requests (first-time and re-verification)
        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingVerifications()
        {
            try
            {
                // Filter doctors who are submitted for verification OR require re-verification
                var filter = Builders<Doctor>.Filter.Or(
                    Builders<Doctor>.Filter.Eq(d => d.IsSubmittedForVerification, true),
                    Builders<Doctor>.Filter.Eq(d => d.IsReVerificationRequired, true)
                );

                var pendingDoctors = await _doctors.Find(filter).ToListAsync();
                var result = new List<PendingVerificationDto>();

                foreach (var doctor in pendingDoctors)
                {
                    var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();
                    
                    var dto = new PendingVerificationDto
                    {
                        Id = user?.Id ?? string.Empty,
                        DoctorId = doctor.Id,
                        Name = user != null ? $"{user.FirstName} {user.LastName}" : doctor.Name,
                        Email = user?.Email ?? doctor.Email,
                        Phone = string.Empty,
                        LicenceNumber = doctor.LicenceNumber,
                        Specialization = doctor.Specialization,
                        Speciality = doctor.Speciality,
                        Experience = doctor.Experience,
                        CnicFrontImage = doctor.CnicFrontImage,
                        CnicBackImage = doctor.CnicBackImage,
                        MbbsImage = doctor.MbbsImage,
                        FcpsImage = doctor.FcpsImage,
                        LicenseImage = doctor.LicenseImage,
                        IsSubmittedForVerification = doctor.IsSubmittedForVerification,
                        IsReVerificationRequired = doctor.IsReVerificationRequired,
                        VerificationType = doctor.IsReVerificationRequired ? "re-verification" : "first",
                        SubmittedAt = DateTime.Now, // You might want to add a submission timestamp field
                        // PMDC Verification Status
                        IsPmdcVerified = doctor.IsPmdcVerified,
                        PmdcVerificationMessage = doctor.PmdcVerificationMessage,
                        PmdcVerifiedName = doctor.PmdcVerifiedName,
                        PmdcVerificationDate = doctor.PmdcVerificationDate
                    };

                    result.Add(dto);
                }

                return Ok(new PendingVerificationListResponse
                {
                    IsSuccess = true,
                    Message = "Pending verifications retrieved",
                    Data = result,
                    TotalCount = result.Count
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new PendingVerificationListResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Get pending first-time verifications only
        [HttpGet("pending/first")]
        public async Task<IActionResult> GetPendingFirstVerifications()
        {
            try
            {
                var filter = Builders<Doctor>.Filter.And(
                    Builders<Doctor>.Filter.Eq(d => d.IsSubmittedForVerification, true),
                    Builders<Doctor>.Filter.Eq(d => d.IsVerified, false),
                    Builders<Doctor>.Filter.Eq(d => d.IsReVerificationRequired, false)
                );

                var pendingDoctors = await _doctors.Find(filter).ToListAsync();
                var result = await MapToPendingDtos(pendingDoctors, "first");

                return Ok(new PendingVerificationListResponse
                {
                    IsSuccess = true,
                    Message = "Pending first-time verifications retrieved",
                    Data = result,
                    TotalCount = result.Count
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new PendingVerificationListResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Get pending re-verifications only
        [HttpGet("pending/reverification")]
        public async Task<IActionResult> GetPendingReVerifications()
        {
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(d => d.IsReVerificationRequired, true);
                var pendingDoctors = await _doctors.Find(filter).ToListAsync();
                var result = await MapToPendingDtos(pendingDoctors, "re-verification");

                return Ok(new PendingVerificationListResponse
                {
                    IsSuccess = true,
                    Message = "Pending re-verifications retrieved",
                    Data = result,
                    TotalCount = result.Count
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new PendingVerificationListResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Get details of a specific doctor for verification review
        [HttpGet("details/{doctorId}")]
        public async Task<IActionResult> GetDoctorVerificationDetails(string doctorId)
        {
            try
            {
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
                
                if (doctor == null)
                {
                    return NotFound(new { isSuccess = false, message = "Doctor not found" });
                }

                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();

                var dto = new PendingVerificationDto
                {
                    Id = user?.Id ?? string.Empty,
                    DoctorId = doctor.Id,
                    Name = user != null ? $"{user.FirstName} {user.LastName}" : doctor.Name,
                    Email = user?.Email ?? doctor.Email,
                    Phone = string.Empty,
                    LicenceNumber = doctor.LicenceNumber,
                    Specialization = doctor.Specialization,
                    Speciality = doctor.Speciality,
                    Experience = doctor.Experience,
                    CnicFrontImage = doctor.CnicFrontImage,
                    CnicBackImage = doctor.CnicBackImage,
                    MbbsImage = doctor.MbbsImage,
                    FcpsImage = doctor.FcpsImage,
                    LicenseImage = doctor.LicenseImage,
                    IsSubmittedForVerification = doctor.IsSubmittedForVerification,
                    IsReVerificationRequired = doctor.IsReVerificationRequired,
                    VerificationType = doctor.IsReVerificationRequired ? "re-verification" : "first"
                };

                return Ok(new { isSuccess = true, message = "Details retrieved", data = dto });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Error: " + ex.Message });
            }
        }

        // Get details of a specific pending doctor for verification review (by ID)
        [HttpGet("pending/{doctorId}")]
        public async Task<IActionResult> GetPendingDoctorDetails(string doctorId)
        {
            try
            {
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
                
                if (doctor == null)
                {
                    return NotFound(new { IsSuccess = false, Message = "Doctor not found" });
                }

                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();

                // Map to DoctorDetails format expected by admin dashboard
                var details = new
                {
                    LicenceNumber = doctor.LicenceNumber,
                    RenewalDate = doctor.RenewalDate,
                    Speciality = doctor.Speciality,
                    IsAvailable = doctor.IsAvailable,
                    ClinicInfo = doctor.ClinicInfo,
                    Experience = doctor.Experience,
                    Fee = doctor.Fee,
                    Specialization = doctor.Specialization,
                    IsSubmittedForVerification = doctor.IsSubmittedForVerification,
                    IsReVerificationRequired = doctor.IsReVerificationRequired,
                    IsLicenseInfoLocked = doctor.IsLicenseInfoLocked,
                    CNICFrontImage = doctor.CnicFrontImage,
                    CNICBackImage = doctor.CnicBackImage,
                    MBBSImage = doctor.MbbsImage,
                    FCPSImage = doctor.FcpsImage,
                    LicenseImage = doctor.LicenseImage
                };

                return Ok(new { IsSuccess = true, Message = "Details retrieved", Data = details });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { IsSuccess = false, Message = "Error: " + ex.Message });
            }
        }

        // Approve first-time verification
        [HttpPost("approve/{doctorId}")]
        public async Task<IActionResult> ApproveVerification(string doctorId)
        {
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(d => d.Id, doctorId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return NotFound(new AdminActionResponse
                    {
                        IsSuccess = false,
                        Message = "Doctor not found"
                    });
                }

                // Verify the doctor is pending first-time verification
                if (!doctor.IsSubmittedForVerification)
                {
                    return BadRequest(new AdminActionResponse
                    {
                        IsSuccess = false,
                        Message = "Doctor has not submitted for verification"
                    });
                }

                // Update verification status
                var update = Builders<Doctor>.Update
                    .Set(d => d.IsVerified, true)
                    .Set(d => d.IsSubmittedForVerification, false)
                    .Set(d => d.IsLicenseInfoLocked, true)
                    .Set(d => d.IsReVerificationRequired, false);

                await _doctors.UpdateOneAsync(filter, update);

                // Create agent assignment based on global mode
                var adminId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "admin";
                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();
                var doctorName = user != null ? $"{user.FirstName} {user.LastName}" : doctor.Name;
                var assignmentOutcome = await _assignmentService.HandleDoctorVerificationApprovedAsync(
                    doctorId, doctorName, doctor.Specialization, adminId);

                // Send notification to doctor via SignalR
                await _hubContext.Clients.Group($"doctor_{doctorId}").SendAsync("VerificationStatusChanged", new
                {
                    Status = "approved",
                    Message = "Congratulations! Your verification has been approved. You now have full access to the doctor dashboard.",
                    IsVerified = true,
                    AssignmentStatus = assignmentOutcome.AssignmentStatus,
                    AssignmentMessage = assignmentOutcome.AssignmentMessage
                });
                Console.WriteLine($"Verification approval notification sent to doctor_{doctorId}");

                return Ok(new AdminActionResponse
                {
                    IsSuccess = true,
                    Message = $"Doctor verification approved successfully. License info is now locked. Assignment: {assignmentOutcome.AssignmentMessage}"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AdminActionResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Approve re-verification request
        [HttpPost("approve-reverification/{doctorId}")]
        public async Task<IActionResult> ApproveReVerification(string doctorId)
        {
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(d => d.Id, doctorId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return NotFound(new AdminActionResponse
                    {
                        IsSuccess = false,
                        Message = "Doctor not found"
                    });
                }

                // Verify the doctor is pending re-verification
                if (!doctor.IsReVerificationRequired)
                {
                    return BadRequest(new AdminActionResponse
                    {
                        IsSuccess = false,
                        Message = "Doctor does not have a pending re-verification request"
                    });
                }

                // Approve re-verification - updated fields are already saved, just update flags
                var update = Builders<Doctor>.Update
                    .Set(d => d.IsVerified, true)
                    .Set(d => d.IsReVerificationRequired, false)
                    .Set(d => d.IsLicenseInfoLocked, true);

                await _doctors.UpdateOneAsync(filter, update);

                // Create/update agent assignment based on global mode
                var adminId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "admin";
                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();
                var doctorName = user != null ? $"{user.FirstName} {user.LastName}" : doctor.Name;
                var assignmentOutcome = await _assignmentService.HandleDoctorVerificationApprovedAsync(
                    doctorId, doctorName, doctor.Specialization, adminId);

                // Send notification to doctor via SignalR
                await _hubContext.Clients.Group($"doctor_{doctorId}").SendAsync("VerificationStatusChanged", new
                {
                    Status = "approved",
                    Message = "Your re-verification request has been approved. Your updated information is now active.",
                    IsVerified = true,
                    AssignmentStatus = assignmentOutcome.AssignmentStatus,
                    AssignmentMessage = assignmentOutcome.AssignmentMessage
                });
                Console.WriteLine($"Re-verification approval notification sent to doctor_{doctorId}");

                return Ok(new AdminActionResponse
                {
                    IsSuccess = true,
                    Message = $"Re-verification approved successfully. Assignment: {assignmentOutcome.AssignmentMessage}"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AdminActionResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Reject verification request
        [HttpPost("reject/{doctorId}")]
        public async Task<IActionResult> RejectVerification(string doctorId, [FromBody] RejectVerificationDto? dto)
        {
            try
            {
                var filter = Builders<Doctor>.Filter.Eq(d => d.Id, doctorId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return NotFound(new AdminActionResponse
                    {
                        IsSuccess = false,
                        Message = "Doctor not found"
                    });
                }

                var rejectionReason = dto?.Reason ?? "Your verification request was rejected. Please review your documents and resubmit.";

                // Reset verification status
                var update = Builders<Doctor>.Update
                    .Set(d => d.IsSubmittedForVerification, false)
                    .Set(d => d.IsReVerificationRequired, false)
                    .Set(d => d.IsVerified, false);

                await _doctors.UpdateOneAsync(filter, update);

                // Send notification to doctor via SignalR
                await _hubContext.Clients.Group($"doctor_{doctorId}").SendAsync("VerificationStatusChanged", new
                {
                    Status = "rejected",
                    Message = rejectionReason,
                    IsVerified = false
                });
                Console.WriteLine($"Verification rejection notification sent to doctor_{doctorId}");

                return Ok(new AdminActionResponse
                {
                    IsSuccess = true,
                    Message = dto?.Reason != null 
                        ? $"Verification rejected. Reason: {dto.Reason}" 
                        : "Verification rejected. Doctor can resubmit after addressing issues."
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AdminActionResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        // Get verification statistics for admin dashboard
        [HttpGet("stats")]
        public async Task<IActionResult> GetVerificationStats()
        {
            try
            {
                var totalDoctors = await _doctors.CountDocumentsAsync(_ => true);
                var verifiedDoctors = await _doctors.CountDocumentsAsync(d => d.IsVerified == true);
                var pendingFirstVerification = await _doctors.CountDocumentsAsync(d => 
                    d.IsSubmittedForVerification == true && d.IsReVerificationRequired == false);
                var pendingReVerification = await _doctors.CountDocumentsAsync(d => d.IsReVerificationRequired == true);
                var unverifiedDoctors = await _doctors.CountDocumentsAsync(d => 
                    d.IsVerified == false && d.IsSubmittedForVerification == false && d.IsReVerificationRequired == false);

                return Ok(new
                {
                    isSuccess = true,
                    data = new
                    {
                        totalDoctors,
                        verifiedDoctors,
                        pendingFirstVerification,
                        pendingReVerification,
                        unverifiedDoctors,
                        totalPending = pendingFirstVerification + pendingReVerification
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Error: " + ex.Message });
            }
        }

        private async Task<List<PendingVerificationDto>> MapToPendingDtos(List<Doctor> doctors, string verificationType)
        {
            var result = new List<PendingVerificationDto>();

            foreach (var doctor in doctors)
            {
                var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();

                result.Add(new PendingVerificationDto
                {
                    Id = user?.Id ?? string.Empty,
                    DoctorId = doctor.Id,
                    Name = user != null ? $"{user.FirstName} {user.LastName}" : doctor.Name,
                    Email = user?.Email ?? doctor.Email,
                    Phone = string.Empty,
                    LicenceNumber = doctor.LicenceNumber,
                    Specialization = doctor.Specialization,
                    Speciality = doctor.Speciality,
                    Experience = doctor.Experience,
                    CnicFrontImage = doctor.CnicFrontImage,
                    CnicBackImage = doctor.CnicBackImage,
                    MbbsImage = doctor.MbbsImage,
                    FcpsImage = doctor.FcpsImage,
                    LicenseImage = doctor.LicenseImage,
                    IsSubmittedForVerification = doctor.IsSubmittedForVerification,
                    IsReVerificationRequired = doctor.IsReVerificationRequired,
                    VerificationType = verificationType,
                    // PMDC Verification Status
                    IsPmdcVerified = doctor.IsPmdcVerified,
                    PmdcVerificationMessage = doctor.PmdcVerificationMessage,
                    PmdcVerifiedName = doctor.PmdcVerifiedName,
                    PmdcVerificationDate = doctor.PmdcVerificationDate
                });
            }

            return result;
        }
    }

    // DTO for rejection reason
    public class RejectVerificationDto
    {
        public string? Reason { get; set; }
    }
}
