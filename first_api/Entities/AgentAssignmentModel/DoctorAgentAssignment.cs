using System;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace first_api.Entities.AgentAssignmentModel
{
    // Represents a doctor's current + historical assignment lifecycle.
    // Collection: doctor_agent_assignments
    [BsonIgnoreExtraElements]
    public class DoctorAgentAssignment
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("doctor_name_snapshot"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("doctorNameSnapshot")]
        public string DoctorNameSnapshot { get; set; } = string.Empty;

        [BsonElement("primary_agent"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("primaryAgent")]
        public string PrimaryAgent { get; set; } = string.Empty;

        [BsonElement("sub_agent"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("subAgent")]
        public string SubAgent { get; set; } = string.Empty;

        /// <summary>
        /// Auto | Manual
        /// </summary>
        [BsonElement("mode"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("mode")]
        public string Mode { get; set; } = "Auto";

        /// <summary>
        /// Pending | Active | Paused | Archived
        /// </summary>
        [BsonElement("status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("status")]
        public string Status { get; set; } = "Pending";

        [BsonElement("is_archived"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isArchived")]
        public bool IsArchived { get; set; } = false;

        /// <summary>
        /// AutoVerificationApproval | ManualVerificationApproval | AdminAction
        /// </summary>
        [BsonElement("source"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("source")]
        public string Source { get; set; } = string.Empty;

        [BsonElement("assigned_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("assignedAt")]
        public DateTime AssignedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("approved_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("approvedAt")]
        public DateTime? ApprovedAt { get; set; }

        [BsonElement("approved_by_admin_id"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("approvedByAdminId")]
        public string ApprovedByAdminId { get; set; } = string.Empty;

        [BsonElement("last_status_changed_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("lastStatusChangedAt")]
        public DateTime LastStatusChangedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("pause_reason"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("pauseReason")]
        public string PauseReason { get; set; } = string.Empty;

        [BsonElement("archive_reason"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("archiveReason")]
        public string ArchiveReason { get; set; } = string.Empty;

        [BsonElement("notes"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;

        [BsonElement("subscription_status_at_last_validation"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("subscriptionStatusAtLastValidation")]
        public string SubscriptionStatusAtLastValidation { get; set; } = string.Empty;

        [BsonElement("is_subscription_eligible"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isSubscriptionEligible")]
        public bool IsSubscriptionEligible { get; set; } = false;

        /// <summary>
        /// Optimistic concurrency version
        /// </summary>
        [BsonElement("version"), BsonRepresentation(BsonType.Int32)]
        [JsonPropertyName("version")]
        public int Version { get; set; } = 1;

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [BsonElement("updated_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
