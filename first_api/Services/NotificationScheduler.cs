using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.NotificationModel;
using first_api.Entities.PrescriptionModel;
using first_api.Entities.PatientModel;
using System.Linq;
using System.Globalization;
using Microsoft.Extensions.Hosting;
using MongoDB.Driver;


// M-11 NOTIFICATION SCHEDULER BACKGROUND SERVICE
namespace first_api.Services
{
    public class NotificationScheduler : BackgroundService
    {
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly NotificationService _notificationService;
        private readonly IMongoCollection<PrescriptionDocument> _prescriptions;
        private readonly IMongoCollection<NotificationPreference> _notificationPrefs;
        private readonly IMongoCollection<PatientModel> _patients;
        private readonly IMongoCollection<AppointmentModel> _appointments;
        private readonly IMongoCollection<Doctor> _doctors;

        public NotificationScheduler(MongodbService mongoDbService, NotificationService notificationService)
        {
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
            _prescriptions = mongoDbService.Database?.GetCollection<PrescriptionDocument>("prescriptions")!;
            _notificationPrefs = mongoDbService.Database?.GetCollection<NotificationPreference>("notification_preferences")!;
            _patients = mongoDbService.Database?.GetCollection<PatientModel>("patient")!;
            _appointments = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _notificationService = notificationService;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Enqueue vitals reminders for patients who haven't logged today
                    try
                    {
                        await _notificationService.ProcessVitalsRemindersAsync(_notificationPrefs, _patients, stoppingToken);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Vitals reminder error: {ex.Message}");
                    }

                    // Enqueue any due medication notifications based on prescriptions
                    try
                    {
                        await EnqueueDueMedicationNotificationsAsync(stoppingToken);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Medication enqueue error: {ex.Message}");
                    }

                    // Phase 5: Enqueue upcoming-appointment notifications for doctors (10-min pre-window)
                    try
                    {
                        await EnqueueUpcomingAppointmentNotificationsAsync(stoppingToken);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Appointment-upcoming enqueue error: {ex.Message}");
                    }

                    // Phase 7: Enqueue medication retry notifications (3 retries then mark missed)
                    try
                    {
                        await EnqueueMedicationRetryAndMissedAsync(stoppingToken);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Medication retry enqueue error: {ex.Message}");
                    }

                    // Then process pending notifications (including those just enqueued)
                    await _notificationService.ProcessPendingNotificationsAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Scheduler loop error: {ex.Message}");
                }

                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }

        private async Task EnqueueDueMedicationNotificationsAsync(CancellationToken cancellationToken)
        {
            var nowUtc = DateTime.UtcNow;
            var today = nowUtc.Date;

            // Default scheduled hour for each slot (UTC) if time not stored in DB
            var slotHours = new Dictionary<string, int>
            {
                { "morning", 4 },   // 9:00 AM PKT (notify at 8:50 AM PKT)
                { "afternoon", 9 }, // 2:00 PM PKT (notify at 1:50 PM PKT)
                { "evening", 13 },  // 6:00 PM PKT (notify at 5:50 PM PKT)
                { "night", 16 }     // 9:00 PM PKT (notify at 8:50 PM PKT)
            };

            // small window in minutes to consider a dose "due"
            var windowMinutes = 10;

            // Fetch active prescriptions that might have doses today
            var prescriptions = await _prescriptions.Find(p => p.IsActive).ToListAsync(cancellationToken);

            foreach (var prescription in prescriptions)
            {
                if (prescription.MedicineItems == null || !prescription.MedicineItems.Any()) continue;

                foreach (var medicine in prescription.MedicineItems)
                {
                    if (medicine.StartDate.Date > today || medicine.EndDate.Date < today) continue;

                    var slots = new List<string>();
                    if (medicine.Morning) slots.Add("morning");
                    if (medicine.Afternoon) slots.Add("afternoon");
                    if (medicine.Evening) slots.Add("evening");
                    if (medicine.Night) slots.Add("night");

                    foreach (var slot in slots)
                    {
                        if (!slotHours.ContainsKey(slot)) continue;

                        var scheduledUtc = GetScheduledUtcTime(medicine, slot, today, slotHours[slot]);
                        var notifyAtUtc = scheduledUtc.AddMinutes(-windowMinutes);

                        // Only enqueue within the 10-minute pre-window (before dose time)
                        if (nowUtc < notifyAtUtc || nowUtc > scheduledUtc) continue;

                        // Build a unique related id to avoid duplicate notifications per slot
                        var relatedId = $"{prescription.Id}:{medicine.Name}:{slot}:{today:yyyy-MM-dd}";

                        var exists = await _notificationLogs.Find(n => n.RelatedId == relatedId).FirstOrDefaultAsync(cancellationToken);
                        if (exists != null) continue; // already enqueued

                        // Create notification payload
                        var payloadObj = new
                        {
                            title = "Medication Reminder",
                            body = $"Time to take {medicine.Name} - {medicine.Dosage}",
                            data = new
                            {
                                prescriptionId = prescription.Id,
                                medicineName = medicine.Name,
                                dosage = medicine.Dosage,
                                timeSlot = slot
                            }
                        };

                        var log = new NotificationLog
                        {
                            UserId = prescription.PatientId,
                            Type = "medication",
                            RelatedId = relatedId,
                            Payload = JsonSerializer.Serialize(payloadObj),
                            ScheduledFor = scheduledUtc,
                            Status = "pending"
                        };

                        await _notificationLogs.InsertOneAsync(log, cancellationToken: cancellationToken);
                        Console.WriteLine($"[Scheduler] Enqueued medication notification for patient {prescription.PatientId} medicine {medicine.Name} slot {slot} at {scheduledUtc}");
                    }
                }
            }
        }

