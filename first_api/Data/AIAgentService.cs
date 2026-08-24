using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;


// M-3 ALL THE MAIN  SPECIALIST AGENTS ARE HANDLED IN THIS SERVICE
// M-8 USED IN PATIENT FOR CHATS AND ALSO IN MODEL CALLING
namespace first_api.Data
{
    public class AIAgentService
    {
        private readonly HttpClient _httpClient;

        // AI Agent endpoints — Unified Python LangGraph Specialist Agents
        // All 4 specialists now run on the new HealthVerse Doctor Agents service
        // Local dev fallback updated to Render URL
        private static readonly string DoctorAgentsBaseUrl = 
            System.Environment.GetEnvironmentVariable("DOCTOR_AGENTS_URL") ?? "https://healthverse-doctor-agents.onrender.com";

        private static readonly Dictionary<string, AgentConfig> AgentEndpoints = new(StringComparer.OrdinalIgnoreCase)
        {
            ["optician"] = new AgentConfig
            {
                Endpoint = $"{DoctorAgentsBaseUrl}/chat/optician",
                RequestFormat = AgentRequestFormat.MessagesArray
            },
            ["optometrist"] = new AgentConfig
            {
                Endpoint = $"{DoctorAgentsBaseUrl}/chat/optometrist",
                RequestFormat = AgentRequestFormat.MessagesArray
            },
            ["ocularist"] = new AgentConfig
            {
                Endpoint = $"{DoctorAgentsBaseUrl}/chat/ocularist",
                RequestFormat = AgentRequestFormat.MessagesArray
            },
            ["ophthalmologist"] = new AgentConfig
            {
                Endpoint = $"{DoctorAgentsBaseUrl}/chat/ophthalmologist",
                RequestFormat = AgentRequestFormat.MessagesArray
            }
        };

        public AIAgentService(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.Timeout = TimeSpan.FromSeconds(120); // AI agents can take time
        }

