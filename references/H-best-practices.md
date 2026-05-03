# Section H — Best Practices

## Table of Contents
1. [C# Coding Standards](#1-c-coding-standards)
2. [Structured Logging — Serilog](#2-structured-logging--serilog)
3. [Built-In Logging (ILogger)](#3-built-in-logging-ilogger)
4. [Error Handling & Exception Middleware](#4-error-handling--exception-middleware)
5. [Performance Optimization](#5-performance-optimization)
6. [Security Hardening](#6-security-hardening)
7. [Testing Standards](#7-testing-standards)
8. [Code Review Checklist (Master)](#8-code-review-checklist-master)
9. [Accessibility (WCAG 2.1 AA)](#9-accessibility-wcag-21-aa)

---

## 1. C# Coding Standards

### Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Classes, records, interfaces | PascalCase | `ProductService`, `IRepository` |
| Methods, properties | PascalCase | `GetByIdAsync`, `TotalPrice` |
| Private fields | `_camelCase` | `_productService`, `_logger` |
| Parameters, locals | camelCase | `productId`, `cancellationToken` |
| Constants | PascalCase | `MaxRetryCount`, `DefaultPageSize` |
| Interfaces | `I` prefix | `IProductRepository` |
| Async methods | `Async` suffix | `CreateProductAsync` |
| Generic type params | Descriptive | `TEntity`, `TResult`, `TKey` |
| Enums | PascalCase (singular type, plural not) | `OrderStatus.Pending` |

### File & Namespace Conventions

```csharp
// ✅ One public type per file — filename matches type name
// ✅ File-scoped namespaces (C# 10+) — reduces indentation
namespace MyApp.Application.Services;

public class ProductService : IProductService { }

// ✅ Global usings in GlobalUsings.cs (project root)
global using System;
global using System.Collections.Generic;
global using System.Linq;
global using System.Threading;
global using System.Threading.Tasks;
global using Microsoft.Extensions.Logging;
global using MyApp.Domain.Entities;
global using MyApp.Domain.Exceptions;
```

### Modern C# Feature Usage

```csharp
// ✅ Records for immutable DTOs and value objects
public record ProductDto(int Id, string Name, decimal Price, string CategoryName);
public record CreateProductRequest([Required] string Name, [Range(0.01, 99999)] decimal Price, int CategoryId);

// ✅ Primary constructors (C# 12) for services with single dependency groups
public class ProductService(IProductRepository repo, IUnitOfWork uow, ILogger<ProductService> log)
    : IProductService
{
    // repo, uow, log available as fields
}

// ✅ Pattern matching — expressive and null-safe
var result = entity switch
{
    { IsDeleted: true }   => "deleted",
    { Stock: 0 }          => "out-of-stock",
    { Price: > 1000 }     => "premium",
    _                     => "standard"
};

// ✅ Null coalescing assignment
_cache ??= new ConcurrentDictionary<int, Product>();

// ✅ Raw string literals for SQL / JSON (C# 11) — no escape noise
const string sql = """
    SELECT p.id, p.name, c.name AS category_name
    FROM products p
    INNER JOIN categories c ON c.id = p.category_id
    WHERE p.is_deleted = 0
      AND p.category_id = @CategoryId
    ORDER BY p.name;
    """;

// ✅ Collection expressions (C# 12)
string[] allowedRoles = ["Admin", "Manager"];
List<int> ids = [1, 2, 3, 4, 5];
int[] merged = [..ids, 6, 7, 8];

// ✅ Required members (C# 11)
public class OrderDto
{
    public required int    Id      { get; init; }
    public required string Status  { get; init; }
    public required decimal Total  { get; init; }
}

// ✅ Target-typed new
Dictionary<string, List<Product>> map = new();
var options = new JsonSerializerOptions { WriteIndented = true };
```

### Async/Await Standards

```csharp
// ❌ Deadlock risk — blocks thread while awaiting
var product = _repo.GetByIdAsync(id).Result;
_repo.SaveChangesAsync().Wait();

// ✅ Correct — fully async
var product = await _repo.GetByIdAsync(id);
await _uow.SaveChangesAsync();

// ❌ async void — exceptions are unobserved (fire-and-forget anti-pattern)
public async void LoadData() { await _svc.LoadAsync(); }

// ✅ async Task — exceptions propagate correctly
public async Task LoadData() { await _svc.LoadAsync(); }

// ✅ Thread-pool parallelism for independent async operations
var productsTask   = _repo.GetAllAsync(ct);
var categoriesTask = _catRepo.GetAllAsync(ct);
await Task.WhenAll(productsTask, categoriesTask);
var products   = await productsTask;
var categories = await categoriesTask;

// ✅ CancellationToken in ALL async public APIs
public async Task<ProductDto> GetByIdAsync(int id, CancellationToken ct = default)
    => await _repo.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Product {id} not found.");

// ✅ ConfigureAwait(false) in library/infrastructure code (not in MVC controllers)
var response = await _httpClient.GetStringAsync(url).ConfigureAwait(false);

// ✅ ValueTask for hot paths that frequently complete synchronously (cache hits)
public ValueTask<Product?> GetCachedAsync(int id)
{
    return _cache.TryGetValue(id, out var p)
        ? new ValueTask<Product?>(p)
        : new ValueTask<Product?>(LoadFromDbAsync(id));
}
```

---

## 2. Structured Logging — Serilog

Serilog emits structured events (key-value pairs) that integrate with log aggregation
platforms (Seq, Elastic, Datadog, Azure Monitor, Loki).

```bash
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Enrichers.Environment
dotnet add package Serilog.Enrichers.Thread
dotnet add package Serilog.Sinks.Console
dotnet add package Serilog.Sinks.File
dotnet add package Serilog.Sinks.Seq           # Optional: structured log UI
dotnet add package Serilog.Formatting.Compact  # JSON output for log aggregators
```

### Program.cs Configuration

```csharp
// Bootstrap logger catches startup errors before full config loads
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((ctx, services, cfg) => cfg
        .ReadFrom.Configuration(ctx.Configuration)  // appsettings.json overrides
        .ReadFrom.Services(services)                // DI-injected enrichers
        .Enrich.FromLogContext()
        .Enrich.WithMachineName()
        .Enrich.WithThreadId()
        .Enrich.WithProperty("Application", "MyApp")
        .Enrich.WithProperty("Environment", ctx.HostingEnvironment.EnvironmentName)
        .WriteTo.Console(
            formatter: ctx.HostingEnvironment.IsDevelopment()
                ? new ExpressionTemplate("[{@t:HH:mm:ss} {@l:u3}] ({SourceContext}) {@m}\n{@x}")
                : new CompactJsonFormatter())
        .WriteTo.File(
            formatter: new CompactJsonFormatter(),
            path: "logs/myapp-.log",
            rollingInterval: RollingInterval.Day,
            retainedFileCountLimit: 30,
            fileSizeLimitBytes: 100 * 1024 * 1024)
        .WriteTo.Seq(ctx.Configuration["Seq:Url"] ?? "http://localhost:5341",
            apiKey: ctx.Configuration["Seq:ApiKey"])
    );

    // ... services, middleware, app.Run()
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application startup failed.");
}
finally
{
    await Log.CloseAndFlushAsync();
}
```

### appsettings.json Serilog section

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft":                       "Warning",
        "Microsoft.AspNetCore":            "Warning",
        "Microsoft.EntityFrameworkCore":   "Warning",
        "System":                          "Warning"
      }
    }
  }
}
```

### Logging in Services — Best Practices

```csharp
public class ProductService : IProductService
{
    private readonly IProductRepository _repo;
    private readonly ILogger<ProductService> _log;

    public ProductService(IProductRepository repo, ILogger<ProductService> log)
        => (_repo, _log) = (repo, log);

    // ✅ Structured logging — properties are indexed and searchable
    // ❌ Never use string interpolation in log calls
    public async Task<ProductDto> CreateAsync(CreateProductRequest req, CancellationToken ct)
    {
        // ❌ Anti-pattern: loses structured data
        _log.LogInformation($"Creating product {req.Name} at price {req.Price}");

        // ✅ Correct: Name and Price are captured as structured fields
        _log.LogInformation("Creating product {ProductName} at price {Price:C}",
            req.Name, req.Price);

        var product = Product.Create(req.Name, req.Price, req.CategoryId);
        await _repo.AddAsync(product, ct);
        await _uow.SaveChangesAsync(ct);

        _log.LogInformation("Product {ProductId} created successfully", product.Id);
        return ProductDto.FromEntity(product);
    }

    // ✅ Use LoggerMessage.Define for high-frequency hot-path logging (zero allocations)
    private static readonly Action<ILogger, int, string, Exception?> ProductCreated =
        LoggerMessage.Define<int, string>(
            LogLevel.Information,
            new EventId(1001, nameof(ProductCreated)),
            "Product {ProductId} ({ProductName}) created.");

    // ✅ Log levels used correctly
    // Debug   — verbose dev-only diagnostics (SQL params, loop iterations)
    // Info    — normal business events (order placed, user registered)
    // Warning — recoverable issues (retry attempt, cache miss, deprecated call)
    // Error   — operation failed but app continues (payment rejected, file not found)
    // Fatal/Critical — app cannot continue (DB down, out of memory)
}
```

---

## 3. Built-In Logging (ILogger)

When Serilog is unavailable, the built-in `ILogger<T>` provider suffices.

```csharp
// appsettings.json
{
  "Logging": {
    "LogLevel": {
      "Default":                         "Information",
      "Microsoft.AspNetCore":            "Warning",
      "Microsoft.EntityFrameworkCore":   "Warning"
    },
    "Console": { "FormatterName": "json" }
  }
}

// Program.cs
builder.Logging
    .ClearProviders()
    .AddConsole(opt => opt.FormatterName = "json")
    .AddDebug()
    .SetMinimumLevel(LogLevel.Information);
```

---

## 4. Error Handling & Exception Middleware

### Domain Exception Hierarchy

```csharp
// All domain errors inherit from DomainException
public abstract class DomainException   : Exception { protected DomainException(string msg) : base(msg) { } }
public class NotFoundException          : DomainException { public NotFoundException(string msg) : base(msg) { } }
public class ValidationException        : DomainException { public ValidationException(string msg) : base(msg) { } }
public class ConflictException          : DomainException { public ConflictException(string msg) : base(msg) { } }
public class ForbiddenException         : DomainException { public ForbiddenException(string msg) : base(msg) { } }
public class UnauthorizedException      : DomainException { public UnauthorizedException(string msg) : base(msg) { } }

// Usage in services
var product = await _repo.GetByIdAsync(id, ct)
    ?? throw new NotFoundException($"Product {id} was not found.");

if (existing is not null)
    throw new ConflictException($"A product with name '{req.Name}' already exists.");
```

### Global Exception Handling Middleware

```csharp
// Infrastructure/Middleware/ExceptionHandlingMiddleware.cs
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _log;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> log)
        => (_next, _log) = (next, log);

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(ctx, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext ctx, Exception ex)
    {
        var (status, title) = ex switch
        {
            NotFoundException     => (404, "Not Found"),
            ValidationException   => (400, "Validation Error"),
            ConflictException     => (409, "Conflict"),
            UnauthorizedException => (401, "Unauthorized"),
            ForbiddenException    => (403, "Forbidden"),
            _                     => (500, "Internal Server Error")
        };

        if (status == 500)
            _log.LogError(ex, "Unhandled exception processing {Method} {Path}",
                ctx.Request.Method, ctx.Request.Path);
        else
            _log.LogWarning(ex, "Domain exception: {ExceptionType}", ex.GetType().Name);

        var problem = new ProblemDetails
        {
            Status   = status,
            Title    = title,
            Detail   = status < 500 ? ex.Message : "An unexpected error occurred.",
            Instance = ctx.Request.Path,
            Extensions = { ["traceId"] = ctx.TraceIdentifier }
        };

        ctx.Response.StatusCode  = status;
        ctx.Response.ContentType = "application/problem+json";
        await ctx.Response.WriteAsJsonAsync(problem);
    }
}

// Extension
public static IApplicationBuilder UseExceptionHandling(this IApplicationBuilder app)
    => app.UseMiddleware<ExceptionHandlingMiddleware>();

// Program.cs — MUST be first in pipeline
app.UseExceptionHandling();
```

### MVC View Error Handling

```csharp
// HomeController.cs
[AllowAnonymous]
public IActionResult Error()
{
    var feature = HttpContext.Features.Get<IExceptionHandlerPathFeature>();
    var model   = new ErrorViewModel
    {
        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
        StatusCode = HttpContext.Response.StatusCode,
        Message   = HttpContext.Response.StatusCode == 404
            ? "The page you requested was not found."
            : "An unexpected error occurred."
    };
    return View(model);
}

// Program.cs
app.UseStatusCodePagesWithReExecute("/Home/Error/{0}");
app.UseExceptionHandler("/Home/Error");
```

---

## 5. Performance Optimization

### EF Core Performance

```csharp
// ✅ AsNoTracking for all read-only queries
var products = await _ctx.Products.AsNoTracking().ToListAsync(ct);

// ✅ Select only required columns
var names = await _ctx.Products
    .Select(p => new { p.Id, p.Name })
    .ToListAsync(ct);

// ✅ Compiled queries for hot paths (evaluated once, reused)
private static readonly Func<AppDbContext, int, Task<Product?>> GetByIdQuery =
    EF.CompileAsyncQuery((AppDbContext db, int id)
        => db.Products.AsNoTracking().FirstOrDefault(p => p.Id == id));

// ✅ Batch operations (EF 7+ — no N+1 round-trips)
await _ctx.Products
    .Where(p => p.CategoryId == obsoleteId)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.IsDeleted, true), ct);

// ✅ AddDbContextPool — reuse DbContext instances across requests
builder.Services.AddDbContextPool<AppDbContext>(opt =>
    opt.UseMySql(connStr, version), poolSize: 128);
```

### Caching

```csharp
// ── In-Memory Cache ─────────────────────────────────────────────────
builder.Services.AddMemoryCache();

public class CategoryService : ICategoryService
{
    private readonly IMemoryCache _cache;
    private readonly ICategoryRepository _repo;

    public async Task<IReadOnlyList<CategoryDto>> GetAllAsync(CancellationToken ct = default)
        => await _cache.GetOrCreateAsync("categories:all", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30);
            entry.SlidingExpiration               = TimeSpan.FromMinutes(10);
            var cats = await _repo.GetAllAsync(ct);
            return cats.Select(CategoryDto.FromEntity).ToList().AsReadOnly();
                as IReadOnlyList<CategoryDto>;
        }) ?? [];
}

