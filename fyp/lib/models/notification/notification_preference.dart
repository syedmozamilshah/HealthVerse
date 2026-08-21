// M-11 CHECKING AND SETTING THE NOTIFICATION PREFERENCES

class NotificationPreference {
  bool appointmentAlertsEnabled;
  bool medicationAlertsEnabled;
  bool vitalsRemindersEnabled;
  String leadTimesJson;
  String vitalsReminderTimesJson;
  String timezone;

  NotificationPreference({
    this.appointmentAlertsEnabled = true,
    this.medicationAlertsEnabled = true,
    this.vitalsRemindersEnabled = true,
    this.leadTimesJson = '',
    this.vitalsReminderTimesJson = '["08:00", "15:00"]',
    this.timezone = 'UTC',
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) =>
      NotificationPreference(
        appointmentAlertsEnabled: json['appointmentAlertsEnabled'] ?? true,
        medicationAlertsEnabled: json['medicationAlertsEnabled'] ?? true,
        vitalsRemindersEnabled: json['vitalsRemindersEnabled'] ?? true,
        leadTimesJson: json['leadTimesJson'] ?? '',
        vitalsReminderTimesJson:
            json['vitalsReminderTimesJson'] ?? '["08:00", "15:00"]',
        timezone: json['timezone'] ?? 'UTC',
      );

  Map<String, dynamic> toJson() => {
        'appointmentAlertsEnabled': appointmentAlertsEnabled,
        'medicationAlertsEnabled': medicationAlertsEnabled,
        'vitalsRemindersEnabled': vitalsRemindersEnabled,
        'leadTimesJson': leadTimesJson,
        'vitalsReminderTimesJson': vitalsReminderTimesJson,
        'timezone': timezone,
      };
}
