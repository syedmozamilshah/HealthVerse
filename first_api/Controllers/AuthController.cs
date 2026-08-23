// MODULE 1 - AUTHENTICATION CONTROLLER

using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using CloudinaryDotNet.Actions;
using first_api.Data;
using first_api.Entities.AuthModel;
using first_api.Entities.DoctorModel;
using first_api.Entities.PatientModel;
using first_api.Entities.UserModel;
using first_api.Services;
using FluentEmail.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;

namespace first_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private const string DoctorAccessCookieName = "hv_access";
        private const string DoctorRefreshCookieName = "hv_refresh";
        private readonly IMongoCollection<User> _users;
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly IMongoCollection<PatientModel> _patientModel;
        private readonly IJwtService _jwtService;
        // USED IN SENDING EMAIL NUGET PACKAGE - FLUENTEMAIL
        private readonly IFluentEmail _fluentEmail;

        private readonly LinkGenerator _linkGenerator;

        private readonly IMongoCollection<EmailVerificationToken> _tokens;

        private readonly IConfiguration _configuration;

        [ActivatorUtilitiesConstructor]
        public AuthController(
            MongodbService mongoDbService,
            IJwtService jwtService,
            IFluentEmail fluentEmail,
            LinkGenerator linkGenerator,
            IConfiguration configuration
            )
        {
            _users = mongoDbService.Database?.GetCollection<User>("users")!;
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _tokens = mongoDbService.Database?.GetCollection<EmailVerificationToken>("email_verification_tokens")!;
            _patientModel = mongoDbService.Database?.GetCollection<PatientModel>("patient")!;
            _jwtService = jwtService;
            _fluentEmail = fluentEmail;
            _linkGenerator = linkGenerator;
            _configuration = configuration;
        }

        private string GetVerificationEmailTemplate(string userName, string? verificationLink)
        {
            verificationLink ??= string.Empty;
            return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
</head>
<body style='margin: 0; padding: 0; font-family: Arial, Helvetica, sans-serif; background-color: #f4f4f4;'>
    <table role='presentation' style='width: 100%; border-collapse: collapse;'>
        <tr>
            <td style='padding: 40px 0;'>
                <table role='presentation' style='max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);'>
                    <!-- Header with gradient -->
                    <tr>
                        <td style='background: linear-gradient(135deg, #1F8A70 0%, #2AAA8A 50%, #40E0D0 100%); padding: 40px 30px; text-align: center;'>
                            <h1 style='color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;'>🏥 HealthVerse</h1>
                            <p style='color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;'>Your Digital Health Companion</p>
                        </td>
                    </tr>
                    
                    <!-- Main Content -->
                    <tr>
                        <td style='padding: 40px 30px;'>
                            <h2 style='color: #1F8A70; margin: 0 0 20px 0; font-size: 24px;'>Verify Your Email Address</h2>
                            <p style='color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;'>
                                Hello <strong>{userName}</strong>,
                            </p>
                            <p style='color: #555555; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;'>
                                Thank you for signing up with HealthVerse! To complete your registration and start your health journey with us, please verify your email address by clicking the button below.
                            </p>
                            
                            <!-- CTA Button -->
                            <table role='presentation' style='margin: 0 auto;'>
                                <tr>
                                    <td style='border-radius: 8px; background: linear-gradient(135deg, #1F8A70 0%, #2AAA8A 100%);'>
                                        <a href='{verificationLink}' style='display: inline-block; padding: 16px 40px; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: bold;'>Verify Email Address</a>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Timer Notice -->
                            <div style='margin: 30px 0; padding: 20px; background-color: #FFF8E1; border-left: 4px solid #FFC107; border-radius: 4px;'>
                                <p style='color: #856404; margin: 0; font-size: 14px;'>
                                    <strong>This link expires in 2 minutes</strong> for your security.
                                </p>
                            </div>
                            
                            <p style='color: #888888; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;'>
                                If the button doesn't work, copy and paste this link into your browser:
                            </p>
                            <p style='color: #1F8A70; font-size: 12px; word-break: break-all; margin: 10px 0 0 0;'>
                                {verificationLink}
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style='background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eeeeee;'>
                            <p style='color: #888888; font-size: 13px; margin: 0 0 10px 0;'>
                                If you didn't create an account with HealthVerse, please ignore this email.
                            </p>
                            <p style='color: #aaaaaa; font-size: 12px; margin: 0;'>
                                © 2025 HealthVerse. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>";
        }