// ── Distributed Cache (Redis) ────────────────────────────────────────
dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
builder.Services.AddStackExchangeRedisCache(opt =>
    opt.Configuration = builder.Configuration.GetConnectionString("Redis"));

// ── Output Cache (.NET 7+) ───────────────────────────────────────────
builder.Services.AddOutputCache(opt =>
{
    opt.AddBasePolicy(b => b.Expire(TimeSpan.FromSeconds(60)));
    opt.AddPolicy("Products", b => b.Expire(TimeSpan.FromMinutes(5))
                                    .Tag("products")
                                    .SetVaryByQuery("page", "size", "search"));
});

[OutputCache(PolicyName = "Products")]
[HttpGet]
public async Task<ActionResult<PagedResult<ProductDto>>> GetAll(...)
```

### Response Compression

```csharp
builder.Services.AddResponseCompression(opt =>
{
    opt.EnableForHttps = true;
    opt.Providers.Add<BrotliCompressionProvider>();
    opt.Providers.Add<GzipCompressionProvider>();
});
builder.Services.Configure<BrotliCompressionProviderOptions>(opt =>
    opt.Level = CompressionLevel.Optimal);

app.UseResponseCompression();  // Before UseStaticFiles
```

### HTTP Client — Connection Reuse

```csharp
// ✅ Always use IHttpClientFactory — never new HttpClient()
builder.Services.AddHttpClient<IPaymentGateway, StripePaymentGateway>(client =>
{
    client.BaseAddress = new Uri("https://api.stripe.com/v1/");
    client.DefaultRequestHeaders.Add("Accept", "application/json");
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddTransientHttpErrorPolicy(p =>
    p.WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))))
