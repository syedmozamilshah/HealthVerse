using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;


// M-9 USED FOR SHOWING THE DATA

namespace first_api.Controllers.AdminController
{
    [Route("api/admin/[controller]")]
    [ApiController]
    [Authorize]
    public class LogsController : ControllerBase
    {
        public static List<LogEntry> RequestLogs = new List<LogEntry>();

        [HttpGet]
        public IActionResult GetLogs()
        {
            try
            {
                var recentLogs = RequestLogs
                    .OrderByDescending(l => l.CreatedAt)
                    .Take(100)
                    .Select(log => new
                    {
                        timestamp = log.Timestamp,
                        user = log.User,
                        action = log.Action,
                        status = log.Status,
                        ipAddress = log.IpAddress
                    })
                    .ToList();

                return Ok(new
                {
                    isSuccess = true,
                    data = recentLogs
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching logs: " + ex.Message
                });
            }
        }
    }

    public class LogEntry
    {
        public string Timestamp { get; set; } = string.Empty;
        public string User { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string IpAddress { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
