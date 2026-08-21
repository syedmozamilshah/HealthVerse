using System;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities;
using first_api.Entities.PatientModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;


// M-4 USED IN APPOINTMENT FOR TRANSCRIPTION
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class VoiceController : ControllerBase
    {
        private readonly IMongoCollection<PatientModel> _patientModel;
        private readonly SpeechNotesService _speechnotesService;

        public VoiceController(MongodbService mongoDbService, SpeechNotesService speechnotesService)
        {
            _patientModel = mongoDbService.Database!.GetCollection<PatientModel>("patient");
            _speechnotesService = speechnotesService;
        }

        [HttpPost("transcribe/send")]
        public async Task<IActionResult> SendTranscription([FromBody] VoiceTranscribeRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();

            var response = await _speechnotesService.SendTranscriptionRequestAsync(
                request.FileUrl ?? "",
                request.FileName ?? "",
                userId
            );

            return Ok(new { success = true, message = "Transcription request sent. Result will be saved automatically.", speechnotesResponse = response });
        }

        [HttpPost("transcribe/webhook")]
        [AllowAnonymous]
        public async Task<IActionResult> TranscriptionWebhook([FromBody] JsonElement payload)
        {
            try
            {
                if (!payload.TryGetProperty("success", out var successProp) ||
                    successProp.GetString()?.ToLower() != "true")
                {
                    return BadRequest("Transcription failed");
                }

                var transcript = payload.TryGetProperty("transcript", out var transcriptProp)
                    ? transcriptProp.GetString() ?? ""
                    : "";

                var apiCustom = payload.TryGetProperty("api_custom", out var customProp)
                    ? customProp.GetString()
                    : null;

                if (string.IsNullOrEmpty(apiCustom))
                    return BadRequest("No api_custom data provided");

                var filter = Builders<PatientModel>.Filter.Eq(x => x.PersonalInfoId, apiCustom);
                var user = await _patientModel.Find(filter).FirstOrDefaultAsync();

                if (user != null)
                {
                    user.InitialConditions = transcript;
                    await _patientModel.ReplaceOneAsync(filter, user);
                    Console.WriteLine($"Transcription saved for user {apiCustom}");
                }
                else
                {
                    Console.WriteLine($"User not found for api_custom={apiCustom}");
                }

                return Ok(new { success = true });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Webhook processing error: {ex.Message}");
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
