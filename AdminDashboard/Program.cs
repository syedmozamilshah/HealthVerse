using AdminDashboard.Components;
using AdminDashboard.Services;
using AdminDashboard.Models;
using Microsoft.JSInterop;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddBlazorBootstrap();
builder.Services.AddHttpClient();
builder.Services.AddHttpContextAccessor();

// Register AuthService as Singleton - maintains auth state across circuits
builder.Services.AddSingleton<AuthService>();
builder.Services.AddScoped<ApiService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// Cookie management endpoints for admin session
app.MapPost("/auth/admin-cookie", (HttpContext context, AdminCookieRequest request) =>
{
    var accessOptions = BuildAdminCookieOptions(context, request.TokenExpires);
    var refreshOptions = BuildAdminCookieOptions(context, request.RefreshExpires);

    if (!string.IsNullOrWhiteSpace(request.Token))
    {
        context.Response.Cookies.Append("admin_access", request.Token, accessOptions);
    }

    if (!string.IsNullOrWhiteSpace(request.RefreshToken))
    {
        context.Response.Cookies.Append("admin_refresh", request.RefreshToken, refreshOptions);
    }

    return Results.Ok();
});

app.MapPost("/auth/admin-cookie/clear", (HttpContext context) =>
{
    var options = BuildAdminCookieOptions(context, null);
    context.Response.Cookies.Delete("admin_access", options);
    context.Response.Cookies.Delete("admin_refresh", options);
    return Results.Ok();
});

static CookieOptions BuildAdminCookieOptions(HttpContext context, long? unixExpires)
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

app.Run();
