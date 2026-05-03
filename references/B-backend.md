# Section B — Backend Service Skills

## Table of Contents
1. [Building ASP.NET Core Web APIs](#1-building-aspnet-core-web-apis)
2. [JSON Serialization — System.Text.Json](#2-json-serialization--systemtextjson)
3. [JWT Authentication](#3-jwt-authentication)
4. [Cookie Authentication](#4-cookie-authentication)
5. [ASP.NET Core Identity](#5-aspnet-core-identity)
6. [CORS Configuration](#6-cors-configuration)
7. [API Security Best Practices (OWASP)](#7-api-security-best-practices-owasp)
8. [Cloud-Ready API Design](#8-cloud-ready-api-design)

---

## 1. Building ASP.NET Core Web APIs

### Project Setup

```bash
# Create Web API project
dotnet new webapi -n MyApp.Api --use-controllers
# Or Minimal API
dotnet new webapi -n MyApp.Api

# Add packages
dotnet add package Pomelo.EntityFrameworkCore.MySql
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Swashbuckle.AspNetCore
dotnet add package Serilog.AspNetCore
dotnet add package FluentValidation.AspNetCore
```

### Response Envelope Pattern

```csharp
// Standard API response wrapper
public class ApiResponse<T>
{
    public bool   Success    { get; init; }
    public T?     Data       { get; init; }
    public string? Message   { get; init; }
    public IReadOnlyList<string> Errors { get; init; } = [];

    public static ApiResponse<T> Ok(T data, string? msg = null)
        => new() { Success = true, Data = data, Message = msg };

    public static ApiResponse<T> Fail(params string[] errors)
        => new() { Success = false, Errors = errors };
}

// Usage in controller
return Ok(ApiResponse<ProductDto>.Ok(product, "Product retrieved."));
return BadRequest(ApiResponse<ProductDto>.Fail("Price must be positive."));
```

### Paginated Result

```csharp
public record PagedResult<T>(
    IReadOnlyList<T> Items,
    int TotalCount,
    int Page,
    int PageSize)
{
    public int  TotalPages      => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasNextPage     => Page < TotalPages;
    public bool HasPreviousPage => Page > 1;

    public static PagedResult<T> Create(IReadOnlyList<T> items, int total, int page, int size)
        => new(items, total, page, size);
}
```

### REST Endpoint — Full CRUD Example

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion(1)]
[Produces("application/json")]
[Authorize]
public class ProductsController : ControllerBase
{
    private readonly IProductService _svc;
    private readonly ILogger<ProductsController> _log;

    public ProductsController(IProductService svc, ILogger<ProductsController> log)
        => (_svc, _log) = (svc, log);

    /// <summary>Returns paginated products, with optional search and category filter.</summary>
    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType(typeof(PagedResult<ProductDto>), 200)]
    public async Task<ActionResult<PagedResult<ProductDto>>> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int size = 20,
        [FromQuery] string? search = null,
        [FromQuery] int? categoryId = null,
        CancellationToken ct = default)
    {
        var result = await _svc.GetPagedAsync(page, size, search, categoryId, ct);
        return Ok(result);
    }

    /// <summary>Returns a single product by its ID.</summary>
    [HttpGet("{id:int}")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(ProductDto), 200)]
    [ProducesResponseType(typeof(ProblemDetails), 404)]
    public async Task<ActionResult<ProductDto>> GetById(int id, CancellationToken ct)
    {
        var product = await _svc.GetByIdAsync(id, ct);
        return product is null ? NotFound() : Ok(product);
    }

    /// <summary>Creates a new product.</summary>
    [HttpPost]
    [Authorize(Roles = "Admin,Manager")]
    [ProducesResponseType(typeof(ProductDto), 201)]
    [ProducesResponseType(typeof(ValidationProblemDetails), 400)]
    public async Task<ActionResult<ProductDto>> Create(
        [FromBody] CreateProductRequest req, CancellationToken ct)
    {
        var product = await _svc.CreateAsync(req, ct);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }

    /// <summary>Fully replaces an existing product.</summary>
    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Manager")]
    [ProducesResponseType(typeof(ProductDto), 200)]
    [ProducesResponseType(404)]
    public async Task<ActionResult<ProductDto>> Update(
        int id, [FromBody] UpdateProductRequest req, CancellationToken ct)
    {
        var updated = await _svc.UpdateAsync(id, req, ct);
        return updated is null ? NotFound() : Ok(updated);
    }

    /// <summary>Partially updates an existing product.</summary>
    [HttpPatch("{id:int}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<ActionResult<ProductDto>> Patch(
        int id, [FromBody] JsonPatchDocument<UpdateProductRequest> patch, CancellationToken ct)
    {
        var req = await _svc.GetForPatchAsync(id, ct);
        if (req is null) return NotFound();
        patch.ApplyTo(req, ModelState);
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var updated = await _svc.ApplyPatchAsync(id, req, ct);
        return Ok(updated);
    }

    /// <summary>Soft-deletes a product.</summary>
    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(204)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
        => await _svc.DeleteAsync(id, ct) ? NoContent() : NotFound();
}
```

---

## 2. JSON Serialization — System.Text.Json

### Global Configuration (Program.cs)

```csharp
builder.Services.AddControllers()
    .AddJsonOptions(opt =>
    {
        // camelCase property names (default in Core)
        opt.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;

        // Read case-insensitive
        opt.JsonSerializerOptions.PropertyNameCaseInsensitive = true;

        // Serialize enums as strings
        opt.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());

        // Ignore null values in output
        opt.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;

        // Indent in development
        opt.JsonSerializerOptions.WriteIndented = builder.Environment.IsDevelopment();

        // Handle reference cycles
        opt.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    });
```

### Source Generation (performance-critical services)

```csharp
[JsonSerializable(typeof(ProductDto))]
[JsonSerializable(typeof(IReadOnlyList<ProductDto>))]
[JsonSerializable(typeof(PagedResult<ProductDto>))]
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
public partial class AppJsonContext : JsonSerializerContext { }

// Register
builder.Services.ConfigureHttpJsonOptions(opt =>
    opt.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonContext.Default));
```

### Custom Converter

```csharp
public class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions opt)
        => DateTime.SpecifyKind(reader.GetDateTime(), DateTimeKind.Utc);

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions opt)
        => writer.WriteStringValue(value.ToUniversalTime().ToString("O"));
}
```

---

## 3. JWT Authentication

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

### Configuration (appsettings.json)

```json
{
  "Jwt": {
    "Issuer":          "https://myapp.com",
    "Audience":        "https://myapp.com",
    "Key":             "USE_USER_SECRETS_OR_ENV_VAR",
    "AccessTokenMins": 60,
    "RefreshTokenDays": 30
  }
}
```

### Program.cs

```csharp
var jwt = builder.Configuration.GetSection("Jwt");
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = jwt["Issuer"],
            ValidAudience            = jwt["Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(
                                          Encoding.UTF8.GetBytes(jwt["Key"]!)),
            ClockSkew                = TimeSpan.Zero   // No tolerance on expiry
        };

        // SignalR / Minimal API WebSocket support
        opt.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });
