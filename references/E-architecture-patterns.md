# Section E — System Architecture Skills

## Table of Contents
1. [Clean Architecture](#1-clean-architecture)
2. [Layered (N-Tier) Architecture](#2-layered-n-tier-architecture)
3. [Domain-Driven Design (DDD) — Optional](#3-domain-driven-design-ddd--optional)
4. [SOLID Principles in ASP.NET](#4-solid-principles-in-aspnet)
5. [MVC Folder Structure & Conventions](#5-mvc-folder-structure--conventions)

---

## 1. Clean Architecture

Clean Architecture enforces the **Dependency Rule**: source code dependencies point
only inward. The innermost circle (Domain) has no external dependencies — zero NuGet
packages, zero framework references.

```
┌────────────────────────────────────────────────────────────────────┐
│  Infrastructure Layer                                              │
│  EF Core · MySQL · SMTP · FileStorage · ExternalAPIs             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Presentation Layer                                         │  │
│  │  ASP.NET Core MVC · Web API · Minimal APIs                 │  │
│  │  Controllers · Views · ViewModels · Filters                 │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  Application Layer                                    │ │  │
│  │  │  Use Cases · DTOs · Service Interfaces               │ │  │
│  │  │  Validators · Mapping · Event Handlers               │ │  │
│  │  │  ┌────────────────────────────────────────────────┐  │ │  │
│  │  │  │  Domain Layer                                 │  │ │  │
│  │  │  │  Entities · Value Objects · Aggregates        │  │ │  │
│  │  │  │  Domain Events · Business Rules · Enums       │  │ │  │
│  │  │  │  Repository Interfaces (contracts only)       │  │ │  │
│  │  │  └────────────────────────────────────────────────┘  │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### Project Layout

```
MyApp.sln
├── src/
│   ├── MyApp.Domain/               ← Zero dependencies
│   │   ├── Entities/
│   │   │   ├── BaseEntity.cs
│   │   │   ├── Product.cs
│   │   │   └── Order.cs
│   │   ├── ValueObjects/
│   │   │   └── Money.cs
│   │   ├── Enums/
│   │   │   └── OrderStatus.cs
│   │   ├── Events/
│   │   │   └── OrderPlacedEvent.cs
│   │   ├── Interfaces/
│   │   │   ├── IProductRepository.cs   ← Contract defined here
│   │   │   └── IUnitOfWork.cs
│   │   └── Exceptions/
│   │       ├── DomainException.cs
│   │       └── NotFoundException.cs
│   │
│   ├── MyApp.Application/           ← References Domain only
│   │   ├── DTOs/
│   │   │   ├── ProductDto.cs
│   │   │   └── OrderDto.cs
│   │   ├── Interfaces/
│   │   │   ├── IProductService.cs
│   │   │   └── IEmailSender.cs
│   │   ├── Services/
│   │   │   └── ProductService.cs
│   │   ├── Validators/
│   │   │   └── CreateProductValidator.cs
│   │   └── Mappings/
│   │       └── ProductMappingProfile.cs
│   │
│   ├── MyApp.Infrastructure/        ← References Application + Domain
│   │   ├── Data/
│   │   │   ├── AppDbContext.cs
│   │   │   ├── Migrations/
│   │   │   └── Configurations/
│   │   │       └── ProductConfiguration.cs
│   │   ├── Repositories/
│   │   │   └── ProductRepository.cs
│   │   └── Services/
│   │       └── SmtpEmailSender.cs
│   │
│   └── MyApp.Web/                   ← References Application (never Infrastructure directly)
│       ├── Controllers/
│       ├── Views/
│       ├── ViewModels/
│       ├── wwwroot/
│       └── Program.cs               ← Composition Root (only place that refs Infrastructure)
│
└── tests/
    ├── MyApp.Domain.Tests/
    ├── MyApp.Application.Tests/
    └── MyApp.Integration.Tests/
```

### Composition Root — Dependency Assembly (Program.cs)

```csharp
// Program.cs is the ONLY place that references Infrastructure
// (via extension methods)
builder.Services.AddApplication();      // Application layer DI
builder.Services.AddInfrastructure(builder.Configuration);  // EF Core, Repos, SMTP

// Infrastructure/DependencyInjection.cs
public static IServiceCollection AddInfrastructure(this IServiceCollection services,
    IConfiguration configuration)
{
    services.AddDbContext<AppDbContext>(opt =>
        opt.UseMySql(configuration.GetConnectionString("Default"),
            ServerVersion.AutoDetect(configuration.GetConnectionString("Default"))));

    services.AddScoped<IProductRepository, ProductRepository>();
    services.AddScoped<IUnitOfWork, UnitOfWork>();
    services.AddTransient<IEmailSender, SmtpEmailSender>();
    return services;
}

// Application/DependencyInjection.cs
public static IServiceCollection AddApplication(this IServiceCollection services)
{
    services.AddScoped<IProductService, ProductService>();
    services.AddValidatorsFromAssembly(typeof(CreateProductValidator).Assembly);
    services.AddAutoMapper(typeof(ProductMappingProfile).Assembly);
    return services;
}
```

---

## 2. Layered (N-Tier) Architecture

Simpler than Clean Architecture; suitable for CRUD-heavy applications where DI still
enforces direction but layers share the same solution without strict project separation.

```
Presentation  →  Business Logic  →  Data Access  →  MySQL
(MVC/API)        (Services)         (Repositories)
```

```
MyApp/
├── Controllers/          ← Presentation
├── Services/             ← Business Logic
│   └── Interfaces/
├── Repositories/         ← Data Access
│   └── Interfaces/
├── Models/
│   ├── Domain/           ← Entities
│   ├── DTOs/
│   └── ViewModels/
├── Data/
│   ├── AppDbContext.cs
│   └── Migrations/
└── Program.cs
```

---

## 3. Domain-Driven Design (DDD) — Optional

DDD applies when business complexity justifies the investment. Key building blocks:

### Aggregate Root

```csharp
public class Order : BaseEntity   // Aggregate Root
{
    private readonly List<OrderItem> _items = [];
    public IReadOnlyList<OrderItem> Items => _items.AsReadOnly();

    public OrderStatus Status { get; private set; } = OrderStatus.Pending;
    public decimal     Total  { get; private set; }

    private Order() { }   // EF parameterless ctor

    public static Order Create(string userId)
        => new() { UserId = userId };

    // Encapsulated mutation — invariants enforced here
    public void AddItem(Product product, int quantity)
    {
        if (Status != OrderStatus.Pending)
            throw new DomainException("Cannot modify a non-pending order.");

        var existing = _items.FirstOrDefault(i => i.ProductId == product.Id);
        if (existing is not null)
            existing.IncrementQuantity(quantity);
        else
            _items.Add(OrderItem.Create(product, quantity));

        RecalculateTotal();
        AddDomainEvent(new ItemAddedToOrderEvent(Id, product.Id, quantity));
    }

    public void Submit()
    {
        if (!_items.Any())   throw new DomainException("Order has no items.");
        if (Total <= 0)      throw new DomainException("Order total must be positive.");
        Status = OrderStatus.Submitted;
        AddDomainEvent(new OrderSubmittedEvent(Id, UserId, Total));
    }

    private void RecalculateTotal()
        => Total = _items.Sum(i => i.UnitPrice * i.Quantity);
}
```

### Value Object

```csharp
public sealed record Money(decimal Amount, string Currency)
{
    public static readonly Money Zero = new(0, "USD");

    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new DomainException($"Cannot add {Currency} and {other.Currency}.");
        return new Money(Amount + other.Amount, Currency);
    }

    public override string ToString() => $"{Amount:F2} {Currency}";
}
```

### Domain Events

```csharp
// Domain event (pure POCO)
public record OrderSubmittedEvent(int OrderId, string UserId, decimal Total) : IDomainEvent;

// Handled in Application layer via MediatR
public class OrderSubmittedHandler : INotificationHandler<OrderSubmittedEvent>
{
    private readonly IEmailSender _email;
    public OrderSubmittedHandler(IEmailSender email) => _email = email;

    public async Task Handle(OrderSubmittedEvent evt, CancellationToken ct)
        => await _email.SendOrderConfirmationAsync(evt.UserId, evt.OrderId, ct);
}
```

---

## 4. SOLID Principles in ASP.NET

### Single Responsibility Principle (SRP)

```csharp
// ❌ Fat controller — violates SRP
public class ProductController : Controller
{
    private readonly AppDbContext _db;
    public IActionResult Create(Product p)
    {
        if (p.Price <= 0) ModelState.AddModelError("", "Bad price");
        var email = new SmtpClient().Send(...)  // Auth, business logic, AND email in one place
        _db.Products.Add(p); _db.SaveChanges();
        return View();
    }
}

// ✅ Thin controller — one responsibility: HTTP orchestration
public class ProductController : Controller
{
    public async Task<IActionResult> Create(CreateProductViewModel vm)
    {
        if (!ModelState.IsValid) return View(vm);
        var product = await _productService.CreateAsync(vm);
        return RedirectToAction(nameof(Index));
    }
}
```

### Open/Closed Principle (OCP)

```csharp
// Extend by adding new strategy classes — never modify existing ones
public interface IDiscountStrategy  { decimal Apply(decimal price, ApplicationUser user); }
public class SeasonalDiscount : IDiscountStrategy { /* ... */ }
public class LoyaltyDiscount  : IDiscountStrategy { /* ... */ }

public class PricingService
{
    private readonly IEnumerable<IDiscountStrategy> _strategies;
    public PricingService(IEnumerable<IDiscountStrategy> strategies) => _strategies = strategies;

    public decimal CalculateFinalPrice(decimal price, ApplicationUser user)
        => _strategies.Aggregate(price, (p, s) => s.Apply(p, user));
}
```

### Interface Segregation Principle (ISP)

```csharp
// Narrow, role-specific interfaces — not one large IRepository<T>
public interface IReadRepository<T>  { Task<T?> GetByIdAsync(int id); Task<IReadOnlyList<T>> GetAllAsync(); }
public interface IWriteRepository<T> { Task AddAsync(T entity); Task UpdateAsync(T entity); Task DeleteAsync(T entity); }
public interface IRepository<T>      : IReadRepository<T>, IWriteRepository<T> { }

// Query-only services only depend on IReadRepository<T>
public class ProductCatalogService
{
    private readonly IReadRepository<Product> _readRepo;
    public ProductCatalogService(IReadRepository<Product> readRepo) => _readRepo = readRepo;
}
```

### Dependency Inversion Principle (DIP)

```csharp
// High-level module (service) depends on abstraction (interface)
// Low-level module (repository) implements the abstraction
// ASP.NET Core DI wires them at runtime

// Application layer
public class ProductService : IProductService        // High-level
{
    private readonly IProductRepository _repo;        // Abstraction
    public ProductService(IProductRepository repo) => _repo = repo;
}

// Infrastructure layer
public class ProductRepository : IProductRepository  // Low-level
{
    private readonly AppDbContext _ctx;
    public ProductRepository(AppDbContext ctx) => _ctx = ctx;
}
```

---

## 5. MVC Folder Structure & Conventions

### ASP.NET Core MVC — Full Clean Architecture Layout

```
MyApp.sln
│
├── src/
│   ├── MyApp.Domain/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Events/
│   │   ├── Interfaces/
│   │   └── Exceptions/
│   │
│   ├── MyApp.Application/
│   │   ├── DTOs/
│   │   ├── Interfaces/
│   │   ├── Services/
│   │   ├── Validators/          ← FluentValidation
│   │   └── Mappings/            ← AutoMapper / manual maps
│   │
│   ├── MyApp.Infrastructure/
│   │   ├── Data/
│   │   │   ├── AppDbContext.cs
│   │   │   ├── Configurations/  ← IEntityTypeConfiguration<T>
│   │   │   └── Migrations/
│   │   ├── Repositories/
│   │   └── Services/            ← SMTP, file storage, external APIs
│   │
│   └── MyApp.Web/
│       ├── Controllers/
│       │   ├── HomeController.cs
│       │   ├── ProductController.cs
│       │   └── Api/
│       │       └── ProductsController.cs
│       ├── Views/
│       │   ├── Home/
│       │   ├── Product/
│       │   └── Shared/
│       │       ├── _Layout.cshtml
│       │       ├── _LoginPartial.cshtml
│       │       ├── _ValidationScriptsPartial.cshtml
│       │       └── Error.cshtml
│       ├── ViewModels/
│       ├── Filters/
│       ├── Middleware/
│       ├── wwwroot/
│       │   ├── css/
│       │   ├── js/
│       │   └── lib/
│       ├── _ViewImports.cshtml
│       ├── _ViewStart.cshtml
│       ├── appsettings.json
│       ├── appsettings.Development.json
│       └── Program.cs
│
└── tests/
    ├── MyApp.Domain.Tests/
    ├── MyApp.Application.Tests/
    └── MyApp.Integration.Tests/
```

### _ViewImports.cshtml

```cshtml
@using MyApp.Web
@using MyApp.Web.ViewModels
@using Microsoft.AspNetCore.Identity
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
@addTagHelper *, MyApp.Web
```

### Areas — for large applications

```csharp
// Organise admin, shop, api into separate areas
MyApp.Web/
├── Areas/
│   ├── Admin/
│   │   ├── Controllers/
│   │   └── Views/
│   └── Shop/
│       ├── Controllers/
│       └── Views/

// Area controller attribute
[Area("Admin")]
public class DashboardController : Controller { }

// Program.cs
app.MapControllerRoute("areas",
    "{area:exists}/{controller=Dashboard}/{action=Index}/{id?}");
```