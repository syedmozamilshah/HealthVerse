using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-1 USED FOR ACCOUNT VERIFICATION AND PASSWORD RESET FUNCTIONALITY
namespace first_api.Entities.AuthModel

{
    public class EmailVerificationToken
    {
        public string Id { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public DateTime CreatedOnUtc { get; set; }
        [BsonElement("ExpiredOnUtc")]
        [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
        public DateTime ExpiredOnUtc { get; set; }

    }

    public class ForgotPasswordRequest
    {
        public string Email { get; set; } = string.Empty;
        public string ProfileType { get; set; } = string.Empty;
    }

    public class ResetPasswordRequest
{
    public string Token { get; set; } = string.Empty;

    [JsonPropertyName("previousPassword")]
    public string PreviousPassword { get; set; } = string.Empty;

    [JsonPropertyName("newPassword")]
    public string NewPassword { get; set; } = string.Empty;
}
}