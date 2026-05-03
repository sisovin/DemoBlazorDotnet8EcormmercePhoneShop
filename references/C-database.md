# Section C — Database Skills (MySQL)

## Table of Contents
1. [MySQL Integration — Entity Framework Core](#1-mysql-integration--entity-framework-core)
2. [DbContext Design & Configuration](#2-dbcontext-design--configuration)
3. [Entity & Schema Design](#3-entity--schema-design)
4. [Migrations](#4-migrations)
5. [LINQ Query Patterns & Optimization](#5-linq-query-patterns--optimization)
6. [ADO.NET with MySQL](#6-adonet-with-mysql)
7. [Repository & Unit of Work Pattern](#7-repository--unit-of-work-pattern)
8. [Connection Pooling](#8-connection-pooling)
9. [Query Optimization](#9-query-optimization)
10. [MVC 5 / EF 6 MySQL](#10-mvc-5--ef-6-mysql)

---

## 1. MySQL Integration — Entity Framework Core

```bash
# Pomelo — recommended open-source MySQL provider
dotnet add package Pomelo.EntityFrameworkCore.MySql
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet tool install -g dotnet-ef
```

### appsettings.json

```json
{
  "ConnectionStrings": {
    "Default": "Server=localhost;Port=3306;Database=myapp_db;User=myapp_user;Password=changeme;SslMode=Required;AllowPublicKeyRetrieval=true;CharSet=utf8mb4;"
  }
}
```

### Program.cs Registration

```csharp
var connStr = builder.Configuration.GetConnectionString("Default")!;

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseMySql(
        connStr,
        ServerVersion.AutoDetect(connStr),
        mysql => mysql
            .EnableRetryOnFailure(
                maxRetryCount:             3,
                maxRetryDelay:             TimeSpan.FromSeconds(5),
                errorNumbersToAdd:         null)
            .CommandTimeout(30)
            .MigrationsAssembly("MyApp.Infrastructure"))
    .EnableSensitiveDataLogging(builder.Environment.IsDevelopment())
    .EnableDetailedErrors(builder.Environment.IsDevelopment())
    .LogTo(Console.WriteLine, builder.Environment.IsDevelopment()
        ? LogLevel.Information : LogLevel.Warning)
);
```

---

## 2. DbContext Design & Configuration

```csharp
public class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // DbSets — one per root aggregate
    public DbSet<Product>   Products   => Set<Product>();
    public DbSet<Category>  Categories => Set<Category>();
    public DbSet<Order>     Orders     => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);   // Required for Identity tables

        // Apply all IEntityTypeConfiguration<T> in assembly
        builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Global MySQL charset
        builder.HasCharSet("utf8mb4");

        // Global soft-delete query filter (applied to all BaseEntity subtypes)
        foreach (var entityType in builder.Model.GetEntityTypes())
        {
            if (typeof(BaseEntity).IsAssignableFrom(entityType.ClrType))
            {
                var method = typeof(AppDbContext)
                    .GetMethod(nameof(SetSoftDeleteFilter),
                        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!
                    .MakeGenericMethod(entityType.ClrType);
                method.Invoke(null, [builder]);
            }
        }
    }

    private static void SetSoftDeleteFilter<T>(ModelBuilder b) where T : BaseEntity
        => b.Entity<T>().HasQueryFilter(e => !e.IsDeleted);

    public override Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        // Automatic audit timestamps
        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            if (entry.State == EntityState.Added)
                entry.Entity.CreatedAt = DateTime.UtcNow;
            if (entry.State is EntityState.Added or EntityState.Modified)
                entry.Entity.UpdatedAt = DateTime.UtcNow;
        }
        return base.SaveChangesAsync(ct);
    }
}
```

---

## 3. Entity & Schema Design

### Base Entity

```csharp
public abstract class BaseEntity
{
    public int       Id        { get; set; }
    public DateTime  CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public bool      IsDeleted { get; set; }
}
```

### Domain Entities

```csharp
public class Category : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public ICollection<Product> Products { get; set; } = [];
}

public class Product : BaseEntity
{
    public string  Name        { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal Price       { get; set; }
    public int     Stock       { get; set; }
    public int     CategoryId  { get; set; }

    // Navigation
    public Category  Category   { get; set; } = null!;
    public ICollection<OrderItem> OrderItems { get; set; } = [];

    // Encapsulated domain behaviour
    public void AdjustStock(int delta)
    {
        if (Stock + delta < 0) throw new DomainException("Insufficient stock.");
        Stock += delta;
    }
}

public class Order : BaseEntity
{
    public string       UserId     { get; set; } = string.Empty;
    public OrderStatus  Status     { get; set; } = OrderStatus.Pending;
    public decimal      Total      { get; set; }
    public ApplicationUser  User   { get; set; } = null!;
    public ICollection<OrderItem> Items { get; set; } = [];

    public decimal ComputeTotal() => Items.Sum(i => i.UnitPrice * i.Quantity);
}

public class OrderItem    // No BaseEntity — value object with composite PK
{
    public int     OrderId   { get; set; }
    public int     ProductId { get; set; }
    public int     Quantity  { get; set; }
    public decimal UnitPrice { get; set; }
    public Order   Order     { get; set; } = null!;
    public Product Product   { get; set; } = null!;
}
```

### Fluent API Configurations

```csharp
public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> b)
    {
        b.ToTable("products");
        b.HasKey(p => p.Id);

        b.Property(p => p.Name)
            .IsRequired().HasMaxLength(200).HasColumnType("varchar(200)");

        b.Property(p => p.Description)
            .HasColumnType("text");

        b.Property(p => p.Price)
            .IsRequired().HasColumnType("decimal(18,2)");

        b.HasIndex(p => p.Name).HasDatabaseName("IX_products_name");
        b.HasIndex(p => p.CategoryId).HasDatabaseName("IX_products_category_id");
        b.HasIndex(p => new { p.CategoryId, p.Price })
            .HasDatabaseName("IX_products_category_price");

        b.HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class OrderItemConfiguration : IEntityTypeConfiguration<OrderItem>
{
    public void Configure(EntityTypeBuilder<OrderItem> b)
    {
        b.ToTable("order_items");
        b.HasKey(oi => new { oi.OrderId, oi.ProductId });  // Composite PK
        b.Property(oi => oi.UnitPrice).HasColumnType("decimal(18,2)");

        b.HasOne(oi => oi.Order).WithMany(o => o.Items).HasForeignKey(oi => oi.OrderId);
        b.HasOne(oi => oi.Product).WithMany(p => p.OrderItems).HasForeignKey(oi => oi.ProductId);
    }
}
```

---

## 4. Migrations

```bash
# Initial migration
dotnet ef migrations add InitialCreate \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web

# Add migration after schema change
dotnet ef migrations add AddProductStock \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web

# Apply pending migrations to DB
dotnet ef database update \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web

# Rollback to a specific migration
dotnet ef database update AddProductStock \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web

# Generate idempotent SQL script for DBA review / production
dotnet ef migrations script --idempotent \
  --output sql/migrations.sql \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web

# Remove the latest unapplied migration
dotnet ef migrations remove \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Web
```

### Auto-apply in Program.cs (development / staging only)

```csharp
if (!app.Environment.IsProduction())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}
```

### Migration with Data Seed

```csharp
public partial class SeedCategories : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.InsertData(
            table:   "categories",
            columns: ["name", "description", "created_at", "is_deleted"],
            values:  new object[,]
            {
                { "Electronics", "Electronic devices and accessories", DateTime.UtcNow, false },
                { "Clothing",    "Apparel and accessories",           DateTime.UtcNow, false }
            });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
        => migrationBuilder.DeleteData(table: "categories",
            keyColumn: "name", keyValues: ["Electronics", "Clothing"]);
}
```

---

## 5. LINQ Query Patterns & Optimization

```csharp
// ✅ AsNoTracking — read-only queries (significant perf improvement)
var products = await _ctx.Products
    .AsNoTracking()
    .Include(p => p.Category)
    .Where(p => p.Price < 500 && p.Stock > 0)
    .OrderBy(p => p.Name)
    .Select(p => new ProductDto(p.Id, p.Name, p.Price, p.Category.Name))
    .ToListAsync(ct);

// ✅ Pagination
var paged = await _ctx.Products
    .AsNoTracking()
    .Where(p => search == null || EF.Functions.Like(p.Name, $"%{search}%"))
    .OrderBy(p => p.Name)
    .Skip((page - 1) * size)
    .Take(size)
    .ToListAsync(ct);

// ✅ AsSplitQuery — avoids cartesian explosion with multiple includes
var orders = await _ctx.Orders
    .AsNoTracking()
    .AsSplitQuery()
    .Include(o => o.Items).ThenInclude(i => i.Product)
    .Include(o => o.User)
    .ToListAsync(ct);

// ✅ Compiled queries for hot paths
private static readonly Func<AppDbContext, int, Task<Product?>> GetByIdQuery =
    EF.CompileAsyncQuery((AppDbContext ctx, int id)
        => ctx.Products.AsNoTracking().FirstOrDefault(p => p.Id == id));

// ✅ Raw SQL for complex aggregations
var stats = await _ctx.Database.SqlQuery<ProductStat>(
    $"SELECT CategoryId, COUNT(*) AS Count, AVG(Price) AS AvgPrice FROM products GROUP BY CategoryId"
).ToListAsync(ct);

// ✅ Projection reduces data transferred
var names = await _ctx.Products
    .AsNoTracking()
    .Select(p => new { p.Id, p.Name })  // Only 2 columns fetched
    .ToListAsync(ct);
```

---

## 6. ADO.NET with MySQL

Use for performance-critical raw SQL that EF Core cannot express efficiently.

```bash
dotnet add package MySqlConnector   # Async-first, recommended over MySql.Data
```

```csharp
public class ReportRepository
{
    private readonly string _connStr;
    public ReportRepository(IConfiguration cfg) => _connStr = cfg.GetConnectionString("Default")!;

    public async Task<IReadOnlyList<SalesSummaryDto>> GetMonthlySalesAsync(
        int year, CancellationToken ct = default)
    {
        const string sql = """
            SELECT
                MONTH(o.created_at)   AS Month,
                COUNT(DISTINCT o.id)  AS OrderCount,
                SUM(oi.unit_price * oi.quantity) AS Revenue
            FROM orders o
            INNER JOIN order_items oi ON oi.order_id = o.id
            WHERE YEAR(o.created_at) = @Year
              AND o.is_deleted = 0
            GROUP BY MONTH(o.created_at)
            ORDER BY Month;
            """;

        await using var conn = new MySqlConnection(_connStr);
        await conn.OpenAsync(ct);

        await using var cmd = new MySqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Year", year);   // Always parameterized

        var results = new List<SalesSummaryDto>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);

        while (await reader.ReadAsync(ct))
        {
            results.Add(new SalesSummaryDto(
                reader.GetInt32("Month"),
                reader.GetInt32("OrderCount"),
                reader.GetDecimal("Revenue")));
        }

        return results;
    }
}
```

---

## 7. Repository & Unit of Work Pattern

```csharp
// Generic base
public abstract class RepositoryBase<T> : IRepository<T> where T : BaseEntity
{
    protected readonly AppDbContext Ctx;
    protected RepositoryBase(AppDbContext ctx) => Ctx = ctx;

    public IQueryable<T> Query() => Ctx.Set<T>().AsQueryable();

    public async Task<T?> GetByIdAsync(int id, CancellationToken ct = default)
        => await Ctx.Set<T>().FindAsync([id], ct);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default)
        => await Ctx.Set<T>().AsNoTracking().ToListAsync(ct);

    public async Task AddAsync(T entity, CancellationToken ct = default)
        => await Ctx.Set<T>().AddAsync(entity, ct);

    public Task UpdateAsync(T entity)
    {
        Ctx.Set<T>().Update(entity);
        return Task.CompletedTask;
    }

    public Task DeleteAsync(T entity)           // Soft delete via global filter
    {
        entity.IsDeleted = true;
        Ctx.Set<T>().Update(entity);
        return Task.CompletedTask;
    }
}

// Domain-specific queries
public class ProductRepository : RepositoryBase<Product>, IProductRepository
{
    public ProductRepository(AppDbContext ctx) : base(ctx) { }

    public async Task<IReadOnlyList<Product>> GetByCategoryAsync(
        int categoryId, CancellationToken ct = default)
        => await Ctx.Products.AsNoTracking()
            .Where(p => p.CategoryId == categoryId)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);

    public async Task<PagedResult<Product>> GetPagedAsync(
        int page, int size, string? search, CancellationToken ct = default)
    {
        var q = Ctx.Products.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(p => EF.Functions.Like(p.Name, $"%{search}%"));
        var total = await q.CountAsync(ct);
        var items = await q.OrderBy(p => p.Name).Skip((page-1)*size).Take(size).ToListAsync(ct);
        return PagedResult<Product>.Create(items, total, page, size);
    }
}

// Unit of Work
public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _ctx;

    public IProductRepository  Products   { get; }
    public ICategoryRepository Categories { get; }
    public IOrderRepository    Orders     { get; }

    public UnitOfWork(AppDbContext ctx,
        IProductRepository products, ICategoryRepository categories, IOrderRepository orders)
    {
        _ctx       = ctx;
        Products   = products;
        Categories = categories;
        Orders     = orders;
    }

    public Task<int> SaveChangesAsync(CancellationToken ct = default)
        => _ctx.SaveChangesAsync(ct);

    public Task BeginTransactionAsync()
        => _ctx.Database.BeginTransactionAsync();

    public Task CommitTransactionAsync()
        => _ctx.Database.CommitTransactionAsync();

    public Task RollbackTransactionAsync()
        => _ctx.Database.RollbackTransactionAsync();
}
```

---

## 8. Connection Pooling

Pomelo (via MySqlConnector) uses built-in connection pooling. Key settings:

```
Server=localhost;Database=myapp;User=myapp;Password=secret;
MinimumPoolSize=5;
MaximumPoolSize=100;
ConnectionTimeout=30;
ConnectionIdleTimeout=180;
ConnectionLifeTime=600;
```

EF Core manages a pool of `DbContext` instances via `AddDbContextPool`:

```csharp
builder.Services.AddDbContextPool<AppDbContext>(opt =>
    opt.UseMySql(connStr, ServerVersion.AutoDetect(connStr)),
    poolSize: 128);   // Default 1024; tune based on load testing
```

---

## 9. Query Optimization

```csharp
// ✅ Index hints — ensure queries use correct index
var products = await _ctx.Products
    .FromSqlRaw("SELECT * FROM products USE INDEX (IX_products_category_id) WHERE category_id = {0}", catId)
    .ToListAsync(ct);

// ✅ Avoid loading unnecessary columns with explicit Select
var summaries = await _ctx.Orders
    .AsNoTracking()
    .Select(o => new { o.Id, o.Status, o.Total, o.CreatedAt })  // No navigation props
    .ToListAsync(ct);

// ✅ Use Contains for IN clause (EF generates parameterized IN())
var ids = new[] { 1, 2, 3, 4, 5 };
var byIds = await _ctx.Products.Where(p => ids.Contains(p.Id)).ToListAsync(ct);

// ✅ Batch insert via AddRangeAsync
await _ctx.Products.AddRangeAsync(productsList, ct);
await _ctx.SaveChangesAsync(ct);

// ✅ Bulk operations via EF Core Execute* (EF 7+)
await _ctx.Products
    .Where(p => p.CategoryId == obsoleteCatId)
    .ExecuteUpdateAsync(set => set.SetProperty(p => p.IsDeleted, true), ct);

await _ctx.Products
    .Where(p => p.IsDeleted && p.UpdatedAt < DateTime.UtcNow.AddYears(-1))
    .ExecuteDeleteAsync(ct);   // Hard delete for purge jobs
```

---

## 10. MVC 5 / EF 6 MySQL

```bash
# NuGet Package Manager Console
Install-Package MySql.Data.EntityFramework
Install-Package EntityFramework
```

```xml
<!-- Web.config -->
<connectionStrings>
  <add name="DefaultConnection"
       connectionString="server=localhost;database=myapp;uid=root;pwd=secret;"
       providerName="MySql.Data.MySqlClient" />
</connectionStrings>
<entityFramework>
  <defaultConnectionFactory type="MySql.Data.Entity.MySqlConnectionFactory, MySql.Data.Entity.EF6" />
  <providers>
    <provider invariantName="MySql.Data.MySqlClient"
              type="MySql.Data.MySqlClient.MySqlProviderServices, MySql.Data.Entity.EF6" />
  </providers>
</entityFramework>
```

```csharp
[DbConfigurationType(typeof(MySqlEFConfiguration))]
public class AppDbContext : DbContext
{
    public AppDbContext() : base("DefaultConnection") { }
    public DbSet<Product>  Products  { get; set; }
    public DbSet<Category> Categories { get; set; }
}

// Package Manager Console
// PM> Enable-Migrations -ContextTypeName AppDbContext
// PM> Add-Migration InitialCreate
// PM> Update-Database
```