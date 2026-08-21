using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.AgentAssignmentModel
{
    // Singleton document for global system-wide mode toggle.
    // Collection: doctor_agent_assignment_settings
    [BsonIgnoreExtraElements]
    public class DoctorAgentAssignmentSettings
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

       [BsonElement("global_mode"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("globalMode")]
        public string GlobalMode { get; set; } = "Auto";

        [BsonElement("updated_by_admin_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("updatedByAdminId")]
        public string UpdatedByAdminId { get; set; } = string.Empty;

        [BsonElement("updated_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("enforce_subscription_gate"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("enforceSubscriptionGate")]
        public bool EnforceSubscriptionGate { get; set; } = true;

        [BsonElement("block_auto_on_archived"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("blockAutoOnArchived")]
        public bool BlockAutoOnArchived { get; set; } = true;
    }
}
