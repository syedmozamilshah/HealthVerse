using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BlazorUI.Models
{
    public class User
    {
        public string Id { get; set; } = string.Empty;

        [Required(ErrorMessage = "First Name is required")]
        [RegularExpression(@"^[A-Za-z\s'\-]{3,}$", ErrorMessage = "First name must be at least 3 letters and contain no digits.")]
        [JsonPropertyName("first_name")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last Name is required")]
        [RegularExpression(@"^[A-Za-z\s'\-]{3,}$", ErrorMessage = "Last name must be at least 3 letters and contain no digits.")]
        [JsonPropertyName("last_name")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Address is required")]
        [StringLength(150, MinimumLength = 10, ErrorMessage = "Address must be between 10 and 150 characters.")]
        [JsonPropertyName("address")]
        public string Address { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Invalid email format")]
        [StringLength(30, MinimumLength = 6, ErrorMessage = "Email must be between 6 and 30 characters.")]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Gender is required")]
        [JsonPropertyName("gender")]
        public string Gender { get; set; } = string.Empty;

        [JsonPropertyName("profile_image")]
        public string ProfileImage { get; set; } = string.Empty;

        [JsonPropertyName("profile_type")]
        public string ProfileType { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        [MinLength(6, ErrorMessage = "Password must be at least 6 characters")]
        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;

        [Required(ErrorMessage = "Confirm Password is required")]
        [Compare("Password", ErrorMessage = "Passwords do not match")]
        public string ConfirmPassword { get; set; } = string.Empty;

    }


    public class LoginUser
    {
        public string Id { get; set; } = string.Empty;

        [Required(ErrorMessage = "First Name is required")]
        [JsonPropertyName("firstName")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last Name is required")]
        [JsonPropertyName("lastName")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Address is required")]
        [JsonPropertyName("address")]
        public string Address { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Invalid email format")]
        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Gender is required")]
        [JsonPropertyName("gender")]
        public string Gender { get; set; } = string.Empty;

        [JsonPropertyName("profileImage")]
        public string ProfileImage { get; set; } = string.Empty;

        [JsonPropertyName("profileType")]
        public string ProfileType { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        [MinLength(6, ErrorMessage = "Password must be at least 6 characters")]
        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;


    }

    public class RegisterLoginResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        public User User { get; set; } = new();
    }

    public class LoginResponse
    {
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;

        public string RefreshToken { get; set; } = string.Empty;
        public long? TokenExpired { get; set; }
        public long? RefreshExpired{ get; set; }
        public LoginUser User { get; set; } = new();
    }
}
