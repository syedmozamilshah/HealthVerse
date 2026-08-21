using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.PatientModel
{
    public class PatientDtos
    {
        [BsonElement("personal_info_id"), BsonRepresentation(BsonType.ObjectId)]

        public string Id { get; set; } = string.Empty;

        [BsonElement("history"), BsonRepresentation(BsonType.String)]

        public string History { get; set; } = string.Empty;

        [BsonElement("initial_conditions"), BsonRepresentation(BsonType.String)]

        public string InitialConditions { get; set; } = string.Empty;

        [BsonElement("first_name"), BsonRepresentation(BsonType.String)]

        public string FirstName { get; set; } = string.Empty;

        [BsonElement("last_name"), BsonRepresentation(BsonType.String)]

        public string LastName { get; set; } = string.Empty;

        [BsonElement("gender"), BsonRepresentation(BsonType.String)]

        public string Gender { get; set; } = string.Empty;

        [BsonElement("blood_group"), BsonRepresentation(BsonType.String)]

        public string BloodGroup { get; set; } = string.Empty;

    }

    public class PatientDtoResponse
    {
        public bool IsSuccess { get; set; } = true;
        public string Message { get; set; } = string.Empty;
        public PatientDtos? Data { get; set; }
    }
}