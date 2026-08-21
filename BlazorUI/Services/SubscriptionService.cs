using System.Net.Http.Json;

namespace BlazorUI.Services
{
    public class SubscriptionService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;

        public SubscriptionService(IHttpClientFactory httpClientFactory, IConfiguration configuration)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
        }

        public async Task<SubscriptionStatusResponse?> GetSubscriptionStatusAsync(string doctorId, string token)
        {
            try
            {
                var client = _httpClientFactory.CreateClient("API");
                client.DefaultRequestHeaders.Authorization = 
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
                
                var response = await client.GetAsync($"api/stripe/subscription-status?doctorId={doctorId}");
                
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<SubscriptionStatusResponse>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error checking subscription status: {ex.Message}");
            }
            
            return null;
        }

        public async Task<CreateCheckoutResponse?> CreateSubscriptionCheckoutAsync(string doctorId, string token)
        {
            try
            {
                var client = _httpClientFactory.CreateClient("API");
                client.DefaultRequestHeaders.Authorization = 
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
                
                var baseUrl = _configuration["ApiSettings:BlazorBaseUrl"] ?? "http://localhost:5180";
                
                var request = new
                {
                    doctorId = doctorId,
                    successUrl = $"{baseUrl}/payment-success",
                    cancelUrl = $"{baseUrl}/payment-due"
                };
                
                var response = await client.PostAsJsonAsync("api/stripe/create-subscription-checkout", request);
                
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<CreateCheckoutResponse>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating checkout session: {ex.Message}");
            }
            
            return null;
        }
    }

    public class SubscriptionStatusResponse
    {
        public bool IsSuccess { get; set; }
        public bool HasActiveSubscription { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime? CurrentPeriodEnd { get; set; }
        public bool IsPaymentCurrent { get; set; }
        public string Message { get; set; } = string.Empty;
    }

    public class CreateCheckoutResponse
    {
        public bool IsSuccess { get; set; }
        public string SessionId { get; set; } = string.Empty;
        public string SessionUrl { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }
}