.AddCircuitBreakerPolicy(...);
```

---

## 6. Security Hardening

### Anti-Forgery (CSRF)

```csharp
// Global enforcement in MVC (Core)
builder.Services.AddControllersWithViews(opt =>
    opt.Filters.Add<AutoValidateAntiforgeryTokenAttribute>());

// Allow specific endpoints (e.g., public API)
[IgnoreAntiforgeryToken]
public IActionResult PublicWebhook([FromBody] WebhookPayload payload) { ... }

// Razor form — tag helper auto-injects the token
<form asp-action="Create">...</form>

// Explicit injection for AJAX
builder.Services.AddAntiforgery(opt =>
{
    opt.HeaderName = "X-CSRF-TOKEN";   // Read by AJAX from meta tag
    opt.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    opt.Cookie.SameSite     = SameSiteMode.Strict;
});
```

### SQL Injection Prevention

```csharp
// ✅ EF Core — all LINQ queries are fully parameterized
var product = await _ctx.Products
    .FirstOrDefaultAsync(p => p.Name == name, ct);  // Safe

// ✅ Raw SQL — use placeholder syntax
await _ctx.Database.ExecuteSqlRawAsync(
    "UPDATE products SET stock = stock - {0} WHERE id = {1}", quantity, productId);

// ❌ NEVER string-interpolate user input into SQL
await _ctx.Database.ExecuteSqlRawAsync(
    $"SELECT * FROM products WHERE name = '{userInput}'");  // SQL injection!
