using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using System.Security.Claims;
using CloudinaryDotNet;
using first_api.Entities.PatientModel;
using first_api.Entities.UserModel;


// M-2 PATIENT PROFILE MANAGEMENT
namespace first_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class UserController : ControllerBase 
    {
        private readonly IMongoCollection<User> _users;
        public UserController(MongodbService mongoDbService)
        {
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
        }

        [HttpPost("profile/update")]
        public async Task<IActionResult> UpdateUser([FromForm] UpdateProfileDtos profile,[FromServices] CloudinaryService cloudinaryService)
        {
            Console.WriteLine($"Received: FirstName='{profile.FirstName}', LastName='{profile.LastName}', Address='{profile.Address}', WhatsappNo='{profile.WhatsappNo}'");
            
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            UserResponse response = new UserResponse();
            if (string.IsNullOrWhiteSpace(userId))
            {
                response.IsSuccess = false;
                response.Message = "unauthorized";
                return StatusCode(404, response);
            }
            try
            {
                var filter = Builders<User>.Filter.Eq(x => x.Id, userId);
                var user = _users.Find(filter).FirstOrDefault();

                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found ";
                    return StatusCode(404, response);
                }
                if (profile.FirstName != "")
                {
                    user.FirstName = profile.FirstName!;          
                }
                if (profile.LastName != "")
                {
                    user.LastName = profile.LastName!;               
                }
                if (profile.Address != "")
                {
                    user.Address = profile.Address!;                
                }
                if (profile.WhatsappNo != "")
                {
                    user.WhatsappNo = profile.WhatsappNo!;                
                }
                Console.WriteLine($"user: checking user profile image");
                if (profile.ProfileImage != null)
                {
                    Console.WriteLine($"profile image: {profile.ProfileImage}");
                    var imageUrl = await cloudinaryService.UploadImageAsync(profile.ProfileImage);
                    if (!string.IsNullOrEmpty(imageUrl))
                        user.ProfileImage = imageUrl;
                }

                await _users.ReplaceOneAsync(filter, user); 
                response.IsSuccess = true;
                response.Message = "User update" + userId;
                response.imageUrl = user.ProfileImage;
                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in UpdateUser: {ex.Message}");
                Console.WriteLine($"Stack Trace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"Inner Exception: {ex.InnerException.Message}");
                }
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        
    }
    
}