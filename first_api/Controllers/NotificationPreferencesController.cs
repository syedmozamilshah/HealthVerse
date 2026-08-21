using System;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.NotificationModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

// M-11 FOR SETTING THE NOTIFICATION PREFERENCES
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationPreferencesController : ControllerBase
    {
        private readonly IMongoCollection<NotificationPreference> _prefs;

        public NotificationPreferencesController(MongodbService mongoDbService)
        {
            _prefs = mongoDbService.Database?.GetCollection<NotificationPreference>("notification_preferences")!;
        }

        [HttpGet("{userId}/notification-preferences")]
        public async Task<IActionResult> GetPreferences(string userId)
        {
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (callerId == null || callerId != userId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            var pref = await _prefs.Find(p => p.UserId == userId).FirstOrDefaultAsync();
            if (pref == null)
            {
                // return defaults
                var defaultPref = new NotificationPreference 
                { 
                    UserId = userId, 
                    Timezone = "UTC", 
                    LeadTimesJson = "", 
                    AppointmentAlertsEnabled = true, 
                    MedicationAlertsEnabled = true,
                    VitalsRemindersEnabled = true,
                    VitalsReminderTimesJson = "[\"08:00\",\"15:00\"]"
                };
                return Ok(new { IsSuccess = true, Data = defaultPref });
            }

            return Ok(new { IsSuccess = true, Data = pref });
        }

        [HttpPut("{userId}/notification-preferences")]
        public async Task<IActionResult> UpdatePreferences(string userId, [FromBody] NotificationPreference req)
        {
            var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (callerId == null || callerId != userId)
            {
                return Unauthorized(new { IsSuccess = false, Message = "unauthorized" });
            }

            try
            {
                var existing = await _prefs.Find(p => p.UserId == userId).FirstOrDefaultAsync();
                if (existing == null)
                {
                    req.UserId = userId;
                    req.UpdatedAt = DateTime.UtcNow;
                    await _prefs.InsertOneAsync(req);
                    Console.WriteLine($"[Notification Preferences] Created new preferences for user {userId}");
                    return Ok(new { IsSuccess = true, Message = "created", Data = req });
                }

                var update = Builders<NotificationPreference>.Update
                    .Set(p => p.AppointmentAlertsEnabled, req.AppointmentAlertsEnabled)
                    .Set(p => p.MedicationAlertsEnabled, req.MedicationAlertsEnabled)
                    .Set(p => p.VitalsRemindersEnabled, req.VitalsRemindersEnabled)
                    .Set(p => p.VitalsReminderTimesJson, req.VitalsReminderTimesJson ?? existing.VitalsReminderTimesJson)
                    .Set(p => p.LeadTimesJson, req.LeadTimesJson ?? existing.LeadTimesJson)
                    .Set(p => p.Timezone, req.Timezone ?? existing.Timezone)
                    .Set(p => p.UpdatedAt, DateTime.UtcNow);

                await _prefs.UpdateOneAsync(p => p.Id == existing.Id, update);
                var updated = await _prefs.Find(p => p.UserId == userId).FirstOrDefaultAsync();
                Console.WriteLine($"[Notification Preferences] Updated preferences for user {userId} - Vitals Reminders: {updated.VitalsRemindersEnabled}, Times: {updated.VitalsReminderTimesJson}");
                return Ok(new { IsSuccess = true, Message = "updated", Data = updated });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Notification Preferences] Error updating preferences for user {userId}: {ex.Message}");
                return StatusCode(500, new { IsSuccess = false, Message = ex.Message });
            }
        }
    }
}
