using System;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;


// M-9 USED FOR SHOWING THE DATA
namespace first_api.Controllers.AdminController.Metrics
{
    [Route("api/admin/[controller]")]
    [ApiController]
    [Authorize]
    public class MetricsController : ControllerBase
    {
        private static readonly DateTime _startTime = DateTime.Now;
        private static int _requestCount = 0;
        private static double _totalResponseTime = 0;

        [HttpGet]
        public async Task<IActionResult> GetMetrics()
        {
            try
            {
                // Get CPU usage
                var cpuUsage = await GetCpuUsageAsync();

                // Get memory usage
                var process = Process.GetCurrentProcess();
                var memoryUsage = (process.WorkingSet64 / 1024.0 / 1024.0 / 1024.0) * 100; // Convert to percentage approximation

                // Get active threads
                var activeThreads = process.Threads.Count;

                // Calculate average response time
                var avgResponseTime = _requestCount > 0 ? _totalResponseTime / _requestCount : 0;

                return Ok(new
                {
                    isSuccess = true,
                    data = new
                    {
                        cpuUsage = Math.Round(cpuUsage, 1),
                        memoryUsage = Math.Round(memoryUsage, 1),
                        activeThreads = activeThreads,
                        avgResponseTime = Math.Round(avgResponseTime, 1)
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching metrics: " + ex.Message
                });
            }
        }

        private async Task<double> GetCpuUsageAsync()
        {
            var startTime = DateTime.Now;
            var startCpuUsage = Process.GetCurrentProcess().TotalProcessorTime;

            await Task.Delay(500);

            var endTime = DateTime.Now;
            var endCpuUsage = Process.GetCurrentProcess().TotalProcessorTime;

            var cpuUsedMs = (endCpuUsage - startCpuUsage).TotalMilliseconds;
            var totalMsPassed = (endTime - startTime).TotalMilliseconds;
            var cpuUsageTotal = cpuUsedMs / (Environment.ProcessorCount * totalMsPassed);

            return cpuUsageTotal * 100;
        }

        public static void RecordRequest(double responseTime)
        {
            _requestCount++;
            _totalResponseTime += responseTime;
        }
    }
}
