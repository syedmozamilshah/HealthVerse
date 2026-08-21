namespace first_api.Entities.StripeModel
{
    public class StripeSettings
    {
        public string PublishableKey { get; set; } = string.Empty;
        public string SecretKey { get; set; } = string.Empty;
        public string ProductId { get; set; } = string.Empty;
        public string WebhookSecret { get; set; } = string.Empty;
        public int DoctorMonthlyFee { get; set; } = 2000;
        public string Currency { get; set; } = "PKR";
        public string DoctorSubscriptionProductId { get; set; } = string.Empty;
        public string DoctorSubscriptionPriceId { get; set; } = string.Empty;
    }
}
