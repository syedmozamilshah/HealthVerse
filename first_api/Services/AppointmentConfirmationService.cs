using System;
using System.Threading;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AppointmentModel;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MongoDB.Driver;


// M-4 USED IN APPOINTMENT CONTROLLER
namespace first_api.Services
{
    // Background service to auto-complete appointments with pending confirmations after 24 hours
    public class AppointmentConfirmationService : BackgroundService
    {
        private readonly ILogger<AppointmentConfirmationService> _logger;
        private readonly IMongoCollection<AppointmentConfirmation> _confirmationCollection;
        private readonly IMongoCollection<AppointmentModel> _appointmentCollection;
        private readonly TimeSpan _checkInterval = TimeSpan.FromHours(1); // Check every hour
        private readonly TimeSpan _autoCompleteAfter = TimeSpan.FromHours(24); // Auto-complete after 24 hours

        public AppointmentConfirmationService(
            ILogger<AppointmentConfirmationService> logger,
            MongodbService mongoDbService)
        {
            _logger = logger;
            _confirmationCollection = mongoDbService.Database?.GetCollection<AppointmentConfirmation>("appointment_confirmations")!;
            _appointmentCollection = mongoDbService.Database?.GetCollection<AppointmentModel>("appointments")!;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("AppointmentConfirmationService started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessPendingConfirmations();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing pending confirmations");
                }

                await Task.Delay(_checkInterval, stoppingToken);
            }
        }

        public async Task ProcessPendingConfirmations()
        {
            var threshold = DateTime.UtcNow.Subtract(_autoCompleteAfter);
            
            var pendingConfirmations = await _confirmationCollection
                .Find(c => c.PatientResponse == "Pending" && c.CompletionRequestedAt <= threshold)
                .ToListAsync();

            _logger.LogInformation($"Found {pendingConfirmations.Count} pending confirmations to auto-complete");

            foreach (var confirmation in pendingConfirmations)
            {
                try
                {
                    // Update confirmation to auto-completed
                    var confirmUpdate = Builders<AppointmentConfirmation>.Update
                        .Set(c => c.PatientResponse, "Confirmed")
                        .Set(c => c.AutoCompletedAt, DateTime.UtcNow)
                        .Set(c => c.ResolutionStatus, "Resolved");
                    await _confirmationCollection.UpdateOneAsync(c => c.Id == confirmation.Id, confirmUpdate);

                    // Update appointment
                    var appointmentUpdate = Builders<AppointmentModel>.Update
                        .Set(a => a.CompletionConfirmed, true);
                    await _appointmentCollection.UpdateOneAsync(a => a.Id == confirmation.AppointmentId, appointmentUpdate);

                    _logger.LogInformation($"Auto-completed appointment {confirmation.AppointmentId}");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error auto-completing appointment {confirmation.AppointmentId}");
                }
            }
        }
    }
}
