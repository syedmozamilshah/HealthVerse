using first_api.Data;
using first_api.Entities.DoctorModel;
using first_api.Entities.StripeModel;
using first_api.Entities.UserModel;
using first_api.Entities.AppointmentModel;
using first_api.Entities.ReferralModel;
using first_api.Entities.NotificationModel;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;
using Stripe;
using Stripe.Checkout;

// M-10 USED IN STRIPE CONTROLLER
namespace first_api.Services
{
    public class StripeService
    {
        private readonly StripeSettings _stripeSettings;
        private readonly IMongoCollection<DoctorSubscription> _subscriptions;
        private readonly IMongoCollection<PaymentHistory> _paymentHistory;
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;
        private readonly IMongoCollection<AppointmentModelDtos> _appointments;
        private readonly IMongoCollection<BsonDocument> _prescriptions;
        private readonly IMongoCollection<Referral> _referrals;
        private readonly IMongoCollection<NotificationLog> _notificationLogs;
        private readonly ILogger<StripeService> _logger;
        private readonly DoctorAgentAssignmentService _assignmentService;

        public StripeService(
            IOptions<StripeSettings> stripeSettings,
            MongodbService mongoDbService,
            ILogger<StripeService> logger,
            DoctorAgentAssignmentService assignmentService)
        {
            _stripeSettings = stripeSettings.Value;
            _logger = logger;
            _assignmentService = assignmentService;
            StripeConfiguration.ApiKey = _stripeSettings.SecretKey;
            
            _subscriptions = mongoDbService.Database?.GetCollection<DoctorSubscription>("doctor_subscriptions")!;
            _paymentHistory = mongoDbService.Database?.GetCollection<PaymentHistory>("payment_history")!;
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _appointments = mongoDbService.Database?.GetCollection<AppointmentModelDtos>("appointments")!;
            _prescriptions = mongoDbService.Database?.GetCollection<BsonDocument>("prescriptions")!;
            _referrals = mongoDbService.Database?.GetCollection<Referral>("referrals")!;
            _notificationLogs = mongoDbService.Database?.GetCollection<NotificationLog>("notification_logs")!;
        }

        // Create or get Stripe customer for doctor
        public async Task<string> GetOrCreateStripeCustomerAsync(string doctorId)
        {
            var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
            if (doctor == null)
                throw new Exception("Doctor not found");

            var user = await _users.Find(u => u.Id == doctor.PersonalInfoId).FirstOrDefaultAsync();
            if (user == null)
                throw new Exception("User not found");

            // Check if doctor already has a subscription record with customer ID
            var existingSubscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();
            if (existingSubscription != null && !string.IsNullOrEmpty(existingSubscription.StripeCustomerId))
            {
                return existingSubscription.StripeCustomerId;
            }

            // Create new Stripe customer
            var customerService = new CustomerService();
            var customer = await customerService.CreateAsync(new CustomerCreateOptions
            {
                Email = doctor.Email,
                Name = doctor.Name,
                Metadata = new Dictionary<string, string>
                {
                    { "doctorId", doctorId },
                    { "userId", doctor.PersonalInfoId }
                }
            });

            return customer.Id;
        }

