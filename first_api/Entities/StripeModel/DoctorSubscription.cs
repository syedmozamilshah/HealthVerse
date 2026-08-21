using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-10 USED IN STRIPE SERVICE
namespace first_api.Entities.StripeModel
{
    [BsonIgnoreExtraElements]
    public class DoctorSubscription
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("stripe_customer_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripeCustomerId")]
        public string StripeCustomerId { get; set; } = string.Empty;

        [BsonElement("stripe_subscription_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripeSubscriptionId")]
        public string StripeSubscriptionId { get; set; } = string.Empty;

        [BsonElement("subscription_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = "inactive"; // active, inactive, past_due, canceled, trialing

        [BsonElement("current_period_start"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("currentPeriodStart")]
        public DateTime CurrentPeriodStart { get; set; }

        [BsonElement("current_period_end"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("currentPeriodEnd")]
        public DateTime CurrentPeriodEnd { get; set; }

        [BsonElement("is_payment_current"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isPaymentCurrent")]
        public bool IsPaymentCurrent { get; set; } = false;

        [BsonElement("last_payment_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("lastPaymentDate")]
        public DateTime? LastPaymentDate { get; set; }

        [BsonElement("next_payment_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("nextPaymentDate")]
        public DateTime? NextPaymentDate { get; set; }

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("updated_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("canceled_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("canceledAt")]
        public DateTime? CanceledAt { get; set; }
    }

    [BsonIgnoreExtraElements]
    public class PaymentHistory
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("patientId")]
        public string? PatientId { get; set; }

        [BsonElement("appointment_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("appointmentId")]
        public string? AppointmentId { get; set; }

        [BsonElement("stripe_payment_intent_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripePaymentIntentId")]
        public string StripePaymentIntentId { get; set; } = string.Empty;

        [BsonElement("stripe_invoice_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("stripeInvoiceId")]
        public string? StripeInvoiceId { get; set; }

        [BsonElement("amount"), BsonRepresentation(BsonType.Int64)]
        [JsonPropertyName("amount")]
        public long Amount { get; set; } // Amount in smallest currency unit (paisa for PKR)

        [BsonElement("currency"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("currency")]
        public string Currency { get; set; } = "pkr";

        [BsonElement("payment_type"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("paymentType")]
        public string PaymentType { get; set; } = string.Empty; // "subscription", "appointment"

        [BsonElement("status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("status")]
        public string Status { get; set; } = "pending"; // pending, succeeded, failed, refunded

        [BsonElement("description"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("paid_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("paidAt")]
        public DateTime? PaidAt { get; set; }
    }

}
