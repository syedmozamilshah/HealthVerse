using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-11 USED FOR NOFICATION CONTROLLER
namespace first_api.Entities.NotificationModel
{
    public class NotificationLog
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("user_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("userId")]
        public string UserId { get; set; } = string.Empty;

        [BsonElement("type"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("type")]
        public string Type { get; set; } = string.Empty; // "appointment" | "medication"

        [BsonElement("related_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("relatedId")]
        public string RelatedId { get; set; } = string.Empty; // appointmentId or medicationId

        [BsonElement("payload"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("payload")]
        public string Payload { get; set; } = string.Empty;

        [BsonElement("scheduled_for"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("scheduledFor")]
        public DateTime ScheduledFor { get; set; }

        [BsonElement("sent_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("sentAt")]
        public DateTime? SentAt { get; set; }

        [BsonElement("status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("status")]
        public string Status { get; set; } = "pending"; // pending | sent | failed

        [BsonElement("acknowledged_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("acknowledgedAt")]
        public DateTime? AcknowledgedAt { get; set; }

        [BsonElement("acknowledged_action"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("acknowledgedAction")]
        public string AcknowledgedAction { get; set; } = string.Empty; // taken | snooze | none

        [BsonElement("fcm_response"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("fcmResponse")]
        public string FcmResponse { get; set; } = string.Empty;

        [BsonElement("retry_count"), BsonRepresentation(BsonType.Int32)]
        [JsonPropertyName("retryCount")]
        public int RetryCount { get; set; } = 0;
    }
}
