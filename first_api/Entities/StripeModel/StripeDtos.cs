using System.Text.Json.Serialization;

namespace first_api.Entities.StripeModel
{
    public class CreateCheckoutSessionDto
    {
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("successUrl")]
        public string SuccessUrl { get; set; } = string.Empty;

        [JsonPropertyName("cancelUrl")]
        public string CancelUrl { get; set; } = string.Empty;
    }

    public class CreatePatientPaymentDto
    {
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("appointmentId")]
        public string AppointmentId { get; set; } = string.Empty;

        [JsonPropertyName("amount")]
        public int Amount { get; set; }

        [JsonPropertyName("currency")]
        public string Currency { get; set; } = "pkr";

        [JsonPropertyName("successUrl")]
        public string SuccessUrl { get; set; } = string.Empty;

        [JsonPropertyName("cancelUrl")]
        public string CancelUrl { get; set; } = string.Empty;
    }

    public class CheckoutSessionResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("sessionId")]
        public string SessionId { get; set; } = string.Empty;

        [JsonPropertyName("sessionUrl")]
        public string SessionUrl { get; set; } = string.Empty;

        [JsonPropertyName("publishableKey")]
        public string PublishableKey { get; set; } = string.Empty;
    }

    public class PaymentIntentResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("clientSecret")]
        public string ClientSecret { get; set; } = string.Empty;

        [JsonPropertyName("paymentIntentId")]
        public string PaymentIntentId { get; set; } = string.Empty;

        [JsonPropertyName("publishableKey")]
        public string PublishableKey { get; set; } = string.Empty;
    }

    public class SubscriptionStatusResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = string.Empty;

        [JsonPropertyName("hasPaidFirstSubscription")]
        public bool HasPaidFirstSubscription { get; set; }

        [JsonPropertyName("subscriptionEndDate")]
        public DateTime? SubscriptionEndDate { get; set; }

        [JsonPropertyName("canAccessDashboard")]
        public bool CanAccessDashboard { get; set; }

        [JsonPropertyName("requiresPayment")]
        public bool RequiresPayment { get; set; }

        [JsonPropertyName("isSubscribed")]
        public bool IsSubscribed { get; set; }

        [JsonPropertyName("isPaymentCurrent")]
        public bool IsPaymentCurrent { get; set; }

        [JsonPropertyName("currentPeriodEnd")]
        public DateTime? CurrentPeriodEnd { get; set; }

        [JsonPropertyName("nextPaymentDate")]
        public DateTime? NextPaymentDate { get; set; }

        [JsonPropertyName("amountDue")]
        public long AmountDue { get; set; }
    }

    public class CancelSubscriptionResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("cancellationDate")]
        public DateTime? CancellationDate { get; set; }
    }

    public class DoctorPaymentStatusDto
    {
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("doctorName")]
        public string DoctorName { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;

        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = string.Empty;

        [JsonPropertyName("lastPaymentDate")]
        public DateTime? LastPaymentDate { get; set; }

        [JsonPropertyName("paymentFailedDate")]
        public DateTime? PaymentFailedDate { get; set; }

        [JsonPropertyName("subscriptionEndDate")]
        public DateTime? SubscriptionEndDate { get; set; }

        [JsonPropertyName("totalPatients")]
        public int TotalPatients { get; set; }

        [JsonPropertyName("totalAppointments")]
        public int TotalAppointments { get; set; }

        [JsonPropertyName("totalPrescriptions")]
        public int TotalPrescriptions { get; set; }

        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; } = string.Empty;
    }

    public class DoctorStatisticsDto
    {
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("doctorName")]
        public string DoctorName { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;

        [JsonPropertyName("totalPatients")]
        public int TotalPatients { get; set; }

        [JsonPropertyName("totalAppointments")]
        public int TotalAppointments { get; set; }

        [JsonPropertyName("totalPrescriptions")]
        public int TotalPrescriptions { get; set; }

        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = string.Empty;

        [JsonPropertyName("consultationFee")]
        public decimal ConsultationFee { get; set; }

        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; } = string.Empty;

        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        [JsonPropertyName("subscriptionEndDate")]
        public DateTime? SubscriptionEndDate { get; set; }
    }

    public class VerifySessionDto
    {
        [JsonPropertyName("sessionId")]
        public string SessionId { get; set; } = string.Empty;
    }

    public class VerifySessionResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("subscriptionActivated")]
        public bool SubscriptionActivated { get; set; }
    }
}
