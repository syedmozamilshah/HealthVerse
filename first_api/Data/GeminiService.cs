using System.Text;
using System.Text.Json;


// M-3 USED FOR RATE LIMITING
// M-4 FOR PRESCRIPTION GENERATION USED IN PRESCRIPTION CONTROLLER
namespace first_api.Data
{
    public class GeminiService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<GeminiService> _logger;
        
        // Multiple API keys for fallback
        private readonly List<string> _apiKeys;
        
        // Multiple models for fallback (in order of preference)
        private readonly List<string> _models;
        
        private int _currentApiKeyIndex = 0;
        private int _currentModelIndex = 0;
        private readonly object _lockObject = new();
        
        // Track rate limit hits per key
        private readonly Dictionary<string, DateTime> _rateLimitedKeys = new();
        private readonly TimeSpan _rateLimitCooldown;

        public GeminiService(IConfiguration configuration, ILogger<GeminiService> logger)
        {
            _httpClient = new HttpClient();
            _logger = logger;
            
            // Load API keys from configuration or use defaults
            var configApiKeys = configuration.GetSection("Gemini:ApiKeys").Get<List<string>>();
            _apiKeys = configApiKeys != null && configApiKeys.Count > 0 
                ? configApiKeys 
                : new List<string>
                {
                    "AIzaSyAmneULnMyMqxBuP6aksw-Myq_7RVspJ94",
                    "AIzaSyCfk1BkQY3UFrD1ekuuxIGg4diViNfqcnE"
                };
            
            // Load models from configuration or use defaults
            var configModels = configuration.GetSection("Gemini:Models").Get<List<string>>();
            _models = configModels != null && configModels.Count > 0 
                ? configModels 
                : new List<string>
                {
                    "gemini-2.5-flash",
                    "gemini-2.5-flash-lite",
                    "gemini-flash-latest"
                };
            
            // Load rate limit cooldown from configuration or use default (1 minute)
            var cooldownMinutes = configuration.GetValue<int>("Gemini:RateLimitCooldownMinutes", 1);
            _rateLimitCooldown = TimeSpan.FromMinutes(cooldownMinutes);
            
            _logger.LogInformation($"GeminiService initialized with {_apiKeys.Count} API keys and {_models.Count} models");
        }
        
        // Get current service status including available keys and models
        public GeminiServiceStatus GetServiceStatus()
        {
            lock (_lockObject)
            {
                return new GeminiServiceStatus
                {
                    TotalApiKeys = _apiKeys.Count,
                    AvailableApiKeys = _apiKeys.Count - _rateLimitedKeys.Count,
                    RateLimitedApiKeys = _rateLimitedKeys.Count,
                    CurrentModelIndex = _currentModelIndex,
                    CurrentModel = _models[_currentModelIndex],
                    AvailableModels = _models.ToList(),
                    RateLimitCooldownMinutes = (int)_rateLimitCooldown.TotalMinutes
                };
            }
        }
        
        // Get the next available API key, skipping rate-limited ones
        private string GetNextAvailableApiKey()
        {
            lock (_lockObject)
            {
                // Clean up expired rate limits
                var expiredKeys = _rateLimitedKeys
                    .Where(kvp => DateTime.UtcNow - kvp.Value > _rateLimitCooldown)
                    .Select(kvp => kvp.Key)
                    .ToList();
                
                foreach (var key in expiredKeys)
                {
                    _rateLimitedKeys.Remove(key);
                    _logger.LogInformation("API key cooldown expired, making available again");
                }
                
                // Find first available key
                for (int i = 0; i < _apiKeys.Count; i++)
                {
                    var index = (_currentApiKeyIndex + i) % _apiKeys.Count;
                    var key = _apiKeys[index];
                    
                    if (!_rateLimitedKeys.ContainsKey(key))
                    {
                        _currentApiKeyIndex = index;
                        return key;
                    }
                }
                
                // All keys are rate limited, return the one with oldest rate limit
                var oldestKey = _rateLimitedKeys.OrderBy(kvp => kvp.Value).First().Key;
                _logger.LogWarning("All API keys are rate limited, using oldest limited key");
                return oldestKey;
            }
        }
        
