using first_api.Data;
using first_api.Entities;
using first_api.Entities.AuthModel;
using first_api.Entities.StripeModel;
using first_api.Hubs;
using first_api.Middleware;
using first_api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;

System.Net.ServicePointManager.Expect100Continue = false;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Your API", Version = "v1" });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: 'Authorization: Bearer {token}'",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            new string[] {}
        }
    });
});

builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("JwtSettings"));

builder.Services.AddHttpClient<SpeechNotesService>(client =>
{
    client.Timeout = TimeSpan.FromMinutes(5); 
});

var jwtSettings = builder.Configuration.GetSection("JwtSettings").Get<JwtSettings>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings?.Issuer,
            ValidAudience = jwtSettings?.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.ASCII.GetBytes(jwtSettings?.SecretKey ?? string.Empty)
            )
        };
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                if (string.IsNullOrEmpty(context.Token)
                    && context.Request.Cookies.TryGetValue("hv_access", out var cookieToken)
                    && !string.IsNullOrWhiteSpace(cookieToken))
                {
                    context.Token = cookieToken;
                }

                return Task.CompletedTask;
            }
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
    
    // SignalR policy with credentials (for specific origins)
    options.AddPolicy("SignalRPolicy", policy =>
    {
        policy.WithOrigins("http://localhost:5166", "https://localhost:5166", "http://localhost:5257", "http://localhost:52330", "http://localhost:49850")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddSingleton<MongodbService>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddHttpClient();
builder.Services.AddScoped<AIAgentService>();
builder.Services.AddScoped<GeminiService>();
builder.Services
    .AddFluentEmail(builder.Configuration["Email:SenderEmail"], builder.Configuration["Email:Sender"])
    .AddSmtpSender(new System.Net.Mail.SmtpClient
    {
        Host = builder.Configuration["Email:Host"] ?? "localhost",
        Port = int.Parse(builder.Configuration["Email:Port"] ?? "587"),
        Credentials = new System.Net.NetworkCredential(
            builder.Configuration["Email:Username"],
            builder.Configuration["Email:Password"]
        ),
        EnableSsl = true
    });

builder.Services.Configure<CloudinarySettings>(builder.Configuration.GetSection("CloudinarySettings"));
builder.Services.AddScoped<CloudinaryService>();

// Add Stripe settings and service
builder.Services.Configure<StripeSettings>(builder.Configuration.GetSection("Stripe"));
builder.Services.AddScoped<StripeService>();

// Add PMDC Verification Service
builder.Services.AddHttpClient<PmdcVerificationService>();

// Add Doctor Agent Assignment Service
builder.Services.AddScoped<first_api.Services.DoctorAgentAssignmentService>();

// Add SignalR
builder.Services.AddSignalR();

// Notification services
builder.Services.AddSingleton<first_api.Services.NotificationService>();
builder.Services.AddHostedService<first_api.Services.NotificationScheduler>();
builder.Services.AddHostedService<first_api.Services.AppointmentConfirmationService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.UseMiddleware<RequestLoggingMiddleware>();

app.MapControllers();

app.MapHub<AppointmentHub>("/hubs/appointment");

using (var scope = app.Services.CreateScope())
{
    var assignmentService = scope.ServiceProvider.GetRequiredService<first_api.Services.DoctorAgentAssignmentService>();
    await assignmentService.EnsureIndexesAsync();
}

await app.RunAsync();