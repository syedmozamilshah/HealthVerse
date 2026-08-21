using first_api.Data;
using first_api.Entities.DoctorModel;
using first_api.Entities.StripeModel;
using MongoDB.Driver;
using System.Security.Claims;


// M-10 MIDDLEWARE TO CHECK THE SUBSCRIPTION STATUS OF DOCTORS BEFORE ALLOWING ACCESS TO CERTAIN ENDPOINTS
namespace first_api.Middleware
{
    public class SubscriptionCheckMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<SubscriptionCheckMiddleware> _logger;

        // Endpoints that require active subscription for doctors
        private readonly string[] _protectedEndpoints = new[]
        {
            "/api/chat",
            "/api/voice",
            "/api/prescription"
        };

        // Endpoints that are always allowed
        private readonly string[] _allowedEndpoints = new[]
        {
            "/api/stripe",
            "/api/auth",
            "/api/doctor/profile",
            "/api/doctor/update-profile"
        };

        public SubscriptionCheckMiddleware(RequestDelegate next, ILogger<SubscriptionCheckMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context, MongodbService mongoDbService)
        {
            var path = context.Request.Path.Value?.ToLower() ?? "";

            // Skip check for allowed endpoints
            if (_allowedEndpoints.Any(e => path.StartsWith(e.ToLower())))
            {
                await _next(context);
                return;
            }

            // Check if endpoint requires subscription
            if (!_protectedEndpoints.Any(e => path.StartsWith(e.ToLower())))
            {
                await _next(context);
                return;
            }

            // Get user claims
            var userIdClaim = context.User.FindFirst(ClaimTypes.NameIdentifier);
            var roleClaim = context.User.FindFirst(ClaimTypes.Role);

            // If no user or not a doctor, continue
            if (userIdClaim == null || roleClaim?.Value != "doctor")
            {
                await _next(context);
                return;
            }

            var userId = userIdClaim.Value;

            try
            {
                var doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor");
                var subscriptions = mongoDbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions");

                var doctor = await doctors.Find(d => d.PersonalInfoId == userId).FirstOrDefaultAsync();
                if (doctor == null)
                {
                    await _next(context);
                    return;
                }

                var subscription = await subscriptions.Find(s => s.DoctorId == doctor.Id).FirstOrDefaultAsync();

                // Check if subscription is active and payment is current
                bool hasValidSubscription = subscription != null && 
                    (subscription.SubscriptionStatus == "active" || subscription.SubscriptionStatus == "trialing") &&
                    subscription.IsPaymentCurrent;

                if (!hasValidSubscription)
                {
                    _logger.LogWarning($"Doctor {doctor.Id} attempted to access {path} without valid subscription");
                    
                    context.Response.StatusCode = 402; // Payment Required
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new
                    {
                        isSuccess = false,
                        requiresPayment = true,
                        message = "Your subscription payment is due. Please complete payment to access this feature.",
                        subscriptionStatus = subscription?.SubscriptionStatus ?? "not_subscribed"
                    });
                    return;
                }

                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in subscription check middleware");
                await _next(context);
            }
        }
    }

    public static class SubscriptionCheckMiddlewareExtensions
    {
        public static IApplicationBuilder UseSubscriptionCheck(this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<SubscriptionCheckMiddleware>();
        }
    }
}
