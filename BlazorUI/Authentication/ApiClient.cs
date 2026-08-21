using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using BlazorUI.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using Microsoft.JSInterop;



// M-1 FOR COOKIE-BASED AUTHENTICATION WITH AUTOMATIC REFRESH
namespace BlazorUI.Authentication
{
    public class ApiClient
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly ProtectedLocalStorage _localStorage;
        private readonly AuthenticationStateProvider _authStateProvider;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IJSRuntime _jsRuntime;
        private HttpClient _client;

        public ApiClient(
            IHttpClientFactory httpClientFactory,
            ProtectedLocalStorage localStorage,
            AuthenticationStateProvider authStateProvider,
            IHttpContextAccessor httpContextAccessor,
            IJSRuntime jsRuntime)
        {
            _httpClientFactory = httpClientFactory;
            _localStorage = localStorage;
            _authStateProvider = authStateProvider;
            _httpContextAccessor = httpContextAccessor;
            _jsRuntime = jsRuntime;
            _client = _httpClientFactory.CreateClient("API");
        }
        public async Task<HttpClient> SetAuthorizedHeader()
        {
            // Create a FRESH HttpClient for each request to prevent cross-user token leakage
            _client = _httpClientFactory.CreateClient("API");

            var cookieToken = _httpContextAccessor.HttpContext?.Request.Cookies["hv_access"];
            var refreshCookie = _httpContextAccessor.HttpContext?.Request.Cookies["hv_refresh"];

            // Doctor cookie-based authentication with automatic refresh
            if (!string.IsNullOrWhiteSpace(cookieToken) || !string.IsNullOrWhiteSpace(refreshCookie))
            {
                // If access token is expired but refresh token exists and is valid, try to refresh
                if ((string.IsNullOrWhiteSpace(cookieToken) || IsTokenExpired(cookieToken)) 
                    && !string.IsNullOrWhiteSpace(refreshCookie) 
                    && !IsTokenExpired(refreshCookie))
                {
                    try
                    {
                        Console.WriteLine("Access token expired, attempting automatic refresh using cookie...");
                        var refreshClient = _httpClientFactory.CreateClient("API");
                        
                        // Call the API with cookie-based refresh
                        var refreshRequest = new HttpRequestMessage(HttpMethod.Get, "/api/Auth/loginByRefreshToken");
                        refreshRequest.Headers.Add("Cookie", $"hv_refresh={refreshCookie}");
                        
                        var refreshResponse = await refreshClient.SendAsync(refreshRequest);
                        if (refreshResponse.IsSuccessStatusCode)
                        {
                            var refreshResult = await refreshResponse.Content.ReadFromJsonAsync<LoginResponse>();
                            if (refreshResult != null)
                            {
                                // Update cookies via JS helper
                                await _jsRuntime.InvokeVoidAsync("authCookies.setDoctorSession",
                                    refreshResult.Token,
                                    refreshResult.RefreshToken,
                                    refreshResult.TokenExpired,
                                    refreshResult.RefreshExpired);

                                // Update auth state
                                await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsAuthenticated(refreshResult);

                                // Use the new token
                                _client.DefaultRequestHeaders.Authorization =
                                    new AuthenticationHeaderValue("Bearer", refreshResult.Token);
                                
                                Console.WriteLine("Token refreshed successfully using cookie");
                                return _client;
                            }
                        }
                        
                        Console.WriteLine("Refresh failed, logging out");
                        await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                        await _jsRuntime.InvokeAsync<object>("authCookies.clearDoctorSession");
                        _client.DefaultRequestHeaders.Authorization = null;
                        return _client;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error during automatic refresh: {ex.Message}");
                        await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                        await _jsRuntime.InvokeAsync<object>("authCookies.clearDoctorSession");
                        _client.DefaultRequestHeaders.Authorization = null;
                        return _client;
                    }
                }

                // If access token is valid, use it
                if (!string.IsNullOrWhiteSpace(cookieToken) && !IsTokenExpired(cookieToken))
                {
                    _client.DefaultRequestHeaders.Authorization =
                        new AuthenticationHeaderValue("Bearer", cookieToken);
                    return _client;
                }

                // If both tokens are expired or missing
                await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                await _jsRuntime.InvokeAsync<object>("authCookies.clearDoctorSession");
                _client.DefaultRequestHeaders.Authorization = null;
                return _client;
            }

            // Fallback to localStorage for patient/admin (existing flow)
            var sessionState = (await _localStorage.GetAsync<LoginResponse>("sessionState")).Value;
            if (sessionState != null && !string.IsNullOrEmpty(sessionState.Token))
            {
                if (sessionState.TokenExpired < DateTimeOffset.UtcNow.ToUnixTimeSeconds())
                {
                    if (sessionState.RefreshExpired < DateTimeOffset.UtcNow.ToUnixTimeSeconds())
                    {
                        await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                        return _client;
                    }
                    else
                    {
                        Console.WriteLine("Calling the api to get the access token");
                        var refreshClient = _httpClientFactory.CreateClient("API");
                        var res = await refreshClient.GetFromJsonAsync<LoginResponse>(
                            $"/api/Auth/loginByRefreshToken?refreshToken={sessionState.RefreshToken}");

                        if (res != null)
                        {
                            await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsAuthenticated(res);
                            await _localStorage.SetAsync("sessionState", res);
                            sessionState = res;
                        }
                        else
                        {
                            await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                            return _client;
                        }
                    }
                    
                }
                else if (sessionState.TokenExpired < DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeSeconds())
                {
                    // var client = HttpClientFactory.CreateClient("API");
                    // var response = await client.PostAsJsonAsync("api/Auth/login", formData);
                    var refreshClient = _httpClientFactory.CreateClient("API");
                    var res = await refreshClient.GetFromJsonAsync<LoginResponse>(
                        $"/api/Auth/loginByRefreshToken?refreshToken={sessionState.RefreshToken}");

                    if (res != null)
                    {
                        await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsAuthenticated(res);
                        await _localStorage.SetAsync("sessionState", res);
                        sessionState = res;
                    }
                    else
                    {
                        await ((CustomAuthStateProvider)_authStateProvider).MarkUserAsLoggedOut();
                        return _client;
                    }
                }
            }

            if (sessionState == null || string.IsNullOrEmpty(sessionState.Token))
            {
                _client.DefaultRequestHeaders.Authorization = null;
                return _client;
            }
            _client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", sessionState!.Token);

            return _client;
        }

        private static bool IsTokenExpired(string token)
        {
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
    }
}