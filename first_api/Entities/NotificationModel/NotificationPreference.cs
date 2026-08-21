using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;


// M-11 USED IN NOTIFCATION PREFERENCES CONTROLLER
namespace first_api.Entities.NotificationModel
{
    public class NotificationPreference
    {
        [BsonId]
        [BsonElement("_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [BsonElement("user_id"), BsonRepresentation(BsonType.ObjectId)]
        [JsonPropertyName("userId")]
        public string UserId { get; set; } = string.Empty;

        [BsonElement("appointment_alerts_enabled"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("appointmentAlertsEnabled")]
        public bool AppointmentAlertsEnabled { get; set; } = true;

        [BsonElement("medication_alerts_enabled"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("medicationAlertsEnabled")]
        public bool MedicationAlertsEnabled { get; set; } = true;

        // Simple JSON string to keep structure minimal (e.g. {"appointment":[1440,60,15]})
        [BsonElement("lead_times_json"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("leadTimesJson")]
        public string LeadTimesJson { get; set; } = string.Empty;

        [BsonElement("timezone"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("timezone")]
        public string Timezone { get; set; } = "UTC";

        [BsonElement("vitals_reminders_enabled"), BsonRepresentation(BsonType.Boolean)]
        [JsonPropertyName("vitalsRemindersEnabled")]
        public bool VitalsRemindersEnabled { get; set; } = true;

        [BsonElement("vitals_reminder_times_json"), BsonRepresentation(BsonType.String)]
        [JsonPropertyName("vitalsReminderTimesJson")]
        public string VitalsReminderTimesJson { get; set; } = "[\"08:00\",\"20:00\"]";

        [BsonElement("updated_at"), BsonRepresentation(BsonType.DateTime)]
        [JsonPropertyName("updatedAt")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
