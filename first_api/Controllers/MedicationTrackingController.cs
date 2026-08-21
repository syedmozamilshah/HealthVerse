using System.Security.Claims;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using first_api.Entities.PrescriptionModel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;


// M-5 USED FOR TRACKING MEDICATION ADHERENCE(TRACKER, INTAKE, HISTORY, GRAPHS)
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class MedicationTrackingController : ControllerBase
    {
        private readonly IMongoCollection<MedicationTracking> _tracking;
        private readonly IMongoCollection<PrescriptionDocument> _prescriptions;
        private readonly IMongoCollection<AppointmentModel> _appointments;
        private readonly ILogger<MedicationTrackingController> _logger;

        public MedicationTrackingController(MongodbService mongoDbService, ILogger<MedicationTrackingController> logger)
        {
            _tracking = mongoDbService.Database?.GetCollection<MedicationTracking>("medication_tracking")!;
            _prescriptions = mongoDbService.Database?.GetCollection<PrescriptionDocument>("prescriptions")!;
            _appointments = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
            _logger = logger;
        }

        // Get active medications for a patient with today's tracking status
        [HttpGet("active/{patientId}")]
        public async Task<IActionResult> GetActiveMedications(string patientId)
        {
            try
            {
                var today = DateTime.UtcNow.Date;
                var nowUtc = DateTime.UtcNow;

                // Get all active prescriptions for this patient
                var prescriptions = await _prescriptions
                    .Find(p => p.PatientId == patientId && p.IsActive)
                    .ToListAsync();

                var activeMedications = new List<ActiveMedicationDto>();

                // Cache next upcoming appointment per doctor (so we don't requery per medicine)
                var nextApptByDoctor = new Dictionary<string, DateTime?>();

                foreach (var prescription in prescriptions)
                {
                    if (prescription.MedicineItems == null || !prescription.MedicineItems.Any())
                        continue;

                    foreach (var medicine in prescription.MedicineItems)
                    {
                        // Check if medicine is still within duration
                        if (medicine.EndDate.Date < today)
                            continue;

                        // Get today's tracking for this medicine
                        var todayTracking = await _tracking
                            .Find(t => t.PrescriptionId == prescription.Id 
                                    && t.MedicineName == medicine.Name 
                                    && t.Date.Date == today)
                            .FirstOrDefaultAsync();

                        // Resolve next upcoming appointment for this doctor (patient-scoped), cached
                        DateTime? nextAppt = null;
                        if (!string.IsNullOrWhiteSpace(prescription.DoctorId))
                        {
                            if (!nextApptByDoctor.TryGetValue(prescription.DoctorId, out nextAppt))
                            {
                                try
                                {
                                    var activeStatuses = new[] { "pending", "confirmed", "in-progress" };
                                    var filter = Builders<AppointmentModel>.Filter.And(
                                        Builders<AppointmentModel>.Filter.Eq(a => a.PatientId, patientId),
                                        Builders<AppointmentModel>.Filter.Eq(a => a.DoctorId, prescription.DoctorId),
                                        Builders<AppointmentModel>.Filter.In(a => a.Status, activeStatuses),
                                        Builders<AppointmentModel>.Filter.Gte(a => a.AppointmentDate, nowUtc.AddHours(-24))
                                    );
                                    var upcoming = await _appointments
                                        .Find(filter)
                                        .SortBy(a => a.AppointmentDate)
                                        .Limit(1)
                                        .FirstOrDefaultAsync();
                                    nextAppt = upcoming?.SlotStartTime ?? upcoming?.AppointmentDate;
                                }
                                catch
                                {
                                    nextAppt = null;
                                }
                                nextApptByDoctor[prescription.DoctorId] = nextAppt;
                            }
                        }

                        activeMedications.Add(new ActiveMedicationDto
                        {
                            PrescriptionId = prescription.Id,
                            DoctorId = prescription.DoctorId,
                            DoctorName = prescription.DoctorName,
                            DoctorSpecialty = prescription.DoctorSpecialty,
                            MedicineName = medicine.Name,
                            Dosage = medicine.Dosage,
                            Instructions = medicine.Instructions,
                            Morning = medicine.Morning,
                            MorningTimeUtc = medicine.MorningTimeUtc,
                            Afternoon = medicine.Afternoon,
                            AfternoonTimeUtc = medicine.AfternoonTimeUtc,
                            Evening = medicine.Evening,
                            EveningTimeUtc = medicine.EveningTimeUtc,
                            Night = medicine.Night,
                            NightTimeUtc = medicine.NightTimeUtc,
                            StartDate = medicine.StartDate,
                            EndDate = medicine.EndDate,
                            DaysRemaining = (medicine.EndDate.Date - today).Days,
                            NextAppointmentDate = nextAppt,
                            TodayTracking = todayTracking
                        });
                    }
                }

                return Ok(new ActiveMedicationsResponse
                {
                    Success = true,
                    Message = $"Found {activeMedications.Count} active medications",
                    Data = activeMedications
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting active medications for patient {PatientId}", patientId);
                return BadRequest(new ActiveMedicationsResponse
                {
                    Success = false,
                    Message = $"Error: {ex.Message}"
                });
            }
        }

        // Mark medication as taken/not taken for a specific time slot
        [HttpPost("mark")]
        public async Task<IActionResult> MarkMedicationTaken([FromBody] MarkMedicationTakenRequest request)
        {
            try
            {
                var today = DateTime.UtcNow.Date;
                var now = DateTime.UtcNow;

                // Get prescription to find patient ID
                var prescription = await _prescriptions
                    .Find(p => p.Id == request.PrescriptionId)
                    .FirstOrDefaultAsync();

                if (prescription == null)
                    return NotFound(new { success = false, message = "Prescription not found" });

                // Find or create today's tracking record
                var existingTracking = await _tracking
                    .Find(t => t.PrescriptionId == request.PrescriptionId 
                            && t.MedicineName == request.MedicineName 
                            && t.Date.Date == today)
                    .FirstOrDefaultAsync();

                if (existingTracking == null)
                {
                    existingTracking = new MedicationTracking
                    {
                        PrescriptionId = request.PrescriptionId,
                        PatientId = prescription.PatientId,
                        MedicineName = request.MedicineName,
                        Date = today,
                        Notes = request.Notes,
                        CreatedAt = now,
                        UpdatedAt = now
                    };
                }

                // Update the appropriate time slot
                switch (request.TimeSlot.ToLower())
                {
                    case "morning":
                        existingTracking.MorningTaken = request.Taken;
                        existingTracking.MorningTime = request.Taken ? now : null;
                        break;
                    case "afternoon":
                        existingTracking.AfternoonTaken = request.Taken;
                        existingTracking.AfternoonTime = request.Taken ? now : null;
                        break;
                    case "evening":
                        existingTracking.EveningTaken = request.Taken;
                        existingTracking.EveningTime = request.Taken ? now : null;
                        break;
                    case "night":
                        existingTracking.NightTaken = request.Taken;
                        existingTracking.NightTime = request.Taken ? now : null;
                        break;
                    default:
                        return BadRequest(new { success = false, message = "Invalid time slot. Use: morning, afternoon, evening, night" });
                }

                existingTracking.UpdatedAt = now;

                // Upsert the tracking record
                if (string.IsNullOrEmpty(existingTracking.Id))
                {
                    await _tracking.InsertOneAsync(existingTracking);
                }
                else
                {
                    await _tracking.ReplaceOneAsync(t => t.Id == existingTracking.Id, existingTracking);
                }

                return Ok(new { success = true, message = "Medication status updated", data = existingTracking });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking medication taken");
                return BadRequest(new { success = false, message = $"Error: {ex.Message}" });
            }
        }

        // Get medication adherence summary for a patient (for doctor view)
        // M-7 MEDICATION CHECKING
        [HttpGet("adherence/{patientId}")]
        public async Task<IActionResult> GetMedicationAdherence(string patientId)
        {
            try
            {
                // Get all prescriptions for this patient
                var prescriptions = await _prescriptions
                    .Find(p => p.PatientId == patientId)
                    .ToListAsync();

                var summaries = new List<MedicationAdherenceSummary>();

                foreach (var prescription in prescriptions)
                {
                    if (prescription.MedicineItems == null || !prescription.MedicineItems.Any())
                        continue;

                    foreach (var medicine in prescription.MedicineItems)
                    {
                        // Get all tracking records for this medicine
                        var trackingHistory = await _tracking
                            .Find(t => t.PrescriptionId == prescription.Id && t.MedicineName == medicine.Name)
                            .SortByDescending(t => t.Date)
                            .ToListAsync();

                        // Calculate expected doses
                        var startDate = medicine.StartDate.Date;
                        var endDate = medicine.EndDate.Date > DateTime.UtcNow.Date ? DateTime.UtcNow.Date : medicine.EndDate.Date;
                        var totalDays = (endDate - startDate).Days + 1;
                        
                        int dosesPerDay = 0;
                        if (medicine.Morning) dosesPerDay++;
                        if (medicine.Afternoon) dosesPerDay++;
                        if (medicine.Evening) dosesPerDay++;
                        if (medicine.Night) dosesPerDay++;

                        int totalDoses = totalDays * dosesPerDay;

                        // Calculate taken doses
                        int takenDoses = 0;
                        foreach (var tracking in trackingHistory)
                        {
                            if (medicine.Morning && tracking.MorningTaken) takenDoses++;
                            if (medicine.Afternoon && tracking.AfternoonTaken) takenDoses++;
                            if (medicine.Evening && tracking.EveningTaken) takenDoses++;
                            if (medicine.Night && tracking.NightTaken) takenDoses++;
                        }

                        summaries.Add(new MedicationAdherenceSummary
                        {
                            PrescriptionId = prescription.Id,
                            MedicineName = medicine.Name,
                            TotalDoses = totalDoses,
                            TakenDoses = takenDoses,
                            MissedDoses = totalDoses - takenDoses,
                            AdherencePercentage = totalDoses > 0 ? Math.Round((double)takenDoses / totalDoses * 100, 1) : 0,
                            TrackingHistory = trackingHistory
                        });
                    }
                }

                return Ok(new { success = true, data = summaries });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting medication adherence for patient {PatientId}", patientId);
                return BadRequest(new { success = false, message = $"Error: {ex.Message}" });
            }
        }

        // Get tracking history for a specific prescription
        // M-7 GETTING THE TRACKING HISTORY(DAILY) 
        [HttpGet("history/{prescriptionId}")]
        public async Task<IActionResult> GetTrackingHistory(string prescriptionId)
        {
            try
            {
                var history = await _tracking
                    .Find(t => t.PrescriptionId == prescriptionId)
                    .SortByDescending(t => t.Date)
                    .ToListAsync();

                return Ok(new { success = true, data = history });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting tracking history for prescription {PrescriptionId}", prescriptionId);
                return BadRequest(new { success = false, message = $"Error: {ex.Message}" });
            }
        }

        // Get daily medication history for a patient (for graph display)
        // Returns data for the last 7 days showing taken vs scheduled doses per day
        [HttpGet("daily-history/{patientId}")]
        public async Task<IActionResult> GetDailyHistory(string patientId, [FromQuery] int days = 7)
        {
            try
            {
                _logger.LogInformation("Getting daily medication history for patient {PatientId} for last {Days} days", patientId, days);

                // Get active prescriptions for this patient
                var activePrescriptions = await _prescriptions
                    .Find(p => p.PatientId == patientId && p.IsActive)
                    .ToListAsync();

                if (!activePrescriptions.Any())
                {
                    return Ok(new
                    {
                        success = true,
                        message = "No active prescriptions",
                        data = new List<object>()
                    });
                }

                var prescriptionIds = activePrescriptions.Select(p => p.Id).ToList();
                var startDate = DateTime.Today.AddDays(-(days - 1));

                // Get all tracking records for these prescriptions in the date range
                var trackingRecords = await _tracking
                    .Find(t => prescriptionIds.Contains(t.PrescriptionId) && t.Date >= startDate)
                    .ToListAsync();

                // Build daily statistics
                var dailyStats = new List<object>();
                for (int i = 0; i < days; i++)
                {
                    var date = startDate.AddDays(i);
                    var dayTracking = trackingRecords.Where(t => t.Date.Date == date.Date).ToList();

                    int scheduledDoses = 0;
                    int takenDoses = 0;

                    // Calculate scheduled doses based on active prescriptions for that day
                    foreach (var prescription in activePrescriptions)
                    {
                        foreach (var medicine in prescription.MedicineItems ?? new List<MedicineItem>())
                        {
                            // Check if this medicine was active on this date
                            if (medicine.StartDate.Date <= date.Date && medicine.EndDate.Date >= date.Date)
                            {
                                if (medicine.Morning) scheduledDoses++;
                                if (medicine.Afternoon) scheduledDoses++;
                                if (medicine.Evening) scheduledDoses++;
                                if (medicine.Night) scheduledDoses++;
                            }
                        }
                    }

                    // Count taken doses from tracking records
                    foreach (var track in dayTracking)
                    {
                        if (track.MorningTaken) takenDoses++;
                        if (track.AfternoonTaken) takenDoses++;
                        if (track.EveningTaken) takenDoses++;
                        if (track.NightTaken) takenDoses++;
                    }

                    dailyStats.Add(new
                    {
                        date = date.ToString("yyyy-MM-dd"),
                        dayName = date.ToString("ddd"),
                        scheduledDoses,
                        takenDoses,
                        missedDoses = Math.Max(0, scheduledDoses - takenDoses),
                        adherencePercentage = scheduledDoses > 0 ? Math.Round((double)takenDoses / scheduledDoses * 100, 1) : 0
                    });
                }

                return Ok(new
                {
                    success = true,
                    message = $"Daily history for last {days} days",
                    data = dailyStats
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting daily history for patient {PatientId}", patientId);
                return BadRequest(new { success = false, message = $"Error: {ex.Message}" });
            }
        }
    }
}
