using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace first_api.Entities.AgentAssignmentModel
{
    // Request DTOs 

    public class UpdateAssignmentSettingsDto
    {
        [JsonPropertyName("globalMode")]
        public string GlobalMode { get; set; } = "Auto";
    }

    public class ManualAssignDto
    {
        [JsonPropertyName("primaryAgent")]
        public string PrimaryAgent { get; set; } = string.Empty;

        [JsonPropertyName("subAgent")]
        public string SubAgent { get; set; } = string.Empty;

        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;
    }

    public class PauseAssignmentDto
    {
        [JsonPropertyName("reason")]
        public string Reason { get; set; } = string.Empty;
    }

    public class ArchiveAssignmentDto
    {
        [JsonPropertyName("reason")]
        public string Reason { get; set; } = string.Empty;
    }

    //  Response DTOs 

    public class AssignmentResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public object? Data { get; set; }
    }

    public class AssignmentSettingsResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("globalMode")]
        public string GlobalMode { get; set; } = "Auto";

        [JsonPropertyName("enforceSubscriptionGate")]
        public bool EnforceSubscriptionGate { get; set; }

        [JsonPropertyName("blockAutoOnArchived")]
        public bool BlockAutoOnArchived { get; set; }

        [JsonPropertyName("updatedAt")]
        public DateTime? UpdatedAt { get; set; }
    }

    public class AssignmentListItemDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("doctorNameSnapshot")]
        public string DoctorNameSnapshot { get; set; } = string.Empty;

        [JsonPropertyName("primaryAgent")]
        public string PrimaryAgent { get; set; } = string.Empty;

        [JsonPropertyName("subAgent")]
        public string SubAgent { get; set; } = string.Empty;

        [JsonPropertyName("mode")]
        public string Mode { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("isArchived")]
        public bool IsArchived { get; set; }

        [JsonPropertyName("source")]
        public string Source { get; set; } = string.Empty;

        [JsonPropertyName("assignedAt")]
        public DateTime AssignedAt { get; set; }

        [JsonPropertyName("approvedAt")]
        public DateTime? ApprovedAt { get; set; }

        [JsonPropertyName("lastStatusChangedAt")]
        public DateTime LastStatusChangedAt { get; set; }

        [JsonPropertyName("pauseReason")]
        public string PauseReason { get; set; } = string.Empty;

        [JsonPropertyName("archiveReason")]
        public string ArchiveReason { get; set; } = string.Empty;

        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;

        [JsonPropertyName("isSubscriptionEligible")]
        public bool IsSubscriptionEligible { get; set; }

        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = string.Empty;
    }

    public class AssignmentListResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public List<AssignmentListItemDto> Data { get; set; } = new();

        [JsonPropertyName("totalCount")]
        public int TotalCount { get; set; }
    }

    public class AssignmentEventDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = string.Empty;

        [JsonPropertyName("oldStatus")]
        public string OldStatus { get; set; } = string.Empty;

        [JsonPropertyName("newStatus")]
        public string NewStatus { get; set; } = string.Empty;

        [JsonPropertyName("triggeredBy")]
        public string TriggeredBy { get; set; } = string.Empty;

        [JsonPropertyName("triggerSource")]
        public string TriggerSource { get; set; } = string.Empty;

        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; }
    }

    public class AssignmentHistoryResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public List<AssignmentEventDto> Data { get; set; } = new();
    }

    // Enhanced can-access-ai-agent response with assignment context.
    
    public class AgentAccessResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("canAccess")]
        public bool CanAccess { get; set; }

        [JsonPropertyName("assignmentStatus")]
        public string AssignmentStatus { get; set; } = string.Empty;

        [JsonPropertyName("assignmentMode")]
        public string AssignmentMode { get; set; } = string.Empty;

        [JsonPropertyName("denialReason")]
        public string DenialReason { get; set; } = string.Empty;

        [JsonPropertyName("denialMessage")]
        public string DenialMessage { get; set; } = string.Empty;

        [JsonPropertyName("subscriptionStatus")]
        public string SubscriptionStatus { get; set; } = string.Empty;

        [JsonPropertyName("hasPaidFirstSubscription")]
        public bool HasPaidFirstSubscription { get; set; }

        [JsonPropertyName("requiresPayment")]
        public bool RequiresPayment { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
    }

    // Outcome returned when assignment is created/attempted during verification approval.
    public class AssignmentOutcome
    {
        [JsonPropertyName("assignmentStatus")]
        public string AssignmentStatus { get; set; } = string.Empty;

        [JsonPropertyName("assignmentMessage")]
        public string AssignmentMessage { get; set; } = string.Empty;
    }
}