        // Create checkout session for doctor subscription
        public async Task<CheckoutSessionResponse> CreateDoctorSubscriptionCheckoutAsync(
            string doctorId, 
            string successUrl, 
            string cancelUrl)
        {
            try
            {
                var customerId = await GetOrCreateStripeCustomerAsync(doctorId);
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();

                // Create or get price for the subscription
                var priceId = await GetOrCreateSubscriptionPriceAsync();

                var options = new SessionCreateOptions
                {
                    Customer = customerId,
                    PaymentMethodTypes = new List<string> { "card" },
                    LineItems = new List<SessionLineItemOptions>
                    {
                        new SessionLineItemOptions
                        {
                            Price = priceId,
                            Quantity = 1,
                        },
                    },
                    Mode = "subscription",
                    SuccessUrl = successUrl + "?session_id={CHECKOUT_SESSION_ID}",
                    CancelUrl = cancelUrl,
                    Metadata = new Dictionary<string, string>
                    {
                        { "doctorId", doctorId },
                        { "type", "doctor_subscription" }
                    },
                    SubscriptionData = new SessionSubscriptionDataOptions
                    {
                        Metadata = new Dictionary<string, string>
                        {
                            { "doctorId", doctorId }
                        }
                    }
                };

                var service = new SessionService();
                var session = await service.CreateAsync(options);

                return new CheckoutSessionResponse
                {
                    IsSuccess = true,
                    SessionId = session.Id,
                    SessionUrl = session.Url,
                    Message = "Checkout session created successfully"
                };
            }
            catch (StripeException stripeEx)
            {
                _logger.LogError(stripeEx, "Stripe API error creating subscription checkout: {Message}", stripeEx.Message);
                return new CheckoutSessionResponse
                {
                    IsSuccess = false,
                    Message = $"Stripe error: {stripeEx.Message}"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating subscription checkout: {Message}", ex.Message);
                return new CheckoutSessionResponse
                {
                    IsSuccess = false,
                    Message = $"Error creating checkout session: {ex.Message}"
                };
            }
        }

        // Create checkout session for patient appointment payment
        public async Task<CheckoutSessionResponse> CreateAppointmentCheckoutAsync(
            string patientId,
            string doctorId,
            string appointmentId,
            long amountInPaisa,
            string currency,
            string successUrl,
            string cancelUrl)
        {
            try
            {
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
                if (doctor == null)
                    throw new Exception("Doctor not found");

                // Use the currency passed from client, default to pkr for patient appointments
                var paymentCurrency = string.IsNullOrEmpty(currency) ? "pkr" : currency.ToLower();

                var options = new SessionCreateOptions
                {
                    PaymentMethodTypes = new List<string> { "card" },
                    LineItems = new List<SessionLineItemOptions>
                    {
                        new SessionLineItemOptions
                        {
                            PriceData = new SessionLineItemPriceDataOptions
                            {
                                Currency = paymentCurrency,
                                UnitAmount = amountInPaisa, // Amount in smallest currency unit
                                ProductData = new SessionLineItemPriceDataProductDataOptions
                                {
                                    Name = $"Appointment with Dr. {doctor.Name}",
                                    Description = $"Eye consultation appointment"
                                }
                            },
                            Quantity = 1,
                        },
                    },
                    Mode = "payment",
                    SuccessUrl = successUrl + "?session_id={CHECKOUT_SESSION_ID}",
                    CancelUrl = cancelUrl,
                    Metadata = new Dictionary<string, string>
                    {
                        { "patientId", patientId },
                        { "doctorId", doctorId },
                        { "appointmentId", appointmentId },
                        { "type", "appointment_payment" }
                    }
                };

                var service = new SessionService();
                var session = await service.CreateAsync(options);

                return new CheckoutSessionResponse
                {
                    IsSuccess = true,
                    SessionId = session.Id,
                    SessionUrl = session.Url,
                    Message = "Checkout session created successfully"
                };
            }
            catch (Exception ex)
            {
                return new CheckoutSessionResponse
                {
                    IsSuccess = false,
                    Message = $"Error creating checkout session: {ex.Message}"
                };
            }
        }

        // Get or create subscription price
        private async Task<string> GetOrCreateSubscriptionPriceAsync()
        {
            try
            {
                _logger.LogInformation("Getting or creating subscription price. Product: {ProductId}, Fee: {Fee}, Currency: {Currency}",
                    _stripeSettings.DoctorSubscriptionProductId,
                    _stripeSettings.DoctorMonthlyFee,
                    _stripeSettings.Currency);

                if (!string.IsNullOrEmpty(_stripeSettings.DoctorSubscriptionPriceId))
                {
                    _logger.LogInformation("Using existing price ID: {PriceId}", _stripeSettings.DoctorSubscriptionPriceId);
                    return _stripeSettings.DoctorSubscriptionPriceId;
                }

                var priceService = new PriceService();
                
                // Check if price already exists for the product with same currency
                var prices = await priceService.ListAsync(new PriceListOptions
                {
                    Product = _stripeSettings.DoctorSubscriptionProductId,
                    Active = true,
                    Currency = _stripeSettings.Currency.ToLower()
                });

                if (prices.Data.Any())
                {
                    var existingPrice = prices.Data.First();
                    _logger.LogInformation("Found existing price: {PriceId}", existingPrice.Id);
                    return existingPrice.Id;
                }

                // Create new price (amount in paisa for PKR)
                var amountInPaisa = _stripeSettings.DoctorMonthlyFee * 100;
                _logger.LogInformation("Creating new price: {Amount} paisa {Currency}", amountInPaisa, _stripeSettings.Currency);
                
                var price = await priceService.CreateAsync(new PriceCreateOptions
                {
                    Product = _stripeSettings.DoctorSubscriptionProductId,
                    UnitAmount = amountInPaisa,
                    Currency = _stripeSettings.Currency.ToLower(),
                    Recurring = new PriceRecurringOptions
                    {
                        Interval = "month"
                    }
                });

                _logger.LogInformation("Created new price: {PriceId}", price.Id);
                return price.Id;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating subscription price");
                throw;
            }
        }

        // Get subscription status for doctor
        public async Task<SubscriptionStatusResponse> GetDoctorSubscriptionStatusAsync(string doctorId)
        {
            var subscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();
            
            if (subscription == null)
            {
                return new SubscriptionStatusResponse
                {
                    IsSuccess = true,
                    IsSubscribed = false,
                    IsPaymentCurrent = false,
                    SubscriptionStatus = "not_subscribed",
                    Message = "No subscription found"
                };
            }

            bool isEligible = subscription.SubscriptionStatus == "active" || 
                              subscription.SubscriptionStatus == "trialing" || 
                              (subscription.SubscriptionStatus == "canceled" && subscription.CurrentPeriodEnd > DateTime.UtcNow);

            return new SubscriptionStatusResponse
            {
                IsSuccess = true,
                IsSubscribed = isEligible,
                CanAccessDashboard = isEligible,
                RequiresPayment = !isEligible,
                IsPaymentCurrent = subscription.IsPaymentCurrent,
                SubscriptionStatus = subscription.SubscriptionStatus,
                CurrentPeriodEnd = subscription.CurrentPeriodEnd,
                NextPaymentDate = subscription.NextPaymentDate,
                AmountDue = isEligible ? 0 : _stripeSettings.DoctorMonthlyFee * 100,
                Message = isEligible ? "Subscription is active" : "Payment is due",
                SubscriptionEndDate = subscription.CurrentPeriodEnd
            };
        }

        // Handle webhook events
        public async Task HandleWebhookEventAsync(Event stripeEvent)
        {
            switch (stripeEvent.Type)
            {
                case "checkout.session.completed":
                    await HandleCheckoutSessionCompleted(stripeEvent);
                    break;
                case "invoice.paid":
                    await HandleInvoicePaid(stripeEvent);
                    break;
                case "invoice.payment_failed":
                    await HandleInvoicePaymentFailed(stripeEvent);
                    break;
                case "customer.subscription.created":
                    await HandleSubscriptionCreated(stripeEvent);
                    break;
                case "customer.subscription.updated":
                    await HandleSubscriptionUpdated(stripeEvent);
                    break;
                case "customer.subscription.deleted":
                    await HandleSubscriptionDeleted(stripeEvent);
                    break;
                case "payment_intent.succeeded":
                    await HandlePaymentIntentSucceeded(stripeEvent);
                    break;
            }
        }

        private async Task HandleCheckoutSessionCompleted(Event stripeEvent)
        {
            var session = stripeEvent.Data.Object as Session;
            if (session == null) return;

            var metadata = session.Metadata;
            var type = metadata.GetValueOrDefault("type", "");
            var doctorId = metadata.GetValueOrDefault("doctorId", "");

            // Fallback: Check ClientReferenceId if metadata is missing (e.g. from Payment Links)
            if (string.IsNullOrEmpty(doctorId) && !string.IsNullOrEmpty(session.ClientReferenceId))
            {
                doctorId = session.ClientReferenceId;
                // Assume it's a doctor subscription if we have a doctor ID in client_reference_id
                if (string.IsNullOrEmpty(type)) type = "doctor_subscription";
            }

            if (type == "doctor_subscription")
            {
                if (string.IsNullOrEmpty(doctorId)) return;

                // Create or update subscription record
                var existingSubscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();
                
                if (existingSubscription == null)
                {
                    var newSubscription = new DoctorSubscription
                    {
                        DoctorId = doctorId,
                        StripeCustomerId = session.CustomerId,
                        StripeSubscriptionId = session.SubscriptionId,
                        SubscriptionStatus = "active",
                        IsPaymentCurrent = true,
                        LastPaymentDate = DateTime.UtcNow,
                        CurrentPeriodStart = DateTime.UtcNow,
                        CurrentPeriodEnd = DateTime.UtcNow.AddMonths(1),
                        NextPaymentDate = DateTime.UtcNow.AddMonths(1),
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };
                    await _subscriptions.InsertOneAsync(newSubscription);
                }
                else
                {
                    var update = Builders<DoctorSubscription>.Update
                        .Set(s => s.StripeCustomerId, session.CustomerId)
                        .Set(s => s.StripeSubscriptionId, session.SubscriptionId)
                        .Set(s => s.SubscriptionStatus, "active")
                        .Set(s => s.IsPaymentCurrent, true)
                        .Set(s => s.LastPaymentDate, DateTime.UtcNow)
                        .Set(s => s.CurrentPeriodStart, DateTime.UtcNow)
                        .Set(s => s.CurrentPeriodEnd, DateTime.UtcNow.AddMonths(1))
                        .Set(s => s.NextPaymentDate, DateTime.UtcNow.AddMonths(1))
                        .Set(s => s.CanceledAt, (DateTime?)null)
                        .Set(s => s.UpdatedAt, DateTime.UtcNow);
                    await _subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, update);
                }

                // IMPORTANT: Also update the doctor collection with subscription status
                var doctorUpdate = Builders<Doctor>.Update
                    .Set(d => d.StripeCustomerId, session.CustomerId)
                    .Set(d => d.StripeSubscriptionId, session.SubscriptionId)
                    .Set(d => d.SubscriptionStatus, "active")
                    .Set(d => d.HasPaidFirstSubscription, true)
                    .Set(d => d.SubscriptionStartDate, DateTime.UtcNow)
                    .Set(d => d.SubscriptionEndDate, DateTime.UtcNow.AddMonths(1))
                    .Set(d => d.LastPaymentDate, DateTime.UtcNow);
                await _doctors.UpdateOneAsync(d => d.Id == doctorId, doctorUpdate);
                Console.WriteLine($"Doctor {doctorId} subscription fields updated in doctor collection.");

                // Auto-activate pending assignment if mode is Auto
                Console.WriteLine($"Doctor {doctorId} subscription payment completed. Checking auto-activation...");
                var (activated, activationMsg) = await _assignmentService.TryAutoActivatePendingAssignmentAsync(doctorId);
                Console.WriteLine($"Doctor {doctorId} auto-activation result: {activated} - {activationMsg}");
            }
            else if (type == "appointment_payment")
            {
                var patientId = metadata.GetValueOrDefault("patientId", "");
                var appointmentId = metadata.GetValueOrDefault("appointmentId", "");

                // Record payment
                var payment = new PaymentHistory
                {
                    DoctorId = doctorId,
                    PatientId = patientId,
                    AppointmentId = appointmentId,
                    StripePaymentIntentId = session.PaymentIntentId,
                    Amount = session.AmountTotal ?? 0,
                    Currency = session.Currency,
                    PaymentType = "appointment",
                    Status = "succeeded",
                    Description = "Appointment payment",
                    CreatedAt = DateTime.UtcNow,
                    PaidAt = DateTime.UtcNow
                };
                await _paymentHistory.InsertOneAsync(payment);

                // Check for referral
                var appointment = await _appointments.Find(a => a.Id == appointmentId).FirstOrDefaultAsync();
                if (appointment != null && !string.IsNullOrEmpty(appointment.ReferralId))
                {
                    // 1. Update Referral status
                    var updateReferral = Builders<Referral>.Update
                        .Set(r => r.Status, "BOOKED")
                        .Set(r => r.AssignedDoctorId, doctorId)
                        .Set(r => r.AppointmentId, appointmentId)
                        .Set(r => r.UpdatedAt, DateTime.UtcNow);
                    await _referrals.UpdateOneAsync(r => r.Id == appointment.ReferralId, updateReferral);

                    var referral = await _referrals.Find(r => r.Id == appointment.ReferralId).FirstOrDefaultAsync();
                    if (referral != null)
                    {
                        var patient = await _users.Find(u => u.Id == patientId).FirstOrDefaultAsync();
                        var patientName = patient != null ? $"{patient.FirstName} {patient.LastName}" : "A referred patient";

                        // 2. Notify Referring Doctor
                        var referringNotification = new NotificationLog
                        {
                            UserId = referral.ReferringDoctorId,
                            Type = "referral_booked",
                            RelatedId = referral.Id,
                            Payload = System.Text.Json.JsonSerializer.Serialize(new
                            {
                                title = "Referred Patient Booked",
                                body = $"{patientName} has successfully booked their appointment."
                            }),
                            ScheduledFor = DateTime.UtcNow,
                            Status = "pending",
                            RetryCount = 0
                        };
                        await _notificationLogs.InsertOneAsync(referringNotification);

                        // 3. Notify Receiving Doctor
                        var receivingNotification = new NotificationLog
                        {
                            UserId = doctorId,
                            Type = "new_referred_patient",
                            RelatedId = referral.Id,
                            Payload = System.Text.Json.JsonSerializer.Serialize(new
                            {
                                title = "New Referred Patient",
                                body = $"A newly referred patient ({patientName}) has been assigned to you."
                            }),
                            ScheduledFor = DateTime.UtcNow,
                            Status = "pending",
                            RetryCount = 0
                        };
                        await _notificationLogs.InsertOneAsync(receivingNotification);
                    }
                }
            }
        }