// REGISTERATION
        [HttpPost("register")]
        public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request)
        {
            var response = new AuthResponse();
            Console.WriteLine("=== Registration Start ===");
            Console.WriteLine($"FirstName: {request.FirstName}");
            Console.WriteLine($"LastName: {request.LastName}");
            Console.WriteLine($"Email: {request.Email}");
            Console.WriteLine($"ProfileType: {request.ProfileType}");
            Console.WriteLine($"Gender: {request.Gender}");
            Console.WriteLine($"Address: {request.Address}");

            try
            {
                // Check if user already exists
                var existingUser = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync();
                if (existingUser != null)
                {
                    response.IsSuccess = false;
                    response.Message = "User with this email already exists";
                    return BadRequest(response);
                }

                if (request.ProfileType == "patient")
                {
                    Console.WriteLine("registeration for patient");

                    // Create new user
                    var user = new User
                    {
                        FirstName = request.FirstName,
                        LastName = request.LastName,
                        Email = request.Email,
                        PasswordHash = _jwtService.HashPassword(request.Password),
                        Dob = request.Dob ?? DateTime.MinValue,
                        Address = request.Address,
                        BloodGroup = request.BloodGroup ?? string.Empty,
                        Gender = request.Gender,
                        ProfileType = request.ProfileType,
                        WhatsappNo = request.WhatsappNo ?? string.Empty,
                        CreatedAt = DateTime.Now,
                        ProfileImage = request.ProfileImage ?? string.Empty,
                        IsEmailVerified = false
                    };

                    
                    await _users.InsertOneAsync(user);
                    var token = _jwtService.GenerateToken(user, false);
                    Console.WriteLine($"sendiing email to {user.Email}");
                    user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync();


                    var verificationToken = new EmailVerificationToken
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = user.Id,
                        CreatedOnUtc = DateTime.UtcNow,
                        ExpiredOnUtc = DateTime.UtcNow.AddMinutes(2),
                    };

                    var patientModel = new PatientModel
                    {
                        PersonalInfoId = user.Id,
                        Name = $"{request.FirstName} {request.LastName}",
                        Email = request.Email,
                        History = "",
                        InitialConditions = "",
                        Allergy = "",
                        IsVerified = false,
                        Vitals=new Vitals
                        {
                            BloodPressure = new List<BloodPressure>(),
                            SugarLevel = new List<SugarLevel>(),
                            LastUpdated=DateTime.Now,
                        }

                    };
                    await _patientModel.InsertOneAsync(patientModel);
                    Console.WriteLine($"Patient created with Name: {patientModel.Name}, Email: {patientModel.Email}");

                    await _tokens.InsertOneAsync(verificationToken);

                    var verificationLink = _linkGenerator.GetUriByAction(
                        HttpContext,
                        action: nameof(VerifyEmail),
                        controller: "Auth",
                        values: new { token = verificationToken.Id }
                    );


                    var emailBody = GetVerificationEmailTemplate(user.FirstName, verificationLink);
                    await _fluentEmail.To(user.Email).Subject("✉️ Verify Your Email - HealthVerse").Body(emailBody, isHtml: true).SendAsync();
                    Console.WriteLine($"email sent to {user.Email}");
                    response.IsSuccess = true;
                    response.Message = "User registered successfully and email verification link sent";
                    response.Token = token;
                    response.User = user;

                    return Ok(response);
                }


                if (request.ProfileType == "doctor")
                {
                    Console.WriteLine("registeration for doctor");

                    var user = new User
                    {
                        FirstName = request.FirstName,
                        LastName = request.LastName,
                        Email = request.Email,
                        PasswordHash = _jwtService.HashPassword(request.Password),
                        Address = request.Address,
                        Gender = request.Gender,
                        ProfileType = request.ProfileType,
                        CreatedAt = DateTime.Now,
                        ProfileImage = request.ProfileImage??string.Empty,
                        IsEmailVerified = false
                    };
                    await _users.InsertOneAsync(user);
                    // Re-fetch user to get MongoDB-assigned _id (critical: without this, user.Id is empty)
                    user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync();
                    var doctor = new Doctor
                    {
                        IsVerified = false,
                        LicenceNumber = "",
                        PersonalInfoId = user.Id,
                        Name = $"{request.FirstName} {request.LastName}",
                        Email = request.Email,
                        RenewalDate = DateTime.Now,
                        Speciality = "",
                        AvailabilityDate = DateTime.Now,
                        IsAvailable = false,
                        AvailableTimeMorning = new AvailableTime(),
                        ClinicInfo = new ClinicInfo(),
                        DailyAvailabilities=new List<DayAvailability>(),
                        Experience = "",
                        Fee ="",
                        ImageUrl = user.ProfileImage,
                        Specialization = ""
                    };
                    await _doctors.InsertOneAsync(doctor);
                    Console.WriteLine($"Doctor created with Name: {doctor.Name}, Email: {doctor.Email}");
                    // Generate JWT token
                    var token = _jwtService.GenerateToken(user, false);
                    Console.WriteLine($"sendiing email to {user.Email}");

                    var verificationToken = new EmailVerificationToken
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = user.Id,
                        CreatedOnUtc = DateTime.UtcNow,
                        ExpiredOnUtc = DateTime.UtcNow.AddMinutes(10),
                    };

                    await _tokens.InsertOneAsync(verificationToken);

                    var verificationLink = _linkGenerator.GetUriByAction(
                        HttpContext,
                        action: nameof(VerifyEmail),
                        controller: "Auth",
                        values: new { token = verificationToken.Id }
                    );


                    var emailBody = GetVerificationEmailTemplate(user.FirstName, verificationLink);
                    await _fluentEmail.To(user.Email).Subject("✉️ Verify Your Email - HealthVerse").Body(emailBody, isHtml: true).SendAsync();
                    Console.WriteLine($"email sent to {user.Email}");
                    response.IsSuccess = true;
                    response.Message = "User registered successfully and email verification link sent";
                    response.Token = token;
                    response.User = user;

                    return Ok(response);
                }

                return StatusCode(400, "not found");


            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

