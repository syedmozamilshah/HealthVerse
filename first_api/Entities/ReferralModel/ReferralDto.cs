using System.Text.Json.Serialization;

namespace first_api.Entities.ReferralModel
{
    public class CreateReferralDto
    {
        [JsonPropertyName("patientId")]
        public string PatientId { get; set; } = string.Empty;

        [JsonPropertyName("targetSpecialty")]
        public string TargetSpecialty { get; set; } = string.Empty;

        [JsonPropertyName("notes")]
        public string Notes { get; set; } = string.Empty;
    }

    public class ReferralResponseDto
    {
        [JsonPropertyName("isSuccess")]
        public bool IsSuccess { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;

        [JsonPropertyName("data")]
        public object? Data { get; set; }
    }
}
