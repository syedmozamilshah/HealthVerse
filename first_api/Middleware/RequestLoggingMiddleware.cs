using System.Diagnostics;
using first_api.Controllers.AdminController;

namespace first_api.Middleware
{
    public class RequestLoggingMiddleware
    {
        private readonly RequestDelegate _next;

        public RequestLoggingMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = Stopwatch.StartNew();

            await _next(context);

            stopwatch.Stop();

            // Skip logging for admin endpoints
            if (context.Request.Path.StartsWithSegments("/api/admin"))
            {
                return;
            }

            // Skip logging if the user is an admin
            if (context.User.Identity?.IsAuthenticated == true && context.User.IsInRole("admin"))
            {
                return;
            }

            var user = context.User?.Identity?.Name;
            if (string.IsNullOrEmpty(user))
            {
                user = context.User?.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value 
                    ?? context.User?.FindFirst("name")?.Value 
                    ?? context.User?.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value 
                    ?? "Anonymous";
            }
            
            
            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            var method = context.Request.Method;
            var path = context.Request.Path;
            var statusCode = context.Response.StatusCode;
            var rawIpAddress = context.Connection.RemoteIpAddress?.ToString() ?? "Unknown";
            var ipAddress = rawIpAddress == "::1" ? "127.0.0.1" : rawIpAddress;

            var logEntry = new LogEntry
            {
                Timestamp = timestamp,
                User = string.IsNullOrWhiteSpace(user) || user == "Anonymous" ? "Guest / Anonymous" : user,
                Action = $"{method} {path}",
                Status = statusCode >= 200 && statusCode < 300 ? "success" : "error",
                IpAddress = ipAddress,
                CreatedAt = DateTime.Now
            };

            LogsController.RequestLogs.Add(logEntry);

            if (LogsController.RequestLogs.Count > 1000)
            {
                LogsController.RequestLogs.RemoveAt(0);
            }
        }
    }
}
