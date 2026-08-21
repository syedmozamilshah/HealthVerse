using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using first_api.Entities.UserModel;


// M-1 USED IN AUTH CONTROLLER FOR REQUEST AND RESPONSE MODELS
namespace first_api.Entities.AuthModel
{
    public class LoginRequest
    {
        [Required]
        [EmailAddress]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [Required]
        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;

        [Required]
        [JsonPropertyName("profile_type")]
        public string ProfileType { get; set; } = string.Empty;

    }

    public class RegisterRequest
{
    [Required]
    [JsonPropertyName("first_name")]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    [JsonPropertyName("last_name")]
    public string LastName { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(6)]
    [JsonPropertyName("password")]
    public string Password { get; set; } = string.Empty;


    [JsonPropertyName("dob")]
    public DateTime? Dob { get; set; }  

    [JsonPropertyName("address")]
    public string Address { get; set; } = string.Empty;

    [JsonPropertyName("blood_group")]
    public string? BloodGroup { get; set; }

    [JsonPropertyName("gender")]
    public string Gender { get; set; }  = string.Empty;

    [JsonPropertyName("profile_type")]
    public string ProfileType { get; set; } = string.Empty;

    [JsonPropertyName("whatsapp_no")]
    public string? WhatsappNo { get; set; }

    [JsonPropertyName("profile_image")]
    public string? ProfileImage { get; set; }
}

    public class AuthResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public string? Token { get; set; }
        public string? RefreshToken { get; set; }
        public long? TokenExpired{ get; set; }
        public long? RefreshExpired{get;set;}
        public User? User { get; set; }
    }
} 