        // Mark an API key as rate limited
        private void MarkKeyAsRateLimited(string apiKey)
        {
            lock (_lockObject)
            {
                _rateLimitedKeys[apiKey] = DateTime.UtcNow;
                _logger.LogWarning("API key marked as rate limited, switching to next key");
                
                // Move to next key
                _currentApiKeyIndex = (_currentApiKeyIndex + 1) % _apiKeys.Count;
            }
        }
        
        // Get the next model to try
        private string GetNextModel()
        {
            lock (_lockObject)
            {
                var model = _models[_currentModelIndex];
                return model;
            }
        }
        
        // Move to next model after failure
        private void SwitchToNextModel()
        {
            lock (_lockObject)
            {
                _currentModelIndex = (_currentModelIndex + 1) % _models.Count;
                _logger.LogInformation($"Switching to model: {_models[_currentModelIndex]}");
            }
        }
        
        // Reset model index (after successful call)
        private void ResetModelIndex()
        {
            lock (_lockObject)
            {
                _currentModelIndex = 0;
            }
        }
        
        // Make API call with automatic fallback to different keys and models
        private async Task<string> CallGeminiWithFallbackAsync(object requestBody, int maxOutputTokens = 2048)
        {
            var totalAttempts = _apiKeys.Count * _models.Count;
            var attempts = 0;
            Exception? lastException = null;
            
            while (attempts < totalAttempts)
            {
                var apiKey = GetNextAvailableApiKey();
                var model = GetNextModel();
                
                try
                {
                    _logger.LogInformation($"Attempting Gemini API call - Model: {model}, Key Index: {_currentApiKeyIndex}, Attempt: {attempts + 1}/{totalAttempts}");
                    
                    var json = JsonSerializer.Serialize(requestBody);
                    var content = new StringContent(json, Encoding.UTF8, "application/json");
                    
                    var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}";
                    
                    var response = await _httpClient.PostAsync(url, content);
                    var responseContent = await response.Content.ReadAsStringAsync();
                    
                    if (response.IsSuccessStatusCode)
                    {
                        _logger.LogInformation($"Gemini API call successful with model {model}");
                        ResetModelIndex(); // Reset to preferred model for next call
                        return responseContent;
                    }
                    
                    // Check for rate limit errors (429) or quota errors
                    if (response.StatusCode == System.Net.HttpStatusCode.TooManyRequests ||
                        responseContent.Contains("RATE_LIMIT_EXCEEDED") ||
                        responseContent.Contains("RESOURCE_EXHAUSTED") ||
                        responseContent.Contains("quota"))
                    {
                        _logger.LogWarning($"Rate limit hit for model {model} with key index {_currentApiKeyIndex}");
                        MarkKeyAsRateLimited(apiKey);
                        attempts++;
                        continue;
                    }
                    
                    // Check for model not found or invalid model errors
                    if (responseContent.Contains("not found") || 
                        responseContent.Contains("INVALID_ARGUMENT") ||
                        responseContent.Contains("is not supported"))
                    {
                        _logger.LogWarning($"Model {model} not available or not supported, trying next model");
                        SwitchToNextModel();
                        attempts++;
                        continue;
                    }
                    
                    // For other errors, log and try next combination
                    _logger.LogError($"Gemini API Error: {response.StatusCode} - {responseContent}");
                    lastException = new Exception($"Gemini API error: {response.StatusCode}");
                    SwitchToNextModel();
                    attempts++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Exception during Gemini API call with model {model}");
                    lastException = ex;
                    SwitchToNextModel();
                    attempts++;
                }
            }
            
