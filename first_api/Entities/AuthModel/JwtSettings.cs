namespace first_api.Entities.AuthModel

// M-1 USED TO GET THE SECRET KEY
{
    public class JwtSettings
    {
        public string SecretKey { get; set; } = string.Empty;
        public string RefreshKey { get; set; } = string.Empty;
        public string Issuer { get; set; } = string.Empty;
        public string Audience { get; set; } = string.Empty;
        public int JwtExpirationInMinutes { get; set; }
        public int RefreshTokenExpiration{ get; set; }
    }
} 