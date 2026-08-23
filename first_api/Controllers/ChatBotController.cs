using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Text;

namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ChatBotController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly HttpClient _httpClient;
        private const string PrimaryModel = "gemini-2.5-flash";
        private const string FallbackModel = "gemini-2.0-flash";
        private const string BaseUrl = "https://generativelanguage.googleapis.com/v1beta/models";
        private const int MaxRetries = 3;

        private const string SystemPrompt = @"You are ""Eye Buddy"" - a friendly, fun, and helpful eye health assistant for HealthVerse app. Your role is to help patients with eye-related questions in simple, easy-to-understand language.

PERSONALITY:
- Be warm, friendly, and encouraging like a helpful friend
- Use simple language that anyone can understand (no medical jargon)
- Add occasional eye-related puns or jokes to keep things fun 👁️
- Be empathetic and reassuring when users express concerns
- Use emojis sparingly to be friendly but professional

WHAT YOU CAN DO:
✅ Answer general eye health questions (dry eyes, eye strain, common symptoms)
✅ Explain common eye conditions in layman's terms (cataracts, glaucoma, myopia, etc.)
✅ Give eye care tips (screen time, nutrition, exercises, proper lighting)
✅ Tell fun eye facts and jokes when asked
✅ Respond to greetings and casual conversation
✅ Encourage users to book appointments for serious concerns
✅ Explain what to expect at eye exams

WHAT YOU CANNOT DO:
❌ Diagnose any eye condition - always recommend seeing a doctor
❌ Prescribe medications or treatments
❌ Answer questions unrelated to eyes, vision, or general wellness
❌ Provide emergency medical advice (direct to emergency services)
❌ Make fun of any disability or condition

BOUNDARIES:
- For non-eye questions, politely redirect: ""I'm your eye health buddy! I can only help with eye-related questions. Is there something about your eyes or vision I can help with? 👁️""
- For serious symptoms (sudden vision loss, severe pain, injury), say: ""That sounds serious! Please seek immediate medical attention or visit your nearest eye doctor/emergency room right away. Your vision is precious! 🏥""
- Never claim to replace professional medical advice

RESPONSE STYLE:
- Keep responses concise (2-4 sentences for simple questions)
- Use bullet points for tips or lists
- End with a helpful question or encouragement when appropriate
- For jokes, keep them light and family-friendly

EXAMPLE JOKES (when asked):
- ""Why did the phone wear glasses? Because it lost all its contacts! 📱👓""
- ""I used to hate my glasses, but then I looked back and realized they helped me see things more clearly!""
- ""What do you call a fish with no eyes? A fsh! 🐟""

Remember: You're here to be helpful, fun, and supportive while keeping eyes healthy! 👁️✨";

        public ChatBotController(IConfiguration configuration)
        {
            _configuration = configuration;
            _httpClient = new HttpClient();
        }

        [HttpPost("ask")]
        public async Task<IActionResult> AskGemini([FromBody] ChatRequest request)
        {
            try
            {
                var apiKeys = _configuration.GetSection("Gemini:ApiKeys").Get<List<string>>();
                if (apiKeys == null || !apiKeys.Any())
                {
                    return StatusCode(500, new { IsSuccess = false, Message = "API keys not configured." });
                }

                // Build Gemini Request Payload
                var requestBody = new
                {
                    system_instruction = new
                    {
                        parts = new[] { new { text = SystemPrompt } }
                    },
                    contents = request.History.Take(10).Select(h => new
                    {
                        role = h.Role,
                        parts = new[] { new { text = h.Parts } }
                    }).Concat(new[]
                    {
                        new
                        {
                            role = "user",
                            parts = new[] { new { text = request.UserMessage } }
                        }
                    }).ToList(),
                    generationConfig = new
                    {
                        temperature = 0.7,
                        topK = 40,
                        topP = 0.95,
                        maxOutputTokens = 1024,
                    },
                    safetySettings = new[]
                    {
                        new { category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_MEDIUM_AND_ABOVE" },
                        new { category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_MEDIUM_AND_ABOVE" },
                        new { category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_MEDIUM_AND_ABOVE" },
                        new { category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_MEDIUM_AND_ABOVE" }
                    }
                };

                var jsonContent = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

                HttpResponseMessage response = null;
                foreach (var apiKey in apiKeys)
                {
                    for (int attempt = 1; attempt <= MaxRetries; attempt++)
                    {
                        response = await _httpClient.PostAsync($"{BaseUrl}/{PrimaryModel}:generateContent?key={apiKey}", jsonContent);
                        
                        if (response.StatusCode == System.Net.HttpStatusCode.Forbidden || response.StatusCode == System.Net.HttpStatusCode.BadRequest)
                        {
                            // API Key might be invalid or leaked, break out of retries and try next key
                            Console.WriteLine($"Gemini API Key failed with status {response.StatusCode}. Trying next key...");
                            break; 
                        }
                        
                        if (response.StatusCode != System.Net.HttpStatusCode.ServiceUnavailable)
                        {
                            break;
                        }
                        Console.WriteLine($"Gemini 503 (attempt {attempt}/{MaxRetries}) - retrying...");
                        await Task.Delay(1000 * (1 << (attempt - 1))); // Exponential backoff
                    }
                    
                    if (response != null && response.StatusCode == System.Net.HttpStatusCode.ServiceUnavailable)
                    {
                        // Fallback model
                        Console.WriteLine($"Falling back to {FallbackModel}...");
                        response = await _httpClient.PostAsync($"{BaseUrl}/{FallbackModel}:generateContent?key={apiKey}", jsonContent);
                    }

                    if (response != null && response.IsSuccessStatusCode)
                    {
                        var responseString = await response.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(responseString);
                        var candidates = doc.RootElement.GetProperty("candidates");
                        if (candidates.GetArrayLength() > 0)
                        {
                            var text = candidates[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();
                            return Ok(new { IsSuccess = true, Message = text });
                        }
                    }
                    
                    // If we get here, this key failed to get a success response, let loop continue to next key
                }
                
                var errorBody = response != null ? await response.Content.ReadAsStringAsync() : "No response";
                Console.WriteLine($"Gemini API Error: {errorBody}");
                return Ok(new { IsSuccess = false, Message = "Oops! I'm having a little trouble connecting. Please try again in a moment! 👁️" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"BuddyChatController Error: {ex.Message}");
                return StatusCode(500, new { IsSuccess = false, Message = $"Something went wrong on my end. Please try again! 👁️" });
            }
        }
    }

    public class ChatRequest
    {
        public string UserMessage { get; set; } = string.Empty;
        public List<ChatMessage> History { get; set; } = new List<ChatMessage>();
    }

    public class ChatMessage
    {
        public string Role { get; set; } = string.Empty;
        public string Parts { get; set; } = string.Empty;
    }
}
