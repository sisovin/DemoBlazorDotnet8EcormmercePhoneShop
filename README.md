# Demo Blazor .NET 8 Ecommerce Phone Shop

A full-stack demo ecommerce application for a phone shop, built with Blazor WebAssembly and ASP.NET Core .NET 8.

## Solution Overview

This solution contains three projects:

- `PhoneShopServer` (ASP.NET Core Web API + EF Core)
- `PhoneShopClient` (Blazor WebAssembly frontend)
- `PhoneShopSharedLibrary` (shared DTOs, models, and response contracts)

## Architecture

### 1) PhoneShopServer

Path: `PhoneShopServer/`

Responsibilities:

- Exposes REST API endpoints for products, categories, and account/authentication workflows.
- Uses Entity Framework Core with `AppDbContext` for data access.
- Implements repositories for data operations.
- Hosts and serves the Blazor WebAssembly client in a typical hosted Blazor setup.

Key folders/files:

- `Controllers/`:
  - `ProductController.cs`
  - `CategoryController.cs`
  - `AccountController.cs`
- `Data/`:
  - `AppDbContext.cs`
  - User and token entities (`UserAccount.cs`, `TokenInfo.cs`, etc.)
- `Repositories/`:
  - Repository interfaces and implementations for products, categories, and user accounts
- `Migrations/`:
  - EF Core migration history
- `Program.cs`:
  - Service registration, middleware, API setup

### 2) PhoneShopClient

Path: `PhoneShopClient/`

Responsibilities:

- Provides the Blazor WebAssembly UI for browsing products, login/register, category management, and cart operations.
- Uses typed client services to consume backend API endpoints.
- Implements token-based authentication state handling.

Key folders/files:

- `Pages/`:
  - Product pages, category pages, cart page, account pages
- `Authentication/`:
  - `AuthenticationService.cs`
  - `CustomAuthenticationStateProvider.cs`
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
  - Login, refresh token, and user session DTOs
- `Models/`:
  - Domain models (`Product`, `Category`)
- `Responses/`:
  - Standard service response wrapper(s)

## Tech Stack

- .NET 8
- ASP.NET Core Web API
- Blazor WebAssembly (hosted)
- Entity Framework Core
- SQL database via EF Core provider (configured in server settings)
- Bootstrap / custom CSS for styling

## Prerequisites

Install the following:

- .NET SDK 8.0+
- A database engine supported by the configured EF Core provider
- Optional tools:
  - Visual Studio 2022+ or VS Code with C# extension
  - Git

## Getting Started

### 1) Clone repository

```bash
git clone https://github.com/sisovin/DemoBlazorDotnet8EcormmercePhoneShop.git
cd DemoBlazorDotnet8EcormmercePhoneShop
```

### 2) Restore dependencies

```bash
dotnet restore DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
```

### 3) Configure settings

Update server configuration if needed:

- `PhoneShopServer/appsettings.json`
- `PhoneShopServer/appsettings.Development.json`

Typical values to validate:

- Connection string
- JWT/Token configuration
- API-related environment settings

### 4) Apply database migrations

From solution root or server project directory:

```bash
dotnet ef database update --project PhoneShopServer
```

If `dotnet ef` is not installed:

```bash
dotnet tool install --global dotnet-ef
```

### 5) Run the application

```bash
dotnet run --project PhoneShopServer
```

Open the app URL shown in console output (usually `https://localhost:<port>`).

## Build and Test

Build whole solution:

```bash
dotnet build DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
```

Run tests (if test projects are added later):

```bash
dotnet test
```

## API Notes

Main API areas:

- `/api/product`
- `/api/category`
- `/api/account`

See controller classes under `PhoneShopServer/Controllers/` for actual routes and request/response formats.

## Authentication Flow (High Level)

- User logs in/registers from `PhoneShopClient` account pages.
- Client authentication services call server account endpoints.
- JWT/token data is stored and reflected through custom auth state provider.
- Protected UI and API flows consume current auth state.

## Repository Structure

```text
DemoBlazorDotnet8EcormmercePhoneShopSolution/
|- DemoBlazorDotnet8EcormmercePhoneShopSolution.sln
|- PhoneShopServer/
|- PhoneShopClient/
|- PhoneShopSharedLibrary/
```

## Roadmap Ideas

- Add unit and integration tests
- Add product image upload and CDN storage
- Add order checkout and payment simulation
- Add admin dashboard and analytics
- Add CI/CD workflow (GitHub Actions)

## Contributing

1. Create a feature branch.
2. Make focused commits.
3. Open a pull request with clear description and screenshots for UI changes.

## License

This is a demo project for learning and experimentation.
Add your preferred license if this repository is intended for public reuse.
