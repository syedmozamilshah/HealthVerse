using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;


// M-1 : Models for Admin Authentication (Login Request and Response)
namespace AdminDashboard.Models
{
    public class AdminLoginRequest
    {
        [Required(ErrorMessage = "Username/Email is required")]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;

        [JsonPropertyName("profile_type")]
        public string ProfileType { get; set; } = "admin";
    }

    public class AdminLoginResponse
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("token")]
        public string? Token { get; set; }

        [JsonPropertyName("refreshToken")]
        public string? RefreshToken { get; set; }

        [JsonPropertyName("tokenExpired")]
        public long? TokenExpired { get; set; }

        [JsonPropertyName("refreshExpired")]
        public long? RefreshExpired { get; set; }

        [JsonPropertyName("user")]
        public AdminUser? User { get; set; }
    }

    public class AdminUser
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("firstName")]
        public string FirstName { get; set; } = string.Empty;

        [JsonPropertyName("lastName")]
        public string LastName { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("profileType")]
        public string ProfileType { get; set; } = string.Empty;

        [JsonPropertyName("profileImage")]
        public string ProfileImage { get; set; } = string.Empty;
    }

    public class AdminCookieRequest
    {
        [JsonPropertyName("token")]
        public string? Token { get; set; }

        [JsonPropertyName("refreshToken")]
        public string? RefreshToken { get; set; }

        [JsonPropertyName("tokenExpires")]
        public long? TokenExpires { get; set; }

        [JsonPropertyName("refreshExpires")]
        public long? RefreshExpires { get; set; }
    }
}