            throw lastException ?? new Exception("All Gemini API attempts failed");
        }

        public async Task<PrescriptionData> GeneratePrescriptionAsync(PrescriptionRequest request)
        {
            try
            {
                var prompt = BuildPrescriptionPrompt(request);
                
                var requestBody = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new[]
                            {
                                new { text = prompt }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        temperature = 0.3,
                        topK = 40,
                        topP = 0.95,
                        maxOutputTokens = 2048
                    }
                };

                var responseContent = await CallGeminiWithFallbackAsync(requestBody);
                
                _logger.LogInformation($"Gemini API Response: {responseContent}");

                return ParseGeminiResponse(responseContent);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating prescription with Gemini");
                throw;
            }
        }

        private string BuildPrescriptionPrompt(PrescriptionRequest request)
        {
            var sb = new StringBuilder();
            
            sb.AppendLine("You are a medical prescription assistant. Based on the following information, generate a structured prescription.");
            sb.AppendLine();
            sb.AppendLine("=== DOCTOR INFORMATION ===");
            sb.AppendLine($"Doctor Name: {request.DoctorName ?? "NIL"}");
            sb.AppendLine($"Specialty: {request.DoctorSpecialty ?? "NIL"}");
            sb.AppendLine();
            sb.AppendLine("=== PATIENT INFORMATION ===");
            sb.AppendLine($"Patient Name: {request.PatientName ?? "NIL"}");
            sb.AppendLine($"Gender: {request.PatientGender ?? "NIL"}");
            sb.AppendLine($"Blood Group: {request.PatientBloodGroup ?? "NIL"}");
            sb.AppendLine($"Initial Symptoms: {request.PatientInitialConditions ?? "NIL"}");
            sb.AppendLine($"Medical History: {request.PatientHistory ?? "NIL"}");
            sb.AppendLine();
            
            if (!string.IsNullOrEmpty(request.DRResult) || !string.IsNullOrEmpty(request.ClassifierResult))
            {
                sb.AppendLine("=== DIAGNOSTIC TOOL RESULTS ===");
                if (!string.IsNullOrEmpty(request.DRResult))
                    sb.AppendLine($"Diabetic Retinopathy Detection: {request.DRResult}");
                if (!string.IsNullOrEmpty(request.ClassifierResult))
                    sb.AppendLine($"Eye Disease Classifier: {request.ClassifierResult}");
                sb.AppendLine();
            }
            
            sb.AppendLine("=== CONSULTATION CONVERSATION ===");
            if (request.Conversation != null && request.Conversation.Count > 0)
            {
                foreach (var msg in request.Conversation)
                {
                    sb.AppendLine($"Doctor: {msg.Message}");
                    if (!string.IsNullOrEmpty(msg.Response))
                    {
                        // Parse AI response if it's JSON (from n8n webhook)
                        var parsedResponse = ParseAIResponseForPrescription(msg.Response);
                        sb.AppendLine($"AI Assistant: {parsedResponse}");
                    }
                }
            }
            else
            {
                sb.AppendLine("No conversation recorded.");
            }
            sb.AppendLine();
            
            sb.AppendLine("=== INSTRUCTIONS ===");
            sb.AppendLine("Based on the above information, generate a prescription in the following EXACT JSON format.");
            sb.AppendLine("If any field has no relevant data, use 'NIL' as the value.");
            sb.AppendLine("Be concise and professional. Only include medically relevant information.");
            sb.AppendLine();
            sb.AppendLine("Respond ONLY with valid JSON in this exact format:");
            sb.AppendLine(@"{
  ""diagnosis"": ""<diagnosis or NIL>"",
  ""medicines"": ""<medicine name, dosage, frequency - one per line, or NIL>"",
  ""usage"": ""<usage instructions or NIL>"",
  ""tests"": ""<recommended tests or NIL>"",
  ""advice"": ""<general advice or NIL>"",
  ""notes"": ""<additional notes or NIL>"",
  ""followUp"": ""<follow-up date/instructions or NIL>"",
  ""summary"": ""<brief summary of the consultation for patient history>""
}");

            return sb.ToString();
        }

        private PrescriptionData ParseGeminiResponse(string responseContent)
        {
            try
            {
                using var doc = JsonDocument.Parse(responseContent);
                var root = doc.RootElement;

                // Navigate to the text content
                var candidates = root.GetProperty("candidates");
                var firstCandidate = candidates[0];
                var content = firstCandidate.GetProperty("content");
                var parts = content.GetProperty("parts");
                var text = parts[0].GetProperty("text").GetString() ?? "";

                _logger.LogInformation($"Gemini text response: {text}");

                // Extract JSON from the response (it might be wrapped in markdown code blocks)
                var jsonStart = text.IndexOf('{');
                var jsonEnd = text.LastIndexOf('}');
                
                if (jsonStart >= 0 && jsonEnd > jsonStart)
                {
                    var jsonString = text.Substring(jsonStart, jsonEnd - jsonStart + 1);
                    var prescription = JsonSerializer.Deserialize<PrescriptionData>(jsonString, new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    });
                    
                    return prescription ?? new PrescriptionData();
                }

                return new PrescriptionData
                {
                    Diagnosis = "NIL",
                    Medicines = "NIL",
                    Usage = "NIL",
                    Tests = "NIL",
                    Advice = "NIL",
                    Notes = "NIL",
                    FollowUp = "NIL",
                    Summary = "Unable to parse prescription"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error parsing Gemini response");
                return new PrescriptionData
                {
                    Diagnosis = "NIL",
                    Medicines = "NIL",
                    Usage = "NIL",
                    Tests = "NIL",
                    Advice = "NIL",
                    Notes = "NIL",
                    FollowUp = "NIL",
                    Summary = "Error parsing prescription"
                };
            }
        }

        // Parse AI response that might be JSON (from n8n webhook) and extract meaningful text
        private string ParseAIResponseForPrescription(string response)
        {
            if (string.IsNullOrEmpty(response))
                return "No response";

            // Check if it looks like JSON
            var trimmed = response.Trim();
            if (!trimmed.StartsWith("{"))
                return response; // Not JSON, return as-is

            try
            {
                using var doc = JsonDocument.Parse(trimmed);
                var root = doc.RootElement;

                var result = new StringBuilder();

                // Extract disease/diagnosis
                if (root.TryGetProperty("disease", out var diseaseElement) && diseaseElement.ValueKind != JsonValueKind.Null)
                {
                    var disease = diseaseElement.GetString();
                    if (!string.IsNullOrEmpty(disease))
                        result.AppendLine($"Diagnosis: {disease}");
                }

                // Extract recommended medicines
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
                        result.AppendLine($"Recommended Medicines: {string.Join(", ", medsList)}");
                }

                // Extract additional advice
                if (root.TryGetProperty("additional_advice", out var adviceElement))
                {
                    var advice = adviceElement.GetString();
                    if (!string.IsNullOrEmpty(advice))
                        result.AppendLine($"Advice: {advice}");
                }

                return result.Length > 0 ? result.ToString().Trim() : response;
            }
            catch
            {
                // If JSON parsing fails, return original
                return response;
            }
        }

        // Generate a concise summary of the prescription for patient history
        // M-7 GETTING THE SUMMARY FOR THE PRESCRIPTION
        public async Task<string> GeneratePrescriptionSummaryAsync(PrescriptionSummaryRequest request)
        {
            try
            {
                var prompt = BuildSummaryPrompt(request);
                
                var requestBody = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new[]
                            {
                                new { text = prompt }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        temperature = 0.3,
                        topK = 40,
                        topP = 0.95,
                        maxOutputTokens = 500
                    }
                };

                var responseContent = await CallGeminiWithFallbackAsync(requestBody, 500);
                
                _logger.LogInformation($"Gemini Summary Response: {responseContent}");

                return ParseSummaryResponse(responseContent);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating prescription summary with Gemini");
                return "Error generating summary";
            }
        }