        private async Task HandleInvoicePaid(Event stripeEvent)
        {
            var invoice = stripeEvent.Data.Object as Invoice;
            if (invoice == null) return;

            var subscriptionId = invoice.SubscriptionId;
            if (string.IsNullOrEmpty(subscriptionId)) return;

            var subscription = await _subscriptions.Find(s => s.StripeSubscriptionId == subscriptionId).FirstOrDefaultAsync();
            if (subscription == null) return;

            var update = Builders<DoctorSubscription>.Update
                .Set(s => s.IsPaymentCurrent, true)
                .Set(s => s.LastPaymentDate, DateTime.UtcNow)
                .Set(s => s.SubscriptionStatus, "active")
                .Set(s => s.UpdatedAt, DateTime.UtcNow);
            await _subscriptions.UpdateOneAsync(s => s.Id == subscription.Id, update);

            // Record payment history
            var payment = new PaymentHistory
            {
                DoctorId = subscription.DoctorId,
                StripePaymentIntentId = invoice.PaymentIntentId ?? "",
                StripeInvoiceId = invoice.Id,
                Amount = invoice.AmountPaid,
                Currency = invoice.Currency,
                PaymentType = "subscription",
                Status = "succeeded",
                Description = "Monthly subscription payment",
                CreatedAt = DateTime.UtcNow,
                PaidAt = DateTime.UtcNow
            };
            await _paymentHistory.InsertOneAsync(payment);
        }

