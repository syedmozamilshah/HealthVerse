namespace BlazorUI.Models
{
    public class PrescriptionRequest
    {
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? PatientGender { get; set; }
        public string? PatientBloodGroup { get; set; }
        public string? PatientInitialConditions { get; set; }
        public string? PatientHistory { get; set; }
        public string? DRResult { get; set; }
        public string? ClassifierResult { get; set; }
        public List<ConversationMessage>? Conversation { get; set; }
    }

    public class ConversationMessage
    {
        public string? Message { get; set; }
        public string? Response { get; set; }
    }

    public class PrescriptionData
    {
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Usage { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string Notes { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public string Summary { get; set; } = "";
    }

    public class PrescriptionResponse
    {
        public bool Success { get; set; }
        public PrescriptionData? Data { get; set; }
        public string? Message { get; set; }
    }

    public class SavePrescriptionRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? AppointmentId { get; set; }
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Usage { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string Notes { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public string Summary { get; set; } = "";
    }

    public class SavedPrescription
    {
        public string? Id { get; set; }
        public string? PatientId { get; set; }
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? PrescriptionUrl { get; set; }
        public string? FileType { get; set; }
        public string? Diagnosis { get; set; }
        public string? Medicines { get; set; }
        public string? Advice { get; set; }
        public string? FollowUp { get; set; }
        public string? PrescriptionDate { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class SavedPrescriptionsResponse
    {
        public bool Success { get; set; }
        public List<SavedPrescription>? Data { get; set; }
    }

    public class CompletePrescriptionRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? PatientSymptoms { get; set; }
        public string? AppointmentId { get; set; }
        public string ImageBase64 { get; set; } = string.Empty;
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
    }

    public class CompletePrescriptionResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public CompletePrescriptionData? Data { get; set; }
    }

    public class CompletePrescriptionData
    {
        public string? PrescriptionId { get; set; }
        public string? PrescriptionUrl { get; set; }
        public string? PrescriptionDate { get; set; }
        public string? Summary { get; set; }
    }

    public class SaveSummaryRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? PatientSymptoms { get; set; }
        public string? AppointmentId { get; set; }
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
    }

    public class SaveSummaryResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public SaveSummaryData? Data { get; set; }
    }

    public class SaveSummaryData
    {
        public string? Summary { get; set; }
        public string? Date { get; set; }
    }

    public class SavePrescriptionImageRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string? DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? AppointmentId { get; set; }
        public string ImageBase64 { get; set; } = string.Empty;
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public List<MedicineItemDto>? MedicineItems { get; set; }
    }

    /// <summary>
    /// Medicine item DTO for prescription
    /// </summary>
    public class MedicineItemDto
    {
        public string Name { get; set; } = string.Empty;
        public string Dosage { get; set; } = string.Empty;
        public int DurationDays { get; set; } = 7;
        public bool Morning { get; set; }
        public bool Afternoon { get; set; }
        public bool Evening { get; set; }
        public bool Night { get; set; }
        public string Instructions { get; set; } = string.Empty;
    }

    public class SavePrescriptionImageResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public SavePrescriptionImageData? Data { get; set; }
    }

    public class SavePrescriptionImageData
    {
        public string? PrescriptionId { get; set; }
        public string? PrescriptionUrl { get; set; }
        public string? PrescriptionDate { get; set; }
    }

    /// <summary>
    /// Response for medication adherence API
    /// </summary>
    public class MedicationAdherenceResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public List<MedicationAdherenceData>? Data { get; set; }
    }

    /// <summary>
    /// Medication adherence data for a single medication
    /// </summary>
    public class MedicationAdherenceData
    {
        public string PrescriptionId { get; set; } = string.Empty;
        public string MedicineName { get; set; } = string.Empty;
        public int TotalDoses { get; set; }
        public int TakenDoses { get; set; }
        public int MissedDoses { get; set; }
        public double AdherencePercentage { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int DaysRemaining { get; set; }
    }

    /// <summary>
    /// Response for daily medication history API
    /// </summary>
    public class DailyHistoryResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public List<DailyHistoryStat>? Data { get; set; }
    }

    /// <summary>
    /// Daily medication history stat for bar graph
    /// </summary>
    public class DailyHistoryStat
    {
        public DateTime Date { get; set; }
        public string DayName { get; set; } = string.Empty;
        public int ScheduledDoses { get; set; }
        public int TakenDoses { get; set; }
        public int MissedDoses { get; set; }
        public double AdherencePercentage { get; set; }
    }
}
