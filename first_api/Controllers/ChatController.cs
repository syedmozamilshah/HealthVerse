using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using first_api.Data;
using first_api.Entities.AgentAssignmentModel;
using first_api.Entities.ChatModel;
using first_api.Entities.DoctorModel;
using first_api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;


// M-8 USED FOR CHAT FOR SPECIFIC PATIENT
namespace first_api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ChatController : ControllerBase
    {
        private readonly IMongoCollection<ChatModel> _chatModel;
        private readonly IMongoCollection<Doctor> _doctors;
        private readonly AIAgentService _aiAgentService;
        private readonly DoctorAgentAssignmentService _assignmentService;

        public ChatController(MongodbService mongoDbService, AIAgentService aiAgentService, DoctorAgentAssignmentService assignmentService)
        {
            _chatModel = mongoDbService.Database?.GetCollection<ChatModel>("chats")!;
            _doctors = mongoDbService.Database?.GetCollection<Doctor>("doctor")!;
            _aiAgentService = aiAgentService;
            _assignmentService = assignmentService;
        }

        // Checks agent assignment access for the current doctor. Returns null if access granted, or an error ActionResult.
        private async Task<(Doctor? Doctor, ActionResult? DenialResult)> CheckAccessGateAsync(string userId)
        {
            var doctor = await _doctors
                .Find(d => d.PersonalInfoId == userId)
                .FirstOrDefaultAsync();

            if (doctor == null)
            {
                return (null, NotFound(new { Status = false, Message = "Doctor profile not found." }));
            }

            var access = await _assignmentService.EvaluateAccessAsync(doctor.Id);
            if (!access.CanAccess)
            {
                return (doctor, StatusCode(403, new
                {
                    Status = false,
                    Message = access.DenialMessage,
                    DenialReason = access.DenialReason,
                    AssignmentStatus = access.AssignmentStatus,
                    RequiresPayment = access.RequiresPayment
                }));
            }

            return (doctor, null);
        }

        // Get a specific chat by patient and doctor IDs
        [HttpGet("{patientId}/{doctorId}")]
        public async Task<ActionResult<ChatModelResponse>> GetChat(string patientId, string doctorId)
        {
            try
            {
                var chat = await _chatModel
                    .Find(c => c.PatientId == patientId && c.DoctorId == doctorId)
                    .FirstOrDefaultAsync();

                if (chat == null)
                {
                    return NotFound(new ChatModelResponse
                    {
                        Status = false,
                        Message = "No chat found for this patient and doctor"
                    });
                }

                return Ok(new ChatModelResponse
                {
                    Status = true,
                    Message = "Chat found",
                    Data = chat
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ChatModelResponse
                {
                    Status = false,
                    Message = ex.Message
                });
            }
        }

        // Get all chats for a specific patient (by the logged-in doctor)
        [HttpGet("patient/{patientId}/list")]
        public async Task<ActionResult<ChatListResponse>> GetChatList(string patientId)
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new ChatListResponse
                    {
                        Status = false,
                        Message = "User not authenticated"
                    });
                }

                var chats = await _chatModel
                    .Find(c => c.PatientId == patientId && c.DoctorId == userId)
                    .SortByDescending(c => c.UpdatedAt)
                    .ToListAsync();

                var summaries = chats.Select(c => new ChatSummary
                {
                    Id = c.Id,
                    PatientId = c.PatientId,
                    Title = c.Title,
                    Date = c.Date,
                    UpdatedAt = c.UpdatedAt,
                    MessageCount = c.Chats.Count
                }).ToList();

                return Ok(new ChatListResponse
                {
                    Status = true,
                    Message = "Chats retrieved successfully",
                    Data = summaries
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ChatListResponse
                {
                    Status = false,
                    Message = ex.Message
                });
            }
        }

        // Get a specific chat by ID
        [HttpGet("{chatId}")]
        public async Task<ActionResult<ChatModelResponse>> GetChatById(string chatId)
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new ChatModelResponse
                    {
                        Status = false,
                        Message = "User not authenticated"
                    });
                }

                var chat = await _chatModel
                    .Find(c => c.Id == chatId && c.DoctorId == userId)
                    .FirstOrDefaultAsync();

                if (chat == null)
                {
                    return NotFound(new ChatModelResponse
                    {
                        Status = false,
                        Message = "Chat not found"
                    });
                }

                return Ok(new ChatModelResponse
                {
                    Status = true,
                    Message = "Chat found",
                    Data = chat
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ChatModelResponse
                {
                    Status = false,
                    Message = ex.Message
                });
            }
        }

        // Send a message to the AI agent and save the conversation
        [HttpPost("send")]
        public async Task<ActionResult<SendMessageResponse>> SendMessage([FromBody] SendMessageRequest request)
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new SendMessageResponse
                    {
                        Status = false,
                        Message = "User not authenticated"
                    });
                }

                // Access gate check
                var (doctor, denialResult) = await CheckAccessGateAsync(userId);
                if (denialResult != null) return denialResult;

                if (doctor == null)
                {
                    return NotFound(new SendMessageResponse
                    {
                        Status = false,
                        Message = "Doctor profile not found. Please complete your profile setup."
                    });
                }

                var specialty = doctor.Speciality;
                if (string.IsNullOrEmpty(specialty))
                {
                    return BadRequest(new SendMessageResponse
                    {
                        Status = false,
                        Message = "Doctor specialty not set. Please update your profile with your specialty."
                    });
                }

                // Check if specialty is supported
                if (!_aiAgentService.IsSpecialtySupported(specialty))
                {
                    return BadRequest(new SendMessageResponse
                    {
                        Status = false,
                        Message = $"No AI agent available for specialty: {specialty}. Supported specialties: {string.Join(", ", _aiAgentService.GetSupportedSpecialties())}"
                    });
                }

                ChatModel chat;
                bool isNewChat = string.IsNullOrEmpty(request.ChatId);

                if (isNewChat)
                {
                    // Create new chat
                    chat = new ChatModel
                    {
                        Id = ObjectId.GenerateNewId().ToString(),
                        PatientId = request.PatientId,
                        DoctorId = userId,
                        Specialty = specialty,
                        Title = GenerateChatTitle(request.Message),
                        Date = DateTime.Now,
                        UpdatedAt = DateTime.Now,
                        Chats = new List<Chat>()
                    };
                }
                else
                {
                    // Get existing chat
                    chat = await _chatModel
                        .Find(c => c.Id == request.ChatId && c.DoctorId == userId)
                        .FirstOrDefaultAsync();

                    if (chat == null)
                    {
                        return NotFound(new SendMessageResponse
                        {
                            Status = false,
                            Message = "Chat not found"
                        });
                    }
                }

                // Convert chat history for AI agent
                var conversationHistory = chat.Chats.Select(c => new Data.ChatMessage
                {
                    Query = c.Query,
                    Response = c.Response
                }).ToList();

                // Send message to AI agent
                var aiResponse = await _aiAgentService.SendMessageAsync(specialty, request.Message, conversationHistory);

                if (!aiResponse.Success)
                {
                    return BadRequest(new SendMessageResponse
                    {
                        Status = false,
                        Message = aiResponse.Error ?? "Failed to get response from AI agent"
                    });
                }

                // Add message to chat
                var newMessage = new Chat
                {
                    Query = request.Message,
                    Response = aiResponse.Message,
                    Timestamp = DateTime.Now
                };
                chat.Chats.Add(newMessage);
                chat.UpdatedAt = DateTime.Now;

                if (isNewChat)
                {
                    await _chatModel.InsertOneAsync(chat);
                }
                else
                {
                    var update = Builders<ChatModel>.Update
                        .Push(c => c.Chats, newMessage)
                        .Set(c => c.UpdatedAt, DateTime.Now);
                    await _chatModel.UpdateOneAsync(c => c.Id == chat.Id, update);
                }

                return Ok(new SendMessageResponse
                {
                    Status = true,
                    Message = "Message sent successfully",
                    ChatId = chat.Id,
                    AIResponse = aiResponse.Message,
                    Timestamp = newMessage.Timestamp
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new SendMessageResponse
                {
                    Status = false,
                    Message = $"Error: {ex.Message}"
                });
            }
        }

        // Create a new chat session with automatic patient context
        [HttpPost("create")]
        public async Task<ActionResult<ChatModelResponse>> CreateChat([FromBody] CreateChatRequest request)
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new ChatModelResponse
                    {
                        Status = false,
                        Message = "User not authenticated"
                    });
                }

                // Access gate check
                var (doctor, denialResult) = await CheckAccessGateAsync(userId);
                if (denialResult != null) return denialResult;

                var specialty = doctor?.Speciality ?? "";

                // Use date as title
                var chatTitle = DateTime.Now.ToString("MMMM dd, yyyy");

                var chat = new ChatModel
                {
                    Id = ObjectId.GenerateNewId().ToString(),
                    PatientId = request.PatientId,
                    DoctorId = userId,
                    Specialty = specialty,
                    Title = chatTitle,
                    Date = DateTime.Now,
                    UpdatedAt = DateTime.Now,
                    Chats = new List<Chat>()
                };

                // Build initial context message with patient info
                var hasContext = !string.IsNullOrWhiteSpace(request.InitialConditions) || !string.IsNullOrWhiteSpace(request.History);
                
                if (hasContext && _aiAgentService.IsSpecialtySupported(specialty))
                {
                    var contextParts = new List<string>();
                    contextParts.Add($"Patient Name: {request.PatientName}");
                    
                    if (!string.IsNullOrWhiteSpace(request.InitialConditions))
                    {
                        contextParts.Add($"Initial Symptoms/Conditions: {request.InitialConditions}");
                    }
                    if (!string.IsNullOrWhiteSpace(request.History))
                    {
                        contextParts.Add($"Medical History: {request.History}");
                    }
                    
                    var contextMessage = $"I am starting a consultation for a patient. Here is their information:\n\n{string.Join("\n", contextParts)}\n\nPlease acknowledge this patient information and let me know you're ready to assist with the consultation.";

                    // Send context to AI agent
                    var aiResponse = await _aiAgentService.SendMessageAsync(specialty, contextMessage, new List<Data.ChatMessage>());

                    if (aiResponse.Success)
                    {
                        chat.Chats.Add(new Chat
                        {
                            Query = contextMessage,
                            Response = aiResponse.Message,
                            Timestamp = DateTime.Now
                        });
                        chat.UpdatedAt = DateTime.Now;
                    }
                }

                await _chatModel.InsertOneAsync(chat);

                return Ok(new ChatModelResponse
                {
                    Status = true,
                    Message = "Chat created successfully",
                    Data = chat
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ChatModelResponse
                {
                    Status = false,
                    Message = ex.Message
                });
            }
        }

        // Delete a chat session
        [HttpDelete("{chatId}")]
        public async Task<ActionResult<ChatModelResponse>> DeleteChat(string chatId)
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new ChatModelResponse
                    {
                        Status = false,
                        Message = "User not authenticated"
                    });
                }

                var result = await _chatModel.DeleteOneAsync(c => c.Id == chatId && c.DoctorId == userId);

                if (result.DeletedCount == 0)
                {
                    return NotFound(new ChatModelResponse
                    {
                        Status = false,
                        Message = "Chat not found or you don't have permission to delete it"
                    });
                }

                return Ok(new ChatModelResponse
                {
                    Status = true,
                    Message = "Chat deleted successfully"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ChatModelResponse
                {
                    Status = false,
                    Message = ex.Message
                });
            }
        }

        // Get the doctor's assigned AI agent info
        [HttpGet("agent-info")]
        public async Task<ActionResult<object>> GetAgentInfo()
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized(new { Status = false, Message = "User not authenticated" });
                }

                // Access gate check
                var (doctor, denialResult) = await CheckAccessGateAsync(userId);
                if (denialResult != null) return denialResult;

                if (doctor == null)
                {
                    return NotFound(new { Status = false, Message = "Doctor profile not found" });
                }

                var specialty = doctor.Speciality;
                var isSupported = _aiAgentService.IsSpecialtySupported(specialty);

                return Ok(new
                {
                    Status = true,
                    Specialty = specialty,
                    IsAgentAvailable = isSupported,
                    SupportedSpecialties = _aiAgentService.GetSupportedSpecialties(),
                    Message = isSupported 
                        ? $"AI agent for {specialty} is available" 
                        : $"No AI agent available for {specialty}"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Status = false, Message = ex.Message });
            }
        }

        private string GenerateChatTitle(string firstMessage)
        {
            // Use the date as the chat title
            return DateTime.Now.ToString("MMMM dd, yyyy");
        }
    }
}