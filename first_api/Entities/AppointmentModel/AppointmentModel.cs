using System;
using System.Collections.Generic;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

// M-4 USED IN APPOINTMENT CONTROLLER
namespace first_api.Entities.AppointmentModel
{
    [BsonIgnoreExtraElements]
    public class AppointmentModel
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("_id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("diagnosis"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("diagnosis")]
        public string Diagnosis { get; set; } = string.Empty;

        [BsonElement("assigned_doctor"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("assignedDoctor")]
        public string AssignedDoctor { get; set; } = string.Empty;

        [BsonElement("appointment_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("appointmentDate")]
        public DateTime AppointmentDate { get; set; }

        [BsonElement("last_visit_date"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("lastVisitDate")]
        public DateTime LastVisitDate { get; set; }

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [BsonElement("slot_start_time"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("slotStartTime")]
        public DateTime? SlotStartTime { get; set; }

        [BsonElement("slot_end_time"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("slotEndTime")]
        public DateTime? SlotEndTime { get; set; }

        [BsonElement("symptoms")]
        [JsonPropertyName("symptoms")]
        public List<Symptoms> Symptoms { get; set; } = new();

        [BsonElement("prescription")]
        [JsonPropertyName("prescription")]
        public List<Prescription> Prescriptions { get; set; } = new();

        [BsonElement("session_started_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("sessionStartedAt")]
        public DateTime? SessionStartedAt { get; set; }

        [BsonElement("completion_confirmed"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("completionConfirmed")]
        public bool CompletionConfirmed { get; set; } = false;

        [BsonElement("referral_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("referralId")]
        public string? ReferralId { get; set; }
    }

    public class Symptoms
    {
        [BsonElement("description"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [BsonElement("duration"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("duration")]
        public string Duration { get; set; } = string.Empty;
    }

    public class Prescription
    {
        [BsonElement("medicine_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("medicineName")]
        public string MedicineName { get; set; } = string.Empty;

        [BsonElement("dosage"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("dosage")]
        public string Dosage { get; set; } = string.Empty;

        [BsonElement("frequency"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("frequency")]
        public string Frequency { get; set; } = string.Empty;

        [BsonElement("duration"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("duration")]
        public string Duration { get; set; } = string.Empty;

        [BsonElement("instructions"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("instructions")]
        public string Instructions { get; set; } = string.Empty;
    }

    public class AppointmentResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("appointmentDtos")]
        public List<AppointmentModel>? AppointmentDtos { get; set; }
    }
}
