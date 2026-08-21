using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using first_api.Data;
using first_api.Entities.NotificationModel;
using first_api.Entities.PatientModel;
using Microsoft.Extensions.Configuration;
using MongoDB.Driver;
using System.Text.Json;

// M-11 USED FOR SENDING VITALS, MEDICINE AND APPOINTMENT NOTIFCATIONS TO USERS
namespace first_api.Services
{
    public class NotificationService
    {
        private readonly IMongoCollection<DeviceToken> _deviceTokens;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;

        public NotificationService(MongodbService mongoDbService, IConfiguration configuration)
        {
            _deviceTokens = mongoDbService.Database?.GetCollection<DeviceToken>("device_tokens")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;

            // Initialize FirebaseApp if not already
            try
            {
                if (FirebaseApp.DefaultInstance == null)
                {
                    var serviceAccountPath = configuration["Firebase:ServiceAccountPath"];
                    var serviceAccountJson = configuration["Firebase:ServiceAccountJson"];

                    GoogleCredential? credential = null;
                    if (!string.IsNullOrWhiteSpace(serviceAccountPath))
                    {
                        credential = GoogleCredential.FromFile(serviceAccountPath);
                        Console.WriteLine($"[FCM] Loading credentials from file: {serviceAccountPath}");
                    }
                    else if (!string.IsNullOrWhiteSpace(serviceAccountJson))
                    {
                        credential = GoogleCredential.FromJson(serviceAccountJson);
                        
                        // Extract and log project ID for verification
                        try
                        {
                            var jsonDoc = JsonDocument.Parse(serviceAccountJson);
                            if (jsonDoc.RootElement.TryGetProperty("project_id", out var projectId))
                            {
                                Console.WriteLine($"[FCM] Loading credentials for project: {projectId.GetString()}");
                            }
                        }
                        catch { }
                    }

                    if (credential != null)
                    {
                        FirebaseApp.Create(new AppOptions()
                        {
                            Credential = credential
                        });
                        Console.WriteLine("[FCM] Firebase initialized successfully");
                    }
                    else
                    {
                        Console.WriteLine("[FCM] WARNING: No Firebase credential found — check ServiceAccountPath/ServiceAccountJson in appsettings.json");
                    }
                }
                else
                {
                    Console.WriteLine("[FCM] Firebase already initialized");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM] Firebase init error: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[FCM]   InnerException: {ex.InnerException.Message}");
                }
            }
        }