// M-7 SUMMARY PROMPT BUILDER AND PARSER
        private string BuildSummaryPrompt(PrescriptionSummaryRequest request)
        {
            var sb = new StringBuilder();
            
            sb.AppendLine("Generate a brief, professional medical summary for a patient's history record.");
            sb.AppendLine("The summary should be concise (2-4 sentences) and include key information about:");
            sb.AppendLine("- Patient's reported symptoms");
            sb.AppendLine("- Diagnosis given");
            sb.AppendLine("- Medicines prescribed");
            sb.AppendLine("- Key advice or precautions");
            sb.AppendLine("- Follow-up instructions if any");
            sb.AppendLine();
            sb.AppendLine("=== PATIENT SYMPTOMS ===");
            sb.AppendLine(request.PatientSymptoms ?? "Not recorded");
            sb.AppendLine();
            sb.AppendLine("=== DIAGNOSIS ===");
            sb.AppendLine(request.Diagnosis ?? "NIL");
            sb.AppendLine();
            sb.AppendLine("=== MEDICINES PRESCRIBED ===");
            sb.AppendLine(request.Medicines ?? "NIL");
            sb.AppendLine();
            sb.AppendLine("=== TESTS RECOMMENDED ===");
            sb.AppendLine(request.Tests ?? "NIL");
            sb.AppendLine();
            sb.AppendLine("=== ADVICE/PRECAUTIONS ===");
            sb.AppendLine(request.Advice ?? "NIL");
            sb.AppendLine();
            sb.AppendLine("=== FOLLOW-UP ===");
            sb.AppendLine(request.FollowUp ?? "NIL");
            sb.AppendLine();
            sb.AppendLine("Respond ONLY with the summary text, no JSON or formatting. Make it readable and informative.");

            return sb.ToString();
        }

        private string ParseSummaryResponse(string responseContent)
        {
            try
            {
                using var doc = JsonDocument.Parse(responseContent);
                var root = doc.RootElement;

                var candidates = root.GetProperty("candidates");
                var firstCandidate = candidates[0];
                var content = firstCandidate.GetProperty("content");
                var parts = content.GetProperty("parts");
                var text = parts[0].GetProperty("text").GetString() ?? "";

                return text.Trim();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error parsing Gemini summary response");
                return "Unable to parse summary";
            }
        }
    }

    public class PrescriptionRequest
    {
        public string? DoctorName { get; set; }
        public string? DoctorSpecialty { get; set; }
        public string? PatientName { get; set; }
        public string? PatientGender { get; set; }
        public string? PatientBloodGroup { get; set; }
        public string? PatientInitialConditions { get; set; }
        public string? PatientHistory { get; set; }
        public string? DRResult { get; set; }
        public string? ClassifierResult { get; set; }
        public List<ConversationMessage>? Conversation { get; set; }
    }

    public class ConversationMessage
    {
        public string? Message { get; set; }
        public string? Response { get; set; }
    }

    public class PrescriptionData
    {
        public string Diagnosis { get; set; } = "NIL";
        public string Medicines { get; set; } = "NIL";
        public string Usage { get; set; } = "NIL";
        public string Tests { get; set; } = "NIL";
        public string Advice { get; set; } = "NIL";
        public string Notes { get; set; } = "NIL";
        public string FollowUp { get; set; } = "NIL";
        public string Summary { get; set; } = "";
    }

    public class PrescriptionSummaryRequest
    {
        public string? PatientSymptoms { get; set; }
        public string? Diagnosis { get; set; }
        public string? Medicines { get; set; }
        public string? Tests { get; set; }
        public string? Advice { get; set; }
        public string? FollowUp { get; set; }
    }

    public class GeminiServiceStatus
    {
        public int TotalApiKeys { get; set; }
        public int AvailableApiKeys { get; set; }
        public int RateLimitedApiKeys { get; set; }
        public int CurrentModelIndex { get; set; }
        public string CurrentModel { get; set; } = "";
        public List<string> AvailableModels { get; set; } = new();
        public int RateLimitCooldownMinutes { get; set; }
    }
}
