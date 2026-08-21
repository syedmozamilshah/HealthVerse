using System;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.DoctorModel;
using first_api.Entities.UserModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace first_api.Controllers.AdminController
{
    
    [Route("api/admin/agent-assignment")]
    [ApiController]
    [Authorize]
    public class AgentAssignmentMigrationController : ControllerBase
    {
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<User> _users;
        private readonly DoctorAgentAssignmentService _assignmentService;

        public AgentAssignmentMigrationController(
            MongodbService mongoDbService,
            DoctorAgentAssignmentService assignmentService)
        {
            _doctors = mongoDbService.Database!.GetCollection<Doctor>("doctor");
            _users = mongoDbService.Database!.GetCollection<User>("users");
            _assignmentService = assignmentService;
        }

        [HttpPost("migrate")]
        public async Task<IActionResult> MigrateExistingDoctors()
        {
            try
            {
                var adminId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "migration";

                // Get all verified doctors
                var verifiedDoctors = await _doctors
                    .Find(d => d.IsVerified == true && d.IsReVerificationRequired == false)
                    .ToListAsync();

                int created = 0;
                int skipped = 0;
                int errors = 0;

                foreach (var doctor in verifiedDoctors)
                {
                    try
                    {
                        // Get doctor name from user collection
                        var user = await _users
                            .Find(u => u.Id == doctor.PersonalInfoId)
                            .FirstOrDefaultAsync();
                        var doctorName = user != null
                            ? $"{user.FirstName} {user.LastName}"
                            : doctor.Name;

                        var outcome = await _assignmentService.HandleDoctorVerificationApprovedAsync(
                            doctor.Id, doctorName, doctor.Specialization, adminId);

                        if (outcome.AssignmentStatus == "Active" || outcome.AssignmentStatus == "Pending")
                        {
                            // Check if it was actually a new creation vs already existed
                            if (outcome.AssignmentMessage.Contains("already has"))
                            {
                                skipped++;
                            }
                            else
                            {
                                created++;
                            }
                        }
                        else
                        {
                            skipped++;
                        }
                    }
                    catch (Exception ex)
                    {
                        errors++;
                        Console.WriteLine($"Migration error for doctor {doctor.Id}: {ex.Message}");
                    }
                }

                return Ok(new
                {
                    isSuccess = true,
                    message = $"Migration complete. Created: {created}, Skipped: {skipped}, Errors: {errors}",
                    totalVerifiedDoctors = verifiedDoctors.Count,
                    created,
                    skipped,
                    errors
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Migration failed: " + ex.Message
                });
            }
        }
    }
}