        public async Task<AIAgentResponse> SendMessageAsync(string specialty, string message, List<ChatMessage>? conversationHistory = null)
        {
            try
            {
                // Normalize specialty name
                var normalizedSpecialty = NormalizeSpecialty(specialty);
                Console.WriteLine($"=== AI Agent Request ===");
                Console.WriteLine($"Specialty: {specialty} -> Normalized: {normalizedSpecialty}");
                
                if (!AgentEndpoints.TryGetValue(normalizedSpecialty, out var agentConfig))
                {
                    return new AIAgentResponse
                    {
                        Success = false,
                        Error = $"No AI agent configured for specialty: {specialty}. Supported specialties: {string.Join(", ", AgentEndpoints.Keys)}"
                    };
                }

                Console.WriteLine($"Endpoint: {agentConfig.Endpoint}");
                Console.WriteLine($"Request Format: {agentConfig.RequestFormat}");

                // Build request based on agent type
                var requestBody = BuildRequestBody(agentConfig.RequestFormat, message, conversationHistory);
                Console.WriteLine($"Request Body: {requestBody}");
                
                var content = new StringContent(requestBody, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync(agentConfig.Endpoint, content);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                Console.WriteLine($"Response Status: {response.StatusCode}");
                Console.WriteLine($"Response Content: {responseContent}");

                if (!response.IsSuccessStatusCode)
                {
                    return new AIAgentResponse
                    {
                        Success = false,
                        Error = $"AI Agent returned error: {response.StatusCode} - {responseContent}"
                    };
                }

                // Parse response based on agent type
                var parsedResponse = ParseResponse(agentConfig.RequestFormat, responseContent);
                Console.WriteLine($"Parsed Response: {parsedResponse}");
                
                return new AIAgentResponse
                {
                    Success = true,
                    Message = parsedResponse,
                    RawResponse = responseContent
                };
            }
            catch (TaskCanceledException)
            {
                Console.WriteLine("AI Agent request timed out");
                return new AIAgentResponse
                {
                    Success = false,
                    Error = "Request to AI agent timed out. Please try again."
                };
            }
            catch (Exception ex)
            {
                Console.WriteLine($"AI Agent error: {ex.Message}");
                return new AIAgentResponse
                {
                    Success = false,
                    Error = $"Error communicating with AI agent: {ex.Message}"
                };
            }
        }

        private string NormalizeSpecialty(string specialty)
        {
            if (string.IsNullOrWhiteSpace(specialty))
                return "";

            // Handle common variations
            var normalized = specialty.Trim().ToLower();
            
            // Map variations to standard names (including common misspellings)
            return normalized switch
            {
                "ophthalmology" => "ophthalmologist",
                "opthamologist" => "ophthalmologist",  // Common misspelling
                "opthamology" => "ophthalmologist",    // Common misspelling
                "optometry" => "optometrist",
                _ => normalized
            };
        }

        private string BuildRequestBody(AgentRequestFormat format, string message, List<ChatMessage>? conversationHistory)
        {
            switch (format)
            {
                case AgentRequestFormat.SimpleMessage:
                    return JsonSerializer.Serialize(new { message });

                case AgentRequestFormat.MessagesArray:
                    var messages = new List<object>();
                    
                    // Add conversation history if available
                    if (conversationHistory != null)
                    {
                        foreach (var chat in conversationHistory)
                        {
                            messages.Add(new { role = "user", content = chat.Query });
                            if (!string.IsNullOrEmpty(chat.Response))
                            {
                                messages.Add(new { role = "assistant", content = chat.Response });
                            }
                        }
                    }
                    
                    // Add current message
                    messages.Add(new { role = "user", content = message });
                    
                    return JsonSerializer.Serialize(new { messages });

                case AgentRequestFormat.N8nWebhook:
                    // n8n webhook format - send full context including conversation history
                    var n8nPayload = new Dictionary<string, object>
                    {
                        ["chatInput"] = message,
                        ["currentMessage"] = message
                    };
                    
                    // Include conversation history if available (contains patient info, symptoms, history)
                    if (conversationHistory != null && conversationHistory.Count > 0)
                    {
                        var chatHistory = new List<object>();
                        foreach (var chat in conversationHistory)
                        {
                            chatHistory.Add(new 
                            { 
                                userMessage = chat.Query, 
                                assistantResponse = chat.Response 
                            });
                        }
                        n8nPayload["conversationHistory"] = chatHistory;
                        
                        // Extract patient context from first message if it contains patient info
                        var firstMessage = conversationHistory.FirstOrDefault();
                        if (firstMessage != null && firstMessage.Query.Contains("Patient Name:"))
                        {
                            n8nPayload["patientContext"] = firstMessage.Query;
                        }
                    }
                    
                    return JsonSerializer.Serialize(n8nPayload);

                default:
                    return JsonSerializer.Serialize(new { message });
            }
        }

        private string ParseResponse(AgentRequestFormat format, string responseContent)
        {
            try
            {
                using var doc = JsonDocument.Parse(responseContent);
                var root = doc.RootElement;

                // Try common response patterns
                if (root.TryGetProperty("response", out var responseElement))
                {
                    return responseElement.GetString() ?? responseContent;
                }
                
                if (root.TryGetProperty("message", out var messageElement))
                {
                    return messageElement.GetString() ?? responseContent;
                }

                if (root.TryGetProperty("output", out var outputElement))
                {
                    return outputElement.GetString() ?? responseContent;
                }

                if (root.TryGetProperty("text", out var textElement))
                {
                    return textElement.GetString() ?? responseContent;
                }

                if (root.TryGetProperty("content", out var contentElement))
                {
                    return contentElement.GetString() ?? responseContent;
                }

                // Handle n8n medical agent format: { "disease": ..., "recommended_medicines": [...], "additional_advice": "..." }
                if (root.TryGetProperty("additional_advice", out var adviceElement))
                {
                    var advice = adviceElement.GetString() ?? "";
                    var disease = "";
                    var medicines = "";
                    
                    if (root.TryGetProperty("disease", out var diseaseElement) && diseaseElement.ValueKind != JsonValueKind.Null)
                    {
                        disease = diseaseElement.GetString() ?? "";
                    }
                    
                    if (root.TryGetProperty("recommended_medicines", out var medsElement) && medsElement.ValueKind == JsonValueKind.Array)
                    {
                        var medsList = new List<string>();
                        foreach (var med in medsElement.EnumerateArray())
                        {
                            var medStr = med.GetString();
                            if (!string.IsNullOrEmpty(medStr))
                                medsList.Add(medStr);
                        }
                        if (medsList.Count > 0)
                            medicines = string.Join(", ", medsList);
                    }
                    
                    // Build a formatted response
                    var response = new StringBuilder();
                    
                    if (!string.IsNullOrEmpty(disease))
                    {
                        response.AppendLine($"**Diagnosis:** {disease}");
                        response.AppendLine();
                    }
                    
                    if (!string.IsNullOrEmpty(medicines))
                    {
                        response.AppendLine($"**Recommended Medicines:** {medicines}");
                        response.AppendLine();
                    }
                    
                    if (!string.IsNullOrEmpty(advice))
                    {
                        if (response.Length > 0)
                            response.AppendLine($"**Advice:** {advice}");
                        else
                            response.Append(advice); // Just the advice if no disease/medicines
                    }
                    
                    return response.ToString().Trim();
                }

                // For n8n webhook, it might return the result directly as a string
                if (root.ValueKind == JsonValueKind.String)
                {
                    return root.GetString() ?? responseContent;
                }

                // If none of the above, return the raw content
                return responseContent;
            }
            catch
            {
                // If parsing fails, return raw content
                return responseContent;
            }
        }

        public bool IsSpecialtySupported(string specialty)
        {
            var normalized = NormalizeSpecialty(specialty);
            return AgentEndpoints.ContainsKey(normalized);
        }

        public IEnumerable<string> GetSupportedSpecialties()
        {
            return AgentEndpoints.Keys;
        }
    }

    public class AgentConfig
    {
        public string Endpoint { get; set; } = string.Empty;
        public AgentRequestFormat RequestFormat { get; set; }
    }

    public enum AgentRequestFormat
    {
        SimpleMessage,     
        MessagesArray,     
        N8nWebhook        
    }

    public class AIAgentResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public string? Error { get; set; }
        public string? RawResponse { get; set; }
    }

    public class ChatMessage
    {
        public string Query { get; set; } = string.Empty;
        public string Response { get; set; } = string.Empty;
    }
}
