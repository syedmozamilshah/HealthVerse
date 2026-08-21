using System.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using first_api.Entities;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Options;
using first_api.Entities.UserModel;
using first_api.Entities.AuthModel;

// M-1 USED IN AUTHENTICATION CONTROLLER FOR TOKEN GENERATION, PASSWORD HASHING, AND PASSWORD GENERATION
namespace first_api.Services
{
    public interface IJwtService
    {
        string GenerateToken(User user,bool isRefreshToken);
        string HashPassword(string password);
        bool VerifyPassword(string password, string hash);
        public string GeneratePassword();
    }

    public class JwtService : IJwtService
    {
        private readonly JwtSettings _jwtSettings;
        private readonly Random _random = new Random();


        public JwtService(IOptions<JwtSettings> jwtSettings)
        {
            _jwtSettings = jwtSettings.Value;
        }


public string GenerateToken(User user, bool isRefreshToken)
{
    var tokenHandler = new JwtSecurityTokenHandler();
    var key = Encoding.ASCII.GetBytes(isRefreshToken ? _jwtSettings.RefreshKey : _jwtSettings.SecretKey);

    var now = DateTime.Now;

    var claims = new List<Claim>
    {
        new Claim(ClaimTypes.NameIdentifier, user.Id),
        new Claim(ClaimTypes.Email, user.Email),
        new Claim(ClaimTypes.Name, $"{user.FirstName} {user.LastName}"),
        new Claim(ClaimTypes.Role, user.ProfileType),
        new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()), 
        new Claim(JwtRegisteredClaimNames.Iat, new DateTimeOffset(now).ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64) 
    };

    var tokenDescriptor = new SecurityTokenDescriptor
    {
        Subject = new ClaimsIdentity(claims),
        Expires = now.AddMinutes(isRefreshToken ? _jwtSettings.RefreshTokenExpiration : _jwtSettings.JwtExpirationInMinutes),
        Issuer = _jwtSettings.Issuer,
        Audience = _jwtSettings.Audience,
        SigningCredentials = new SigningCredentials(
            new SymmetricSecurityKey(key),
            SecurityAlgorithms.HmacSha256Signature
        )
    };

    var token = tokenHandler.CreateToken(tokenDescriptor);
    return tokenHandler.WriteToken(token);
}

        public string GeneratePassword()
        {
            const int length = 8; // minimum length
            const string upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            const string lower = "abcdefghijklmnopqrstuvwxyz";
            const string digits = "0123456789";
            const string special = "!@#$%^&*()-_=+[]{};:,.<>?";
            var all = upper + lower + digits + special;

            char GetRandomChar(string src)
            {
                var idx = RandomNumberGenerator.GetInt32(src.Length);
                return src[idx];
            }

            var chars = new List<char>
            {
                GetRandomChar(upper),
                GetRandomChar(digits),
                GetRandomChar(special)
            };

            while (chars.Count < length)
            {
                chars.Add(GetRandomChar(all));
            }

            for (int i = chars.Count - 1; i > 0; i--)
            {
                int j = RandomNumberGenerator.GetInt32(i + 1);
                var tmp = chars[i];
                chars[i] = chars[j];
                chars[j] = tmp;
            }

            return new string(chars.ToArray());
        }


        public string HashPassword(string password)
        {
            using var sha256 = SHA256.Create();
            var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(hashedBytes);
        }

        public bool VerifyPassword(string password, string hash)
        {
            var hashedPassword = HashPassword(password);
            return hashedPassword == hash;
        }
    }
} 