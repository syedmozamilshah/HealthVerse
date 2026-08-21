using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-11 USED IN NOTIFICATION CONTROLLER
namespace first_api.Entities.NotificationModel
{
    public class DeviceToken
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("user_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("userId")]
        public string UserId { get; set; } = string.Empty;

        [BsonElement("token"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("token")]
        public string Token { get; set; } = string.Empty;

        [BsonElement("platform"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("platform")]
        public string Platform { get; set; } = "android";

        [BsonElement("is_active"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isActive")]
        public bool IsActive { get; set; } = true;

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("last_seen_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("lastSeenAt")]
        public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    }
}
