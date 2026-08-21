using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MongoDB.Bson.Serialization.Attributes;


// M-8 USED FOR CHAT FOR SPECIFIC PATIENT
namespace first_api.Entities.ChatModel
{
    public class ChatModel
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(MongoDB.Bson.BsonType.ObjectId)]
        public string Id { get; set; } = string.Empty;

        [BsonElement("patient_id"), BsonRepresentation(MongoDB.Bson.BsonType.ObjectId)]
        public string PatientId { get; set; } = string.Empty;

        [BsonElement("doctor_id"), BsonRepresentation(MongoDB.Bson.BsonType.ObjectId)]
        public string DoctorId { get; set; } = string.Empty;

        [BsonElement("specialty"), BsonRepresentation(MongoDB.Bson.BsonType.String)]
        public string Specialty { get; set; } = string.Empty;

        [BsonElement("title"), BsonRepresentation(MongoDB.Bson.BsonType.String)]
        public string Title { get; set; } = string.Empty;

        [BsonElement("date"), BsonRepresentation(MongoDB.Bson.BsonType.DateTime)]
        public DateTime Date { get; set; } = DateTime.Now;

        [BsonElement("updated_at"), BsonRepresentation(MongoDB.Bson.BsonType.DateTime)]
        public DateTime UpdatedAt { get; set; } = DateTime.Now;

        [BsonElement("chat")]
        public List<Chat> Chats { get; set; } = new List<Chat>();

    }

    public class Chat
    {
        [BsonElement("query"), BsonRepresentation(MongoDB.Bson.BsonType.String)]
        public string Query { get; set; } = string.Empty;

        [BsonElement("response"), BsonRepresentation(MongoDB.Bson.BsonType.String)]
        public string Response { get; set; } = string.Empty;

        [BsonElement("timestamp"), BsonRepresentation(MongoDB.Bson.BsonType.DateTime)]
        public DateTime Timestamp { get; set; } = DateTime.Now;
    }

    public class ChatModelResponse
    {
        public bool Status { get; set; }
        public string Message { get; set; } = string.Empty;
        public ChatModel? Data { get; set; }
    }

    public class ChatListResponse
    {
        public bool Status { get; set; }
        public string Message { get; set; } = string.Empty;
        public List<ChatSummary>? Data { get; set; }
    }

    public class ChatSummary
    {
        public string Id { get; set; } = string.Empty;
        public string PatientId { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public DateTime Date { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int MessageCount { get; set; }
    }

    // Request DTOs
    public class SendMessageRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string ChatId { get; set; } = string.Empty; // Empty for new chat
        public string Message { get; set; } = string.Empty;
    }

    public class CreateChatRequest
    {
        public string PatientId { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public string InitialConditions { get; set; } = string.Empty;
        public string History { get; set; } = string.Empty;
    }

    // Response DTOs
    public class SendMessageResponse
    {
        public bool Status { get; set; }
        public string Message { get; set; } = string.Empty;
        public string ChatId { get; set; } = string.Empty;
        public string AIResponse { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
    }
}