        private async Task HandleInvoicePaymentFailed(Event stripeEvent)
        {
            var invoice = stripeEvent.Data.Object as Invoice;
            if (invoice == null) return;

            var subscriptionId = invoice.SubscriptionId;
            if (string.IsNullOrEmpty(subscriptionId)) return;

            var subscription = await _subscriptions.Find(s => s.StripeSubscriptionId == subscriptionId).FirstOrDefaultAsync();
            if (subscription == null) return;

            var update = Builders<DoctorSubscription>.Update
                .Set(s => s.IsPaymentCurrent, false)
                .Set(s => s.SubscriptionStatus, "past_due")
                .Set(s => s.UpdatedAt, DateTime.UtcNow);
            await _subscriptions.UpdateOneAsync(s => s.Id == subscription.Id, update);

            // Also update doctor collection
            var doctorUpdate = Builders<Doctor>.Update
                .Set(d => d.SubscriptionStatus, "past_due")
                .Set(d => d.PaymentFailedDate, DateTime.UtcNow);
            await _doctors.UpdateOneAsync(d => d.Id == subscription.DoctorId, doctorUpdate);

            // Record failed payment
            var payment = new PaymentHistory
            {
                DoctorId = subscription.DoctorId,
                StripePaymentIntentId = invoice.PaymentIntentId ?? "",
                StripeInvoiceId = invoice.Id,
                Amount = invoice.AmountDue,
                Currency = invoice.Currency,
                PaymentType = "subscription",
                Status = "failed",
                Description = "Monthly subscription payment failed",
                CreatedAt = DateTime.UtcNow
            };
            await _paymentHistory.InsertOneAsync(payment);
        }

