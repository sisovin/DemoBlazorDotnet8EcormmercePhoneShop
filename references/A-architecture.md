# Section A — Architecture & Framework Skills

## Table of Contents
1. [MVC Architecture Pattern](#1-mvc-architecture-pattern)
2. [RESTful API Architecture](#2-restful-api-architecture)
3. [Minimal API Design (.NET 6+)](#3-minimal-api-design-net-6)
4. [Routing](#4-routing)
5. [Controllers, Action Methods & Model Binding](#5-controllers-action-methods--model-binding)
6. [Razor Views & View Engine](#6-razor-views--view-engine)
7. [Middleware Pipeline](#7-middleware-pipeline)
8. [Dependency Injection](#8-dependency-injection)
9. [Filters](#9-filters)
10. [API Versioning](#10-api-versioning)
11. [OpenAPI / Swagger Documentation](#11-openapi--swagger-documentation)

---

## 1. MVC Architecture Pattern

```
HTTP Request
    │
    ▼
┌──────────────────────────────────────────────┐
│  Routing Engine                              │
│  URL → Controller → Action                  │
└───────────────────┬──────────────────────────┘
                    ▼
┌────────────────────────────────────────────────────────────┐
│  Controller                                                │
│  · Receives bound parameters (route, query, body, form)   │
│  · Calls Application Service / Use Case                   │
│  · Returns IActionResult                                   │
└──────────┬─────────────────────────┬───────────────────────┘
           ▼                         ▼
┌─────────────────────┐   ┌──────────────────────────────────┐
│  Model (ViewModel)  │   │  View (.cshtml / Razor)          │
│  · Data Transfer    │   │  · Server-rendered HTML          │
│  · Validation attrs │   │  · Tag Helpers (Core)            │
│  · Domain entities  │   │  · HTML Helpers (MVC5 compat)    │
└─────────────────────┘   └──────────────────────────────────┘
```

**Separation of concerns:**
- **Model** — Domain entities, ViewModels, DTOs, Data Annotations
- **View** — Razor templates; zero business logic
- **Controller** — HTTP orchestration only; delegates to services

---

## 2. RESTful API Architecture

REST constraints applied to ASP.NET Core Web API:

| Constraint | ASP.NET Core Implementation |
|---|---|
| Stateless | No session; JWT per-request |
| Uniform Interface | `[HttpGet/Post/Put/Delete/Patch]` attributes |
| Resource-based URLs | `/api/products`, `/api/products/{id}` |
| Representations | JSON via `System.Text.Json` |
| HATEOAS (optional) | Custom links in response envelopes |

### HTTP Status Code Conventions

| Scenario | Status | ActionResult |
|---|---|---|
| Success, data returned | 200 | `Ok(data)` |
| Resource created | 201 | `CreatedAtAction(...)` |
| Success, no content | 204 | `NoContent()` |
| Validation failure | 400 | `BadRequest(ModelState)` |
| Unauthenticated | 401 | `Unauthorized()` |
| Insufficient permission | 403 | `Forbid()` |
| Resource not found | 404 | `NotFound()` |
| Business rule violation | 422 | `UnprocessableEntity(problem)` |
| Server error | 500 | Via exception middleware |

---

## 3. Minimal API Design (.NET 6+)

Minimal APIs eliminate the controller class; endpoints are registered directly on `WebApplication`.

```csharp
// Program.cs — endpoint groups
var products = app.MapGroup("/api/products")
    .WithTags("Products")
    .WithOpenApi()
    .RequireAuthorization();

products.MapGet("/", async (IProductService svc, CancellationToken ct) =>
{
    var items = await svc.GetAllAsync(ct);
    return Results.Ok(items);
})
.WithName("GetProducts")
.Produces<IReadOnlyList<ProductDto>>();

products.MapGet("/{id:int}", async (int id, IProductService svc, CancellationToken ct) =>
{
    var item = await svc.GetByIdAsync(id, ct);
    return item is null ? Results.NotFound() : Results.Ok(item);
})
.WithName("GetProductById")
.Produces<ProductDto>()
.ProducesProblem(404);

products.MapPost("/", async (CreateProductRequest req, IProductService svc, CancellationToken ct) =>
{
    var created = await svc.CreateAsync(req, ct);
    return Results.CreatedAtRoute("GetProductById", new { id = created.Id }, created);
})
.WithName("CreateProduct")
.Accepts<CreateProductRequest>("application/json")
.Produces<ProductDto>(201)
.ProducesValidationProblem();

products.MapDelete("/{id:int}", async (int id, IProductService svc, CancellationToken ct) =>
{
    var deleted = await svc.DeleteAsync(id, ct);
    return deleted ? Results.NoContent() : Results.NotFound();
})
.RequireAuthorization("Admin");

// Organize into endpoint files (IEndpointRouteBuilder extension)
public static class ProductEndpoints
{
    public static IEndpointRouteBuilder MapProductEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/products").WithTags("Products");
        group.MapGet("/", GetAll);
        group.MapGet("/{id:int}", GetById);
        group.MapPost("/", Create);
        return app;
    }

    private static async Task<IResult> GetAll(IProductService svc, CancellationToken ct)
        => Results.Ok(await svc.GetAllAsync(ct));

    private static async Task<IResult> GetById(int id, IProductService svc, CancellationToken ct)
    {
        var item = await svc.GetByIdAsync(id, ct);
        return item is null ? Results.NotFound() : Results.Ok(item);
    }

    private static async Task<IResult> Create(
        CreateProductRequest req, IProductService svc, CancellationToken ct)
    {
        var created = await svc.CreateAsync(req, ct);
        return Results.CreatedAtRoute("GetProductById", new { id = created.Id }, created);
    }
}

// Program.cs
app.MapProductEndpoints();
```

### Minimal API vs. Controller API — When to Use

| Factor | Minimal API | Controller API |
|---|---|---|
| Low ceremony / microservices | ✅ Preferred | ⚠️ Verbose |
| Complex filter pipelines | ⚠️ Limited | ✅ Full support |
| Team familiar with MVC | ⚠️ New pattern | ✅ Familiar |
| Large, complex APIs | ⚠️ Can sprawl | ✅ Organized by controller |
| Performance (startup) | ✅ Faster | ⚠️ Slightly heavier |

---

## 4. Routing

### Attribute Routing (Web API — Required)

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet]                           // GET  api/v1/products
    [HttpGet("{id:int:min(1)}")]        // GET  api/v1/products/5
    [HttpGet("category/{catId:int}")]   // GET  api/v1/products/category/3
    [HttpPost]                          // POST api/v1/products
    [HttpPut("{id:int}")]               // PUT  api/v1/products/5
    [HttpPatch("{id:int}")]             // PATCH api/v1/products/5
    [HttpDelete("{id:int}")]            // DELETE api/v1/products/5
}
```

### Route Constraints Reference

```csharp
{id:int}             // Integer only
{id:int:min(1)}      // Integer ≥ 1
{id:guid}            // GUID format
{slug:alpha}         // Alphabetic only
{slug:regex(^[a-z0-9\-]+$)}  // Regex match
{date:datetime}      // Parseable datetime
{version:apiVersion} // API versioning constraint
```

### Conventional Routing (MVC — Program.cs)

```csharp
// Default route
app.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");

// Area route
app.MapControllerRoute("areas", "{area:exists}/{controller=Home}/{action=Index}/{id?}");

// Named custom route
app.MapControllerRoute("blog", "blog/{year:int}/{month:int}/{slug}",
    new { controller = "Blog", action = "Post" });
```

### [MVC5] RouteConfig.cs

```csharp
public class RouteConfig
{
    public static void RegisterRoutes(RouteCollection routes)
    {
        routes.IgnoreRoute("{resource}.axd/{*pathInfo}");
        routes.MapMvcAttributeRoutes();   // Enable attribute routing in MVC 5
        routes.MapRoute("Default", "{controller}/{action}/{id}",
            new { controller = "Home", action = "Index", id = UrlParameter.Optional });
    }
}
```

---

## 5. Controllers, Action Methods & Model Binding

### MVC Controller (returns Views)

```csharp
public class ProductController : Controller
{
    private readonly IProductService _svc;
    private readonly ILogger<ProductController> _log;

    public ProductController(IProductService svc, ILogger<ProductController> log)
        => (_svc, _log) = (svc, log);

    [HttpGet]
    public async Task<IActionResult> Index([FromQuery] int page = 1, [FromQuery] int size = 20)
    {
        var model = await _svc.GetPagedAsync(page, size);
        return View(model);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Details(int id)
    {
        var product = await _svc.GetByIdAsync(id);
        return product is null ? NotFound() : View(product);
    }

    [HttpGet]
    public IActionResult Create() => View(new CreateProductViewModel());

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(CreateProductViewModel vm)
    {
        if (!ModelState.IsValid) return View(vm);
        await _svc.CreateAsync(vm);
        TempData["Success"] = "Product created successfully.";
        return RedirectToAction(nameof(Index));
    }
}
```

### API Controller (returns JSON)

```csharp
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _svc;
    public ProductsController(IProductService svc) => _svc = svc;

    [HttpGet]
    public async Task<ActionResult<PagedResult<ProductDto>>> GetAll(
        [FromQuery] ProductQueryParams query, CancellationToken ct)
        => Ok(await _svc.GetPagedAsync(query, ct));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProductDto>> GetById(int id, CancellationToken ct)
    {
        var p = await _svc.GetByIdAsync(id, ct);
        return p is null ? NotFound() : Ok(p);
    }

    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(
        [FromBody] CreateProductRequest req, CancellationToken ct)
    {
        var created = await _svc.CreateAsync(req, ct);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<ProductDto>> Update(
        int id, [FromBody] UpdateProductRequest req, CancellationToken ct)
    {
        var updated = await _svc.UpdateAsync(id, req, ct);
        return updated is null ? NotFound() : Ok(updated);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
        => await _svc.DeleteAsync(id, ct) ? NoContent() : NotFound();
}
```

### Model Binding Sources

```csharp
public IActionResult Demo(
    [FromRoute]  int id,            // /products/{id}
    [FromQuery]  string? search,    // ?search=widget
    [FromBody]   CreateRequest req, // JSON body
    [FromForm]   IFormFile file,    // multipart/form-data
    [FromHeader] string apiKey,     // Request header
    [FromServices] IEmailSender mailer)  // DI injection
```

---

## 6. Razor Views & View Engine

### _Layout.cshtml

```cshtml
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] — @AppSettings.AppName</title>
    <link rel="stylesheet" href="~/css/site.min.css" asp-append-version="true" />
    @await RenderSectionAsync("Styles", required: false)
</head>
<body>
    <header>@await Html.PartialAsync("_Navbar")</header>
    <main role="main" class="container py-4">
        @await Html.PartialAsync("_Alerts")
        @RenderBody()
    </main>
    <footer>@await Html.PartialAsync("_Footer")</footer>
    <script src="~/lib/jquery/dist/jquery.min.js"></script>
    @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
```

### Tag Helpers (Core) vs. HTML Helpers (MVC 5)

```cshtml
@* ─── Tag Helpers (Core — preferred) ─── *@
<form asp-action="Create" asp-controller="Product" method="post">
    <label asp-for="Name"></label>
    <input asp-for="Name" class="form-control" autocomplete="off" />
    <span asp-validation-for="Name" class="text-danger"></span>

    <select asp-for="CategoryId" asp-items="Model.Categories">
        <option value="">— Select Category —</option>
    </select>

    <a asp-controller="Product" asp-action="Index">Cancel</a>
    <button type="submit" class="btn btn-primary">Save</button>
</form>

@* ─── HTML Helpers (MVC 5 / legacy compat) ─── *@
@using (Html.BeginForm("Create", "Product", FormMethod.Post))
{
    @Html.AntiForgeryToken()
    @Html.LabelFor(m => m.Name)
    @Html.TextBoxFor(m => m.Name, new { @class = "form-control" })
    @Html.ValidationMessageFor(m => m.Name)
}
```

### View Components (Core — for logic-bearing partials)

```csharp
public class CategoryMenuViewComponent : ViewComponent
{
    private readonly ICategoryService _svc;
    public CategoryMenuViewComponent(ICategoryService svc) => _svc = svc;

    public async Task<IViewComponentResult> InvokeAsync()
        => View(await _svc.GetAllAsync());
}
```

```cshtml
@* In any view *@
@await Component.InvokeAsync("CategoryMenu")
```

---

## 7. Middleware Pipeline

### Pipeline Order (Critical — incorrect order causes auth/routing failures)

```csharp
// Program.cs — canonical order for ASP.NET Core MVC + API
app.UseExceptionHandler("/Error");  // 1. Catch all unhandled exceptions
app.UseHsts();                      // 2. HTTP Strict Transport Security
app.UseHttpsRedirection();          // 3. Redirect HTTP → HTTPS
app.UseStaticFiles();               // 4. Serve wwwroot before routing
app.UseCors("Policy");              // 5. CORS headers (before routing for preflight)
app.UseRouting();                   // 6. Match endpoints
app.UseRateLimiter();               // 7. Rate limiting (after routing for endpoint data)
app.UseAuthentication();            // 8. Identify the user (cookie/JWT/etc.)
app.UseAuthorization();             // 9. Enforce policies
app.UseOutputCache();               // 10. Output caching
app.MapControllers();               // 11. Execute matched controller action
```

### Custom Middleware (class-based — recommended)

```csharp
public class CorrelationIdMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;
    private const string Header = "X-Correlation-Id";

    public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
        => (_next, _logger) = (next, logger);

    public async Task InvokeAsync(HttpContext ctx)
    {
        var correlationId = ctx.Request.Headers[Header].FirstOrDefault()
                            ?? Guid.NewGuid().ToString("N");

        ctx.Response.Headers[Header] = correlationId;

        using (_logger.BeginScope(new Dictionary<string, object>
               { ["CorrelationId"] = correlationId }))
        {
            await _next(ctx);
        }
    }
}

// Registration
app.UseMiddleware<CorrelationIdMiddleware>();
// or extension method:
public static IApplicationBuilder UseCorrelationId(this IApplicationBuilder app)
    => app.UseMiddleware<CorrelationIdMiddleware>();
```

---

## 8. Dependency Injection

### Service Lifetimes

| Lifetime | Method | Creates new instance |
|---|---|---|
| Transient | `AddTransient<I,T>()` | Every injection |
| Scoped | `AddScoped<I,T>()` | Once per HTTP request |
| Singleton | `AddSingleton<I,T>()` | Once per application lifetime |

```csharp
// Program.cs — registration patterns
builder.Services.AddScoped<IProductRepository, ProductRepository>();      // DB access
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();           // Stateless
builder.Services.AddSingleton<IMemoryCache, MemoryCache>();               // Shared state
builder.Services.AddHttpClient<IPaymentGateway, StripePaymentGateway>();  // HttpClientFactory

// Options pattern (typed config)
builder.Services.AddOptions<JwtSettings>()
    .BindConfiguration(JwtSettings.Section)
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Named / generic registrations
builder.Services.AddScoped(typeof(IRepository<>), typeof(RepositoryBase<>));

// Conditional registration
if (builder.Environment.IsDevelopment())
    builder.Services.AddTransient<IEmailSender, NullEmailSender>();
else
    builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
```

### [MVC5] Autofac DI

```csharp
// Global.asax.cs Application_Start()
var autofacBuilder = new ContainerBuilder();
autofacBuilder.RegisterControllers(typeof(MvcApplication).Assembly);
autofacBuilder.RegisterType<ProductRepository>().As<IProductRepository>().InstancePerRequest();
autofacBuilder.RegisterType<ProductService>().As<IProductService>().InstancePerRequest();
var container = autofacBuilder.Build();
DependencyResolver.SetResolver(new AutofacDependencyResolver(container));
```

---

## 9. Filters

Filters intercept the MVC/API pipeline at defined stages.

**Execution order:** Authorization → Resource → Action → (action body) → Result → Exception

### Action Filter

```csharp
public class PerformanceFilter : IAsyncActionFilter
{
    private readonly ILogger<PerformanceFilter> _log;
    public PerformanceFilter(ILogger<PerformanceFilter> log) => _log = log;

    public async Task OnActionExecutionAsync(ActionExecutingContext ctx, ActionExecutionDelegate next)
    {
        var sw = Stopwatch.StartNew();
        var result = await next();
        sw.Stop();

        if (sw.ElapsedMilliseconds > 500)
            _log.LogWarning("Slow action {Action}: {Ms}ms",
                ctx.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
    }
}
```

### Exception Filter

```csharp
public class ApiExceptionFilter : IExceptionFilter
{
    private readonly ILogger<ApiExceptionFilter> _log;
    public ApiExceptionFilter(ILogger<ApiExceptionFilter> log) => _log = log;

    public void OnException(ExceptionContext ctx)
    {
        _log.LogError(ctx.Exception, "Unhandled exception in {Action}",
            ctx.ActionDescriptor.DisplayName);

        var (status, title) = ctx.Exception switch
        {
            NotFoundException    => (404, "Not Found"),
            ValidationException  => (400, "Validation Error"),
            UnauthorizedException => (401, "Unauthorized"),
            _                    => (500, "Internal Server Error")
        };

        ctx.Result = new ObjectResult(new ProblemDetails
        {
            Status = status, Title = title,
            Detail = ctx.Exception.Message,
            Instance = ctx.HttpContext.Request.Path
        })
        { StatusCode = status };

        ctx.ExceptionHandled = true;
    }
}
```

### Global Registration

```csharp
builder.Services.AddControllers(options =>
{
    options.Filters.Add<PerformanceFilter>();
    options.Filters.Add<ApiExceptionFilter>();
});
```

---

## 10. API Versioning

```bash
dotnet add package Asp.Versioning.Mvc
dotnet add package Asp.Versioning.Mvc.ApiExplorer
```

```csharp
// Program.cs
builder.Services.AddApiVersioning(opt =>
{
    opt.DefaultApiVersion = new ApiVersion(1);
    opt.AssumeDefaultVersionWhenUnspecified = true;
    opt.ReportApiVersions = true;
    opt.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),           // /api/v1/products
        new HeaderApiVersionReader("X-Api-Version"), // Header: X-Api-Version: 2
        new QueryStringApiVersionReader("api-version")); // ?api-version=2
})
.AddApiExplorer(opt =>
{
    opt.GroupNameFormat           = "'v'V";
    opt.SubstituteApiVersionInUrl = true;
});

// Controller
[ApiController]
[Route("api/v{version:apiVersion}/products")]
[ApiVersion(1)]
[ApiVersion(2)]
public class ProductsController : ControllerBase
{
    [HttpGet, MapToApiVersion(1)]
    public IActionResult GetV1() => Ok(new { version = "v1" });

    [HttpGet, MapToApiVersion(2)]
    public IActionResult GetV2() => Ok(new { version = "v2", extra = "newField" });
}
```

---

## 11. OpenAPI / Swagger Documentation

```bash
dotnet add package Swashbuckle.AspNetCore
```

```csharp
builder.Services.AddSwaggerGen(opt =>
{
    opt.SwaggerDoc("v1", new OpenApiInfo
    {
        Title   = "MyApp API",
        Version = "v1",
        Description = "Full-stack ASP.NET Core Web API",
        Contact = new OpenApiContact { Name = "Engineering Team", Email = "eng@example.com" },
        License = new OpenApiLicense { Name = "MIT" }
    });

    // XML comments from source code
    var xml = Path.Combine(AppContext.BaseDirectory,
        $"{Assembly.GetExecutingAssembly().GetName().Name}.xml");
    opt.IncludeXmlComments(xml);

    // JWT auth in Swagger UI
    opt.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type        = SecuritySchemeType.Http,
        Scheme      = "Bearer",
        BearerFormat = "JWT",
        In          = ParameterLocation.Header,
        Description = "Enter your JWT token."
    });
    opt.AddSecurityRequirement(new OpenApiSecurityRequirement
    {{
        new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference
                { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
        },
        Array.Empty<string>()
    }});

    // Per-version Swagger docs
    opt.DocInclusionPredicate((docName, apiDesc) =>
        apiDesc.GroupName == docName);
});

// Enable XML docs in .csproj
// <GenerateDocumentationFile>true</GenerateDocumentationFile>
// <NoWarn>$(NoWarn);1591</NoWarn>

app.UseSwagger();
app.UseSwaggerUI(opt =>
{
    opt.SwaggerEndpoint("/swagger/v1/swagger.json", "MyApp API v1");
    opt.RoutePrefix = string.Empty; // Serve at root: https://api.example.com/
});
```