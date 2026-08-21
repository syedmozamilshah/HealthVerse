using System;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using BlazorUI.Authentication;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Configuration;

namespace BlazorUI.Services
{
    public class AppointmentHubClient : IAsyncDisposable
    {
        private readonly ApiClient _apiClient;
        private readonly IConfiguration _configuration;
        private HubConnection? _connection;
        private bool _handlersRegistered;
        private string? _doctorId;
        private readonly SemaphoreSlim _startLock = new(1, 1);

        public event Func<AppointmentNotification, Task>? NewAppointment;
        public event Func<VerificationStatusNotification, Task>? VerificationStatusChanged;

        public AppointmentHubClient(ApiClient apiClient, IConfiguration configuration)
        {
            _apiClient = apiClient;
            _configuration = configuration;
        }

        public async Task StartAsync()
        {
            await _startLock.WaitAsync();
            try
            {
                if (_connection?.State == HubConnectionState.Connected ||
                    _connection?.State == HubConnectionState.Connecting)
                {
                    return;
                }

                await EnsureConnectionAsync();
            }
            finally
            {
                _startLock.Release();
            }
        }

        public async Task SetDoctorIdAsync(string? doctorId)
        {
            if (string.IsNullOrWhiteSpace(doctorId))
            {
                return;
            }

            _doctorId = doctorId;
            if (_connection?.State == HubConnectionState.Connected)
            {
                await _connection.InvokeAsync("JoinDoctorGroup", _doctorId);
                Console.WriteLine($"[HubClient] Joined doctor group: doctor_{_doctorId}");
            }
        }

        private async Task EnsureConnectionAsync()
        {
            if (_connection == null)
            {
                var apiBaseUrl = (_configuration["ApiSettings:BaseUrl"] ?? _configuration["ConnectionStrings:ApiBaseUrl"] ?? "https://fyp-apis-bhe7cjbscyehccff.centralindia-01.azurewebsites.net").TrimEnd('/');
                _connection = new HubConnectionBuilder()
                    .WithUrl($"{apiBaseUrl}/hubs/appointment")
                    .WithAutomaticReconnect()
                    .Build();

                RegisterHandlers();
                _connection.Reconnected += async _ => await EnsureDoctorGroupAsync();
            }

            try
            {
                await _connection.StartAsync();
                Console.WriteLine("[HubClient] SignalR connected");
                await EnsureDoctorGroupAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[HubClient] SignalR connection failed: {ex.Message}");
            }
        }

        private void RegisterHandlers()
        {
            if (_handlersRegistered || _connection == null)
            {
                return;
            }

            _handlersRegistered = true;

            _connection.On<object>("NewAppointment", async data =>
            {
                var payload = ParseAppointment(data);
                if (NewAppointment != null)
                {
                    await NewAppointment(payload);
                }
            });

            _connection.On<object>("VerificationStatusChanged", async data =>
            {
                var payload = ParseVerification(data);
                if (VerificationStatusChanged != null)
                {
                    await VerificationStatusChanged(payload);
                }
            });
        }

        private async Task EnsureDoctorGroupAsync()
        {
            if (_connection == null || _connection.State != HubConnectionState.Connected)
            {
                return;
            }

            if (string.IsNullOrEmpty(_doctorId))
            {
                _doctorId = await LoadDoctorIdAsync();
            }

            if (!string.IsNullOrEmpty(_doctorId))
            {
                await _connection.InvokeAsync("JoinDoctorGroup", _doctorId);
                Console.WriteLine($"[HubClient] Joined doctor group: doctor_{_doctorId}");
            }
        }

        private async Task<string?> LoadDoctorIdAsync()
        {
            try
            {
                var client = await _apiClient.SetAuthorizedHeader();
                var response = await client.GetAsync("api/Doctor/get/profile");
                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"[HubClient] Doctor profile fetch failed: {response.StatusCode}");
                    return null;
                }

                var payload = await response.Content.ReadFromJsonAsync<DoctorProfileResponse>();
                return payload?.Doctor?.Id;
            }
            catch
            {
                return null;
            }
        }

        private static AppointmentNotification ParseAppointment(object data)
        {
            try
            {
                var json = JsonSerializer.Serialize(data);
                return JsonSerializer.Deserialize<AppointmentNotification>(json) ?? new AppointmentNotification();
            }
            catch
            {
                return new AppointmentNotification();
            }
        }

        private static VerificationStatusNotification ParseVerification(object data)
        {
            try
            {
                var json = JsonSerializer.Serialize(data);
                return JsonSerializer.Deserialize<VerificationStatusNotification>(json) ?? new VerificationStatusNotification();
            }
            catch
            {
                return new VerificationStatusNotification();
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (_connection != null)
            {
                await _connection.DisposeAsync();
            }
        }

        private class DoctorProfileResponse
        {
            [JsonPropertyName("isSuccess")]
            public bool IsSuccess { get; set; }

            [JsonPropertyName("doctor")]
            public DoctorProfileDto? Doctor { get; set; }
        }

        private class DoctorProfileDto
        {
            [JsonPropertyName("id")]
            public string? Id { get; set; }
        }
    }

    public class AppointmentNotification
    {
        [JsonPropertyName("appointmentId")]
        public string? AppointmentId { get; set; }

        [JsonPropertyName("patientId")]
        public string? PatientId { get; set; }

        [JsonPropertyName("patientName")]
        public string? PatientName { get; set; }

        [JsonPropertyName("appointmentDate")]
        public DateTime? AppointmentDate { get; set; }

        [JsonPropertyName("slotTime")]
        public DateTime? SlotTime { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }
    }

    public class VerificationStatusNotification
    {
        [JsonPropertyName("Status")]
        public string? Status { get; set; }

        [JsonPropertyName("Message")]
        public string? Message { get; set; }

        [JsonPropertyName("IsVerified")]
        public bool IsVerified { get; set; }
    }
}