```

### Token Service

```csharp
public interface IJwtTokenService
{
    string GenerateAccessToken(ApplicationUser user, IList<string> roles);
    string GenerateRefreshToken();
    ClaimsPrincipal? ValidateExpiredToken(string token);
}

public class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _settings;

    public JwtTokenService(IOptions<JwtSettings> opts) => _settings = opts.Value;

    public string GenerateAccessToken(ApplicationUser user, IList<string> roles)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub,   user.Id),
            new(JwtRegisteredClaimNames.Email, user.Email!),
            new(JwtRegisteredClaimNames.Jti,   Guid.NewGuid().ToString()),
            new(ClaimTypes.Name,               user.FullName ?? user.Email!)
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer:             _settings.Issuer,
            audience:           _settings.Audience,
            claims:             claims,
            notBefore:          DateTime.UtcNow,
            expires:            DateTime.UtcNow.AddMinutes(_settings.AccessTokenMins),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateRefreshToken()
        => Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

    public ClaimsPrincipal? ValidateExpiredToken(string token)
    {
        var handler = new JwtSecurityTokenHandler();
        var key     = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Key));

        try
        {
            return handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey         = key,
                ValidateIssuer           = false,
                ValidateAudience         = false,
                ValidateLifetime         = false   // Allow expired tokens for refresh
            }, out _);
        }
        catch { return null; }
    }
}
```

### Auth Controller Endpoints

```csharp
[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    [HttpPost("login")]
    public async Task<ActionResult<TokenResponse>> Login(
        [FromBody] LoginRequest req, CancellationToken ct)
    {
        var user = await _userManager.FindByEmailAsync(req.Email);
        if (user is null || !await _userManager.CheckPasswordAsync(user, req.Password))
            return Unauthorized(new { message = "Invalid credentials." });

        var roles        = await _userManager.GetRolesAsync(user);
        var accessToken  = _tokenSvc.GenerateAccessToken(user, roles);
        var refreshToken = _tokenSvc.GenerateRefreshToken();

        await _userManager.SetAuthenticationTokenAsync(user, "JWT", "RefreshToken", refreshToken);

        return Ok(new TokenResponse(accessToken, refreshToken,
            DateTime.UtcNow.AddMinutes(_settings.AccessTokenMins)));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<TokenResponse>> Refresh([FromBody] RefreshRequest req)
    {
        var principal = _tokenSvc.ValidateExpiredToken(req.AccessToken);
        if (principal is null) return BadRequest("Invalid access token.");

        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)!;
        var user   = await _userManager.FindByIdAsync(userId);
        var stored = await _userManager.GetAuthenticationTokenAsync(user!, "JWT", "RefreshToken");

        if (stored != req.RefreshToken) return Unauthorized("Invalid refresh token.");

        var roles       = await _userManager.GetRolesAsync(user!);
        var newAccess   = _tokenSvc.GenerateAccessToken(user!, roles);
        var newRefresh  = _tokenSvc.GenerateRefreshToken();

        await _userManager.SetAuthenticationTokenAsync(user!, "JWT", "RefreshToken", newRefresh);

        return Ok(new TokenResponse(newAccess, newRefresh,
            DateTime.UtcNow.AddMinutes(_settings.AccessTokenMins)));
    }

    [HttpPost("logout"), Authorize]
    public async Task<IActionResult> Logout()
    {
        var userId = User.FindFirstValue(JwtRegisteredClaimNames.Sub)!;
        var user   = await _userManager.FindByIdAsync(userId);
        await _userManager.RemoveAuthenticationTokenAsync(user!, "JWT", "RefreshToken");
        return NoContent();
    }
}
```

---

## 4. Cookie Authentication

```csharp
// Program.cs
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opt =>
    {
        opt.LoginPath          = "/Account/Login";
        opt.LogoutPath         = "/Account/Logout";
        opt.AccessDeniedPath   = "/Account/AccessDenied";
        opt.ExpireTimeSpan     = TimeSpan.FromDays(14);
        opt.SlidingExpiration  = true;
        opt.Cookie.HttpOnly    = true;
        opt.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        opt.Cookie.SameSite    = SameSiteMode.Strict;
        opt.Cookie.Name        = "__myapp_auth";
    });
