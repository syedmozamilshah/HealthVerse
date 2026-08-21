using System;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

namespace first_api.Entities.ReferralModel
{
    [BsonIgnoreExtraElements]
    public class Referral
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("referring_doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("referringDoctorId")]
        public string ReferringDoctorId { get; set; } = string.Empty;

        [BsonElement("target_specialty"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("targetSpecialty")]
        public string TargetSpecialty { get; set; } = string.Empty;

        [BsonElement("notes"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;

        [BsonElement("status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("status")]
        public string Status { get; set; } = "ACTIVE"; // ACTIVE or BOOKED

        [BsonElement("assigned_doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("assignedDoctorId")]
        public string? AssignedDoctorId { get; set; }

        [BsonElement("appointment_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("appointmentId")]
        public string? AppointmentId { get; set; }

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("updated_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
