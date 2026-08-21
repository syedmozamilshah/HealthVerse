using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using MongoDB.Bson.Serialization.Attributes;

// M-1 - USED IN AUTH CONTROLLER
// M-4 USED IN APPOINTMENT CONTROLLER
// M-4 USED IN VOICE CONTROLLER
// M-6 VITALS ENTRY FOR PATIENTS
namespace first_api.Entities.PatientModel
{
    [BsonIgnoreExtraElements]
    public class PatientModel
    {
        [BsonId]
        [BsonElement("_id")]
        [BsonRepresentation(MongoDB.Bson.BsonType.ObjectId)]
        public string Id { get; set; } = string.Empty;

        [BsonElement("personal_info_id")]
        [BsonRepresentation(MongoDB.Bson.BsonType.ObjectId)]
        public string PersonalInfoId { get; set; } = string.Empty;

        [BsonElement("name")]
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [BsonElement("email")]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [BsonElement("history")]
        public string History { get; set; } = string.Empty;

        [BsonElement("initial_conditions")]
        public string InitialConditions { get; set; } = string.Empty;

        [BsonElement("allergy")]
        public string Allergy { get; set; } = string.Empty;

        [BsonElement("is_verified")]
        public bool IsVerified { get; set; }

        [BsonElement("vitals")]
        public Vitals Vitals { get; set; } = new Vitals();

        [BsonElement("bmi")]
        public double? Bmi { get; set; }
    }

    public class Vitals
    {
        [BsonElement("blood_pressure")]
        public List<BloodPressure> BloodPressure { get; set; } = new List<BloodPressure>();

        [BsonElement("sugar")]
        public List<SugarLevel> SugarLevel { get; set; } = new List<SugarLevel>();

        [BsonElement("last_updated")]
        public DateTime LastUpdated { get; set; } = DateTime.Now;

        [BsonElement("last_logged_date")]
        public DateTime? LastLoggedDate { get; set; }
    }

    public class BloodPressure
    {
        [BsonElement("systolic")]
        [JsonPropertyName("systolic")]
        public int Systolic { get; set; }

        [BsonElement("diastolic")]
        [JsonPropertyName("diastolic")]
        public int Diastolic { get; set; }

        [BsonElement("date")]
        [JsonPropertyName("date")]
        public DateTime Date { get; set; }   
    }

    public class SugarLevel
    {
        [BsonElement("fasting")]
        [JsonPropertyName("fasting")]
        public double? Fasting { get; set; }

        [BsonElement("after_two_hours")]
        [JsonPropertyName("after_two_hours")]
        public double? AfterTwoHours { get; set; }

        [BsonElement("random")]
        [JsonPropertyName("random")]
        public double? Random { get; set; }

        [BsonElement("date")]
        [JsonPropertyName("date")]
        public DateTime Date { get; set; }
    }

    public class PatientResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public PatientModel? Patient { get; set; }
    }

    public class VitalResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public Vitals? Vitals { get; set; }
    }
}
