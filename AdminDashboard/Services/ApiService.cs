using System.Net.Http.Json;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace AdminDashboard.Services
{
    public class ApiService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly string _baseUrl;
        private readonly AuthService _authService;

        public ApiService(IHttpClientFactory httpClientFactory, IConfiguration configuration, AuthService authService)
        {
            _httpClientFactory = httpClientFactory;
            _baseUrl = configuration["ApiSettings:BaseUrl"] ?? "https://healthverse-ubdt.onrender.com";
            _authService = authService;
        }

        private HttpClient CreateClient()
        {
            var httpClient = _httpClientFactory.CreateClient();
            httpClient.BaseAddress = new Uri(_baseUrl);

            var token = _authService.Token;
            if (!string.IsNullOrWhiteSpace(token))
            {
                httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }

            return httpClient;
        }

        /// <summary>
        /// Ensure token is refreshed if needed before making API calls
        /// </summary>
        private async Task EnsureTokenRefreshedAsync()
        {
            try
            {
                if (_authService.ShouldRefreshToken())
                {
                    Console.WriteLine("Token refresh needed, refreshing...");
                    await _authService.RefreshTokenAsync();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error ensuring token refresh: {ex.Message}");
            }
        }

        public async Task<T?> GetAsync<T>(string endpoint)
        {
            try
            {
                await EnsureTokenRefreshedAsync();
                
                var httpClient = CreateClient();
                
                var response = await httpClient.GetAsync(endpoint);
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<T>(content, options);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"API Error: {ex.Message}");
            }
            return default;
        }

        public async Task<TResponse?> PostAsync<TRequest, TResponse>(string endpoint, TRequest data)
        {
            try
            {
                await EnsureTokenRefreshedAsync();
                
                var httpClient = CreateClient();
                
                var json = JsonSerializer.Serialize(data);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await httpClient.PostAsync(endpoint, content);
                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<TResponse>(responseContent, options);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"API Post Error: {ex.Message}");
            }
            return default;
        }

        public async Task<T?> PostAsync<T>(string endpoint, object? data)
        {
            try
            {
                await EnsureTokenRefreshedAsync();
                
                var httpClient = CreateClient();
                
                var content = data != null 
                    ? new StringContent(JsonSerializer.Serialize(data), Encoding.UTF8, "application/json")
                    : new StringContent("{}", Encoding.UTF8, "application/json");
                
                var response = await httpClient.PostAsync(endpoint, content);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<T>(responseContent, options);
                }
                else
                {
                    // Try to parse error response
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<T>(responseContent, options);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"API Post Error: {ex.Message}");
            }
            return default;
        }

        public async Task<T?> PutAsync<T>(string endpoint, object? data)
        {
            try
            {
                await EnsureTokenRefreshedAsync();
                
                var httpClient = CreateClient();
                
                var content = data != null 
                    ? new StringContent(JsonSerializer.Serialize(data), Encoding.UTF8, "application/json")
                    : new StringContent("{}", Encoding.UTF8, "application/json");
                
                var response = await httpClient.PutAsync(endpoint, content);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<T>(responseContent, options);
                }
                else
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    return JsonSerializer.Deserialize<T>(responseContent, options);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"API Put Error: {ex.Message}");
            }
            return default;
        }
    }

    // Response models
    public class ApiResponse<T>
    {
        public bool IsSuccess { get; set; }
        public T? Data { get; set; }
        public string? Message { get; set; }
    }

    public class UserInfo
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
    }

    public class CountData
    {
        public long TotalUsers { get; set; }
        public long VerifiedUsers { get; set; }
        public long UnverifiedUsers { get; set; }
        public long TotalDoctors { get; set; }
        public long VerifiedDoctors { get; set; }
        public long UnverifiedDoctors { get; set; }
    }

    public class DoctorDetails
    {
        public string LicenceNumber { get; set; } = string.Empty;
        public DateTime RenewalDate { get; set; }
        public string Speciality { get; set; } = string.Empty;
        public bool IsAvailable { get; set; }
        public ClinicInfo? ClinicInfo { get; set; }
        public string Experience { get; set; } = string.Empty;
        public string Fee { get; set; } = string.Empty;
        public string Specialization { get; set; } = string.Empty;
        
        // Verification fields
        public bool IsSubmittedForVerification { get; set; }
        public bool IsReVerificationRequired { get; set; }
        public bool IsLicenseInfoLocked { get; set; }
        public string CNICFrontImage { get; set; } = string.Empty;
        public string CNICBackImage { get; set; } = string.Empty;
        public string MBBSImage { get; set; } = string.Empty;
        public string FCPSImage { get; set; } = string.Empty;
        public string LicenseImage { get; set; } = string.Empty;
    }

    public class ClinicInfo
    {
        public string Location { get; set; } = string.Empty;
    }

    public class ServerMetrics
    {
        public double CpuUsage { get; set; }
        public double MemoryUsage { get; set; }
        public int ActiveThreads { get; set; }
        public double AvgResponseTime { get; set; }
    }

    public class ActivityLog
    {
        public string Timestamp { get; set; } = string.Empty;
        public string User { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string IpAddress { get; set; } = string.Empty;
    }
}
