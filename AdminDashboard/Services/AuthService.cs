using System.Net.Http.Json;
using System.Text.Json;
using System.IdentityModel.Tokens.Jwt;
using AdminDashboard.Models;


namespace AdminDashboard.Services
{

    // M-1 CALLING ALL THE API ENDPOINTS RELATED TO AUTHENTICATION
    public class AuthService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly string _baseUrl;
        private bool _isAuthenticated = false;
        private string? _token;
        private string? _refreshToken;
        private long _tokenExpired = 0;
        private long _refreshExpired = 0;
        private AdminUser? _currentUser;



        public AuthService(IHttpClientFactory httpClientFactory, IConfiguration configuration)
        {
            _httpClientFactory = httpClientFactory;
            _baseUrl = configuration["ApiSettings:BaseUrl"] ?? "http://localhost:5257";
        }

        public bool IsAuthenticated => _isAuthenticated;
        public string? Token => _token;
        public string? RefreshToken => _refreshToken;
        public long TokenExpired => _tokenExpired;
        public long RefreshExpired => _refreshExpired;
        public AdminUser? CurrentUser => _currentUser;

        public event Action? OnAuthStateChanged;

        // Clear auth state when circuit closes (e.g., tab closed)
        public async Task LogoutAsync()
        {
            _isAuthenticated = false;
            _token = null;
            _refreshToken = null;
            _tokenExpired = 0;
            _refreshExpired = 0;
            _currentUser = null;

            // Clear cookies via HTTP call to endpoint
            try
            {
                await ClearCookiesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error clearing cookies: {ex.Message}");
            }

            OnAuthStateChanged?.Invoke();
        }

        // Legacy sync logout for backwards compatibility
        public void Logout()
        {
            _isAuthenticated = false;
            _token = null;
            _refreshToken = null;
            _tokenExpired = 0;
            _refreshExpired = 0;
            _currentUser = null;
            OnAuthStateChanged?.Invoke();
        }

        /// <summary>
        /// Authenticates admin user - currently uses local validation 
        /// since API doesn't have admin-specific login endpoint
        /// </summary>
        public async Task<(bool success, string message)> LoginAsync(string email, string password)
        {
            try
            {
                // Try API authentication first (works when backend has admin account)
                if (!string.IsNullOrWhiteSpace(_baseUrl))
                {
                    try
                    {
                        var httpClient = _httpClientFactory.CreateClient();
                        var baseAddr = _baseUrl.EndsWith("/") ? _baseUrl : _baseUrl + "/";
                        httpClient.BaseAddress = new Uri(baseAddr);

                        var loginRequest = new AdminLoginRequest
                        {
                            Email = email,
                            Password = password,
                            ProfileType = "admin"
                        };

                        var response = await httpClient.PostAsJsonAsync("api/Auth/login", loginRequest);
                        var content = await response.Content.ReadAsStringAsync();

                        if (response.IsSuccessStatusCode)
                        {
                            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                            var loginResponse = JsonSerializer.Deserialize<AdminLoginResponse>(content, options);

                            if (loginResponse?.IsSuccess == true)
                            {
                                _isAuthenticated = true;
                                _token = loginResponse.Token;
                                _refreshToken = loginResponse.RefreshToken;
                                _tokenExpired = loginResponse.TokenExpired ?? 0;
                                _refreshExpired = loginResponse.RefreshExpired ?? 0;
                                _currentUser = loginResponse.User;

                                // Set cookies via HTTP call to endpoint
                                try
                                {
                                    await SetCookiesAsync(loginResponse.Token, loginResponse.RefreshToken, loginResponse.TokenExpired, loginResponse.RefreshExpired);
                                }
                                catch (Exception ex)
                                {
                                    Console.WriteLine($"Error setting cookies: {ex.Message}");
                                }

                                OnAuthStateChanged?.Invoke();
                                return (true, loginResponse.Message);
                            }

                            // If API returned a well-formed response but authentication failed, return that message
                            return (false, loginResponse?.Message ?? "Login failed");
                        }

                        // If API responded with non-success, fall through to local validation fallback
                        Console.WriteLine($"API login failed with status {response.StatusCode}: {content}");
                    }
                    catch (Exception ex)
                    {
                        // Network / serialization errors -> log and fallback to local validation
                        Console.WriteLine($"API login attempt failed: {ex.Message}");
                    }
                }

                // Local fallback: used when API is unavailable or admin endpoint not present
                // Enforce email-only login for admin (remove legacy username aliases)
                // if (email == AdminEmail && password == AdminPassword)
                // {
                //     _isAuthenticated = true;
                //     _currentUser = new AdminUser
                //     {
                //         Id = "admin-001",
                //         FirstName = "Admin",
                //         LastName = "User",
                //         Email = AdminEmail,
                //         ProfileType = "admin"
                //     };
                //     OnAuthStateChanged?.Invoke();
                //     return (true, "Login successful (local fallback)");
                // }

                return (false, "Invalid email or password");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Login Error: {ex.Message}");
                return (false, "An error occurred during login. Please try again.");
            }
        }

