using System;
using System.Collections.Generic;
using System.Linq;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using Radzen;
using BlazorUI.Models;


// M-1 GETTING THE ACCESS TOKEN 
namespace BlazorUI.Authentication
{
    public class CustomAuthStateProvider(ProtectedLocalStorage localStorage, IHttpContextAccessor httpContextAccessor) : AuthenticationStateProvider
    {

        public async override Task<AuthenticationState> GetAuthenticationStateAsync()
        {
            LoginResponse sessionModel = null;
            var cookieToken = httpContextAccessor.HttpContext?.Request.Cookies["hv_access"];
            try
            {
                if (string.IsNullOrWhiteSpace(cookieToken))
                {
                    var result = await localStorage.GetAsync<LoginResponse>("sessionState");
                    if (result.Success)
                    {
                        sessionModel = result.Value;
                    }
                }
            }
            catch (System.Security.Cryptography.CryptographicException)
            {
                try { await localStorage.DeleteAsync("sessionState"); } catch { }
            }
            catch
            {
            }

            var token = string.IsNullOrWhiteSpace(cookieToken) ? sessionModel?.Token : cookieToken;
            var identity = string.IsNullOrWhiteSpace(token) ? new ClaimsIdentity() : GetClaimsIdentity(token);
            var user = new ClaimsPrincipal(identity);
            return new AuthenticationState(user);
        }

        public async Task MarkUserAsAuthenticated(LoginResponse model)
        {
            await localStorage.SetAsync("sessionState", model);
            var identity = GetClaimsIdentity(model.Token);
            var user = new ClaimsPrincipal(identity);
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(user)));
        }

        public async Task MarkUserAsLoggedOut()
        {
            await localStorage.DeleteAsync("sessionState");
            var identity = new ClaimsIdentity();
            var user = new ClaimsPrincipal(identity);
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(user)));
        }

        private ClaimsIdentity GetClaimsIdentity(string token)
        {
            var handler = new JwtSecurityTokenHandler();
            var jwtToken = handler.ReadJwtToken(token);
            var claims = jwtToken.Claims;
            return new ClaimsIdentity(claims, "jwt");
        }

        
    }
}