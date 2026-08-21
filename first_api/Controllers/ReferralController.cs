using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.NotificationModel;
using first_api.Entities.ReferralModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ReferralController : ControllerBase
    {
        private readonly IMongoCollection<Referral> _referrals;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;

        public ReferralController(MongodbService mongoDbService)
        {
            _referrals = mongoDbService.Database?.GetCollection<Referral>("referrals")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
        }

        [HttpPost("create")]
        public async Task<IActionResult> CreateReferral([FromBody] CreateReferralDto request)
        {
            var doctorId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(doctorId))
            {
                return Unauthorized(new ReferralResponseDto { IsSuccess = false, Message = "Unauthorized" });
            }

            if (string.IsNullOrEmpty(request.PatientId) || string.IsNullOrEmpty(request.TargetSpecialty))
            {
                return BadRequest(new ReferralResponseDto { IsSuccess = false, Message = "PatientId and TargetSpecialty are required." });
            }

            try
            {
                var referral = new Referral
                {
                    PatientId = request.PatientId,
                    ReferringDoctorId = doctorId,
                    TargetSpecialty = request.TargetSpecialty,
                    Notes = request.Notes,
                    Status = "ACTIVE",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                await _referrals.InsertOneAsync(referral);

                // Queue push notification to patient
                var notification = new NotificationLog
                {
                    UserId = request.PatientId,
                    Type = "referral_created",
                    RelatedId = referral.Id,
                    Payload = JsonSerializer.Serialize(new
                    {
                        title = "Referral",
                        body = $"You have been referred to a {request.TargetSpecialty}. Kindly book your appointment.",
                        data = new { referralId = referral.Id, specialty = request.TargetSpecialty }
                    }),
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending",
                    RetryCount = 0
                };

                await _notificationLogs.InsertOneAsync(notification);

                return Ok(new ReferralResponseDto
                {
                    IsSuccess = true,
                    Message = "Referral created successfully.",
                    Data = referral
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ReferralResponseDto { IsSuccess = false, Message = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpGet("patient/{patientId}/active")]
        public async Task<IActionResult> GetActiveReferrals(string patientId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized(new ReferralResponseDto { IsSuccess = false, Message = "Unauthorized" });
            }

            try
            {
                var filter = Builders<Referral>.Filter.And(
                    Builders<Referral>.Filter.Eq(r => r.PatientId, patientId),
                    Builders<Referral>.Filter.Eq(r => r.Status, "ACTIVE")
                );

                var referrals = await _referrals.Find(filter).SortByDescending(r => r.CreatedAt).ToListAsync();

                return Ok(new ReferralResponseDto
                {
                    IsSuccess = true,
                    Message = "Active referrals retrieved.",
                    Data = referrals
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ReferralResponseDto { IsSuccess = false, Message = $"An error occurred: {ex.Message}" });
            }
        }
    }
}
