using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using BlazorUI.Models.UserDto;

namespace BlazorUI.Models.AppointmentModel
{
    public class AppointmentModelDtos
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("diagnosis")]
        public string Diagnosis { get; set; }= string.Empty;

        [JsonPropertyName("assignedDoctor")]
        public string AssignedDoctor { get; set; }= string.Empty;

        [JsonPropertyName("appointmentDate")]
        public DateTime AppointmentDate { get; set; }

        [JsonPropertyName("lastVisitDate")]
        public DateTime LastVisitDate { get; set; }

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("patientId")]
        public string PatientId { get; set; }= string.Empty;

        [JsonPropertyName("address")]
        public string Address { get; set; }= string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("slotStartTime")]
        public DateTime? SlotStartTime { get; set; }

        [JsonPropertyName("slotEndTime")]
        public DateTime? SlotEndTime { get; set; }

        [JsonPropertyName("symptoms")]
        public List<Symptoms> Symptoms { get; set; } = new();

        [JsonPropertyName("prescriptions")]
        public List<Prescription> Prescriptions { get; set; } = new();

        [JsonPropertyName("users")]
        public UserDtos Users { get; set; } = new();
    }


    public class Symptoms
    {
        public string Description { get; set; } = string.Empty;

        public string Duration { get; set; } = string.Empty;
    }

    public class Prescription
    {
        public string MedicineName { get; set; } = string.Empty;

        public string Dosage { get; set; } = string.Empty;

        public string Frequency { get; set; } = string.Empty;

        public string Duration { get; set; } = string.Empty;

        public string Instructions { get; set; } = string.Empty;
    }

    public class AppointmentDtosResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; }= string.Empty;
        public List<AppointmentModelDtos>? AppointmentDtos { get; set; }
    }

}