// ACCOUNT VERIFICATION
        [HttpGet("verify-email")]
        public async Task<IActionResult> VerifyEmail([FromQuery] string token)
        {
            try
            {
                var verificationToken = await _tokens.Find(t => t.Id == token).FirstOrDefaultAsync();
                if (verificationToken == null)
                {
                    return Content(GetVerificationResultPage(false, "Invalid Verification Link", "The verification link is invalid or has already been used. Please request a new verification email by trying to sign in."), "text/html");
                }
                if (verificationToken.ExpiredOnUtc < DateTime.UtcNow)
                {
                    // Delete expired token
                    await _tokens.DeleteOneAsync(t => t.Id == token);
                    return Content(GetVerificationResultPage(false, "Link Expired", "This verification link has expired. Please sign in to receive a new verification email."), "text/html");
                }

                var user = await _users.Find(u => u.Id == verificationToken.UserId).FirstOrDefaultAsync();
                if (user == null)
                {
                    return Content(GetVerificationResultPage(false, "User Not Found", "We couldn't find your account. Please try registering again."), "text/html");
                }

                var update = Builders<User>.Update.Set(u => u.IsEmailVerified, true);
                await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                
                // Delete the used token
                await _tokens.DeleteOneAsync(t => t.Id == token);

                return Content(GetVerificationResultPage(true, "Email Verified!", $"Congratulations {user.FirstName}! Your email has been verified successfully. You can now sign in to your HealthVerse account."), "text/html");
            }
            catch (Exception)
            {
                return Content(GetVerificationResultPage(false, "Something Went Wrong", "An error occurred while verifying your email. Please try again later."), "text/html");
            }
        }

        private string GetVerificationResultPage(bool isSuccess, string title, string message)
        {
            var iconColor = isSuccess ? "#1F8A70" : "#DC3545";
            var icon = isSuccess ? "✓" : "✗";
            var buttonText = isSuccess ? "Ok" : "Try Again";
            
            return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>{title} - HealthVerse</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #1F8A70 0%, #2AAA8A 50%, #40E0D0 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        .card {{
            background: white;
            border-radius: 20px;
            padding: 50px 40px;
            max-width: 450px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
        }}
        .icon {{
            width: 80px;
            height: 80px;
            border-radius: 50%;
            background: {iconColor};
            color: white;
            font-size: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 25px;
        }}
        .logo {{
            font-size: 24px;
            font-weight: bold;
            color: #1F8A70;
            margin-bottom: 30px;
        }}
        h1 {{
            color: #333;
            font-size: 28px;
            margin-bottom: 15px;
        }}
        p {{
            color: #666;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 30px;
        }}
        .btn {{
            display: inline-block;
            background: linear-gradient(135deg, #1F8A70 0%, #2AAA8A 100%);
            color: white;
            padding: 15px 40px;
            border-radius: 10px;
            text-decoration: none;
            font-weight: bold;
            font-size: 16px;
            transition: transform 0.2s, box-shadow 0.2s;
        }}
        .btn:hover {{
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(31, 138, 112, 0.4);
        }}
        .footer {{
            margin-top: 30px;
            color: #999;
            font-size: 14px;
        }}
    </style>
</head>
<body>
    <div class='card'>
        <div class='logo'>🏥 HealthVerse</div>
        <div class='icon'>{icon}</div>
        <h1>{title}</h1>
        <p>{message}</p>
        <a href='#' class='btn' onclick='window.close(); return false;'>{buttonText}</a>
        <div class='footer'>© 2025 HealthVerse. All rights reserved.</div>
    </div>
</body>
</html>";
        }

