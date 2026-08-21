using Microsoft.AspNetCore.Mvc;
using first_api.Data;
using MongoDB.Driver;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using first_api.Entities.DoctorModel;
using first_api.Entities.StripeModel;

// M-9 USED FOR SHOWING THE DATA
namespace first_api.Controllers.AdminDashboard.AdminController.Metrics
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class GraphInfoController : ControllerBase
    {
        private readonly MongodbService _mongodbService;

        public GraphInfoController(MongodbService mongodbService)
        {
            _mongodbService = mongodbService;
        }

        [HttpGet]
        public async Task<IActionResult> GetGraphInfo()
        {
            var subscriptionCollection = _mongodbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions");

            // Get last 7 days
            var labels = new List<string>();
            var counts = new List<int>();
            var today = DateTime.UtcNow.Date;

            for (int i = 6; i >= 0; i--)
            {
                var date = today.AddDays(-i);
                labels.Add(date.ToString("MMM dd"));

                // Count new subscriptions created on this specific date (UTC) that are active
                var startOfDay = DateTime.SpecifyKind(date, DateTimeKind.Utc);
                var endOfDay = DateTime.SpecifyKind(date.AddDays(1).AddTicks(-1), DateTimeKind.Utc);

                var filter = Builders<DoctorSubscription>.Filter.And(
                    Builders<DoctorSubscription>.Filter.Gte(s => s.CreatedAt, startOfDay),
                    Builders<DoctorSubscription>.Filter.Lte(s => s.CreatedAt, endOfDay),
                    Builders<DoctorSubscription>.Filter.Eq(s => s.SubscriptionStatus, "active")
                );

                var count = await subscriptionCollection!.CountDocumentsAsync(filter);
                counts.Add((int)count);

                Console.WriteLine($"Date: {date:yyyy-MM-dd}, StartOfDay: {startOfDay:yyyy-MM-dd HH:mm:ss}, EndOfDay: {endOfDay:yyyy-MM-dd HH:mm:ss}, Count: {count}");
            }

            // Also print all subscriptions
            var allSubs = await subscriptionCollection.Find(FilterDefinition<DoctorSubscription>.Empty).ToListAsync();
            Console.WriteLine($"\nTotal subscriptions: {allSubs.Count}");
            foreach (var s in allSubs)
            {
                Console.WriteLine($"Subscription: {s.Id}, DoctorId: {s.DoctorId}, Status: {s.SubscriptionStatus}, CreatedAt: {s.CreatedAt:yyyy-MM-dd HH:mm:ss}");
            }

            return Ok(new
            {
                isSuccess = true,
                data = new
                {
                    labels = labels,
                    activeSubscriptions = counts
                }
            });
        }
    }
}
