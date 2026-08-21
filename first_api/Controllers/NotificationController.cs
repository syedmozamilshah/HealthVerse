using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.NotificationModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;


// M-11 USED FOR NOTIFICATION SYSTEM
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly IMongoCollection<DeviceToken> _deviceTokens;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly first_api.Services.NotificationService _notificationService;

        public NotificationController(MongodbService mongoDbService, first_api.Services.NotificationService notificationService)
        {
            _deviceTokens = mongoDbService.Database?.GetCollection<DeviceToken>("device_tokens")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _notificationService = notificationService;
        }

        public class RegisterTokenRequest
        {
            public string Token { get; set; } = string.Empty;
            public string Platform { get; set; } = "android";
        }

        [HttpPost("{userId}/device-tokens")]
        public async Task<IActionResult> RegisterDeviceToken(string userId, [FromBody] RegisterTokenRequest req)
        {
            var response = new { IsSuccess = true, Message = "" };
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (callerId == null || callerId != userId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            if (string.IsNullOrWhiteSpace(req.Token))
            {
                return BadRequest(new { IsSuccess = false, Message = "token required" });
            }

            try
            {
                var existing = await _deviceTokens.Find(d => d.Token == req.Token).FirstOrDefaultAsync();
                if (existing != null)
                {
                    var update = Builders<DeviceToken>.Update
                        .Set(d => d.UserId, userId)
                        .Set(d => d.Platform, req.Platform ?? "android")
                        .Set(d => d.IsActive, true)
                        .Set(d => d.LastSeenAt, DateTime.UtcNow);
                    await _deviceTokens.UpdateOneAsync(d => d.Id == existing.Id, update);
                    return Ok(response);
                }

                var tokenDoc = new DeviceToken
                {
                    UserId = userId,
                    Token = req.Token,
                    Platform = req.Platform ?? "android",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    LastSeenAt = DateTime.UtcNow
                };

                await _deviceTokens.InsertOneAsync(tokenDoc);
                return Ok(response);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { IsSuccess = false, Message = ex.Message });
            }
        }

        [HttpGet("{userId}/device-tokens")]
        public async Task<IActionResult> GetDeviceTokens(string userId)
        {
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (callerId == null || callerId != userId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            var tokens = await _deviceTokens.Find(d => d.UserId == userId && d.IsActive).ToListAsync();
            return Ok(new { IsSuccess = true, Data = tokens });
        }

        [HttpDelete("{userId}/device-tokens")]
        public async Task<IActionResult> DeleteDeviceToken(string userId, [FromQuery] string token)
        {
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (callerId == null || callerId != userId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            if (string.IsNullOrWhiteSpace(token))
            {
                return BadRequest(new { IsSuccess = false, Message = "token required" });
            }

            var result = await _deviceTokens.DeleteOneAsync(d => d.UserId == userId && d.Token == token);
            if (result.DeletedCount > 0)
                return Ok(new { IsSuccess = true, Message = "deleted" });

            return NotFound(new { IsSuccess = false, Message = "not found" });
        }

        public class SendTestRequest
        {
            public string UserId { get; set; } = string.Empty;
            public string Title { get; set; } = string.Empty;
            public string Body { get; set; } = string.Empty;
        }

        [HttpPost("send-test")]
        public async Task<IActionResult> SendTestNotification([FromBody] SendTestRequest req)
        {
            // Enqueue a NotificationLog and optionally process immediately.
            try
            {
                var log = new NotificationLog
                {
                    UserId = req.UserId,
                    Type = "test",
                    RelatedId = string.Empty,
                    Payload = $"{{\"title\":\"{req.Title}\",\"body\":\"{req.Body}\"}}",
                    ScheduledFor = DateTime.UtcNow,
                    Status = "pending"
                };
                await _notificationLogs.InsertOneAsync(log);
                // Optionally process immediately (admin/service can also call trigger)
                await _notificationService.ProcessPendingNotificationsAsync();
                return Ok(new { IsSuccess = true, Message = "enqueued_and_processed" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { IsSuccess = false, Message = ex.Message });
            }
        }

        [HttpPost("trigger")]
        [Authorize]
        public async Task<IActionResult> TriggerScheduler()
        {
            var role = User.FindFirstValue(ClaimTypes.Role);
            if (string.IsNullOrWhiteSpace(role) || !(role.Equals("admin", StringComparison.OrdinalIgnoreCase) || role.Equals("service", StringComparison.OrdinalIgnoreCase)))
            {
                return Forbid();
            }

            try
            {
                await _notificationService.ProcessPendingNotificationsAsync();
                return Ok(new { IsSuccess = true, Message = "triggered" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { IsSuccess = false, Message = ex.Message });
            }
        }

        public class SendNowRequest
        {
            public string UserId { get; set; } = string.Empty;
            public string Title { get; set; } = string.Empty;
            public string Body { get; set; } = string.Empty;
        }

        [HttpPost("send-now")]
        [Authorize]
        public async Task<IActionResult> SendNow([FromBody] SendNowRequest req)
        {
            // Allow admin/service or the user themselves to send immediate test notification
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var role = User.FindFirstValue(ClaimTypes.Role);
            if (callerId != req.UserId && !(role != null && (role.Equals("admin", StringComparison.OrdinalIgnoreCase) || role.Equals("service", StringComparison.OrdinalIgnoreCase))))
            {
                return Forbid();
            }

            try
            {
                var tokens = await _deviceTokens.Find(d => d.UserId == req.UserId && d.IsActive).ToListAsync();
                var tokenStrings = tokens.Select(t => t.Token).Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().ToList();
                if (tokenStrings.Count == 0) return NotFound(new { IsSuccess = false, Message = "no active tokens" });

                var resp = await _notificationService.SendMulticastAsync(tokenStrings, req.Title, req.Body, null);
                return Ok(new { IsSuccess = true, Message = "sent", SuccessCount = resp?.SuccessCount ?? 0, FailureCount = resp?.FailureCount ?? 0 });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { IsSuccess = false, Message = ex.Message });
            }
        }

        public class AcknowledgeRequest
        {
            public string MessageId { get; set; } = string.Empty;
            public string Action { get; set; } = "taken"; // taken | snooze
            public DateTime? SnoozeUntil { get; set; }
        }

        [HttpPost("acknowledge")]
        [Authorize]
        public async Task<IActionResult> Acknowledge([FromBody] AcknowledgeRequest req)
        {
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(req.MessageId)) return BadRequest(new { IsSuccess = false, Message = "MessageId required" });

            var existing = await _notificationLogs.Find(n => n.Id == req.MessageId).FirstOrDefaultAsync();
            if (existing == null) return NotFound(new { IsSuccess = false, Message = "not found" });

            if (callerId == null || callerId != existing.UserId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            var update = Builders<NotificationLog>.Update
                .Set(n => n.AcknowledgedAt, DateTime.UtcNow)
                .Set(n => n.AcknowledgedAction, req.Action ?? "taken");

            // If snoozed, optionally create a new pending notification at SnoozeUntil
            await _notificationLogs.UpdateOneAsync(n => n.Id == req.MessageId, update);

            if (req.Action != null && req.Action.Equals("snooze", StringComparison.OrdinalIgnoreCase) && req.SnoozeUntil.HasValue)
            {
                var snoozeLog = new NotificationLog
                {
                    UserId = existing.UserId,
                    Type = existing.Type,
                    RelatedId = existing.RelatedId,
                    Payload = existing.Payload,
                    ScheduledFor = req.SnoozeUntil.Value,
                    Status = "pending"
                };
                await _notificationLogs.InsertOneAsync(snoozeLog);
            }

            return Ok(new { IsSuccess = true, Message = "acknowledged" });
        }
    }
}