// MULTI-ROLE LOGIN
        [HttpPost("login")]
        public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
        {
            Console.WriteLine(request.Email);
            Console.WriteLine(request.Password);
            Console.WriteLine(request.ProfileType);
            var response = new AuthResponse();
            System.Console.WriteLine("here is login");

            try
            {
                var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync();
                
                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "Invalid email or password";
                    Console.WriteLine("user null");
                    return BadRequest(response);
                }

                Console.WriteLine($"Found user: {user.Id}");

                // ✅ STEP 1: Check password FIRST before anything else
                if (!_jwtService.VerifyPassword(request.Password, user.PasswordHash))
                {
                    Console.WriteLine("Wrong password entered");
                    response.IsSuccess = false;
                    response.Message = "Incorrect password. Please try again.";
                    return StatusCode(401, response);
                }

                // ✅ STEP 2: Check profile type match
                Console.WriteLine(user.ProfileType);
                if (user.ProfileType != request.ProfileType)
                {
                    response.IsSuccess = false;
                    response.Message = "Invalid credentials or unverified account profile not matched.";
                    return StatusCode(404, response);
                }

                // ✅ STEP 3: Check account status
                var acctStatus = (user.AccountStatus ?? (user.IsEmailVerified ? "Active" : "Pending")).ToLowerInvariant();
                if (acctStatus == "banned")
                {
                    response.IsSuccess = false;
                    response.Message = "Your account has been banned. Please contact support if you believe this is a mistake.";
                    return BadRequest(response);
                }
                if (acctStatus == "suspended")
                {
                    response.IsSuccess = false;
                    response.Message = "Your account is suspended. Please contact support for assistance.";
                    return BadRequest(response);
                }

                // ✅ STEP 4: Now check email verification (password was correct)
                var userToken = await _tokens.Find(t => t.UserId == user.Id).FirstOrDefaultAsync();

                if (!user.IsEmailVerified && userToken == null)
                {
                    Console.WriteLine($"sendiing email to {user.Email}");

                    var verificationToken = new EmailVerificationToken
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = user.Id,
                        CreatedOnUtc = DateTime.UtcNow,
                        ExpiredOnUtc = DateTime.UtcNow.AddMinutes(10),
                    };

                    await _tokens.InsertOneAsync(verificationToken);

                    var verificationLink = _linkGenerator.GetUriByAction(
                        HttpContext,
                        action: nameof(VerifyEmail),
                        controller: "Auth",
                        values: new { token = verificationToken.Id }
                    );

                    var emailBody = GetVerificationEmailTemplate(user.FirstName, verificationLink ?? "");
                    await _fluentEmail.To(user.Email).Subject("✉️ Verify Your Email - HealthVerse").Body(emailBody, isHtml: true).SendAsync();
                    Console.WriteLine($"email sent to {user.Email}");
                    response.IsSuccess = false;
                    response.Message = "Your email is not verified! A new verification link has been sent to your email. Please check your inbox and verify to continue.";

                    return BadRequest(response);
                }
                else
                {
                    if (!user.IsEmailVerified && userToken != null)
                    {
                        response.IsSuccess = false;
                        response.Message = "Your email is not verified! Please check your inbox for the verification link we sent earlier. The link expires in 10 minutes.";

                        return BadRequest(response);
                    }
                }

                var token = _jwtService.GenerateToken(user, false);
                var refreshToken = _jwtService.GenerateToken(user, true); 

                var update = Builders<User>.Update.Set(u => u.RefreshToken, refreshToken);
                var result = await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                Console.WriteLine($"Matched: {result.MatchedCount}, Modified: {result.ModifiedCount}");
                response.IsSuccess = true;
                response.Message = "Login successful";
                response.Token = token;
                response.RefreshToken = refreshToken;
                response.RefreshExpired = DateTimeOffset.UtcNow.AddMinutes(3600).ToUnixTimeSeconds();
                response.TokenExpired = DateTimeOffset.UtcNow.AddMinutes(15).ToUnixTimeSeconds();
                response.User = user;

                if (string.Equals(request.ProfileType, "doctor", StringComparison.OrdinalIgnoreCase))
                {
                    AppendDoctorAuthCookies(token, refreshToken, response.TokenExpired, response.RefreshExpired);
                }

                return Ok(response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }
        }

        private void AppendDoctorAuthCookies(string accessToken, string refreshToken, long? accessExpires, long? refreshExpires)
        {
            var accessOptions = BuildCookieOptions(accessExpires);
            var refreshOptions = BuildCookieOptions(refreshExpires);

            Response.Cookies.Append(DoctorAccessCookieName, accessToken, accessOptions);
            Response.Cookies.Append(DoctorRefreshCookieName, refreshToken, refreshOptions);
        }

        private CookieOptions BuildCookieOptions(long? unixExpires)
        {
            var options = new CookieOptions
            {
                HttpOnly = true,
                Secure = HttpContext.Request.IsHttps,
                SameSite = SameSiteMode.Lax,
                Path = "/"
            };

            if (unixExpires.HasValue)
            {
                options.Expires = DateTimeOffset.FromUnixTimeSeconds(unixExpires.Value);
            }

            return options;
        }

