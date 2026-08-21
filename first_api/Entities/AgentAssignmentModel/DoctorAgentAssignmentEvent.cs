using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.AgentAssignmentModel
{
    // Full audit/history trail for every assignment state change.
    // Collection: doctor_agent_assignment_events
    [BsonIgnoreExtraElements]
    public class DoctorAgentAssignmentEvent
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("assignment_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("assignmentId")]
        public string AssignmentId { get; set; } = string.Empty;

        [BsonElement("event_type"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = string.Empty;

        [BsonElement("old_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("oldStatus")]
        public string OldStatus { get; set; } = string.Empty;

        [BsonElement("new_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("newStatus")]
        public string NewStatus { get; set; } = string.Empty;

        [BsonElement("triggered_by"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("triggeredBy")]
        public string TriggeredBy { get; set; } = string.Empty;

        [BsonElement("trigger_source"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("triggerSource")]
        public string TriggerSource { get; set; } = string.Empty;

        [BsonElement("metadata")]
        [JsonPropertyName("metadata")]
        public BsonDocument? Metadata { get; set; }

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
