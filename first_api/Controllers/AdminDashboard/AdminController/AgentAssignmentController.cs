using System;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Entities.AgentAssignmentModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace first_api.Controllers.AdminController
{
    
    [Route("api/admin/agent-assignment")]
    [ApiController]
    [Authorize]
    public class AgentAssignmentController : ControllerBase
    {
        private readonly DoctorAgentAssignmentService _assignmentService;

        public AgentAssignmentController(DoctorAgentAssignmentService assignmentService)
        {
            _assignmentService = assignmentService;
        }

        private string GetAdminId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "unknown";

        [HttpGet("settings")]
        public async Task<IActionResult> GetSettings()
        {
            try
            {
                var settings = await _assignmentService.GetSettingsAsync();
                return Ok(new AssignmentSettingsResponse
                {
                    IsSuccess = true,
                    Message = "Settings retrieved",
                    GlobalMode = settings.GlobalMode,
                    EnforceSubscriptionGate = settings.EnforceSubscriptionGate,
                    BlockAutoOnArchived = settings.BlockAutoOnArchived,
                    UpdatedAt = settings.UpdatedAt
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpPut("settings")]
        public async Task<IActionResult> UpdateSettings([FromBody] UpdateAssignmentSettingsDto dto)
        {
            try
            {
                if (dto.GlobalMode != "Auto" && dto.GlobalMode != "Manual")
                {
                    return BadRequest(new AssignmentResponse
                    {
                        IsSuccess = false,
                        Message = "GlobalMode must be 'Auto' or 'Manual'"
                    });
                }

                var adminId = GetAdminId();
                var settings = await _assignmentService.UpdateSettingsAsync(dto.GlobalMode, adminId);

                return Ok(new AssignmentSettingsResponse
                {
                    IsSuccess = true,
                    Message = $"Global mode updated to {dto.GlobalMode}",
                    GlobalMode = settings.GlobalMode,
                    EnforceSubscriptionGate = settings.EnforceSubscriptionGate,
                    BlockAutoOnArchived = settings.BlockAutoOnArchived,
                    UpdatedAt = settings.UpdatedAt
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPending()
        {
            try
            {
                var (items, total) = await _assignmentService.GetPendingAssignmentsAsync();
                return Ok(new AssignmentListResponse
                {
                    IsSuccess = true,
                    Message = "Pending assignments retrieved",
                    Data = items,
                    TotalCount = total
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpGet("list")]
        public async Task<IActionResult> GetList(
            [FromQuery] string? status = null,
            [FromQuery] string? mode = null,
            [FromQuery] string? search = null)
        {
            try
            {
                var (items, total) = await _assignmentService.GetAssignmentsAsync(status, mode, search);
                return Ok(new AssignmentListResponse
                {
                    IsSuccess = true,
                    Message = "Assignments retrieved",
                    Data = items,
                    TotalCount = total
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpPost("approve/{doctorId}")]
        public async Task<IActionResult> Approve(string doctorId)
        {
            try
            {
                var adminId = GetAdminId();
                var (success, message) = await _assignmentService.ApprovePendingAsync(doctorId, adminId);

                if (!success)
                {
                    return BadRequest(new AssignmentResponse
                    {
                        IsSuccess = false,
                        Message = message
                    });
                }

                return Ok(new AssignmentResponse
                {
                    IsSuccess = true,
                    Message = message
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpPost("pause/{doctorId}")]
        public async Task<IActionResult> Pause(string doctorId, [FromBody] PauseAssignmentDto? dto)
        {
            try
            {
                var adminId = GetAdminId();
                var (success, message) = await _assignmentService.PauseActiveAsync(
                    doctorId, adminId, dto?.Reason ?? "");

                if (!success)
                {
                    return BadRequest(new AssignmentResponse
                    {
                        IsSuccess = false,
                        Message = message
                    });
                }

                return Ok(new AssignmentResponse
                {
                    IsSuccess = true,
                    Message = message
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpPost("resume/{doctorId}")]
        public async Task<IActionResult> Resume(string doctorId)
        {
            try
            {
                var adminId = GetAdminId();
                var (success, message) = await _assignmentService.ResumePausedAsync(doctorId, adminId);

                if (!success)
                {
                    return BadRequest(new AssignmentResponse
                    {
                        IsSuccess = false,
                        Message = message
                    });
                }

                return Ok(new AssignmentResponse
                {
                    IsSuccess = true,
                    Message = message
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpPost("archive/{doctorId}")]
        public async Task<IActionResult> Archive(string doctorId, [FromBody] ArchiveAssignmentDto? dto)
        {
            try
            {
                var adminId = GetAdminId();
                var (success, message) = await _assignmentService.ArchiveAssignmentAsync(
                    doctorId, adminId, dto?.Reason ?? "");

                if (!success)
                {
                    return BadRequest(new AssignmentResponse
                    {
                        IsSuccess = false,
                        Message = message
                    });
                }

                return Ok(new AssignmentResponse
                {
                    IsSuccess = true,
                    Message = message
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }

        [HttpGet("history/{doctorId}")]
        public async Task<IActionResult> GetHistory(string doctorId)
        {
            try
            {
                var events = await _assignmentService.GetHistoryAsync(doctorId);
                return Ok(new AssignmentHistoryResponse
                {
                    IsSuccess = true,
                    Message = "History retrieved",
                    Data = events
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new AssignmentResponse
                {
                    IsSuccess = false,
                    Message = "Error: " + ex.Message
                });
            }
        }
    }
}
