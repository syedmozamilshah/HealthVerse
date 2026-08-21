using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.UserModel
{
    public class UserDto
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("first_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("firstName")]
        public string FirstName { get; set; } = string.Empty;

        [BsonElement("last_name"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("lastName")]
        public string LastName { get; set; } = string.Empty;

        [BsonElement("profile_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("profileImage")]
        public string ProfileImage { get; set; } = string.Empty;
        

    }
}