        /// <summary>
        /// Check if access token is expired or will expire within 5 minutes (proactive refresh)
        /// </summary>
        public bool ShouldRefreshToken()
        {
            if (_tokenExpired == 0)
                return false;

            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var expiresIn5Minutes = now + (5 * 60); // 5 minutes in seconds

            // Refresh if token is already expired or will expire within 5 minutes
            return _tokenExpired <= expiresIn5Minutes;
        }

        /// <summary>
        /// Check if a JWT token has expired
        /// </summary>
        private static bool IsTokenExpired(string? token)
        {
            if (string.IsNullOrWhiteSpace(token))
                return true;

            try
            {
                var handler = new JwtSecurityTokenHandler();
                var jwtToken = handler.ReadJwtToken(token);
                return jwtToken.ValidTo <= DateTime.UtcNow;
            }
            catch
            {
                return true;
            }
        }

        /// <summary>
        /// Refresh the access token using the refresh token
        /// </summary>
        public async Task<bool> RefreshTokenAsync()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_refreshToken))
                {
                    Console.WriteLine("No refresh token available");
                    await LogoutAsync();
                    return false;
                }

                // Check if refresh token itself has expired
                if (IsTokenExpired(_refreshToken))
                {
                    Console.WriteLine("Refresh token has expired");
                    await LogoutAsync();
                    return false;
                }

                var httpClient = _httpClientFactory.CreateClient();
                var baseAddr = _baseUrl.EndsWith("/") ? _baseUrl : _baseUrl + "/";
                httpClient.BaseAddress = new Uri(baseAddr);

                var response = await httpClient.GetAsync($"api/Auth/loginByRefreshToken?refreshToken={_refreshToken}");
                var content = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    var loginResponse = JsonSerializer.Deserialize<AdminLoginResponse>(content, options);

                    if (loginResponse?.IsSuccess == true && !string.IsNullOrWhiteSpace(loginResponse.Token))
                    {
                        _token = loginResponse.Token;
                        _refreshToken = loginResponse.RefreshToken;
                        _tokenExpired = loginResponse.TokenExpired ?? 0;
                        _refreshExpired = loginResponse.RefreshExpired ?? 0;

                        // Update cookies via HTTP call to endpoint
                        try
                        {
                            await SetCookiesAsync(loginResponse.Token, loginResponse.RefreshToken, loginResponse.TokenExpired, loginResponse.RefreshExpired);
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error updating cookies after refresh: {ex.Message}");
                        }

                        Console.WriteLine("Token refreshed successfully");
                        return true;
                    }
                }

                // If refresh failed, logout
                Console.WriteLine("Token refresh failed");
                await LogoutAsync();
                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Token refresh error: {ex.Message}");
                await LogoutAsync();
                return false;
            }
        }

        /// <summary>
        /// Restore authentication state from cookies (called on app startup)
        /// </summary>
        /// <summary>
        /// Set cookies on the server via HTTP call
        /// </summary>
        private async Task SetCookiesAsync(string? token, string? refreshToken, long? tokenExpires, long? refreshExpires)
        {
            try
            {
                var httpClient = new HttpClient();
                // For local Blazor server calls, use localhost explicitly
                httpClient.BaseAddress = new Uri("http://localhost:5230");  // Adjust port as needed

                var request = new AdminCookieRequest
                {
                    Token = token,
                    RefreshToken = refreshToken,
                    TokenExpires = tokenExpires,
                    RefreshExpires = refreshExpires
                };

                var response = await httpClient.PostAsJsonAsync("/auth/admin-cookie", request);
                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"Cookie endpoint returned {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error setting cookies via endpoint: {ex.Message}");
            }
        }

        /// <summary>
        /// Clear cookies on the server via HTTP call
        /// </summary>
        private async Task ClearCookiesAsync()
        {
            try
            {
                var httpClient = new HttpClient();
                // For local Blazor server calls, use localhost explicitly
                httpClient.BaseAddress = new Uri("http://localhost:5230");  // Adjust port as needed

                var response = await httpClient.PostAsync("/auth/admin-cookie/clear", null);
                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"Clear cookie endpoint returned {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error clearing cookies via endpoint: {ex.Message}");
            }
        }

       
    }
}
