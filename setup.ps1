#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bootstraps the PhoneShop solution: creates the .sln file and links all three projects.
.DESCRIPTION
    Run once from the root of the repository:
        .\setup.ps1
    Then update appsettings.json in PhoneShopServer with your SQL Server connection string,
    run EF migrations, and start the server project.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Creating PhoneShop solution…" -ForegroundColor Cyan
dotnet new sln -n DemoBlazorDotnet8EcormmercePhoneShopSolution --force

Write-Host "Adding projects to solution…" -ForegroundColor Cyan
dotnet sln DemoBlazorDotnet8EcormmercePhoneShopSolution.sln add PhoneShopSharedLibrary/PhoneShopSharedLibrary.csproj
dotnet sln DemoBlazorDotnet8EcormmercePhoneShopSolution.sln add PhoneShopServer/PhoneShopServer.csproj
dotnet sln DemoBlazorDotnet8EcormmercePhoneShopSolution.sln add PhoneShopClient/PhoneShopClient.csproj

Write-Host "Restoring NuGet packages…" -ForegroundColor Cyan
dotnet restore

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Edit PhoneShopServer/appsettings.json with your SQL Server connection string."
Write-Host "  2. Apply EF Core migrations:"
Write-Host "       cd PhoneShopServer"
Write-Host "       dotnet ef migrations add InitialCreate -o Data/Migrations"
Write-Host "       dotnet ef database update"
Write-Host "  3. Start the application: dotnet run --project PhoneShopServer"
Write-Host "     (PhoneShopClient is hosted by PhoneShopServer — no separate run needed)"
Write-Host "  4. OpenAPI UI: https://localhost:5001/swagger"