```

---

## 5. ASP.NET Core Identity

```csharp
// ApplicationUser.cs
public class ApplicationUser : IdentityUser
{
    public string?   FullName  { get; set; }
    public DateTime  CreatedAt { get; set; } = DateTime.UtcNow;
    public bool      IsActive  { get; set; } = true;
}

// Program.cs
builder.Services
    .AddIdentity<ApplicationUser, IdentityRole>(opt =>
    {
        opt.Password.RequiredLength          = 8;
        opt.Password.RequireDigit            = true;
        opt.Password.RequireUppercase        = true;
        opt.Password.RequireNonAlphanumeric  = false;
        opt.Lockout.MaxFailedAccessAttempts  = 5;
        opt.Lockout.DefaultLockoutTimeSpan   = TimeSpan.FromMinutes(15);
        opt.User.RequireUniqueEmail          = true;
        opt.SignIn.RequireConfirmedEmail     = true;
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();
```

---

## 6. CORS Configuration

```csharp
builder.Services.AddCors(opt =>
{
    opt.AddPolicy("ProductionPolicy", policy =>
        policy.WithOrigins("https://myapp.com", "https://www.myapp.com")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials()
              .WithExposedHeaders("X-Pagination", "X-Request-Id"));

    opt.AddPolicy("DevelopmentPolicy", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

app.UseCors(app.Environment.IsDevelopment() ? "DevelopmentPolicy" : "ProductionPolicy");
```

---

## 7. API Security Best Practices (OWASP)

### OWASP API Security Top 10 — ASP.NET Core Mitigations

| Risk | Mitigation |
|---|---|
| Broken Object Level Authorization | Verify `userId == resource.OwnerId` in every service method |
| Broken Authentication | JWT with short expiry + refresh token rotation; rate limit auth endpoints |
| Broken Object Property Level Auth | Never expose domain entities directly; use strict DTOs |
| Unrestricted Resource Consumption | Rate limiting + `[RequestSizeLimit]` + pagination |
| Broken Function Level Authorization | `[Authorize(Roles = "Admin")]` per endpoint; avoid relying on URL obscurity |
| Unrestricted Access to Sensitive Business Flows | CAPTCHA / OTP for sensitive flows; anomaly detection |
| SSRF | Validate and allowlist URLs before server-side HTTP calls |
| Security Misconfiguration | HSTS, security headers, disable server version headers |
| Improper Inventory Management | API versioning; deprecate/remove old versions |
| Unsafe Consumption of APIs | Validate and sanitize all third-party API responses |

### Security Headers Middleware

```csharp
app.Use(async (ctx, next) =>
{
    var h = ctx.Response.Headers;
    h.Append("X-Content-Type-Options",   "nosniff");
    h.Append("X-Frame-Options",          "DENY");
    h.Append("X-XSS-Protection",         "1; mode=block");
    h.Append("Referrer-Policy",          "strict-origin-when-cross-origin");
    h.Append("Permissions-Policy",       "camera=(), microphone=(), geolocation=()");
    h.Remove("Server");
    h.Remove("X-Powered-By");
    await next();
});
```

### Rate Limiting (.NET 7+)

```csharp
builder.Services.AddRateLimiter(opt =>
{
    // Global sliding window — 100 requests per minute per IP
    opt.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetSlidingWindowLimiter(
            ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit       = 100,
                Window            = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 6,
                AutoReplenishment = true
            }));

    // Strict limit for auth endpoints
    opt.AddPolicy("AuthPolicy", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new FixedWindowRateLimiterOptions
                { PermitLimit = 5, Window = TimeSpan.FromMinutes(1) }));

    opt.OnRejected = async (context, ct) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        await context.HttpContext.Response.WriteAsJsonAsync(
            new ProblemDetails { Status = 429, Title = "Too Many Requests" }, ct);
    };
});
```

---

## 8. Cloud-Ready API Design

### Health Checks

```csharp
builder.Services.AddHealthChecks()
    .AddMySql(connStr, name: "mysql",         tags: ["db", "ready"])
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"]);

app.MapHealthChecks("/health/live",  new() { Predicate = h => h.Tags.Contains("live") });
app.MapHealthChecks("/health/ready", new() { Predicate = h => h.Tags.Contains("ready") });
```

### Graceful Shutdown

```csharp
// Program.cs
builder.Services.Configure<HostOptions>(opt =>
{
    opt.ShutdownTimeout = TimeSpan.FromSeconds(30);
});
```

### Structured Observability

```csharp
// OpenTelemetry (for Azure Monitor / Datadog / Jaeger)
builder.Services.AddOpenTelemetry()
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation())
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation());
```