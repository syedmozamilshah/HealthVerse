using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using first_api.Entities.UserModel;

// M-9 USED FOR PATIENT ACTIVITY TRACKING
namespace first_api.Controllers.AdminController
{
    [Route("api/admin/[controller]")]
    [ApiController]
    [Authorize]
    public class UserDataController : ControllerBase
    {
        private readonly IMongoCollection<User> _users;

        public UserDataController(MongodbService mongoDbService)
        {
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
        }

        [HttpGet("info")]
        public async Task<IActionResult> GetUserInfo()
        {
            try
            {
                var users = await _users.Find(u => u.ProfileType == "patient").ToListAsync();

                var userInfo = users.Select(user => new
                {
                    id = user.Id,
                    name = $"{user.FirstName} {user.LastName}",
                    email = user.Email,
                    accountStatus = user.AccountStatus ?? (user.IsEmailVerified ? "Active" : "Pending")
                }).ToList();

                return Ok(new
                {
                    isSuccess = true,
                    data = userInfo
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching user info: " + ex.Message
                });
            }
        }

        [HttpGet("count")]
        public async Task<IActionResult> GetUserCount()
        {
            try
            {
                var totalCount = await _users.CountDocumentsAsync(u => u.ProfileType == "patient");
                var verifiedCount = await _users.CountDocumentsAsync(u => u.ProfileType == "patient" && u.IsEmailVerified == true);
                var unverifiedCount = await _users.CountDocumentsAsync(u => u.ProfileType == "patient" && u.IsEmailVerified == false);

                return Ok(new
                {
                    isSuccess = true,
                    data = new
                    {
                        totalUsers = totalCount,
                        verifiedUsers = verifiedCount,
                        unverifiedUsers = unverifiedCount
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    isSuccess = false,
                    message = "Error fetching user count: " + ex.Message
                });
            }
        }

        [HttpPost("suspend/{userId}")]
        public async Task<IActionResult> SuspendUser(string userId)
        {
            try
            {
                var filter = Builders<User>.Filter.Eq(u => u.Id, userId);
                var update = Builders<User>.Update.Set(u => u.AccountStatus, "Suspended");
                var result = await _users.UpdateOneAsync(filter, update);

                if (result.ModifiedCount == 0)
                {
                    return NotFound(new { isSuccess = false, message = "User not found" });
                }

                return Ok(new { isSuccess = true, message = "User suspended successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Error suspending user: " + ex.Message });
            }
        }

        [HttpPost("activate/{userId}")]
        public async Task<IActionResult> ActivateUser(string userId)
        {
            try
            {
                var filter = Builders<User>.Filter.Eq(u => u.Id, userId);
                var update = Builders<User>.Update.Set(u => u.AccountStatus, "Active");
                var result = await _users.UpdateOneAsync(filter, update);

                if (result.ModifiedCount == 0)
                {
                    return NotFound(new { isSuccess = false, message = "User not found" });
                }

                return Ok(new { isSuccess = true, message = "User activated successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Error activating user: " + ex.Message });
            }
        }

        [HttpPost("ban/{userId}")]
        public async Task<IActionResult> BanUser(string userId)
        {
            try
            {
                var filter = Builders<User>.Filter.Eq(u => u.Id, userId);
                var update = Builders<User>.Update.Set(u => u.AccountStatus, "Banned");
                var result = await _users.UpdateOneAsync(filter, update);

                if (result.ModifiedCount == 0)
                {
                    return NotFound(new { isSuccess = false, message = "User not found" });
                }

                return Ok(new { isSuccess = true, message = "User banned successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { isSuccess = false, message = "Error banning user: " + ex.Message });
            }
        }
    }
}