        // Phase 5: enqueue an FCM notification to the doctor when an appointment's slot is within the next 10 minutes.
        // Idempotent via unique RelatedId per appointment.
        private async Task EnqueueUpcomingAppointmentNotificationsAsync(CancellationToken cancellationToken)
        {
            var nowUtc = DateTime.UtcNow;
            var windowEnd = nowUtc.AddMinutes(10);

            // Active-ish statuses that should trigger the reminder
            var activeStatuses = new[] { "pending", "Pending", "confirmed", "Confirmed", "in-progress", "In-Progress" };

            var filter = Builders<AppointmentModel>.Filter.And(
                Builders<AppointmentModel>.Filter.In(a => a.Status, activeStatuses),
                Builders<AppointmentModel>.Filter.Gte(a => a.SlotStartTime, nowUtc),
                Builders<AppointmentModel>.Filter.Lte(a => a.SlotStartTime, windowEnd)
            );

            var upcoming = await _appointments.Find(filter).ToListAsync(cancellationToken);

            foreach (var appt in upcoming)
            {
                var relatedId = $"appt-up:{appt.Id}";
                var exists = await _notificationLogs.Find(n => n.RelatedId == relatedId).FirstOrDefaultAsync(cancellationToken);
                if (exists != null) continue;

                // Resolve doctor user id (FCM is keyed on user id, not doctor profile id)
                var doctor = await _doctors.Find(d => d.Id == appt.DoctorId).FirstOrDefaultAsync(cancellationToken);
                var doctorUserId = doctor?.PersonalInfoId;
                if (string.IsNullOrWhiteSpace(doctorUserId)) continue;

                // Resolve patient name for the body
                var patient = await _patients.Find(p => p.PersonalInfoId == appt.PatientId).FirstOrDefaultAsync(cancellationToken);
                var patientName = patient?.Name ?? "your patient";

                var slotStart = appt.SlotStartTime ?? appt.AppointmentDate;
                var minutesUntil = Math.Max(0, (int)Math.Round((slotStart - nowUtc).TotalMinutes));

                var payload = JsonSerializer.Serialize(new
                {
                    title = "Upcoming Appointment",
                    body = minutesUntil <= 1
                        ? $"Your appointment with {patientName} is starting now."
                        : $"Your appointment with {patientName} starts in {minutesUntil} minutes.",
                    data = new
                    {
                        appointmentId = appt.Id,
                        patientId = appt.PatientId,
                        slotStartUtc = slotStart.ToString("O"),
                        type = "appointment_upcoming"
                    }
                });

                var log = new NotificationLog
                {
                    UserId = doctorUserId,
                    Type = "appointment_upcoming",
                    RelatedId = relatedId,
                    Payload = payload,
                    ScheduledFor = nowUtc,
                    Status = "pending"
                };

                await _notificationLogs.InsertOneAsync(log, cancellationToken: cancellationToken);
                Console.WriteLine($"[Scheduler] Enqueued upcoming-appointment notification for doctor {doctorUserId} appt {appt.Id} starting {slotStart:u}");
            }
        }