        private async Task HandleSubscriptionCreated(Event stripeEvent)
        {
            var subscription = stripeEvent.Data.Object as Subscription;
            if (subscription == null) return;

            var doctorId = subscription.Metadata.GetValueOrDefault("doctorId", "");
            if (string.IsNullOrEmpty(doctorId)) return;

            var existingSubscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();
            
            if (existingSubscription == null)
            {
                var newSubscription = new DoctorSubscription
                {
                    DoctorId = doctorId,
                    StripeCustomerId = subscription.CustomerId,
                    StripeSubscriptionId = subscription.Id,
                    SubscriptionStatus = subscription.Status,
                    CurrentPeriodStart = subscription.CurrentPeriodStart,
                    CurrentPeriodEnd = subscription.CurrentPeriodEnd,
                    NextPaymentDate = subscription.CurrentPeriodEnd,
                    IsPaymentCurrent = subscription.Status == "active" || subscription.Status == "trialing",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                await _subscriptions.InsertOneAsync(newSubscription);
            }
            else
            {
                var update = Builders<DoctorSubscription>.Update
                    .Set(s => s.StripeSubscriptionId, subscription.Id)
                    .Set(s => s.SubscriptionStatus, subscription.Status)
                    .Set(s => s.CurrentPeriodStart, subscription.CurrentPeriodStart)
                    .Set(s => s.CurrentPeriodEnd, subscription.CurrentPeriodEnd)
                    .Set(s => s.NextPaymentDate, subscription.CurrentPeriodEnd)
                    .Set(s => s.IsPaymentCurrent, subscription.Status == "active" || subscription.Status == "trialing")
                    .Set(s => s.UpdatedAt, DateTime.UtcNow);
                await _subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, update);
            }

            // Also update doctor collection
            var isActive = subscription.Status == "active" || subscription.Status == "trialing";
            var doctorUpdate = Builders<Doctor>.Update
                .Set(d => d.StripeCustomerId, subscription.CustomerId)
                .Set(d => d.StripeSubscriptionId, subscription.Id)
                .Set(d => d.SubscriptionStatus, subscription.Status)
                .Set(d => d.HasPaidFirstSubscription, isActive)
                .Set(d => d.SubscriptionStartDate, subscription.CurrentPeriodStart)
                .Set(d => d.SubscriptionEndDate, subscription.CurrentPeriodEnd);
            await _doctors.UpdateOneAsync(d => d.Id == doctorId, doctorUpdate);
        }

        private async Task HandleSubscriptionUpdated(Event stripeEvent)
        {
            var subscription = stripeEvent.Data.Object as Subscription;
            if (subscription == null) return;

            var doctorId = subscription.Metadata.GetValueOrDefault("doctorId", "");
            if (string.IsNullOrEmpty(doctorId))
            {
                // Try to find by subscription ID
                var existingSub = await _subscriptions.Find(s => s.StripeSubscriptionId == subscription.Id).FirstOrDefaultAsync();
                if (existingSub != null)
                    doctorId = existingSub.DoctorId;
            }

            if (string.IsNullOrEmpty(doctorId)) return;

            var update = Builders<DoctorSubscription>.Update
                .Set(s => s.SubscriptionStatus, subscription.Status)
                .Set(s => s.CurrentPeriodStart, subscription.CurrentPeriodStart)
                .Set(s => s.CurrentPeriodEnd, subscription.CurrentPeriodEnd)
                .Set(s => s.NextPaymentDate, subscription.CurrentPeriodEnd)
                .Set(s => s.IsPaymentCurrent, subscription.Status == "active" || subscription.Status == "trialing")
                .Set(s => s.UpdatedAt, DateTime.UtcNow);

            if (subscription.CanceledAt.HasValue)
            {
                update = update.Set(s => s.CanceledAt, subscription.CanceledAt.Value);
            }

            await _subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, update);

            // Also update doctor collection
            var isActive = subscription.Status == "active" || subscription.Status == "trialing";
            var doctorUpdate = Builders<Doctor>.Update
                .Set(d => d.SubscriptionStatus, subscription.Status)
                .Set(d => d.SubscriptionStartDate, subscription.CurrentPeriodStart)
                .Set(d => d.SubscriptionEndDate, subscription.CurrentPeriodEnd);
            await _doctors.UpdateOneAsync(d => d.Id == doctorId, doctorUpdate);
        }

