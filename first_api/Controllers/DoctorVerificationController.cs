using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AgentAssignmentModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.UserModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

// M-1 FOR DOCTOR VERIFICATION, PMDC API INTEGRATION, AND AI AGENT ACCESS CONTROL
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DoctorVerificationController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;
        private readonly CloudinaryService _cloudinaryService;
        private readonly PmdcVerificationService _pmdcService;
        private readonly DoctorAgentAssignmentService _assignmentService;

        public DoctorVerificationController(
            MongodbService mongoDbService, 
            CloudinaryService cloudinaryService,
            PmdcVerificationService pmdcService,
            DoctorAgentAssignmentService assignmentService)
        {
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _cloudinaryService = cloudinaryService;
            _pmdcService = pmdcService;
            _assignmentService = assignmentService;
        }

        // Get verification status for the current doctor
        [HttpGet("status")]
        public async Task<IActionResult> GetVerificationStatus()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var response = new VerificationStatusResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(401, response);
            }

            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Doctor profile not found";
                    return StatusCode(404, response);
                }

                response.IsSuccess = true;
                response.Message = "Verification status retrieved";
                response.IsVerified = doctor.IsVerified;
                response.IsSubmittedForVerification = doctor.IsSubmittedForVerification;
                response.IsReVerificationRequired = doctor.IsReVerificationRequired;
                response.IsLicenseInfoLocked = doctor.IsLicenseInfoLocked;

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Lookup PMDC details by license number (used for auto-fetch on UI blur)
        [HttpGet("pmdc-lookup")]
        public async Task<IActionResult> LookupPmdcByLicence([FromQuery] string licenceNumber)
        {
            var response = new PmdcLookupResponse();

            if (string.IsNullOrWhiteSpace(licenceNumber))
            {
                response.IsSuccess = false;
                response.Message = "Licence number is required";
                return StatusCode(400, response);
            }

            var normalizedLicence = licenceNumber.Trim();
            if (normalizedLicence.Length != 7)
            {
                response.IsSuccess = false;
                response.Message = "Licence number must be exactly 7 characters";
                return StatusCode(400, response);
            }

            try
            {
                var pmdcResult = await _pmdcService.VerifyDoctorAsync(normalizedLicence);

                response.IsSuccess = true;
                response.IsVerified = pmdcResult.IsVerified;
                response.Message = pmdcResult.Message;
                response.DoctorName = pmdcResult.DoctorName ?? string.Empty;
                response.FatherName = pmdcResult.FatherName ?? string.Empty;
                response.RegistrationNo = pmdcResult.RegistrationNo ?? string.Empty;
                response.Qualification = pmdcResult.Qualification ?? string.Empty;
                response.Status = pmdcResult.Status ?? string.Empty;
                response.DateOfRegistration = pmdcResult.DateOfRegistration ?? string.Empty;

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Upload verification documents (CNIC, MBBS, FCPS, License images) 
        [HttpPost("upload-documents")]
        public async Task<IActionResult> UploadVerificationDocuments([FromForm] UpdateVerificationDocumentsDto dto)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var response = new VerificationStatusResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(401, response);
            }

            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Doctor profile not found";
                    return StatusCode(404, response);
                }

                // Upload documents to Cloudinary
                if (dto.CnicFrontImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.CnicFrontImage);
                    if (!string.IsNullOrEmpty(url)) doctor.CnicFrontImage = url;
                }

                if (dto.CnicBackImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.CnicBackImage);
                    if (!string.IsNullOrEmpty(url)) doctor.CnicBackImage = url;
                }

                if (dto.MbbsImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.MbbsImage);
                    if (!string.IsNullOrEmpty(url)) doctor.MbbsImage = url;
                }

                if (dto.FcpsImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.FcpsImage);
                    if (!string.IsNullOrEmpty(url)) doctor.FcpsImage = url;
                }

                if (dto.LicenseImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.LicenseImage);
                    if (!string.IsNullOrEmpty(url)) doctor.LicenseImage = url;
                }

                await _doctors.ReplaceOneAsync(filter, doctor);

                response.IsSuccess = true;
                response.Message = "Documents uploaded successfully";
                response.IsVerified = doctor.IsVerified;
                response.IsSubmittedForVerification = doctor.IsSubmittedForVerification;
                response.IsReVerificationRequired = doctor.IsReVerificationRequired;
                response.IsLicenseInfoLocked = doctor.IsLicenseInfoLocked;

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Submit for first-time verification
        [HttpPost("submit")]
        public async Task<IActionResult> SubmitForVerification([FromForm] SubmitVerificationDto dto)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var response = new VerificationStatusResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(401, response);
            }

            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Doctor profile not found";
                    return StatusCode(404, response);
                }

                // Check if already verified
                if (doctor.IsVerified)
                {
                    response.IsSuccess = false;
                    response.Message = "You are already verified";
                    return StatusCode(400, response);
                }

                // Check if already submitted
                if (doctor.IsSubmittedForVerification)
                {
                    response.IsSuccess = false;
                    response.Message = "Verification request already submitted. Please wait for admin approval.";
                    return StatusCode(400, response);
                }

                // Upload documents if provided
                if (dto.CnicFrontImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.CnicFrontImage);
                    if (!string.IsNullOrEmpty(url)) doctor.CnicFrontImage = url;
                }

                if (dto.CnicBackImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.CnicBackImage);
                    if (!string.IsNullOrEmpty(url)) doctor.CnicBackImage = url;
                }

                if (dto.MbbsImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.MbbsImage);
                    if (!string.IsNullOrEmpty(url)) doctor.MbbsImage = url;
                }

                if (dto.FcpsImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.FcpsImage);
                    if (!string.IsNullOrEmpty(url)) doctor.FcpsImage = url;
                }

                if (dto.LicenseImage != null)
                {
                    var url = await _cloudinaryService.UploadImageAsync(dto.LicenseImage);
                    if (!string.IsNullOrEmpty(url)) doctor.LicenseImage = url;
                }

                // Update licence number and specialization if provided
                if (!string.IsNullOrEmpty(dto.LicenceNumber))
                {
                    doctor.LicenceNumber = dto.LicenceNumber;
                }

                if (!string.IsNullOrEmpty(dto.Specialization))
                {
                    doctor.Specialization = dto.Specialization;
                }

                // Validate required documents
                var missingDocs = new List<string>();
                // if (string.IsNullOrEmpty(doctor.CnicFrontImage)) missingDocs.Add("CNIC Front");
                // if (string.IsNullOrEmpty(doctor.CnicBackImage)) missingDocs.Add("CNIC Back");
                if (string.IsNullOrEmpty(doctor.MbbsImage)) missingDocs.Add("MBBS Degree");
                if (string.IsNullOrEmpty(doctor.LicenseImage)) missingDocs.Add("PMDC License");
                if (string.IsNullOrEmpty(doctor.LicenceNumber)) missingDocs.Add("License Number");
                if (string.IsNullOrEmpty(doctor.Specialization)) missingDocs.Add("Specialization");

                if (missingDocs.Any())
                {
                    response.IsSuccess = false;
                    response.Message = $"Missing required fields: {string.Join(", ", missingDocs)}";
                    return StatusCode(400, response);
                }

                // Verify with PMDC API
                Console.WriteLine($"Verifying doctor with PMDC. License Number: {doctor.LicenceNumber}");
                var pmdcResult = await _pmdcService.VerifyDoctorAsync(doctor.LicenceNumber);
                
                doctor.IsPmdcVerified = pmdcResult.IsVerified;
                doctor.PmdcVerificationMessage = pmdcResult.Message;
                doctor.PmdcVerifiedName = pmdcResult.DoctorName ?? string.Empty;
                doctor.PmdcVerificationDate = DateTime.Now;

                Console.WriteLine($"PMDC Verification Result: IsVerified={pmdcResult.IsVerified}, Message={pmdcResult.Message}");

                // Submit for verification
                doctor.IsSubmittedForVerification = true;
                doctor.IsVerified = false;

                await _doctors.ReplaceOneAsync(filter, doctor);

                var pmdcStatus = pmdcResult.IsVerified 
                    ? "Your PMDC registration has been verified." 
                    : "Warning: Could not verify your PMDC registration. Admin will review manually.";

                response.IsSuccess = true;
                response.Message = $"Verification request submitted successfully. {pmdcStatus} Please wait for admin approval.";
                response.IsVerified = doctor.IsVerified;
                response.IsSubmittedForVerification = doctor.IsSubmittedForVerification;
                response.IsReVerificationRequired = doctor.IsReVerificationRequired;
                response.IsLicenseInfoLocked = doctor.IsLicenseInfoLocked;

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Submit for re-verification (when updating locked fields)
        [HttpPost("submit-reverification")]
        public async Task<IActionResult> SubmitForReVerification([FromBody] ReVerificationRequestDto dto)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var response = new VerificationStatusResponse();

            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "Unauthorized";
                return StatusCode(401, response);
            }

            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Doctor profile not found";
                    return StatusCode(404, response);
                }

                // Check if license info is locked (which means doctor is verified)
                if (!doctor.IsLicenseInfoLocked)
                {
                    response.IsSuccess = false;
                    response.Message = "You need to be verified first before requesting re-verification";
                    return StatusCode(400, response);
                }

                // Check if already pending re-verification
                if (doctor.IsReVerificationRequired)
                {
                    response.IsSuccess = false;
                    response.Message = "Re-verification request already pending. Please wait for admin approval.";
                    return StatusCode(400, response);
                }

                // Update the requested fields (temporarily store them, admin will approve)
                if (!string.IsNullOrEmpty(dto.LicenceNumber))
                {
                    doctor.LicenceNumber = dto.LicenceNumber;
                }

                if (!string.IsNullOrEmpty(dto.Specialization))
                {
                    doctor.Specialization = dto.Specialization;
                }

                // Set re-verification flags
                doctor.IsReVerificationRequired = true;
                doctor.IsVerified = false; // Revoke verified status until re-approved

                await _doctors.ReplaceOneAsync(filter, doctor);

                response.IsSuccess = true;
                response.Message = "Re-verification request submitted. Your AI Agent access has been temporarily suspended until admin approval.";
                response.IsVerified = doctor.IsVerified;
                response.IsSubmittedForVerification = doctor.IsSubmittedForVerification;
                response.IsReVerificationRequired = doctor.IsReVerificationRequired;
                response.IsLicenseInfoLocked = doctor.IsLicenseInfoLocked;

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        // Check if doctor can access AI Agent (must be verified, not pending re-verification, have active subscription, and have Active assignment)
        [HttpGet("can-access-ai-agent")]
        public async Task<IActionResult> CanAccessAIAgent()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return StatusCode(401, new AgentAccessResponse
                {
                    IsSuccess = false,
                    CanAccess = false,
                    DenialReason = "Unauthorized",
                    DenialMessage = "User not authenticated",
                    Message = "Unauthorized"
                });
            }

            try
            {
                // Get doctor profile by PersonalInfoId (userId)
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return StatusCode(404, new AgentAccessResponse
                    {
                        IsSuccess = false,
                        CanAccess = false,
                        DenialReason = "DoctorNotFound",
                        DenialMessage = "Doctor profile not found",
                        Message = "Doctor profile not found"
                    });
                }

                // Use centralized service for access evaluation (uses doctor.Id not userId)
                var accessResponse = await _assignmentService.EvaluateAccessAsync(doctor.Id);
                return StatusCode(200, accessResponse);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AgentAccessResponse
                {
                    IsSuccess = false,
                    CanAccess = false,
                    DenialReason = "Error",
                    DenialMessage = "Exception: " + ex.Message,
                    Message = "Exception: " + ex.Message
                });
            }
        }

        // Get doctor verification documents (for admin preview or doctor self-view)
        [HttpGet("documents")]
        public async Task<IActionResult> GetVerificationDocuments()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return StatusCode(401, new { isSuccess = false, message = "Unauthorized" });
            }

            try
            {
                var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
                var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

                if (doctor == null)
                {
                    return StatusCode(404, new { isSuccess = false, message = "Doctor profile not found" });
                }

                return StatusCode(200, new
                {
                    isSuccess = true,
                    message = "Documents retrieved",
                    data = new
                    {
                        cnicFrontImage = doctor.CnicFrontImage,
                        cnicBackImage = doctor.CnicBackImage,
                        mbbsImage = doctor.MbbsImage,
                        fcpsImage = doctor.FcpsImage,
                        licenseImage = doctor.LicenseImage,
                        licenceNumber = doctor.LicenceNumber,
                        specialization = doctor.Specialization
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Exception: " + ex.Message });
            }
        }
    }
}