        // Phase 7: retry medication reminder up to 3 times (+10, +20, +30 min), then mark the dose as missed.
        private async Task EnqueueMedicationRetryAndMissedAsync(CancellationToken cancellationToken)
        {
            var nowUtc = DateTime.UtcNow;
            var today = nowUtc.Date;

            var slotHours = new Dictionary<string, int>
            {
                { "morning", 4 },
                { "afternoon", 9 },
                { "evening", 13 },
                { "night", 16 }
            };

            var medicationTracking = _notificationLogs.Database.GetCollection<MedicationTracking>("medication_tracking");

            var prescriptions = await _prescriptions.Find(p => p.IsActive).ToListAsync(cancellationToken);

            foreach (var prescription in prescriptions)
            {
                if (prescription.MedicineItems == null || !prescription.MedicineItems.Any()) continue;

                foreach (var medicine in prescription.MedicineItems)
                {
                    if (medicine.StartDate.Date > today || medicine.EndDate.Date < today) continue;

                    var slots = new List<string>();
                    if (medicine.Morning) slots.Add("morning");
                    if (medicine.Afternoon) slots.Add("afternoon");
                    if (medicine.Evening) slots.Add("evening");
                    if (medicine.Night) slots.Add("night");

                    foreach (var slot in slots)
                    {
                        if (!slotHours.ContainsKey(slot)) continue;

                        var scheduledUtc = GetScheduledUtcTime(medicine, slot, today, slotHours[slot]);
                        var minutesPast = (nowUtc - scheduledUtc).TotalMinutes;
                        if (minutesPast < 10) continue; // not yet in retry territory
                        if (minutesPast >= 40) // enqueue miss once
                        {
                            await EnqueueMedicationMissedAsync(medicationTracking, prescription, medicine, slot, scheduledUtc, today, cancellationToken);
                            continue;
                        }

                        // Skip if the dose has already been marked taken today for this medicine+slot
                        if (await IsDoseTakenAsync(medicationTracking, prescription.PatientId, prescription.Id, medicine.Name, slot, today, cancellationToken))
                        {
                            continue;
                        }

                        int retryIndex = minutesPast < 20 ? 1 : (minutesPast < 30 ? 2 : 3);
                        var relatedId = $"{prescription.Id}:{medicine.Name}:{slot}:{today:yyyy-MM-dd}:retry{retryIndex}";

                        var exists = await _notificationLogs.Find(n => n.RelatedId == relatedId).FirstOrDefaultAsync(cancellationToken);
                        if (exists != null) continue;

                        var payload = JsonSerializer.Serialize(new
                        {
                            title = "Medication Reminder",
                            body = $"You missed your {slot} dose of {medicine.Name}. Please take it now. Reminder",
                            data = new
                            {
                                prescriptionId = prescription.Id,
                                medicineName = medicine.Name,
                                dosage = medicine.Dosage,
                                timeSlot = slot,
                                retry = retryIndex
                            }
                        });

                        var log = new NotificationLog
                        {
                            UserId = prescription.PatientId,
                            Type = "medication",
                            RelatedId = relatedId,
                            Payload = payload,
                            ScheduledFor = nowUtc,
                            Status = "pending"
                        };

                        await _notificationLogs.InsertOneAsync(log, cancellationToken: cancellationToken);
                        Console.WriteLine($"[Scheduler] Enqueued medication retry{retryIndex} for patient {prescription.PatientId} medicine {medicine.Name} slot {slot}");
                    }
                }
            }
        }

        private static async Task<bool> IsDoseTakenAsync(
            IMongoCollection<MedicationTracking> tracking,
            string patientId,
            string prescriptionId,
            string medicineName,
            string slot,
            DateTime today,
            CancellationToken ct)
        {
            var filter = Builders<MedicationTracking>.Filter.And(
                Builders<MedicationTracking>.Filter.Eq(t => t.PatientId, patientId),
                Builders<MedicationTracking>.Filter.Eq(t => t.PrescriptionId, prescriptionId),
                Builders<MedicationTracking>.Filter.Eq(t => t.MedicineName, medicineName),
                Builders<MedicationTracking>.Filter.Gte(t => t.Date, today),
                Builders<MedicationTracking>.Filter.Lt(t => t.Date, today.AddDays(1))
            );

            var record = await tracking.Find(filter).FirstOrDefaultAsync(ct);
            if (record == null) return false;
            return slot switch
            {
                "morning" => record.MorningTaken,
                "afternoon" => record.AfternoonTaken,
                "evening" => record.EveningTaken,
                "night" => record.NightTaken,
                _ => false
            };
        }

