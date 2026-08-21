using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-5 USED IN MEDICATION TRACKING 
namespace first_api.Entities.PrescriptionModel
{
    // Represents a single medicine in a prescription
    public class MedicineItem
    {
        [BsonElement("name")]
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [BsonElement("dosage")]
        [JsonPropertyName("dosage")]
        public string Dosage { get; set; } = string.Empty; // e.g., "1 tablet", "5ml"

        [BsonElement("frequency")]
        [JsonPropertyName("frequency")]
        public string Frequency { get; set; } = string.Empty; // e.g., "twice daily"

        [BsonElement("duration_days")]
        [JsonPropertyName("durationDays")]
        public int DurationDays { get; set; } = 7; // How many days to take

        [BsonElement("morning")]
        [JsonPropertyName("morning")]
        public bool Morning { get; set; } = false;

        [BsonElement("morning_time_utc")]
        [JsonPropertyName("morningTimeUtc")]
        public string MorningTimeUtc { get; set; } = string.Empty; // "HH:mm" or ISO datetime (UTC)

        [BsonElement("afternoon")]
        [JsonPropertyName("afternoon")]
        public bool Afternoon { get; set; } = false;

        [BsonElement("afternoon_time_utc")]
        [JsonPropertyName("afternoonTimeUtc")]
        public string AfternoonTimeUtc { get; set; } = string.Empty; // "HH:mm" or ISO datetime (UTC)

        [BsonElement("evening")]
        [JsonPropertyName("evening")]
        public bool Evening { get; set; } = false;

        [BsonElement("evening_time_utc")]
        [JsonPropertyName("eveningTimeUtc")]
        public string EveningTimeUtc { get; set; } = string.Empty; // "HH:mm" or ISO datetime (UTC)

        [BsonElement("night")]
        [JsonPropertyName("night")]
        public bool Night { get; set; } = false;

        [BsonElement("night_time_utc")]
        [JsonPropertyName("nightTimeUtc")]
        public string NightTimeUtc { get; set; } = string.Empty; // "HH:mm" or ISO datetime (UTC)

        [BsonElement("start_date")]
        [JsonPropertyName("startDate")]
        public DateTime StartDate { get; set; } = DateTime.UtcNow;

        [BsonElement("end_date")]
        [JsonPropertyName("endDate")]
        public DateTime EndDate { get; set; } = DateTime.UtcNow.AddDays(7);

        [BsonElement("instructions")]
        [JsonPropertyName("instructions")]
        public string Instructions { get; set; } = string.Empty; // e.g., "Take after meal"
    }

    [BsonIgnoreExtraElements]
    public class PrescriptionDocument
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("doctor_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("doctorName")]
        public string DoctorName { get; set; } = string.Empty;

        [BsonElement("doctor_specialty"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("doctorSpecialty")]
        public string DoctorSpecialty { get; set; } = string.Empty;

        [BsonElement("patient_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("patientName")]
        public string PatientName { get; set; } = string.Empty;

        [BsonElement("prescription_url"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("prescriptionUrl")]
        public string PrescriptionUrl { get; set; } = string.Empty;

        [BsonElement("file_type"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("fileType")]
        public string FileType { get; set; } = "image"; // "image" or "pdf"

        [BsonElement("diagnosis"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("diagnosis")]
        public string Diagnosis { get; set; } = string.Empty;

        [BsonElement("medicines"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("medicines")]
        public string Medicines { get; set; } = string.Empty;

        [BsonElement("advice"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("advice")]
        public string Advice { get; set; } = string.Empty;

        [BsonElement("follow_up"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("followUp")]
        public string FollowUp { get; set; } = string.Empty;

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [BsonElement("prescription_date"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("prescriptionDate")]
        public string PrescriptionDate { get; set; } = string.Empty;

        [BsonElement("medicine_items")]
        [JsonPropertyName("medicineItems")]
        public List<MedicineItem> MedicineItems { get; set; } = new List<MedicineItem>();

        [BsonElement("is_active")]
        [JsonPropertyName("isActive")]
        public bool IsActive { get; set; } = true; // Whether prescription is currently active
    }

    public class PrescriptionDocumentResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public PrescriptionDocument? Prescription { get; set; }
        public List<PrescriptionDocument>? Prescriptions { get; set; }
    }

    public class SavePrescriptionImageRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? ImageBase64 { get; set; }
        public string? Diagnosis { get; set; }
        public string? Medicines { get; set; }
        public string? Advice { get; set; }
        public string? FollowUp { get; set; }
        public List<MedicineItem>? MedicineItems { get; set; }
    }
}