```

### XSS Prevention

```cshtml
@* Razor auto-encodes all string output *@
<p>@Model.UserContent</p>    @* Safe — encoded as HTML entities *@

@* Raw HTML — only when content is trusted and sanitized *@
@Html.Raw(htmlSanitizer.Sanitize(Model.EditorContent))
```

```csharp
// Install: dotnet add package HtmlSanitizer
var sanitizer = new HtmlSanitizer();
sanitizer.AllowedTags.Add("b"); sanitizer.AllowedTags.Add("i"); sanitizer.AllowedTags.Add("p");
var safe = sanitizer.Sanitize(userHtmlInput);
```

### Secrets Management

```bash
# Development — User Secrets (stored outside project)
dotnet user-secrets init --project src/MyApp.Web
dotnet user-secrets set "ConnectionStrings:Default" "Server=localhost;..." --project src/MyApp.Web
dotnet user-secrets set "Jwt:Key" "dev-secret-key" --project src/MyApp.Web

# CI/CD — GitHub Actions Secrets → environment variables
# Production — Azure Key Vault / AWS Secrets Manager / HashiCorp Vault
```

```csharp
// Azure Key Vault integration
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{builder.Configuration["KeyVault:Name"]}.vault.azure.net/"),
    new DefaultAzureCredential());