        // Phase 7: when all retries expire, insert a "missed" notification log (stops further retries for this dose).
        // Also adds a tracking doc with notes="missed" so the UI can reflect the missed dose.
        private async Task EnqueueMedicationMissedAsync(
            IMongoCollection<MedicationTracking> tracking,
            PrescriptionDocument prescription,
            MedicineItem medicine,
            string slot,
            DateTime scheduledUtc,
            DateTime today,
            CancellationToken cancellationToken)
        {
            // Skip if already taken
            if (await IsDoseTakenAsync(tracking, prescription.PatientId, prescription.Id, medicine.Name, slot, today, cancellationToken))
            {
                return;
            }

            var relatedId = $"{prescription.Id}:{medicine.Name}:{slot}:{today:yyyy-MM-dd}:missed";
            var exists = await _notificationLogs.Find(n => n.RelatedId == relatedId).FirstOrDefaultAsync(cancellationToken);
            if (exists != null) return;

            var payload = JsonSerializer.Serialize(new
            {
                title = "Medication Missed",
                body = $"You missed your {slot} dose of {medicine.Name}.",
                data = new
                {
                    prescriptionId = prescription.Id,
                    medicineName = medicine.Name,
                    timeSlot = slot,
                    status = "missed"
                }
            });

            var log = new NotificationLog
            {
                UserId = prescription.PatientId,
                Type = "medication_missed",
                RelatedId = relatedId,
                Payload = payload,
                ScheduledFor = DateTime.UtcNow,
                Status = "pending"
            };
            await _notificationLogs.InsertOneAsync(log, cancellationToken: cancellationToken);

            // Best-effort: upsert tracking record with notes="missed:<slot>" so the UI can show it
            try
            {
                var filter = Builders<MedicationTracking>.Filter.And(
                    Builders<MedicationTracking>.Filter.Eq(t => t.PatientId, prescription.PatientId),
                    Builders<MedicationTracking>.Filter.Eq(t => t.PrescriptionId, prescription.Id),
                    Builders<MedicationTracking>.Filter.Eq(t => t.MedicineName, medicine.Name),
                    Builders<MedicationTracking>.Filter.Gte(t => t.Date, today),
                    Builders<MedicationTracking>.Filter.Lt(t => t.Date, today.AddDays(1))
                );

                var existing = await tracking.Find(filter).FirstOrDefaultAsync(cancellationToken);
                var missedNote = $"missed:{slot}";
                if (existing == null)
                {
                    var newDoc = new MedicationTracking
                    {
                        PatientId = prescription.PatientId,
                        PrescriptionId = prescription.Id,
                        MedicineName = medicine.Name,
                        Date = today,
                        Notes = missedNote,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };
                    await tracking.InsertOneAsync(newDoc, cancellationToken: cancellationToken);
                }
                else if (!existing.Notes.Contains(missedNote))
                {
                    var newNotes = string.IsNullOrWhiteSpace(existing.Notes) ? missedNote : $"{existing.Notes};{missedNote}";
                    var update = Builders<MedicationTracking>.Update
                        .Set(t => t.Notes, newNotes)
                        .Set(t => t.UpdatedAt, DateTime.UtcNow);
                    await tracking.UpdateOneAsync(filter, update, cancellationToken: cancellationToken);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Scheduler] medication missed tracking upsert error: {ex.Message}");
            }
        }

        private static DateTime GetScheduledUtcTime(MedicineItem medicine, string slot, DateTime todayUtc, int fallbackHour)
        {
            var timeText = slot switch
            {
                "morning" => medicine.MorningTimeUtc,
                "afternoon" => medicine.AfternoonTimeUtc,
                "evening" => medicine.EveningTimeUtc,
                "night" => medicine.NightTimeUtc,
                _ => string.Empty
            };

            if (!string.IsNullOrWhiteSpace(timeText))
            {
                // Accept ISO datetime or HH:mm; always treat as UTC time-of-day
                if (DateTime.TryParse(timeText, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var dt))
                {
                    return todayUtc.Date.AddHours(dt.Hour).AddMinutes(dt.Minute);
                }

                if (TimeSpan.TryParseExact(timeText, new[] { "HH\\:mm", "H\\:mm", "hh\\:mm", "h\\:mm" }, CultureInfo.InvariantCulture, out var ts))
                {
                    return todayUtc.Date.Add(ts);
                }
            }

            return todayUtc.Date.AddHours(fallbackHour);
        }
    }
}
