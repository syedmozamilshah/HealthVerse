using System;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;

// M-1 USED FOR VERIFICATON RESPONSE AND REQUEST SENDING

namespace first_api.Entities.DoctorModel
{
    // DTO for submitting verification documents
    
    public class SubmitVerificationDto
    {
        [FromForm(Name = "cnic_front_image")]
        public IFormFile? CnicFrontImage { get; set; }

        [FromForm(Name = "cnic_back_image")]
        public IFormFile? CnicBackImage { get; set; }

        [FromForm(Name = "mbbs_image")]
        public IFormFile? MbbsImage { get; set; }

        [FromForm(Name = "fcps_image")]
        public IFormFile? FcpsImage { get; set; }

        [FromForm(Name = "license_image")]
        public IFormFile? LicenseImage { get; set; }

        [FromForm(Name = "LicenceNumber")]
        public string LicenceNumber { get; set; } = string.Empty;

        [FromForm(Name = "Specialization")]
        public string Specialization { get; set; } = string.Empty;
    }

    // DTO for updating verification documents (re-upload)
    public class UpdateVerificationDocumentsDto
    {
        [FromForm(Name = "cnic_front_image")]
        public IFormFile? CnicFrontImage { get; set; }

        [FromForm(Name = "cnic_back_image")]
        public IFormFile? CnicBackImage { get; set; }

        [FromForm(Name = "mbbs_image")]
        public IFormFile? MbbsImage { get; set; }

        [FromForm(Name = "fcps_image")]
        public IFormFile? FcpsImage { get; set; }

        [FromForm(Name = "license_image")]
        public IFormFile? LicenseImage { get; set; }
    }

    // DTO for re-verification request when updating locked fields
    public class ReVerificationRequestDto
    {
        [JsonPropertyName("licence_number")]
        public string LicenceNumber { get; set; } = string.Empty;

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;

        [JsonPropertyName("reason")]
        public string Reason { get; set; } = string.Empty;
    }

    // Response DTO for verification status
    public class VerificationStatusResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        [JsonPropertyName("isSubmittedForVerification")]
        public bool IsSubmittedForVerification { get; set; }

        [JsonPropertyName("isReVerificationRequired")]
        public bool IsReVerificationRequired { get; set; }

        [JsonPropertyName("isLicenseInfoLocked")]
        public bool IsLicenseInfoLocked { get; set; }
    }

    // Response DTO for PMDC lookup by license number
    public class PmdcLookupResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("doctorName")]
        public string DoctorName { get; set; } = string.Empty;

        [JsonPropertyName("fatherName")]
        public string FatherName { get; set; } = string.Empty;

        [JsonPropertyName("registrationNo")]
        public string RegistrationNo { get; set; } = string.Empty;

        [JsonPropertyName("qualification")]
        public string Qualification { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("dateOfRegistration")]
        public string DateOfRegistration { get; set; } = string.Empty;
    }

    // DTO for admin pending verification list
    public class PendingVerificationDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("phone")]
        public string Phone { get; set; } = string.Empty;

        [JsonPropertyName("licenceNumber")]
        public string LicenceNumber { get; set; } = string.Empty;

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;

        [JsonPropertyName("speciality")]
        public string Speciality { get; set; } = string.Empty;

        [JsonPropertyName("experience")]
        public string Experience { get; set; } = string.Empty;

        [JsonPropertyName("cnicFrontImage")]
        public string CnicFrontImage { get; set; } = string.Empty;

        [JsonPropertyName("cnicBackImage")]
        public string CnicBackImage { get; set; } = string.Empty;

        [JsonPropertyName("mbbsImage")]
        public string MbbsImage { get; set; } = string.Empty;

        [JsonPropertyName("fcpsImage")]
        public string FcpsImage { get; set; } = string.Empty;

        [JsonPropertyName("licenseImage")]
        public string LicenseImage { get; set; } = string.Empty;

        [JsonPropertyName("isSubmittedForVerification")]
        public bool IsSubmittedForVerification { get; set; }

        [JsonPropertyName("isReVerificationRequired")]
        public bool IsReVerificationRequired { get; set; }

        [JsonPropertyName("verificationType")]
        public string VerificationType { get; set; } = string.Empty; // "first" or "re-verification"

        [JsonPropertyName("submittedAt")]
        public DateTime SubmittedAt { get; set; }

        // PMDC Verification Status
        [JsonPropertyName("isPmdcVerified")]
        public bool IsPmdcVerified { get; set; }

        [JsonPropertyName("pmdcVerificationMessage")]
        public string PmdcVerificationMessage { get; set; } = string.Empty;

        [JsonPropertyName("pmdcVerifiedName")]
        public string PmdcVerifiedName { get; set; } = string.Empty;

        [JsonPropertyName("pmdcVerificationDate")]
        public DateTime? PmdcVerificationDate { get; set; }
    }

    // Response for pending verification list
    public class PendingVerificationListResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public List<PendingVerificationDto>? Data { get; set; }

        [JsonPropertyName("totalCount")]
        public int TotalCount { get; set; }
    }

    // Admin action response
    public class AdminActionResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
    }
}