        private async Task HandleSubscriptionDeleted(Event stripeEvent)
        {
            var subscription = stripeEvent.Data.Object as Subscription;
            if (subscription == null) return;

            var existingSub = await _subscriptions.Find(s => s.StripeSubscriptionId == subscription.Id).FirstOrDefaultAsync();
            if (existingSub == null) return;

            var update = Builders<DoctorSubscription>.Update
                .Set(s => s.SubscriptionStatus, "canceled")
                .Set(s => s.IsPaymentCurrent, false)
                .Set(s => s.CanceledAt, DateTime.UtcNow)
                .Set(s => s.UpdatedAt, DateTime.UtcNow);
            await _subscriptions.UpdateOneAsync(s => s.Id == existingSub.Id, update);

            // Also update doctor collection
            var doctorUpdate = Builders<Doctor>.Update
                .Set(d => d.SubscriptionStatus, "canceled")
                .Set(d => d.HasPaidFirstSubscription, false);
            await _doctors.UpdateOneAsync(d => d.Id == existingSub.DoctorId, doctorUpdate);
        }

        private async Task HandlePaymentIntentSucceeded(Event stripeEvent)
        {
            var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
            if (paymentIntent == null) return;

            // Update any pending payment records
            var existingPayment = await _paymentHistory.Find(p => p.StripePaymentIntentId == paymentIntent.Id).FirstOrDefaultAsync();
            if (existingPayment != null)
            {
                var update = Builders<PaymentHistory>.Update
                    .Set(p => p.Status, "succeeded")
                    .Set(p => p.PaidAt, DateTime.UtcNow);
                await _paymentHistory.UpdateOneAsync(p => p.Id == existingPayment.Id, update);
            }
        }

