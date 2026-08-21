using Microsoft.AspNetCore.SignalR;
// M-4 APPOINTMENT HUB FOR REAL-TIME NOTIFICATIONS
// M-9 USED IN DOCTOR VERIFICATION TO NOTIFY DOCTORS ABOUT VERIFICATION STATUS CHANGES

namespace first_api.Hubs
{
    public class AppointmentHub : Hub
    {
        public async Task JoinDoctorGroup(string doctorId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"doctor_{doctorId}");
            Console.WriteLine($"Client {Context.ConnectionId} joined doctor group: doctor_{doctorId}");
        }

        public async Task LeaveDoctorGroup(string doctorId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"doctor_{doctorId}");
            Console.WriteLine($"Client {Context.ConnectionId} left doctor group: doctor_{doctorId}");
        }

        public async Task JoinPatientGroup(string patientId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"patient_{patientId}");
            Console.WriteLine($"Client {Context.ConnectionId} joined patient group: patient_{patientId}");
        }

        public async Task LeavePatientGroup(string patientId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"patient_{patientId}");
            Console.WriteLine($"Client {Context.ConnectionId} left patient group: patient_{patientId}");
        }

        public override async Task OnConnectedAsync()
        {
            Console.WriteLine($"Client connected: {Context.ConnectionId}");
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            Console.WriteLine($"Client disconnected: {Context.ConnectionId}");
            await base.OnDisconnectedAsync(exception);
        }
    }
}
