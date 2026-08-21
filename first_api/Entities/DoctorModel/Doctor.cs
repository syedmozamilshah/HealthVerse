using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

// M-1 USED IN AUTH CONTROLLER FOR DOCTOR 
// M-1 USED IN DOCTOR CONTROLLER FOR DOCTOR AND ALSO IN DOCTOR VERIFICATION CONTROLLER
// M-4 USED IN APPOINTMENT CONTROLLER FOR DOCTOR AVAILABILITY AND ALSO IN DOCTOR CONTROLLER FOR DOCTOR AVAILABILITY
// M-4 USED IN DOCTOR BASIC INFO CONTROLLER
// M-8 USED IN CHAT CONTROLLER FOR CHAT FOR SPECIFIC PATIENT
// M-9 USED IN DOCTOR VERIFICATION CONTROLLER
// M-9 USED IN DOCTOR ACTIVITY TRACKING
// M-1O USED IN STRIPE SERVICE
namespace first_api.Entities.DoctorModel
{
    [BsonIgnoreExtraElements]
    public class Doctor
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("is_verified"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        [BsonElement("is_submitted_for_verification"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isSubmittedForVerification")]
        public bool IsSubmittedForVerification { get; set; }

        [BsonElement("is_re_verification_required"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isReVerificationRequired")]
        public bool IsReVerificationRequired { get; set; }

        [BsonElement("is_license_info_locked"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isLicenseInfoLocked")]
        public bool IsLicenseInfoLocked { get; set; }

        // PMDC Verification Status
        [BsonElement("is_pmdc_verified"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isPmdcVerified")]
        public bool IsPmdcVerified { get; set; }

        [BsonElement("pmdc_verification_message"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("pmdcVerificationMessage")]
        public string PmdcVerificationMessage { get; set; } = string.Empty;

        [BsonElement("pmdc_verified_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("pmdcVerifiedName")]
        public string PmdcVerifiedName { get; set; } = string.Empty;

        [BsonElement("pmdc_verification_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("pmdcVerificationDate")]
        public DateTime? PmdcVerificationDate { get; set; }

        // Verification Document URLs
        [BsonElement("cnic_front_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("cnicFrontImage")]
        public string CnicFrontImage { get; set; } = string.Empty;

        [BsonElement("cnic_back_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("cnicBackImage")]
        public string CnicBackImage { get; set; } = string.Empty;

        [BsonElement("mbbs_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("mbbsImage")]
        public string MbbsImage { get; set; } = string.Empty;

        [BsonElement("fcps_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("fcpsImage")]
        public string FcpsImage { get; set; } = string.Empty;

        [BsonElement("license_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("licenseImage")]
        public string LicenseImage { get; set; } = string.Empty;

        [BsonElement("licence_number"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("licenceNumber")]
        public string LicenceNumber { get; set; } = string.Empty;

        [BsonElement("personal_info_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("personalInfoId")]
        public string PersonalInfoId { get; set; } = string.Empty;

        [BsonElement("name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [BsonElement("email"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [BsonElement("renewal_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("renewalDate")]
        public DateTime RenewalDate { get; set; }

        [BsonElement("speciality"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("speciality")]
        public string Speciality { get; set; } = string.Empty;

        [BsonElement("availability_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("availabilityDate")]
        public DateTime AvailabilityDate { get; set; }

        [BsonElement("is_available"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isAvailable")]
        public bool IsAvailable { get; set; }



        [BsonElement("available_time_morning")]
        [JsonPropertyName("availableTimeMorning")]
        public AvailableTime AvailableTimeMorning { get; set; } = new AvailableTime();

        [BsonElement("clinic_info")]
        [JsonPropertyName("clinicInfo")]
        public ClinicInfo ClinicInfo { get; set; } = new ClinicInfo();

        [BsonElement("experience"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("experience")]
        public string Experience { get; set; } = string.Empty;

        [BsonElement("fee"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("fee")]
        public string Fee { get; set; }=string.Empty; 

        [BsonElement("image_url"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; } = string.Empty;

        [BsonElement("specialization"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;
        
        [BsonElement("daily_availabilities")]
        [JsonPropertyName("dailyAvailabilities")]
        public List<DayAvailability> DailyAvailabilities { get; set; } = new();

        // Stripe Subscription Fields
        [BsonElement("stripe_customer_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripeCustomerId")]
        public string StripeCustomerId { get; set; } = string.Empty;

        [BsonElement("stripe_subscription_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripeSubscriptionId")]
        public string StripeSubscriptionId { get; set; } = string.Empty;

        [BsonElement("subscription_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = "none"; // none, active, past_due, canceled, unpaid

        [BsonElement("subscription_start_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("subscriptionStartDate")]
        public DateTime? SubscriptionStartDate { get; set; }

        [BsonElement("subscription_end_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("subscriptionEndDate")]
        public DateTime? SubscriptionEndDate { get; set; }

        [BsonElement("last_payment_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("lastPaymentDate")]
        public DateTime? LastPaymentDate { get; set; }

        [BsonElement("payment_failed_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("paymentFailedDate")]
        public DateTime? PaymentFailedDate { get; set; }

        [BsonElement("has_paid_first_subscription"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("hasPaidFirstSubscription")]
        public bool HasPaidFirstSubscription { get; set; } = false;

    }

    public class AvailableTime
    {
        [BsonElement("start_time"), BsonRepresentation(BsonType.DateTime)]
        public DateTime StartTime { get; set; }

        [BsonElement("end_time"), BsonRepresentation(BsonType.DateTime)]
        public DateTime EndTime { get; set; }
    }

    public class DayAvailability
    {   
        [BsonElement("Date"), BsonRepresentation(BsonType.DateTime)]
        public DateTime Date { get; set; }
        
        [BsonElement("StartTime"), BsonRepresentation(BsonType.DateTime)]
        public DateTime StartTime { get; set; }
        
        [BsonElement("EndTime"), BsonRepresentation(BsonType.DateTime)]
        public DateTime EndTime { get; set; }

        [BsonElement("slots")]
        public List<Slot> Slots { get; set; } = new();
    }


    public class Slot
    {
        [BsonElement("start_time"), BsonRepresentation(BsonType.DateTime)]
        public DateTime StartTime { get; set; }

        [BsonElement("end_time"), BsonRepresentation(BsonType.DateTime)]
        public DateTime EndTime { get; set; }

        [BsonElement("is_booked"), BsonRepresentation(BsonType.Boolean)]
        public bool IsBooked { get; set; } = false;

        [BsonElement("user_id"), BsonRepresentation(BsonType.String)]
        public string UserId { get; set; } = string.Empty;
    }

    public class ClinicInfo
    {
        [BsonElement("location"), BsonRepresentation(BsonType.String)]
        public string Location { get; set; } = string.Empty;
    }

    public class DoctorResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public List<DoctorDtos>? doctorDtos { get; set; }

        public string ImageUrl { get; set; } = string.Empty;
        public Doctor? doctor { get; set; }
    }

}


