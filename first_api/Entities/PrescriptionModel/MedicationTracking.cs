using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

// M-5 USED IN MEDICATION TRACKING CONTROLLER
namespace first_api.Entities.PrescriptionModel
{
    // Tracks when a patient takes their medication
    [BsonIgnoreExtraElements]
    public class MedicationTracking
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("prescription_id")]
        [JsonPropertyName("prescriptionId")]
        public string PrescriptionId { get; set; } = string.Empty;

        [BsonElement("patient_id")]
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("medicine_name")]
        [JsonPropertyName("medicineName")]
        public string MedicineName { get; set; } = string.Empty;

        [BsonElement("date")]
        [JsonPropertyName("date")]
        public DateTime Date { get; set; } = DateTime.UtcNow.Date;

        [BsonElement("morning_taken")]
        [JsonPropertyName("morningTaken")]
        public bool MorningTaken { get; set; } = false;

        [BsonElement("morning_time")]
        [JsonPropertyName("morningTime")]
        public DateTime? MorningTime { get; set; }

        [BsonElement("afternoon_taken")]
        [JsonPropertyName("afternoonTaken")]
        public bool AfternoonTaken { get; set; } = false;

        [BsonElement("afternoon_time")]
        [JsonPropertyName("afternoonTime")]
        public DateTime? AfternoonTime { get; set; }

        [BsonElement("evening_taken")]
        [JsonPropertyName("eveningTaken")]
        public bool EveningTaken { get; set; } = false;

        [BsonElement("evening_time")]
        [JsonPropertyName("eveningTime")]
        public DateTime? EveningTime { get; set; }

        [BsonElement("night_taken")]
        [JsonPropertyName("nightTaken")]
        public bool NightTaken { get; set; } = false;

        [BsonElement("night_time")]
        [JsonPropertyName("nightTime")]
        public DateTime? NightTime { get; set; }

        [BsonElement("notes")]
        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;

        [BsonElement("created_at")]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("updated_at")]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }

    // Summary of medication adherence for a patient
    public class MedicationAdherenceSummary
    {
        [JsonPropertyName("prescriptionId")]
        public string PrescriptionId { get; set; } = string.Empty;

        [JsonPropertyName("medicineName")]
        public string MedicineName { get; set; } = string.Empty;

        [JsonPropertyName("totalDoses")]
        public int TotalDoses { get; set; } = 0;

        [JsonPropertyName("takenDoses")]
        public int TakenDoses { get; set; } = 0;

        [JsonPropertyName("missedDoses")]
        public int MissedDoses { get; set; } = 0;

        [JsonPropertyName("adherencePercentage")]
        public double AdherencePercentage { get; set; } = 0;

        [JsonPropertyName("trackingHistory")]
        public List<MedicationTracking> TrackingHistory { get; set; } = new List<MedicationTracking>();
    }

    public class MarkMedicationTakenRequest
    {
        [JsonPropertyName("prescriptionId")]
        public string PrescriptionId { get; set; } = string.Empty;

        [JsonPropertyName("medicineName")]
        public string MedicineName { get; set; } = string.Empty;

        [JsonPropertyName("timeSlot")]
        public string TimeSlot { get; set; } = string.Empty; // "morning", "afternoon", "evening", "night"

        [JsonPropertyName("taken")]
        public bool Taken { get; set; } = true;

        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;
    }

    public class ActiveMedicationDto
    {
        [JsonPropertyName("prescriptionId")]
        public string PrescriptionId { get; set; } = string.Empty;

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("doctorName")]
        public string DoctorName { get; set; } = string.Empty;

        [JsonPropertyName("doctorSpecialty")]
        public string DoctorSpecialty { get; set; } = string.Empty;

        [JsonPropertyName("medicineName")]
        public string MedicineName { get; set; } = string.Empty;

        [JsonPropertyName("dosage")]
        public string Dosage { get; set; } = string.Empty;

        [JsonPropertyName("instructions")]
        public string Instructions { get; set; } = string.Empty;

        [JsonPropertyName("morning")]
        public bool Morning { get; set; } = false;

        [JsonPropertyName("morningTimeUtc")]
        public string MorningTimeUtc { get; set; } = string.Empty;

        [JsonPropertyName("afternoon")]
        public bool Afternoon { get; set; } = false;

        [JsonPropertyName("afternoonTimeUtc")]
        public string AfternoonTimeUtc { get; set; } = string.Empty;

        [JsonPropertyName("evening")]
        public bool Evening { get; set; } = false;

        [JsonPropertyName("eveningTimeUtc")]
        public string EveningTimeUtc { get; set; } = string.Empty;

        [JsonPropertyName("night")]
        public bool Night { get; set; } = false;

        [JsonPropertyName("nightTimeUtc")]
        public string NightTimeUtc { get; set; } = string.Empty;

        [JsonPropertyName("startDate")]
        public DateTime StartDate { get; set; }

        [JsonPropertyName("endDate")]
        public DateTime EndDate { get; set; }

        [JsonPropertyName("daysRemaining")]
        public int DaysRemaining { get; set; }

        [JsonPropertyName("nextAppointmentDate")]
        public DateTime? NextAppointmentDate { get; set; }

        [JsonPropertyName("todayTracking")]
        public MedicationTracking? TodayTracking { get; set; }
    }

    public class ActiveMedicationsResponse
    {
        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public List<ActiveMedicationDto> Data { get; set; } = new List<ActiveMedicationDto>();
    }
}
