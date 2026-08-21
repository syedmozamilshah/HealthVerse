using System.Security.Claims;
using first_api.Data;
using first_api.Entities.DoctorModel;
using first_api.Entities.StripeModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using Stripe;


// M-10 USED IN DOCTOR SUBSCRIPTION MANAGEMENT, PAYMENT INTENT CREATION, 
// CHECKOUT SESSION CREATION, WEBHOOK HANDLING, AND ADMIN REPORTING
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class StripeController : ControllerBase
    {
        private readonly StripeService _stripeService;
        private readonly StripeSettings _stripeSettings;
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly ILogger<StripeController> _logger;

        public StripeController(
            StripeService stripeService,
            IOptions<StripeSettings> stripeSettings,
            MongodbService mongodbService,
            ILogger<StripeController> logger)
        {
            _stripeService = stripeService;
            _stripeSettings = stripeSettings.Value;
            _doctors = mongodbService.Database?.GetCollection<Doctor>("doctor")!;
            _logger = logger;
        }

        // Get Stripe publishable key
        [HttpGet("publishable-key")]
        public IActionResult GetPublishableKey()
        {
            return Ok(new { publishableKey = _stripeSettings.PublishableKey });
        }

        // Create checkout session for doctor subscription
        [HttpPost("doctor/create-checkout-session")]
        [Authorize]
        public async Task<IActionResult> CreateDoctorCheckoutSession([FromBody] CreateCheckoutSessionDto dto)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { isSuccess = false, message = "Invalid user identity. Please log out and log back in." });
            }

            // Get doctor ID from personal info ID
            var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
            var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

            if (doctor == null)
            {
                return NotFound(new { isSuccess = false, message = "Doctor profile not found" });
            }

            var result = await _stripeService.CreateDoctorSubscriptionCheckoutAsync(
                doctor.Id,
                dto.SuccessUrl,
                dto.CancelUrl
            );

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Create checkout session for doctor subscription (with explicit doctor ID)
        [HttpPost("doctor/create-checkout-session/{doctorId}")]
        [Authorize]
        public async Task<IActionResult> CreateDoctorCheckoutSessionById(
            string doctorId,
            [FromBody] CreateCheckoutSessionDto dto)
        {
            // Verify the requesting user owns this doctor profile
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized(new { isSuccess = false, message = "Invalid user identity" });

            var doctor = await _doctors.Find(d => d.Id == doctorId && d.PersonalInfoId == userId).FirstOrDefaultAsync();
            if (doctor == null)
                return StatusCode(403, new { isSuccess = false, message = "You do not have permission to create a checkout for this doctor" });

            var result = await _stripeService.CreateDoctorSubscriptionCheckoutAsync(
                doctorId,
                dto.SuccessUrl,
                dto.CancelUrl
            );

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Create payment intent for patient appointment
        [HttpPost("patient/create-payment-intent")]
        [Authorize]
        public async Task<IActionResult> CreatePatientPaymentIntent([FromBody] CreatePatientPaymentDto dto)
        {
            var result = await _stripeService.CreatePatientPaymentIntentAsync(
                dto.PatientId,
                dto.DoctorId,
                dto.AppointmentId,
                dto.Amount,
                dto.Currency
            );

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Create checkout session for patient appointment payment
        [HttpPost("patient/create-checkout-session")]
        [AllowAnonymous]
        public async Task<IActionResult> CreatePatientCheckoutSession([FromBody] CreatePatientPaymentDto dto)
        {
            var result = await _stripeService.CreatePatientPaymentCheckoutAsync(
                dto.PatientId,
                dto.DoctorId,
                dto.AppointmentId,
                dto.Amount,
                dto.Currency,
                dto.SuccessUrl,
                dto.CancelUrl
            );

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Get doctor subscription status
        [HttpGet("doctor/subscription-status")]
        [Authorize]
        public async Task<IActionResult> GetDoctorSubscriptionStatus()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { isSuccess = false, message = "Invalid user identity. Please log out and log back in." });
            }

            var result = await _stripeService.GetDoctorSubscriptionStatusByPersonalIdAsync(userId);

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Get doctor subscription status by doctor ID
        [HttpGet("doctor/subscription-status/{doctorId}")]
        public async Task<IActionResult> GetDoctorSubscriptionStatusById(string doctorId)
        {
            var result = await _stripeService.GetDoctorSubscriptionStatusAsync(doctorId);

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Cancel doctor subscription
        [HttpPost("doctor/cancel-subscription")]
        [Authorize]
        public async Task<IActionResult> CancelDoctorSubscription()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { isSuccess = false, message = "Unauthorized" });
            }

            // Get doctor ID from personal info ID
            var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
            var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

            if (doctor == null)
            {
                return NotFound(new { isSuccess = false, message = "Doctor profile not found" });
            }

            var result = await _stripeService.CancelDoctorSubscriptionAsync(doctor.Id);

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Stripe webhook endpoint
        [HttpPost("webhook")]
        public async Task<IActionResult> HandleWebhook()
        {
            var json = await new StreamReader(HttpContext.Request.Body).ReadToEndAsync();

            try
            {
                Event stripeEvent;

                // Verify webhook signature if secret is configured
                if (!string.IsNullOrEmpty(_stripeSettings.WebhookSecret))
                {
                    var signatureHeader = Request.Headers["Stripe-Signature"];
                    stripeEvent = EventUtility.ConstructEvent(
                        json,
                        signatureHeader,
                        _stripeSettings.WebhookSecret
                    );
                }
                else
                {
                    // For development without webhook secret
                    stripeEvent = EventUtility.ParseEvent(json);
                }

                await _stripeService.HandleWebhookEventAsync(stripeEvent);

                return Ok(new { received = true });
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe webhook error");
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Webhook processing error");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        // Get doctors with failed payments (Admin only)
        [HttpGet("admin/failed-payments")]
        public async Task<IActionResult> GetDoctorsWithFailedPayments()
        {
            var result = await _stripeService.GetDoctorsWithFailedPaymentsAsync();
            return Ok(new { isSuccess = true, data = result });
        }

        // Get all doctor statistics (Admin only)
        [HttpGet("admin/doctor-statistics")]
        public async Task<IActionResult> GetDoctorStatistics()
        {
            var result = await _stripeService.GetDoctorStatisticsAsync();
            return Ok(new { isSuccess = true, data = result });
        }

        // Get subscription configuration
        [HttpGet("config")]
        public IActionResult GetStripeConfig()
        {
            return Ok(new
            {
                publishableKey = _stripeSettings.PublishableKey,
                doctorMonthlyFee = _stripeSettings.DoctorMonthlyFee,
                currency = _stripeSettings.Currency
            });
        }

        // Verify checkout session and activate subscription
        [HttpPost("doctor/verify-session")]
        [Authorize]
        public async Task<IActionResult> VerifyCheckoutSession([FromBody] VerifySessionDto dto)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { isSuccess = false, message = "Invalid user identity. Please log out and log back in." });
            }

            // Get doctor from personal info ID
            var filter = Builders<Doctor>.Filter.Eq(x => x.PersonalInfoId, userId);
            var doctor = await _doctors.Find(filter).FirstOrDefaultAsync();

            if (doctor == null)
            {
                return NotFound(new { isSuccess = false, message = "Doctor profile not found" });
            }

            var result = await _stripeService.VerifyAndActivateSubscriptionAsync(doctor.Id, dto.SessionId);

            if (result.IsSuccess)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        // Sync subscription data from doctor_subscriptions to doctor collection
        [HttpPost("sync-subscriptions")]
        public async Task<IActionResult> SyncSubscriptions([FromServices] MongodbService mongodbService)
        {
            try
            {
                var subscriptions = mongodbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions");
                var doctors = mongodbService.Database?.GetCollection<Doctor>("doctor");

                if (subscriptions == null || doctors == null)
                    return BadRequest(new { isSuccess = false, message = "Database collections not found" });

                var allSubscriptions = await subscriptions.Find(_ => true).ToListAsync();
                var allDoctors = await doctors.Find(_ => true).ToListAsync();
                int syncedCount = 0;
                var details = new List<object>();

                Console.WriteLine($"Found {allSubscriptions.Count} subscriptions and {allDoctors.Count} doctors");

                foreach (var sub in allSubscriptions)
                {
                    Console.WriteLine($"Processing subscription for doctor_id: {sub.DoctorId}");
                    
                    // Try to find doctor by ID
                    var doctor = allDoctors.FirstOrDefault(d => d.Id == sub.DoctorId);
                    
                    if (doctor == null)
                    {
                        Console.WriteLine($"Doctor not found with ID: {sub.DoctorId}");
                        details.Add(new { subscriptionDoctorId = sub.DoctorId, status = "doctor_not_found" });
                        continue;
                    }

                    var isActive = sub.SubscriptionStatus == "active" || sub.SubscriptionStatus == "trialing";
                    var update = Builders<Doctor>.Update
                        .Set(d => d.StripeCustomerId, sub.StripeCustomerId)
                        .Set(d => d.StripeSubscriptionId, sub.StripeSubscriptionId)
                        .Set(d => d.SubscriptionStatus, sub.SubscriptionStatus)
                        .Set(d => d.HasPaidFirstSubscription, isActive)
                        .Set(d => d.SubscriptionStartDate, sub.CurrentPeriodStart)
                        .Set(d => d.SubscriptionEndDate, sub.CurrentPeriodEnd)
                        .Set(d => d.LastPaymentDate, sub.LastPaymentDate);

                    var result = await doctors.UpdateOneAsync(d => d.Id == sub.DoctorId, update);
                    Console.WriteLine($"Update result: MatchedCount={result.MatchedCount}, ModifiedCount={result.ModifiedCount}");
                    
                    if (result.ModifiedCount > 0 || result.MatchedCount > 0) 
                    {
                        syncedCount++;
                        details.Add(new { doctorId = sub.DoctorId, status = "synced", modified = result.ModifiedCount });
                    }
                }

                // Also list all doctor IDs for debugging
                var doctorIds = allDoctors.Select(d => new { d.Id, d.Name }).ToList();

                return Ok(new { 
                    isSuccess = true, 
                    message = $"Synced {syncedCount} doctor records", 
                    totalSubscriptions = allSubscriptions.Count,
                    details,
                    allDoctorIds = doctorIds
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { isSuccess = false, message = ex.Message, stackTrace = ex.StackTrace });
            }
        }

        // Reactivate a subscription by clearing canceled_at (Admin use)
        [HttpPost("admin/reactivate-subscription/{doctorId}")]
        public async Task<IActionResult> ReactivateSubscription(string doctorId, [FromServices] MongodbService mongodbService)
        {
            try
            {
                var subscriptions = mongodbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions");
                var doctors = mongodbService.Database?.GetCollection<Doctor>("doctor");

                if (subscriptions == null || doctors == null)
                    return BadRequest(new { isSuccess = false, message = "Database collections not found" });

                // Update subscription - clear canceled_at and set active
                var subUpdate = Builders<DoctorSubscription>.Update
                    .Set(s => s.SubscriptionStatus, "active")
                    .Set(s => s.IsPaymentCurrent, true)
                    .Set(s => s.CanceledAt, (DateTime?)null)
                    .Set(s => s.CurrentPeriodStart, DateTime.UtcNow)
                    .Set(s => s.CurrentPeriodEnd, DateTime.UtcNow.AddMonths(1))
                    .Set(s => s.UpdatedAt, DateTime.UtcNow);
                var subResult = await subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, subUpdate);

                // Update doctor collection
                var docUpdate = Builders<Doctor>.Update
                    .Set(d => d.SubscriptionStatus, "active")
                    .Set(d => d.HasPaidFirstSubscription, true)
                    .Set(d => d.SubscriptionStartDate, DateTime.UtcNow)
                    .Set(d => d.SubscriptionEndDate, DateTime.UtcNow.AddMonths(1));
                var docResult = await doctors.UpdateOneAsync(d => d.Id == doctorId, docUpdate);

                return Ok(new
                {
                    isSuccess = true,
                    message = "Subscription reactivated successfully",
                    subscriptionUpdated = subResult.ModifiedCount,
                    doctorUpdated = docResult.ModifiedCount
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { isSuccess = false, message = ex.Message });
            }
        }
    }
}