        // Cancel subscription
        public async Task<CancelSubscriptionResponse> CancelDoctorSubscriptionAsync(string doctorId)
        {
            try
            {
                var subscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();
                if (subscription == null || string.IsNullOrEmpty(subscription.StripeSubscriptionId))
                {
                    return new CancelSubscriptionResponse
                    {
                        IsSuccess = false,
                        Message = "No active subscription found"
                    };
                }

                var subscriptionService = new SubscriptionService();
                var cancelOptions = new SubscriptionUpdateOptions
                {
                    CancelAtPeriodEnd = true
                };
                var updatedSubscription = await subscriptionService.UpdateAsync(subscription.StripeSubscriptionId, cancelOptions);

                var update = Builders<DoctorSubscription>.Update
                    .Set(s => s.SubscriptionStatus, "canceled")
                    .Set(s => s.CurrentPeriodEnd, updatedSubscription.CurrentPeriodEnd)
                    .Set(s => s.NextPaymentDate, updatedSubscription.CurrentPeriodEnd)
                    .Set(s => s.CanceledAt, DateTime.UtcNow)
                    .Set(s => s.UpdatedAt, DateTime.UtcNow);
                await _subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, update);

                // Also update doctor collection
                var doctorUpdate = Builders<Doctor>.Update
                    .Set(d => d.SubscriptionStatus, "canceled")
                    .Set(d => d.SubscriptionEndDate, updatedSubscription.CurrentPeriodEnd);
                await _doctors.UpdateOneAsync(d => d.Id == doctorId, doctorUpdate);

                return new CancelSubscriptionResponse
                {
                    IsSuccess = true,
                    Message = "Subscription canceled successfully",
                    CancellationDate = DateTime.UtcNow
                };
            }
            catch (Exception ex)
            {
                return new CancelSubscriptionResponse
                {
                    IsSuccess = false,
                    Message = $"Error canceling subscription: {ex.Message}"
                };
            }
        }

        // Get doctors with failed payments (for admin dashboard)
        public async Task<List<DoctorPaymentStatusDto>> GetDoctorsWithFailedPaymentsAsync()
        {
            var failedSubscriptions = await _subscriptions.Find(s => 
                s.SubscriptionStatus == "past_due" || 
                (s.SubscriptionStatus == "active" && !s.IsPaymentCurrent)
            ).ToListAsync();

            var result = new List<DoctorPaymentStatusDto>();

            foreach (var sub in failedSubscriptions)
            {
                var doctor = await _doctors.Find(d => d.Id == sub.DoctorId).FirstOrDefaultAsync();
                if (doctor != null)
                {
                    result.Add(new DoctorPaymentStatusDto
                    {
                        DoctorId = doctor.Id,
                        DoctorName = doctor.Name,
                        Email = doctor.Email,
                        SubscriptionStatus = sub.SubscriptionStatus,
                        LastPaymentDate = sub.LastPaymentDate,
                        NextPaymentDate = sub.NextPaymentDate,
                        AmountDue = _stripeSettings.DoctorMonthlyFee
                    });
                }
            }

            return result;
        }

        // Get all payment history for a doctor
        public async Task<List<PaymentHistory>> GetDoctorPaymentHistoryAsync(string doctorId)
        {
            return await _paymentHistory.Find(p => p.DoctorId == doctorId)
                .SortByDescending(p => p.CreatedAt)
                .ToListAsync();
        }

        // Get doctor statistics for admin dashboard
        public async Task<List<DoctorStatisticsDto>> GetDoctorStatisticsAsync()
        {
            var result = new List<DoctorStatisticsDto>();

            try
            {
                var doctors = await _doctors.Find(_ => true).ToListAsync();
                var users = await _users.Find(_ => true).ToListAsync();

                foreach (var doctor in doctors)
                {
                    // Get user info for doctor name
                    var user = users.FirstOrDefault(u => u.Id == doctor.PersonalInfoId);
                    var doctorName = !string.IsNullOrEmpty(doctor.Name) 
                        ? doctor.Name 
                        : (user != null ? $"{user.FirstName} {user.LastName}" : "Unknown");
                    var email = !string.IsNullOrEmpty(doctor.Email) 
                        ? doctor.Email 
                        : (user?.Email ?? "");

                    // Count appointments for this doctor
                    var appointmentCount = await _appointments.CountDocumentsAsync(
                        Builders<AppointmentModelDtos>.Filter.Eq("doctor_id", doctor.Id)
                    );

                    // Count unique patients for this doctor
                    var patientIds = await _appointments
                        .Distinct<string>("patient_id", Builders<AppointmentModelDtos>.Filter.Eq("doctor_id", doctor.Id))
                        .ToListAsync();

                    // Count prescriptions for this doctor
                    var prescriptionCount = await _prescriptions.CountDocumentsAsync(
                        Builders<BsonDocument>.Filter.Eq("doctor_id", doctor.Id)
                    );

                    // Get subscription status - check both subscription collection and doctor's subscription status
                    var subscription = await _subscriptions.Find(s => s.DoctorId == doctor.Id).FirstOrDefaultAsync();
                    var subscriptionStatus = subscription?.SubscriptionStatus ?? doctor.SubscriptionStatus ?? "Not Subscribed";

                    // Parse consultation fee
                    int fee = 0;
                    if (!string.IsNullOrEmpty(doctor.Fee))
                    {
                        var feeStr = doctor.Fee.Replace(",", "").Replace("Rs.", "").Replace("PKR", "").Replace("Rs", "").Trim();
                        int.TryParse(feeStr, out fee);
                    }

                    result.Add(new DoctorStatisticsDto
                    {
                        DoctorId = doctor.Id,
                        DoctorName = doctorName,
                        Email = email,
                        Specialization = doctor.Specialization ?? doctor.Speciality ?? "",
                        TotalPatients = patientIds.Count,
                        TotalAppointments = (int)appointmentCount,
                        TotalPrescriptions = (int)prescriptionCount,
                        SubscriptionStatus = subscriptionStatus,
                        SubscriptionEndDate = doctor.SubscriptionEndDate,
                        ConsultationFee = fee,
                        IsVerified = doctor.IsVerified
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching doctor statistics");
            }

            return result;
        }

        public string GetPublishableKey()
        {
            return _stripeSettings.PublishableKey;
        }

        // Create payment intent for patient appointment
        public async Task<PaymentIntentResponse> CreatePatientPaymentIntentAsync(
            string patientId,
            string doctorId,
            string appointmentId,
            int amount,
            string currency = "pkr")
        {
            try
            {
                var doctor = await _doctors.Find(d => d.Id == doctorId).FirstOrDefaultAsync();
                if (doctor == null)
                    throw new Exception("Doctor not found");

                var paymentIntentService = new PaymentIntentService();
                var paymentIntent = await paymentIntentService.CreateAsync(new PaymentIntentCreateOptions
                {
                    Amount = amount,
                    Currency = currency.ToLower(),
                    Metadata = new Dictionary<string, string>
                    {
                        { "patientId", patientId },
                        { "doctorId", doctorId },
                        { "appointmentId", appointmentId },
                        { "type", "appointment_payment" }
                    },
                    Description = $"Appointment payment with Dr. {doctor.Name}"
                });

                // Record payment history
                var payment = new PaymentHistory
                {
                    DoctorId = doctorId,
                    PatientId = patientId,
                    AppointmentId = appointmentId,
                    StripePaymentIntentId = paymentIntent.Id,
                    Amount = amount,
                    Currency = currency,
                    PaymentType = "appointment",
                    Status = "pending",
                    Description = $"Appointment payment with Dr. {doctor.Name}",
                    CreatedAt = DateTime.UtcNow
                };
                await _paymentHistory.InsertOneAsync(payment);

                return new PaymentIntentResponse
                {
                    IsSuccess = true,
                    ClientSecret = paymentIntent.ClientSecret,
                    PaymentIntentId = paymentIntent.Id,
                    PublishableKey = _stripeSettings.PublishableKey,
                    Message = "Payment intent created successfully"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating payment intent");
                return new PaymentIntentResponse
                {
                    IsSuccess = false,
                    Message = $"Error creating payment intent: {ex.Message}"
                };
            }
        }

        // Create checkout session for patient payment
        public async Task<CheckoutSessionResponse> CreatePatientPaymentCheckoutAsync(
            string patientId,
            string doctorId,
            string appointmentId,
            int amount,
            string currency,
            string successUrl,
            string cancelUrl)
        {
            return await CreateAppointmentCheckoutAsync(patientId, doctorId, appointmentId, amount, currency, successUrl, cancelUrl);
        }

        // Get subscription status by personal info ID (user ID)
        public async Task<SubscriptionStatusResponse> GetDoctorSubscriptionStatusByPersonalIdAsync(string personalInfoId)
        {
            var doctor = await _doctors.Find(d => d.PersonalInfoId == personalInfoId).FirstOrDefaultAsync();
            if (doctor == null)
            {
                return new SubscriptionStatusResponse
                {
                    IsSuccess = false,
                    Message = "Doctor not found"
                };
            }

            return await GetDoctorSubscriptionStatusAsync(doctor.Id);
        }

        // Verify and activate subscription after checkout
        public async Task<VerifySessionResponse> VerifyAndActivateSubscriptionAsync(string doctorId, string sessionId)
        {
            try
            {
                var sessionService = new SessionService();
                var session = await sessionService.GetAsync(sessionId);

                if (session.PaymentStatus != "paid")
                {
                    return new VerifySessionResponse
                    {
                        IsSuccess = false,
                        Message = "Payment not completed",
                        SubscriptionActivated = false
                    };
                }

                // Update or create subscription record
                var existingSubscription = await _subscriptions.Find(s => s.DoctorId == doctorId).FirstOrDefaultAsync();

                if (existingSubscription == null)
                {
                    var newSubscription = new DoctorSubscription
                    {
                        DoctorId = doctorId,
                        StripeCustomerId = session.CustomerId,
                        StripeSubscriptionId = session.SubscriptionId,
                        SubscriptionStatus = "active",
                        IsPaymentCurrent = true,
                        LastPaymentDate = DateTime.UtcNow,
                        CurrentPeriodStart = DateTime.UtcNow,
                        CurrentPeriodEnd = DateTime.UtcNow.AddMonths(1),
                        NextPaymentDate = DateTime.UtcNow.AddMonths(1),
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };
                    await _subscriptions.InsertOneAsync(newSubscription);
                }
                else
                {
                    var update = Builders<DoctorSubscription>.Update
                        .Set(s => s.StripeCustomerId, session.CustomerId)
                        .Set(s => s.StripeSubscriptionId, session.SubscriptionId)
                        .Set(s => s.SubscriptionStatus, "active")
                        .Set(s => s.IsPaymentCurrent, true)
                        .Set(s => s.LastPaymentDate, DateTime.UtcNow)
                        .Set(s => s.CurrentPeriodStart, DateTime.UtcNow)
                        .Set(s => s.CurrentPeriodEnd, DateTime.UtcNow.AddMonths(1))
                        .Set(s => s.NextPaymentDate, DateTime.UtcNow.AddMonths(1))
                        .Set(s => s.CanceledAt, (DateTime?)null)
                        .Set(s => s.UpdatedAt, DateTime.UtcNow);
                    await _subscriptions.UpdateOneAsync(s => s.DoctorId == doctorId, update);
                }

                // Also update the doctor collection
                var doctorUpdate = Builders<Doctor>.Update
                    .Set(d => d.StripeCustomerId, session.CustomerId)
                    .Set(d => d.StripeSubscriptionId, session.SubscriptionId)
                    .Set(d => d.SubscriptionStatus, "active")
                    .Set(d => d.HasPaidFirstSubscription, true)
                    .Set(d => d.SubscriptionStartDate, DateTime.UtcNow)
                    .Set(d => d.SubscriptionEndDate, DateTime.UtcNow.AddMonths(1))
                    .Set(d => d.LastPaymentDate, DateTime.UtcNow);
                await _doctors.UpdateOneAsync(d => d.Id == doctorId, doctorUpdate);

                // Auto-activate pending assignment if mode is Auto
                var (activated, activationMsg) = await _assignmentService.TryAutoActivatePendingAssignmentAsync(doctorId);
                _logger.LogInformation("Doctor {DoctorId} verify-session auto-activation: {Activated} - {Message}", doctorId, activated, activationMsg);

                return new VerifySessionResponse
                {
                    IsSuccess = true,
                    Message = activated 
                        ? "Subscription activated and AI Agent assigned automatically." 
                        : "Subscription activated successfully",
                    SubscriptionActivated = true
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error verifying subscription session");
                return new VerifySessionResponse
                {
                    IsSuccess = false,
                    Message = $"Error verifying subscription: {ex.Message}",
                    SubscriptionActivated = false
                };
            }
        }
    }

    public class DoctorPaymentStatusDto
    {
        public string DoctorId { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string SubscriptionStatus { get; set; } = string.Empty;
        public DateTime? LastPaymentDate { get; set; }
        public DateTime? NextPaymentDate { get; set; }
        public int AmountDue { get; set; }
    }

    public class DoctorStatisticsDto
    {
        public string DoctorId { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Specialization { get; set; } = string.Empty;
        public int TotalPatients { get; set; }
        public int TotalAppointments { get; set; }
        public int TotalPrescriptions { get; set; }
        public string SubscriptionStatus { get; set; } = "Not Subscribed";
        public decimal ConsultationFee { get; set; }
        public bool IsVerified { get; set; }
        public DateTime? SubscriptionEndDate { get; set; }
    }
}
