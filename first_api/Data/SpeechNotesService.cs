using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

// M-4 USED IN VOICE CONTROLLER AS A SERVICE
namespace first_api.Data
{
    public class SpeechNotesService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _config;

        public SpeechNotesService(HttpClient httpClient, IConfiguration config)
        {
            _httpClient = httpClient;
            _config = config;
        }

        public async Task<string> SendTranscriptionRequestAsync(string fileUrl, string fileName, string userId)
        {
            try
            {
                var requestBody = new
                {
                    apiKey = _config["Speechnotes:ApiKey"],
                    apiSecret = _config["Speechnotes:ApiSecret"],
                    type = "upload",
                    fileUrl = fileUrl,
                    fileName = fileName,
                    language = "ur-PK", 
                    numSpeakers = "1",
                    api_custom = userId 
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(requestBody),
                    Encoding.UTF8,
                    "application/json"
                );

                jsonContent.Headers.Add("Origin", "https://speechnotes.co/files/");

                var response = await _httpClient.PostAsync(_config["Speechnotes:ApiUrl"], jsonContent);
                var resultContent = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"Error: {resultContent}");
                    throw new HttpRequestException($"Speechnotes API returned {response.StatusCode}: {resultContent}");
                }

                Console.WriteLine($"Transcription request sent successfully. Job will be processed asynchronously.");
                return resultContent; 
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending transcription request: {ex.Message}");
                throw;
            }
        }
    }
}
