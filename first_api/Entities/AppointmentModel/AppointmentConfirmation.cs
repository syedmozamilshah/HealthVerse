using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

// M-4 USED IN APPOINTMENT CONTROLLER FOR CONFIRMATION
namespace first_api.Entities.AppointmentModel
{
    [BsonIgnoreExtraElements]
    public class AppointmentConfirmation
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("appointment_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("appointmentId")]
        public string AppointmentId { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("completion_requested_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("completionRequestedAt")]
        public DateTime CompletionRequestedAt { get; set; }

        [BsonElement("patient_response"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("patientResponse")]
        public string PatientResponse { get; set; } = "Pending"; // Pending | Confirmed | Disputed

        [BsonElement("patient_responded_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("patientRespondedAt")]
        public DateTime? PatientRespondedAt { get; set; }

        [BsonElement("auto_completed_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("autoCompletedAt")]
        public DateTime? AutoCompletedAt { get; set; }

        [BsonElement("dispute_reason"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("disputeReason")]
        public string DisputeReason { get; set; } = string.Empty;

        [BsonElement("resolution_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("resolutionStatus")]
        public string ResolutionStatus { get; set; } = "Pending"; // Pending | Resolved | UnderReview
    }

    public class PatientConfirmationRequest
    {
        [JsonPropertyName("response")]
        public string Response { get; set; } = string.Empty; // Confirmed | Disputed

        [JsonPropertyName("disputeReason")]
        public string DisputeReason { get; set; } = string.Empty;
    }
}