```

### Secure File Upload

```csharp
[HttpPost]
[RequestSizeLimit(10 * 1024 * 1024)]  // 10 MB
public async Task<IActionResult> Upload(IFormFile file, CancellationToken ct)
{
    // 1. Validate MIME type by reading magic bytes — NOT extension
    var allowedSignatures = new Dictionary<string, byte[]>
    {
        ["jpg"] = [0xFF, 0xD8, 0xFF],
        ["png"] = [0x89, 0x50, 0x4E, 0x47],
        ["pdf"] = [0x25, 0x50, 0x44, 0x46]
    };

    using var reader = new BinaryReader(file.OpenReadStream());
    var header = reader.ReadBytes(4);
    var isValid = allowedSignatures.Values.Any(sig => header.Take(sig.Length).SequenceEqual(sig));
    if (!isValid) return BadRequest("File type not permitted.");

    // 2. Validate size
    if (file.Length > 10 * 1024 * 1024) return BadRequest("File exceeds 10 MB limit.");

    // 3. Store with GUID filename outside wwwroot — never use user-provided name
    var ext      = Path.GetExtension(file.FileName).ToLowerInvariant();
    var safeName = $"{Guid.NewGuid():N}{ext}";
    var fullPath = Path.Combine(_settings.UploadRoot, safeName);

    await using var stream = System.IO.File.Create(fullPath);
    await file.CopyToAsync(stream, ct);

    return Ok(new { fileName = safeName });
}
```

---

## 7. Testing Standards

### xUnit + Moq + FluentAssertions

```bash
dotnet add package xunit
dotnet add package Moq
dotnet add package FluentAssertions
dotnet add package Microsoft.AspNetCore.Mvc.Testing  # Integration tests
```

### Unit Test Anatomy

```csharp
// Naming: MethodName_Scenario_ExpectedResult
public class ProductServiceTests
{
    // System Under Test + Mocks declared at class level
    private readonly Mock<IProductRepository> _repoMock = new();
    private readonly Mock<IUnitOfWork>        _uowMock  = new();
    private readonly ProductService           _sut;