// ACCOUNT RECOVERY
        [HttpPost("forgot-password")]
        public async Task<ActionResult> ForgotPassword(ForgotPasswordRequest request)
        {
            var response = new AuthResponse();
            
            try
            {
                var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync();
                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found";
                    return NotFound(response);
                }
                if (user.ProfileType != request.ProfileType)
                {
                    response.IsSuccess = false;
                    response.Message = "Invalid credentials or unverified account profile not matched.";

                    return StatusCode(404, response);
                }
                string password = _jwtService.GeneratePassword();
                Console.WriteLine($"sendiing email to {user.Email}");
                await _fluentEmail.To(user.Email).Subject("Password Changed request for HEALTHVERSE").Body($@"
<div style=""font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f4f7f6; padding: 20px; border-radius: 10px;"">
    <div style=""background: linear-gradient(135deg, #a8e6cf 0%, #dcedc1 100%); padding: 40px 20px; border-radius: 15px 15px 0 0; text-align: center;"">
        <h1 style=""color: #198754; margin: 0; font-size: 32px; font-weight: 800; letter-spacing: 1px; text-shadow: 0 2px 4px rgba(0,0,0,0.1);"">HEALTHVERSE</h1>
        <p style=""color: #146c43; margin: 10px 0 0; font-size: 16px; font-weight: 500;"">Your Digital Health Companion</p>
    </div>
    <div style=""background-color: #ffffff; padding: 40px; border-radius: 0 0 15px 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.05);"">
        <h2 style=""color: #2c3e50; margin-top: 0; font-size: 24px; border-bottom: 2px solid #f0f0f0; padding-bottom: 15px;"">Account Recovery</h2>
        <p style=""color: #555; line-height: 1.6; font-size: 16px;"">Hello,</p>
        <p style=""color: #555; line-height: 1.6; font-size: 16px;"">We received a request to recover your HealthVerse account. Please use the following temporary password to sign in:</p>
        
        <div style=""background-color: #f8f9fa; border: 2px dashed #198754; border-radius: 12px; padding: 25px; text-align: center; margin: 30px 0;"">
            <span style=""font-size: 36px; font-weight: bold; color: #198754; letter-spacing: 3px; font-family: monospace;"">{password}</span>
        </div>

        <div style=""background-color: #fff8e1; border-left: 5px solid #ffc107; padding: 20px; border-radius: 8px; margin-bottom: 30px;"">
            <p style=""margin: 0; color: #856404; font-size: 14px; line-height: 1.5;""><strong>Security Alert:</strong> This is a temporary password. Please change it immediately after logging in to secure your account.</p>
        </div>
        
        <p style=""color: #999; font-size: 14px; text-align: center; margin-top: 40px;"">If you did not request this password reset, please contact our support team immediately.</p>
    </div>
    <div style=""text-align: center; margin-top: 25px; color: #adb5bd; font-size: 12px;"">
        <p>&copy; {DateTime.Now.Year} HealthVerse. All rights reserved.</p>
    </div>
</div>", isHtml: true).SendAsync();
                Console.WriteLine($"email sent to {user.Email}");
                var update = Builders<User>.Update.Set(u => u.PasswordHash, _jwtService.HashPassword(password));
                await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                response.IsSuccess = true;
                response.Message = "Password reset link sent to your email.";


                return StatusCode(200,response);
            }
            catch (Exception ex)
            {
                return StatusCode(500, "Exception occurs: " + ex.Message);
            }
            
        }


// ACCOUNT MODERATION
        [Authorize]
        [HttpPost("reset-password")]
        public async Task<ActionResult> ResetPassword(ResetPasswordRequest request)
        {

            Console.WriteLine("Previous password" + request.PreviousPassword);
            Console.WriteLine("New password" + request.NewPassword);
            var response = new AuthResponse();
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                Console.WriteLine($"userId: {userId}");

                if (string.IsNullOrWhiteSpace(userId))
                {
                    response.IsSuccess = false;
                    response.Message = "Invalid user identity. Please log out and log back in.";
                    return Unauthorized(response);
                }

                var filter = Builders<User>.Filter.Eq(x => x.Id, userId);
                var user = _users.Find(filter).FirstOrDefault();
                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found";
                    response.User = user;
                    return NotFound(response);
                }

                Console.WriteLine($"user: {request.PreviousPassword}");

                if (!_jwtService.VerifyPassword(request.PreviousPassword, user.PasswordHash))
                {
                    response.IsSuccess = false;
                    response.Message = "previous password is incorrect";

                    return BadRequest(response);
                }

                var update = Builders<User>.Update.Set(u => u.PasswordHash, _jwtService.HashPassword(request.NewPassword));
                await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                response.IsSuccess = true;
                response.Message = "Password reset successful";


                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }

        }


