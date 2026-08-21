using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.DoctorModel
{
    public class DoctorDtos
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = string.Empty;

        [BsonElement("first_name"), BsonRepresentation(BsonType.String)]
        public string FirstName { get; set; } = string.Empty;

        [BsonElement("last_name"), BsonRepresentation(BsonType.String)]
        public string LastName { get; set; } = string.Empty;

        [BsonElement("email"), BsonRepresentation(BsonType.String)]
        public string Email { get; set; } = string.Empty;

        [BsonElement("whatsapp_no"), BsonRepresentation(BsonType.String)]
        public string WhatsappNo { get; set; } = string.Empty;

        public bool IsAvailable { get; set; }
        public string Speciality { get; set; } = string.Empty;
        public string Experience { get; set; } = string.Empty;

        public string MorningStartTime { get; set; } = string.Empty;
        public string MorningEndTime { get; set; } = string.Empty;

        [BsonElement("DailyAvailabilities")]
        public List<DayAvailability> DailyAvailabilities { get; set; } = new();

        public string Fee { get; set; } = string.Empty; 
        public string ClinicLocation { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string Specialization { get; set; } = string.Empty;
    }

}