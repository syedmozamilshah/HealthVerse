using System;
using System.Text.Json.Serialization;

namespace BlazorUI.Models.DoctorModel
{
    public class DoctorProfile
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        [JsonPropertyName("isSubmittedForVerification")]
        public bool IsSubmittedForVerification { get; set; }

        [JsonPropertyName("isReVerificationRequired")]
        public bool IsReVerificationRequired { get; set; }

        [JsonPropertyName("isLicenseInfoLocked")]
        public bool IsLicenseInfoLocked { get; set; }

        // Verification Documents
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

        [JsonPropertyName("licenceNumber")]
        public string LicenceNumber { get; set; } = string.Empty;

        [JsonPropertyName("personalInfoId")]
        public string PersonalInfoId { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("speciality")]
        public string Speciality { get; set; } = string.Empty;

        [JsonPropertyName("experience")]
        public string Experience { get; set; } = string.Empty;

        [JsonPropertyName("fee")]
        public string Fee { get; set; } = string.Empty;

        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; } = string.Empty;

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;

        [JsonPropertyName("isAvailable")]
        public bool IsAvailable { get; set; }

        [JsonPropertyName("clinicInfo")]
        public ClinicInfo? ClinicInfo { get; set; }

        // Subscription fields
        [JsonPropertyName("stripeCustomerId")]
        public string? StripeCustomerId { get; set; }

        [JsonPropertyName("stripeSubscriptionId")]
        public string? StripeSubscriptionId { get; set; }

        [JsonPropertyName("subscriptionStatus")]
        public string? SubscriptionStatus { get; set; }

        [JsonPropertyName("subscriptionStartDate")]
        public DateTime? SubscriptionStartDate { get; set; }

        [JsonPropertyName("subscriptionEndDate")]
        public DateTime? SubscriptionEndDate { get; set; }

        [JsonPropertyName("lastPaymentDate")]
        public DateTime? LastPaymentDate { get; set; }

        [JsonPropertyName("paymentFailedDate")]
        public DateTime? PaymentFailedDate { get; set; }

        [JsonPropertyName("hasPaidFirstSubscription")]
        public bool HasPaidFirstSubscription { get; set; }
    }

    public class ClinicInfo
    {
        [JsonPropertyName("location")]
        public string Location { get; set; } = string.Empty;
    }

    public class DoctorProfileResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("doctor")]
        public DoctorProfile? Doctor { get; set; }
    }

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
}
