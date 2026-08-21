using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

// M-1 USED IN AUTHCONTROLLER FOR USER REGISTRATION, LOGIN, AND ACCOUNT MANAGEMENT
// M-2 USED IN USERCONTROLLER FOR PATIENT PROFILE MANAGEMENT PLUS DOCTOR PROFILE MANAGEMENT, ALSO IN DOCTOR VERIFICATION CONTROLLER
// M-4 USED IN APPOINTMENT CONTROLLER
// M-4 USED IN DOCTOR BASIC INFO CONTROLLER FOR MOBILE APP
// M-6 USED IN PATIENT CONTROLLER FOR VITALS ENTRY  FOR PATIENTS
// M-9 USED IN DOCTOR VERIFICATION CONTROLLER
// M-9 USED IN DOCTOR ACTIVITY TRACKING
// M-9 USED IN PATIENT ACTIVITY TRACKING
// M-10 USED IN STRIPE SERVICE
namespace first_api.Entities.UserModel
{
    public class User
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

        [BsonElement("dob"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("dob")]
        public DateTime Dob { get; set; }

        [BsonElement("address"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("address")]
        public string Address { get; set; } = string.Empty;

        [BsonElement("blood_group"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("bloodGroup")]
        public string BloodGroup { get; set; } = string.Empty;

        [BsonElement("created_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; }

        [BsonElement("email"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;


        [BsonElement("gender"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("gender")]
        public string Gender { get; set; } = string.Empty;

        [BsonElement("password_hash"), BsonRepresentation(BsonType.String)]
        [System.Text.Json.Serialization.JsonIgnore]
        public string PasswordHash { get; set; } = string.Empty;

        [BsonElement("profile_type"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("profileType")]
        public string ProfileType { get; set; } = string.Empty;

        [BsonElement("whatsapp_no"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("whatsappNo")]
        public string WhatsappNo { get; set; } = string.Empty;

        [BsonElement("profile_image"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("profileImage")]
        public string ProfileImage { get; set; } = string.Empty;

        [BsonElement("is_email_verified"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("isEmailVerified")]
        public bool IsEmailVerified { get; set; } = false;

        [BsonElement("account_status"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("accountStatus")]
        public string? AccountStatus { get; set; }
        
        [BsonElement("refresh_token"), BsonRepresentation(BsonType.String)]
        [System.Text.Json.Serialization.JsonIgnore]
        public string? RefreshToken { get; set; } 
    }

    public class UserResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;

        public string? imageUrl { get; set; } = string.Empty;
    }
}