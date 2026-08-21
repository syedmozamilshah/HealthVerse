using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using first_api.Entities.UserModel;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-8 APPOINTMENT MODEL DTOS
// M-10 USED IN STRIPE SERVICE
namespace first_api.Entities.AppointmentModel
{
    public class AppointmentModelDtos
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
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
        [JsonPropertyName("prescriptions")]
        public List<Prescription> Prescriptions { get; set; } = new();

        [JsonPropertyName("users")]
        public UserDto Users { get; set; } = new();

        [BsonElement("referral_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("referralId")]
        public string? ReferralId { get; set; }
    }


    public class AppointmentDtosResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("appointmentDtos")]
        public List<AppointmentModelDtos>? AppointmentDtos { get; set; }
    }

}