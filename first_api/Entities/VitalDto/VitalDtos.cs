using System;
using System.Text.Json.Serialization;
using first_api.Entities.PatientModel;
using MongoDB.Bson.Serialization.Attributes;

// M-6 USED IN VITALS CONTROLLER
namespace first_api.Entities.VitalDto
{
    public class BloodPressureDto
    {
        [JsonPropertyName("systolic")]
        public int Systolic { get; set; }

        [JsonPropertyName("diastolic")]
        public int Diastolic { get; set; }

        [JsonPropertyName("date")]
        public DateTime Date { get; set; }
    }

    public class SugarLevelDto
    {
        [JsonPropertyName("fasting")]
        public double Fasting { get; set; }

        [JsonPropertyName("after_two_hours")]
        public double AfterTwoHours { get; set; }

        [JsonPropertyName("random")]
        public double Random { get; set; }

        [JsonPropertyName("date")]
        public DateTime Date { get; set; }
    }

    public class VitalDtos
    {
        [BsonElement("blood_pressure"), BsonRepresentation(MongoDB.Bson.BsonType.Array)]
        [JsonPropertyName("blood_pressure")]
        public BloodPressureDto BloodPressure { get; set; } = new BloodPressureDto();

        [JsonPropertyName("sugar")]
        [BsonElement("sugar"), BsonRepresentation(MongoDB.Bson.BsonType.Array)]
        public SugarLevelDto SugarLevel { get; set; } = new SugarLevelDto();

        [JsonPropertyName("last_updated")]
        [BsonElement("last_updated"), BsonRepresentation(MongoDB.Bson.BsonType.Array)]
        public DateTime LastUpdated { get; set; } = DateTime.Now;

    }
}