        public async Task<BatchResponse?> SendMulticastAsync(IEnumerable<string> tokens, string title, string body, IDictionary<string, string>? data = null)
        {
            var tokenList = tokens?.Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().Take(500).ToList();
            if (tokenList == null || tokenList.Count == 0) return null;

            var message = new MulticastMessage()
            {
                Tokens = tokenList,
                Notification = new Notification { Title = title, Body = body },
                Data = data != null ? new Dictionary<string, string>(data) : null
            };

            try
            {
                var messaging = FirebaseMessaging.DefaultInstance;
                
                // Use SendEachForMulticastAsync for better per-token error details
                var response = await messaging.SendEachForMulticastAsync(message);

                Console.WriteLine($"[FCM] Multicast result: {response.SuccessCount}/{tokenList.Count} succeeded");

                // Process failures and mark invalid tokens as inactive
                if (response.FailureCount > 0)
                {
                    Console.WriteLine($"[FCM] {response.FailureCount} token(s) failed:");
                    
                    for (int i = 0; i < response.Responses.Count; i++)
                    {
                        var sendResp = response.Responses[i];
                        if (!sendResp.IsSuccess)
                        {
                            var token = tokenList[i];
                            var errorCode = sendResp.Exception?.MessagingErrorCode;
                            var errorMsg = sendResp.Exception?.Message ?? "Unknown error";
                            
                            Console.WriteLine($"[FCM]   Token {i+1}: {token.Substring(0, Math.Min(20, token.Length))}...");
                            Console.WriteLine($"[FCM]     Error: {errorCode} - {errorMsg}");
                            
                            // Mark token as inactive for these error codes:
                            // - Unregistered: Token was deleted/app uninstalled
                            // - InvalidArgument: Token format invalid or from wrong project
                            // - SenderIdMismatch: Token from different Firebase project
                            if (errorCode == MessagingErrorCode.Unregistered ||
                                errorCode == MessagingErrorCode.InvalidArgument ||
                                errorCode == MessagingErrorCode.SenderIdMismatch ||
                                errorMsg.Contains("404"))
                            {
                                Console.WriteLine($"[FCM]     Marking token as INVALID (will be removed from database)");
                                var update = Builders<DeviceToken>.Update
                                    .Set(d => d.IsActive, false)
                                    .Set(d => d.LastSeenAt, DateTime.UtcNow);
                                await _deviceTokens.UpdateOneAsync(d => d.Token == token, update);
                            }
                        }
                    }
                }
                else
                {
                    Console.WriteLine($"[FCM] All notifications sent successfully!");
                }

                return response;
            }
            catch (FirebaseMessagingException fex)
            {
                Console.WriteLine($"[FCM ERROR] FirebaseMessagingException:");
                Console.WriteLine($"  Message: {fex.Message}");
                Console.WriteLine($"  ErrorCode: {fex.MessagingErrorCode}");
                Console.WriteLine($"  StackTrace: {fex.StackTrace}");
                if (fex.InnerException != null)
                {
                    Console.WriteLine($"  InnerException: {fex.InnerException.Message}");
                }
                
                // If it's a 404 error, mark all tokens as invalid
                if (fex.Message.Contains("404"))
                {
                    Console.WriteLine($"[FCM] 404 Error detected - marking all tokens as invalid");
                    foreach (var token in tokenList)
                    {
                        var update = Builders<DeviceToken>.Update
                            .Set(d => d.IsActive, false)
                            .Set(d => d.LastSeenAt, DateTime.UtcNow);
                        await _deviceTokens.UpdateOneAsync(d => d.Token == token, update);
                    }
                }
                
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM ERROR] Exception:");
                Console.WriteLine($"  Type: {ex.GetType().Name}");
                Console.WriteLine($"  Message: {ex.Message}");
                Console.WriteLine($"  StackTrace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"  InnerException: {ex.InnerException.Message}");
                }
                return null;
            }
        }

        // Convenience: send to a single token
        public async Task<string?> SendToTokenAsync(string token, string title, string body, IDictionary<string, string>? data = null)
        {
            try
            {
                var msg = new Message
                {
                    Token = token,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data != null ? new Dictionary<string, string>(data) : null
                };
                var res = await FirebaseMessaging.DefaultInstance.SendAsync(msg);
                return res; // messageId
            }
            catch (FirebaseMessagingException fex)
            {
                // mark token inactive for common errors (unregistered / invalid)
                try
                {
                    if (fex.MessagingErrorCode == MessagingErrorCode.Unregistered || fex.MessagingErrorCode == MessagingErrorCode.InvalidArgument || (fex.Message?.Contains("registration-token-not-registered", StringComparison.OrdinalIgnoreCase) == true))
                    {
                        var update = Builders<DeviceToken>.Update.Set(d => d.IsActive, false).Set(d => d.LastSeenAt, DateTime.UtcNow);
                        await _deviceTokens.UpdateOneAsync(d => d.Token == token, update);
                    }
                }
                catch { }

                Console.WriteLine($"SendToToken error: {fex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"SendToToken error: {ex.Message}");
                return null;
            }
        }

        public async Task ProcessPendingNotificationsAsync(System.Threading.CancellationToken cancellationToken = default)
        {
            var now = DateTime.UtcNow;
            Console.WriteLine($"[FCM] --- Processing Pending Notifications (Current UTC time: {now:yyyy-MM-dd HH:mm:ss}) ---");
            
            var pending = await _notificationLogs.Find(n => n.Status == "pending" && n.ScheduledFor <= now).Limit(100).ToListAsync(cancellationToken);
            Console.WriteLine($"[FCM] Found {pending.Count} pending notifications due for processing");

            foreach (var log in pending)
            {
                try
                {
                    // For vitals reminder, only send if current time is within the same minute as scheduled time
                    if (log.Type == "vitals_reminder")
                    {
                        var timeDifference = Math.Abs((now - log.ScheduledFor).TotalSeconds);
                        Console.WriteLine($"[FCM] Vitals reminder check: Current={now:HH:mm:ss}, Scheduled={log.ScheduledFor:HH:mm:ss}, Diff={timeDifference}s");
                        
                        // Only send if within 1 minute (60 seconds) of scheduled time
                        if (timeDifference > 60)
                        {
                            Console.WriteLine($"[FCM] ⏸️ Vitals reminder not yet at scheduled time, skipping for now");
                            continue;
                        }
                    }

                    string title = "";
                    string body = "";
                    IDictionary<string, string>? data = null;
                    if (!string.IsNullOrWhiteSpace(log.Payload))
                    {
                        try
                        {
                            using var doc = JsonDocument.Parse(log.Payload);
                            if (doc.RootElement.TryGetProperty("title", out var t)) title = t.GetString() ?? "";
                            if (doc.RootElement.TryGetProperty("body", out var b)) body = b.GetString() ?? "";
                            if (doc.RootElement.TryGetProperty("data", out var d))
                            {
                                data = new Dictionary<string, string>();
                                foreach (var prop in d.EnumerateObject()) data[prop.Name] = prop.Value.GetString() ?? string.Empty;
                            }
                        }
                        catch { }
                    }

                    Console.WriteLine($"[FCM] Processing notification {log.Id} for user {log.UserId}, type={log.Type}, scheduled={log.ScheduledFor:HH:mm:ss}");
                    
                    // Check ALL tokens for this user (including inactive) for debugging
                    var allTokens = await _deviceTokens.Find(t => t.UserId == log.UserId).ToListAsync(cancellationToken);
                    Console.WriteLine($"[FCM] Total tokens for user {log.UserId}: {allTokens.Count} (active: {allTokens.Count(t => t.IsActive)}, inactive: {allTokens.Count(t => !t.IsActive)})");
                    foreach (var dt in allTokens)
                    {
                        Console.WriteLine($"[FCM]   Token: {dt.Token?[..Math.Min(20, dt.Token?.Length ?? 0)]}... IsActive={dt.IsActive}, Platform={dt.Platform}");
                    }

                    var tokens = await _deviceTokens.Find(t => t.UserId == log.UserId && t.IsActive).ToListAsync(cancellationToken);
                    var tokenStrings = tokens.Select(t => t.Token).Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().ToList();
                    if (tokenStrings.Count > 0)
                    {
                        Console.WriteLine($"[FCM] Sending to {tokenStrings.Count} token(s) — title: {title}");
                        var resp = await SendMulticastAsync(tokenStrings, title, body, data);
                        if (resp != null)
                        {
                            if (resp.SuccessCount > 0)
                            {
                                var update = Builders<NotificationLog>.Update.Set(n => n.Status, "sent").Set(n => n.SentAt, DateTime.UtcNow).Set(n => n.FcmResponse, $"success:{resp.SuccessCount}");
                                await _notificationLogs.UpdateOneAsync(n => n.Id == log.Id, update, cancellationToken: cancellationToken);
                                continue;
                            }

                            // resp exists but no successes
                            var failureDetails = $"success:0,failure:{resp.FailureCount}";
                            try
                            {
                                // collect first few failure reasons
                                var reasons = new List<string>();
                                for (int i = 0; i < resp.Responses.Count && i < 10; i++)
                                {
                                    var r = resp.Responses[i];
                                    if (!r.IsSuccess && r.Exception != null)
                                    {
                                        reasons.Add(r.Exception.Message);
                                    }
                                }
                                if (reasons.Count > 0) failureDetails += ",reasons:" + string.Join(";", reasons);
                            }
                            catch { }

                            var failUpdate = Builders<NotificationLog>.Update.Inc(n => n.RetryCount, 1).Set(n => n.Status, "failed").Set(n => n.FcmResponse, failureDetails);
                            await _notificationLogs.UpdateOneAsync(n => n.Id == log.Id, failUpdate, cancellationToken: cancellationToken);
                            continue;
                        }
                        else
                        {
                            // No response (exception likely logged in SendMulticastAsync)
                            var retryUpdate = Builders<NotificationLog>.Update.Inc(n => n.RetryCount, 1).Set(n => n.Status, "failed").Set(n => n.FcmResponse, "no_response_from_fcm");
                            await _notificationLogs.UpdateOneAsync(n => n.Id == log.Id, retryUpdate, cancellationToken: cancellationToken);
                            continue;
                        }
                    }

                    var retryUpdateDefault = Builders<NotificationLog>.Update.Inc(n => n.RetryCount, 1).Set(n => n.Status, "failed").Set(n => n.FcmResponse, "no_active_device_tokens");
                    Console.WriteLine($"[FCM] *** NO ACTIVE TOKENS for user {log.UserId} — notification {log.Id} marked failed ***");
                    await _notificationLogs.UpdateOneAsync(n => n.Id == log.Id, retryUpdateDefault, cancellationToken: cancellationToken);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Processing notification error: {ex.Message}");
                }
            }
        }

        public async Task ProcessVitalsRemindersAsync(IMongoCollection<NotificationPreference> prefs, IMongoCollection<PatientModel> patients, System.Threading.CancellationToken cancellationToken = default)
        {
            try
            {
                var today = DateTime.UtcNow.Date;
                var now = DateTime.UtcNow;

                Console.WriteLine($"[Vitals] --- Processing Vitals Reminders ---");

                // First, auto-create default preferences for patients who don't have any
                Console.WriteLine($"[Vitals] Step 1: Auto-creating default preferences for patients without them...");
                var allPatients = await patients.Find(p => true).ToListAsync(cancellationToken);
                Console.WriteLine($"[Vitals] Total patients: {allPatients.Count}");

                foreach (var patient in allPatients)
                {
                    var existingPref = await prefs.Find(p => p.UserId == patient.PersonalInfoId).FirstOrDefaultAsync(cancellationToken);
                    
                    if (existingPref == null)
                    {
                        var defaultPref = new NotificationPreference
                        {
                            UserId = patient.PersonalInfoId,
                            VitalsRemindersEnabled = true,
                            VitalsReminderTimesJson = "[\"08:00\",\"15:00\"]",
                            AppointmentAlertsEnabled = true,
                            MedicationAlertsEnabled = true,
                            Timezone = "UTC",
                            UpdatedAt = DateTime.UtcNow
                        };
                        await prefs.InsertOneAsync(defaultPref, cancellationToken: cancellationToken);
                        Console.WriteLine($"[Vitals] Created default preferences for patient {patient.PersonalInfoId}");
                    }
                }

                // Get all users with vitals reminders enabled
                Console.WriteLine($"[Vitals] Step 2: Processing reminders for enabled users...");
                var enabledPrefs = await prefs.Find(p => p.VitalsRemindersEnabled).ToListAsync(cancellationToken);
                Console.WriteLine($"[Vitals] Found {enabledPrefs.Count} users with vitals reminders enabled");

                foreach (var pref in enabledPrefs)
                {
                    Console.WriteLine($"[Vitals] Processing user {pref.UserId}");
                    var patient = await patients.Find(p => p.PersonalInfoId == pref.UserId).FirstOrDefaultAsync(cancellationToken);

                    if (patient == null)
                    {
                        Console.WriteLine($"[Vitals] Patient not found for user {pref.UserId}");
                        continue;
                    }

                    var lastLoggedDate = patient.Vitals?.LastLoggedDate?.Date;
                    Console.WriteLine($"[Vitals] Patient found. LastLoggedDate: {lastLoggedDate:yyyy-MM-dd}, Today: {today:yyyy-MM-dd}");

                    // Skip if patient already logged vitals today
                    if (lastLoggedDate == today)
                    {
                        Console.WriteLine($"[Vitals] Patient already logged vitals today, skipping");
                        continue;
                    }

                    // Parse reminder times from JSON (default: 8:00 AM, 8:00 PM)
                    var times = new[] { "08:00", "15:00" };
                    Console.WriteLine($"[Vitals] VitalsReminderTimesJson from DB: '{pref.VitalsReminderTimesJson}'");

                    try
                    {
                        var parsed = System.Text.Json.JsonSerializer.Deserialize<string[]>(pref.VitalsReminderTimesJson);
                        if (parsed?.Length > 0)
                        {
                            times = parsed;
                            Console.WriteLine($"[Vitals]  Parsed times: {string.Join(", ", times)}");
                        }
                        else
                        {
                            Console.WriteLine($"[Vitals]  Parsed array is empty or null, using defaults");
                        }
                    }
                    catch (Exception parseEx)
                    {
                        Console.WriteLine($"[Vitals]  Parse error: {parseEx.Message}, using defaults: {string.Join(", ", times)}");
                    }

                    // Create notification logs for each reminder time for TODAY if one doesn't already exist
                    foreach (var timeStr in times)
                    {
                        if (!TimeSpan.TryParse(timeStr, out var timeOfDay))
                        {
                            Console.WriteLine($"[Vitals] Invalid time format: '{timeStr}'");
                            continue;
                        }

                        var scheduledTime = today.Add(timeOfDay);
                        Console.WriteLine($"[Vitals] Checking reminder for {timeStr} → {scheduledTime:yyyy-MM-dd HH:mm:ss}");

                        // Check exact existing scheduled notification for the same date/time
                        var existing = await _notificationLogs.Find(n =>
                            n.UserId == pref.UserId &&
                            n.Type == "vitals_reminder" &&
                            n.ScheduledFor == scheduledTime
                        ).FirstOrDefaultAsync(cancellationToken);

                        if (existing == null)
                        {
                            var notifLog = new NotificationLog
                            {
                                UserId = pref.UserId,
                                Type = "vitals_reminder",
                                ScheduledFor = scheduledTime,
                                Status = "pending",
                                Payload = System.Text.Json.JsonSerializer.Serialize(new
                                {
                                    title = "Log Your Vitals",
                                    body = "Please log your blood pressure and sugar levels"
                                })
                            };
                            await _notificationLogs.InsertOneAsync(notifLog, cancellationToken: cancellationToken);
                            Console.WriteLine($"[Vitals] Created reminder for user {pref.UserId} at {scheduledTime:HH:mm} (UTC)");
                        }
                        else
                        {
                            Console.WriteLine($"[Vitals] Reminder already exists for {scheduledTime:HH:mm}");
                        }
                    }
                }
                Console.WriteLine($"[Vitals] --- Done ---");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Vitals] Error processing reminders: {ex.Message}");
                Console.WriteLine($"[Vitals] Stack trace: {ex.StackTrace}");
            }
        }
    }
}