    public ProductServiceTests()
    {
        _uowMock.Setup(u => u.Products).Returns(_repoMock.Object);
        _sut = new ProductService(_uowMock.Object,
                   Mock.Of<ILogger<ProductService>>());
    }

    [Fact]
    public async Task CreateAsync_ValidRequest_ReturnsProductDtoWithCorrectData()
    {
        // Arrange
        var request = new CreateProductRequest("Widget Pro", 29.99m, CategoryId: 1);

        _repoMock.Setup(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()))
                 .Returns(Task.CompletedTask);
        _uowMock.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()))
                .ReturnsAsync(1);

        // Act
        var result = await _sut.CreateAsync(request, CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result.Name.Should().Be("Widget Pro");
        result.Price.Should().Be(29.99m);

        _repoMock.Verify(r => r.AddAsync(It.Is<Product>(p => p.Name == "Widget Pro"),
            It.IsAny<CancellationToken>()), Times.Once);
        _uowMock.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("",       29.99,  "Name cannot be empty")]
    [InlineData("Widget", -1,     "Price must be positive")]
    [InlineData("Widget",  0,     "Price must be positive")]
    public async Task CreateAsync_InvalidInput_ThrowsDomainException(
        string name, decimal price, string _)
    {
        var act = async () => await _sut.CreateAsync(
            new CreateProductRequest(name, price, 1), CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
        _repoMock.Verify(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
```

### Integration Test with WebApplicationFactory

```csharp
public class ProductApiIntegrationTests
    : IClassFixture<WebApplicationFactory<Program>>, IAsyncLifetime
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ProductApiIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.ConfigureServices(services =>
            {
                // Replace real DB with SQLite in-memory for speed
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(opt =>
                    opt.UseInMemoryDatabase("TestDb_" + Guid.NewGuid()));
            });
        });

        _client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    public async Task InitializeAsync()
    {
        // Seed test data
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.EnsureCreatedAsync();
        db.Categories.Add(new Category { Name = "Electronics" });
        db.Products.Add(new Product { Name = "Test Widget", Price = 9.99m, CategoryId = 1 });
        await db.SaveChangesAsync();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task GET_api_products_Returns200WithItems()
    {
        var response = await _client.GetAsync("/api/v1/products");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<PagedResult<ProductDto>>();
        body.Should().NotBeNull();
        body!.Items.Should().HaveCountGreaterThan(0);
    }

    [Fact]
    public async Task POST_api_products_Returns201WithLocation()
    {
        var request = new CreateProductRequest("New Product", 49.99m, 1);

        var response = await _client.PostAsJsonAsync("/api/v1/products", request);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();

        var created = await response.Content.ReadFromJsonAsync<ProductDto>();
        created!.Name.Should().Be("New Product");
    }
}
```

---

## 8. Code Review Checklist (Master)

```markdown
## Architecture
- [ ] No business logic in controllers or Razor views
- [ ] Interfaces used for all service and repository dependencies
- [ ] Layer dependencies flow Domain ← Application ← Infrastructure/Presentation
- [ ] No circular project references

## Security
- [ ] No raw SQL with unsanitized user input
- [ ] [ValidateAntiForgeryToken] on all non-API POST actions
- [ ] No secrets, passwords, or keys in code or appsettings.json
- [ ] Sensitive fields not serialized in API responses (no PasswordHash, SecurityStamp)
- [ ] Authorization attributes present on all endpoints that require them
- [ ] File uploads validated by magic bytes, stored with GUID names outside wwwroot

## Data Access
- [ ] AsNoTracking() on all EF Core read-only queries
- [ ] CancellationToken threaded through the entire async call chain
- [ ] No N+1 queries (Include / projection / split queries used appropriately)
- [ ] Migrations reviewed for correctness, reversibility, and data safety
- [ ] No DbContext resolved from singleton services

## Async Code
- [ ] No async void methods (except event handlers)
- [ ] No .Result or .Wait() calls
- [ ] No unnecessary await wrapping (return Task directly where possible)

## Code Quality
- [ ] No magic strings or magic numbers — enums/constants used
- [ ] No unused using directives, variables, or parameters
- [ ] No commented-out code committed
- [ ] Error handling is explicit — no swallowed exceptions (empty catch blocks)
- [ ] Logging uses structured format, not string interpolation

## Testing
- [ ] New public methods have unit tests
- [ ] Bug fixes include regression tests
- [ ] Test names follow MethodName_Scenario_ExpectedResult
- [ ] Test assertions use FluentAssertions for readable failures
- [ ] No test dependencies on external services (DB, SMTP, etc.)

## Performance
- [ ] No database queries inside loops
- [ ] Paginated endpoints have sane default and max page sizes
- [ ] Expensive stable data is cached appropriately
```

---

## 9. Accessibility (WCAG 2.1 AA)

```cshtml
@* ── Skip Link (first element in body) ── *@
<a class="visually-hidden-focusable" href="#main-content">Skip to main content</a>

@* ── Semantic landmarks ── *@
<header role="banner">...</header>
<nav aria-label="Main navigation">...</nav>
<main id="main-content" role="main">...</main>
<aside aria-label="Filters">...</aside>
<footer role="contentinfo">...</footer>

@* ── Form accessibility ── *@
<label for="product-name" class="form-label">
    Product Name <span aria-hidden="true" class="text-danger">*</span>
    <span class="visually-hidden">(required)</span>
</label>
<input id="product-name"
       asp-for="Name"
       class="form-control"
       aria-required="true"
       aria-describedby="name-error name-hint"
       autocomplete="off" />
<div id="name-hint" class="form-text">2 to 200 characters.</div>
<span id="name-error" asp-validation-for="Name"
      class="invalid-feedback d-block" role="alert"></span>

@* ── Icon buttons — always label the action ── *@
<button type="button"
        class="btn btn-sm btn-danger"
        aria-label="Delete product @Model.Name">
    <i class="bi bi-trash" aria-hidden="true"></i>
</button>

@* ── Status announcements for AJAX updates ── *@
<div id="status-announcer"
     role="status"
     aria-live="polite"
     aria-atomic="true"
     class="visually-hidden">
    @TempData["StatusMessage"]
</div>

@* ── Data tables ── *@
<table class="table" aria-label="Product catalog">
    <caption class="visually-hidden">List of products — sortable by name, price, or category</caption>
    <thead>
        <tr>
            <th scope="col">Name</th>
            <th scope="col" aria-sort="ascending">Price</th>
            <th scope="col">Category</th>
            <th scope="col"><span class="visually-hidden">Actions</span></th>
        </tr>
    </thead>
    <tbody>
        @foreach (var p in Model.Products)
        {
            <tr>
                <td>@p.Name</td>
                <td>@p.Price.ToString("C")</td>
                <td>@p.CategoryName</td>
                <td>
                    <a asp-action="Edit" asp-route-id="@p.Id"
                       aria-label="Edit @p.Name">Edit</a>
                </td>
            </tr>
        }
    </tbody>
</table>

@* ── Focus management after AJAX operations ── *@
@section Scripts {
<script>
    document.addEventListener('DOMContentLoaded', () => {
        // Move focus to the newly created item's heading after AJAX insert
        const announcer = document.getElementById('status-announcer');
        const announce  = msg => { announcer.textContent = ''; announcer.textContent = msg; };

        document.getElementById('create-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            const result = await ApiClient.post('/api/products', ...);
            announce(`Product ${result.name} created successfully.`);
            document.getElementById('product-list').focus();
        });
    });
</script>
}
```