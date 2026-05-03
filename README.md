# Demo Blazor .NET 8 Ecommerce Phone Shop

A full-stack demo ecommerce application for a phone shop, built with Blazor WebAssembly and ASP.NET Core .NET 8.

## Solution Overview

Solution file: `DemoBlazorDotnet8EcormmercePhoneShopSolution.sln`

This solution contains three projects:

- `PhoneShopServer` — ASP.NET Core Web API + EF Core (hosts the Blazor WASM client)
- `PhoneShopClient` — Blazor WebAssembly frontend
- `PhoneShopSharedLibrary` — shared DTOs, models, and response contracts

## Architecture

### 1) PhoneShopServer

Path: `PhoneShopServer/`

Responsibilities:

- Exposes REST API endpoints for products, categories, and account/authentication workflows.
- Uses Entity Framework Core with SQL Server (`AppDbContext`) for data access.
- Implements repository pattern for clean data-layer separation.
- Hosts and serves the Blazor WebAssembly client in a hosted Blazor setup.

Key folders/files:

- `Controllers/`:
  - `ProductController.cs`
  - `CategoryController.cs`
  - `AccountController.cs`
- `Data/`:
  - `AppDbContext.cs` — registers `Products`, `Categories`, `UserAccounts`, `SystemRoles`, `UserRoles`, `TokenInfo`
  - `UserAccount.cs`, `TokenInfo.cs`, `SystemRole.cs`, `UserRole.cs`
- `Repositories/`:
  - `IProduct` / `ProductRepository`
  - `ICategory` / `CategoryRepository`
  - `IUserAccount` / `UserAccountRepository`
- `Migrations/`:
  - EF Core migration history (initial migration: `20231218135703_First`)
- `Program.cs`:
  - Service registration, EF Core, Swagger, middleware, and fallback to `index.html`

### 2) PhoneShopClient

Path: `PhoneShopClient/`

Responsibilities:

- Provides the Blazor WebAssembly UI for browsing products, login/register, category management, and cart operations.
- Uses typed `HttpClient` services to consume backend API endpoints.
- Implements token-based authentication state handling with `Blazored.LocalStorage`.

Key folders/files:

- `Pages/`:
  - Product pages, category pages, cart page, account pages
- `Authentication/`:
  - `AuthenticationService.cs`
  - `CustomAuthenticationStateProvider.cs`
  - `TokenProp.cs`
- `Services/`:
  - API-facing services and abstractions (`IProductService.cs`, `ICategoryService.cs`, etc.)
- `Layout/`:
  - Navigation, menu, main layout
- `wwwroot/`:
  - Static assets, CSS, JS

### 3) PhoneShopSharedLibrary

Path: `PhoneShopSharedLibrary/`

Responsibilities:

- Defines shared contracts used by both server and client.
- Prevents duplication and keeps API payloads consistent.

Key folders/files:

- `DTOs/`:
  - `LoginDTO.cs`, `PostRefreshTokenDTO.cs`, `UserDTO.cs`, `UserSession.cs`
- `Models/`:
  - `Product.cs`, `Category.cs`
- `Responses/`:
  - `ServiceResponse.cs`

## Tech Stack

- .NET 8
- ASP.NET Core Web API
- Blazor WebAssembly (hosted — served by the server project)
- Entity Framework Core 8 with SQL Server provider
- BCrypt.Net-Next for password hashing
- Syncfusion Blazor components (Navigations, Themes)
- Blazored.LocalStorage for client-side token storage
- Swashbuckle / Swagger UI for API exploration

## Prerequisites

Install the following:

- .NET SDK 8.0+
- SQL Server (local or remote) — the default connection string targets `(local)` with Windows authentication
- Optional tools:
  - Visual Studio 2022+ or VS Code with C# Dev Kit
  - Git
  - `dotnet-ef` global tool (see step 4 below)

## Getting Started

### 1) Clone repository

```bash
git clone https://github.com/sisovin/DemoBlazorDotnet8EcormmercePhoneShop.git
cd DemoBlazorDotnet8EcormmercePhoneShopSolution
```

### 2) Restore dependencies

```bash
dotnet restore DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
```

### 3) Configure settings

Update the connection string in `PhoneShopServer/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "Default": "Server=(local); Database=YouShopDb; Trusted_Connection=True; TrustServerCertificate=True;"
  }
}
```

Override for development in `PhoneShopServer/appsettings.Development.json` if needed.

### 4) Apply database migrations

If `dotnet ef` is not installed:

```bash
dotnet tool install --global dotnet-ef
```

From the solution root:

```bash
dotnet ef database update --project PhoneShopServer
```

### 5) Run the application

```bash
dotnet run --project PhoneShopServer
```

`PhoneShopClient` is a hosted Blazor WebAssembly project — it is compiled and served automatically by `PhoneShopServer`. Open the URL shown in the console output (usually `https://localhost:5001`).

## Build and Test

Build the whole solution:

```bash
dotnet build DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
```

Run tests (when test projects are added):

```bash
dotnet test
```

## API Notes

Main API areas:

- `GET/POST/PUT/DELETE /api/product`
- `GET/POST/PUT/DELETE /api/category`
- `POST /api/account/login`, `/api/account/register`, `/api/account/refresh-token`

Swagger UI is available at `https://localhost:5001/swagger` when running in Development mode.

See controller classes under `PhoneShopServer/Controllers/` for actual routes and request/response formats.

## Authentication Flow (High Level)

- User logs in or registers from `PhoneShopClient` account pages.
- Client `AuthenticationService` calls server account endpoints.
- Access and refresh tokens are stored via `Blazored.LocalStorage`.
- `CustomAuthenticationStateProvider` reads token state and exposes it to protected UI and API calls.
- Refresh tokens are cycled server-side and stored in the `TokenInfo` table.

## CI/CD

A GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and pull request:

- Validates required repository files and structure.
- Runs the UI pre-commit checker in strict mode for React, Vue, and Tailwind files.

## Repository Structure

```text
DemoBlazorDotnet8EcormmercePhoneShopSolution/
├── DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
├── setup.ps1
├── README.md
├── PhoneShopServer/
│   ├── Controllers/
│   ├── Data/
│   ├── Migrations/
│   ├── Repositories/
│   └── Program.cs
├── PhoneShopClient/
│   ├── Authentication/
│   ├── Layout/
│   ├── Pages/
│   ├── Services/
│   └── wwwroot/
├── PhoneShopSharedLibrary/
│   ├── DTOs/
│   ├── Models/
│   └── Responses/
├── references/
│   └── (architecture, backend, database, frontend, and other reference docs)
└── scripts/
    └── (PowerShell helper scripts)
```

## Roadmap Ideas

- Add unit and integration tests
- Add product image upload and storage
- Add order checkout and payment simulation
- Add admin dashboard and analytics
- Add deployment configuration (Docker, Azure App Service)

## Contributing

1. Create a feature branch.
2. Make focused commits.
3. Open a pull request with a clear description and screenshots for UI changes.

## License

This is a demo project for learning and experimentation.
Add your preferred license if this repository is intended for public reuse.