// STATELESS AUTHENTICATION WITH REFRESH TOKEN
        [HttpGet("loginByRefreshToken")]
        public async Task<ActionResult> LoginByRefreshToken(string? refreshToken)
        {
            // Try to get refresh token from query parameter first, then from cookie
            if (string.IsNullOrWhiteSpace(refreshToken))
            {
                refreshToken = Request.Cookies[DoctorRefreshCookieName];
            }

            if (string.IsNullOrWhiteSpace(refreshToken))
            {
                return new StatusCodeResult(StatusCodes.Status401Unauthorized);
            }

            var secret = _configuration.GetValue<string>("JwtSettings:RefreshKey");
            var claimPrincipal = GetClaimsPrincipalFromToken(refreshToken, secret!);

            if (claimPrincipal == null)
            {
                return new StatusCodeResult(StatusCodes.Status401Unauthorized);
            }

            var response = new AuthResponse();
            try
            {
                var userId = claimPrincipal.FindFirstValue(ClaimTypes.NameIdentifier);
                Console.WriteLine($"userId: {userId}");

                if (string.IsNullOrWhiteSpace(userId))
                {
                    response.IsSuccess = false;
                    response.Message = "Invalid user identity. Please log out and log back in.";
                    return Unauthorized(response);
                }

                var filter = Builders<User>.Filter.Eq(x => x.Id, userId);
                var user = _users.Find(filter).FirstOrDefault();
                if (user == null)
                {
                    response.IsSuccess = false;
                    response.Message = "User not found";
                    response.User = user;
                    return NotFound(response);
                }
                var preToken = user.RefreshToken;
                if (preToken == null)
                {
                    return StatusCode(StatusCodes.Status400BadRequest);
                }
                var newToken = _jwtService.GenerateToken(user, false);
                var newRefreshToken = _jwtService.GenerateToken(user, true);


                // Console.WriteLine($"user: {request.PreviousPassword}");

                // if (!_jwtService.VerifyPassword(request.PreviousPassword, user.PasswordHash))
                // {
                //     response.IsSuccess = false;
                //     response.Message = "previous password is incorrect";

                //     return BadRequest(response);
                // }

                // var update = Builders<User>.Update.Set(u => u.PasswordHash, _jwtService.HashPassword(request.NewPassword));
                // await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                var update = Builders<User>.Update.Set(u => u.RefreshToken, newRefreshToken);
                await _users.UpdateOneAsync(u => u.Id == user.Id, update);
                response.User = user;
                response.Token = newToken;
                response.RefreshToken = newRefreshToken;
                response.RefreshExpired = DateTimeOffset.UtcNow.AddMinutes(3600).ToUnixTimeSeconds();
                response.TokenExpired = DateTimeOffset.UtcNow.AddMinutes(15).ToUnixTimeSeconds();
                response.IsSuccess = true;
                response.Message = "Token refreshed successfully";

                // If the refresh token came from cookie (doctor profile), set new cookies
                if (Request.Cookies.ContainsKey(DoctorRefreshCookieName))
                {
                    AppendDoctorAuthCookies(newToken, newRefreshToken, response.TokenExpired, response.RefreshExpired);
                }

                return StatusCode(200, response);
            }
            catch (Exception ex)
            {
                response.IsSuccess = false;
                response.Message = "Exception occurs: " + ex.Message;
                return StatusCode(500, response);
            }

        }

        private ClaimsPrincipal GetClaimsPrincipalFromToken(string token , string secret)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(secret);
            try
            {
                var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
                {
                    ValidateAudience = true,
                    ValidAudience = _configuration.GetValue<string>("JwtSettings:Audience"),
                    ValidateIssuer = true,
                    ValidIssuer = _configuration.GetValue<string>("JwtSettings:Issuer"),
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                }, out var validatedToken);
                return principal;
            }
            catch 
            {
                return null!;
            }
        }
    }
} 