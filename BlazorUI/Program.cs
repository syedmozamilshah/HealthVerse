using BlazorUI.Authentication;
using BlazorUI.Components;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddAuthentication();
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddScoped<ApiClient>();
builder.Services.AddScoped<BlazorUI.Services.AppointmentHubClient>();
builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
builder.Services.AddHttpContextAccessor();

// Configure SignalR to accept larger messages for file uploads
builder.Services.AddSignalR(options =>
{
    options.MaximumReceiveMessageSize = 10 * 1024 * 1024; // 10MB
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(60);
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
});

builder.Services.AddHttpClient("API", client =>
{
    var apiBaseUrl = builder.Configuration["ApiSettings:BaseUrl"]
        ?? "https://fyp-apis-bhe7cjbscyehccff.centralindia-01.azurewebsites.net";

    client.BaseAddress = new Uri(apiBaseUrl.TrimEnd('/') + "/");
});

builder.Services.AddHttpClient();
builder.Services.AddScoped<ProtectedSessionStorage>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}


app.UseStaticFiles();
app.UseAntiforgery();

app.UseAuthentication();
app.UseAuthorization();

app.MapPost("/auth/doctor-cookie", (HttpContext context, DoctorCookieRequest request) =>
{
    var accessOptions = BuildDoctorCookieOptions(context, request.TokenExpires);
    var refreshOptions = BuildDoctorCookieOptions(context, request.RefreshExpires);

    if (!string.IsNullOrWhiteSpace(request.Token))
    {
        context.Response.Cookies.Append("hv_access", request.Token, accessOptions);
    }

    if (!string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        context.Response.Cookies.Append("hv_refresh", request.RefreshToken, refreshOptions);
    }

    return Results.Ok();
});

app.MapPost("/auth/doctor-cookie/clear", (HttpContext context) =>
{
    var options = BuildDoctorCookieOptions(context, null);
    context.Response.Cookies.Delete("hv_access", options);
    context.Response.Cookies.Delete("hv_refresh", options);
    return Results.Ok();
});


app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();

static CookieOptions BuildDoctorCookieOptions(HttpContext context, long? unixExpires)
{
    var options = new CookieOptions
    {
        HttpOnly = true,
        Secure = context.Request.IsHttps,
        SameSite = SameSiteMode.Lax,
        Path = "/"
    };

    if (unixExpires.HasValue)
    {
        options.Expires = DateTimeOffset.FromUnixTimeSeconds(unixExpires.Value);
    }

    return options;
}

record DoctorCookieRequest(string Token, string RefreshToken, long? TokenExpires, long? RefreshExpires);
