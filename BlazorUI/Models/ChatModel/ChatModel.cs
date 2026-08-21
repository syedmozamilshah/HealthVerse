using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace BlazorUI.Models.ChatModel
{
    public class ChatModel
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("doctorId")]
        public string DoctorId { get; set; } = string.Empty;

        [JsonPropertyName("specialty")]
        public string Specialty { get; set; } = string.Empty;

        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("date")]
        public DateTime Date { get; set; }

        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; }

        [JsonPropertyName("chats")]
        public List<ChatMessage> Chats { get; set; } = new List<ChatMessage>();
    }

    public class ChatMessage
    {
        [JsonPropertyName("query")]
        public string Query { get; set; } = string.Empty;

        [JsonPropertyName("response")]
        public string Response { get; set; } = string.Empty;

        [JsonPropertyName("timestamp")]
        public DateTime Timestamp { get; set; }
    }

    // Response classes
    public class ChatModelResponse
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public ChatModel? Data { get; set; }
    }

    public class ChatListResponse
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public List<ChatSummary>? Data { get; set; }
    }

    public class ChatSummary
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("date")]
        public DateTime Date { get; set; }

        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; }

        [JsonPropertyName("messageCount")]
        public int MessageCount { get; set; }
    }

    // Request classes
    public class SendMessageRequest
    {
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("chatId")]
        public string ChatId { get; set; } = string.Empty;

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
    }

    public class CreateChatRequest
    {
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("patientName")]
        public string PatientName { get; set; } = string.Empty;

        [JsonPropertyName("initialConditions")]
        public string InitialConditions { get; set; } = string.Empty;

        [JsonPropertyName("history")]
        public string History { get; set; } = string.Empty;
    }

    public class SendMessageResponse
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("chatId")]
        public string ChatId { get; set; } = string.Empty;

        [JsonPropertyName("aiResponse")]
        public string AIResponse { get; set; } = string.Empty;

        [JsonPropertyName("timestamp")]
        public DateTime Timestamp { get; set; }
    }

    public class AgentInfoResponse
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; }

        [JsonPropertyName("specialty")]
        public string Specialty { get; set; } = string.Empty;

        [JsonPropertyName("isAgentAvailable")]
        public bool IsAgentAvailable { get; set; }

        [JsonPropertyName("supportedSpecialties")]
        public List<string>? SupportedSpecialties { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
    }
}
