#!/usr/bin/env bash
# aspnet-cheatsheet.sh — ASP.NET MVC / Web API / Minimal API CLI quick reference
# Usage: bash aspnet-cheatsheet.sh [topic]
# Topics: new | ef | run | publish | docker | test | nuget | git

TOPIC="${1:-all}"

print_section() { echo -e "\n\033[1;36m══ $1 ══\033[0m"; }
cmd()            { echo -e "  \033[33m$1\033[0m  \033[2m# $2\033[0m"; }

if [[ "$TOPIC" == "new" || "$TOPIC" == "all" ]]; then
print_section "PROJECT SCAFFOLDING"
cmd "dotnet new webapi -n MyApp.Api --use-controllers"    "Web API with controllers"
cmd "dotnet new webapi -n MyApp.Api"                      "Web API (Minimal APIs default)"
cmd "dotnet new mvc   -n MyApp.Web"                       "ASP.NET Core MVC"
cmd "dotnet new sln   -n MyApp"                           "Solution file"
cmd "dotnet sln MyApp.sln add src/MyApp.Web/MyApp.Web.csproj" "Add project to solution"
cmd "dotnet new classlib -n MyApp.Domain"                 "Class library (Domain layer)"
cmd "dotnet new xunit  -n MyApp.Tests"                    "xUnit test project"
fi

if [[ "$TOPIC" == "nuget" || "$TOPIC" == "all" ]]; then
print_section "COMMON NUGET PACKAGES"
cmd "dotnet add package Pomelo.EntityFrameworkCore.MySql"        "MySQL / EF Core provider"
cmd "dotnet add package Microsoft.EntityFrameworkCore.Design"    "EF Core design tools"
cmd "dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer" "JWT auth"
cmd "dotnet add package Swashbuckle.AspNetCore"                  "Swagger / OpenAPI"
cmd "dotnet add package Serilog.AspNetCore"                      "Structured logging"
cmd "dotnet add package FluentValidation.AspNetCore"             "Fluent validators"
cmd "dotnet add package AutoMapper.Extensions.Microsoft.DependencyInjection" "Object mapping"
cmd "dotnet add package Asp.Versioning.Mvc"                      "API versioning"
cmd "dotnet add package Moq"                                     "Mocking (tests)"
cmd "dotnet add package FluentAssertions"                        "Assertion library (tests)"
cmd "dotnet add package Microsoft.AspNetCore.Mvc.Testing"        "Integration tests"
cmd "dotnet add package MySqlConnector"                          "High-perf MySQL ADO.NET"
fi

if [[ "$TOPIC" == "ef" || "$TOPIC" == "all" ]]; then
print_section "ENTITY FRAMEWORK CORE (dotnet ef)"
cmd "dotnet tool install -g dotnet-ef"                           "Install EF CLI globally"
cmd "dotnet tool update  -g dotnet-ef"                           "Update EF CLI"
cmd "dotnet ef migrations add InitialCreate -p src/MyApp.Infrastructure -s src/MyApp.Web" \
    "Add migration"
cmd "dotnet ef migrations remove           -p src/MyApp.Infrastructure -s src/MyApp.Web" \
    "Remove last migration"
cmd "dotnet ef database update             -p src/MyApp.Infrastructure -s src/MyApp.Web" \
    "Apply pending migrations"
cmd "dotnet ef database drop               -p src/MyApp.Infrastructure -s src/MyApp.Web" \
    "Drop database"
cmd "dotnet ef migrations script --idempotent -o migrations.sql -p src/MyApp.Infrastructure -s src/MyApp.Web" \
    "Generate SQL script for DBA"
cmd "dotnet ef dbcontext scaffold 'Server=...' Pomelo.EntityFrameworkCore.MySql -o Models/Generated" \
    "Scaffold from existing DB"
fi

if [[ "$TOPIC" == "run" || "$TOPIC" == "all" ]]; then
print_section "BUILD & RUN"
cmd "dotnet restore"                          "Restore NuGet packages"
cmd "dotnet build -c Release"                 "Build Release configuration"
cmd "dotnet run --project src/MyApp.Web"      "Run development server"
cmd "dotnet watch --project src/MyApp.Web"    "Run with hot reload"
cmd "dotnet clean"                            "Clean build artifacts"
fi

if [[ "$TOPIC" == "test" || "$TOPIC" == "all" ]]; then
print_section "TESTING"
cmd "dotnet test"                                                 "Run all tests"
cmd "dotnet test -c Release --no-build"                          "Test (pre-built)"
cmd "dotnet test --collect:'XPlat Code Coverage'"                "With coverage"
cmd "dotnet test --logger 'trx;LogFileName=results.trx'"         "TRX report"
cmd "dotnet test --filter 'FullyQualifiedName~ProductService'"   "Filter by name"
cmd "dotnet test --filter 'Category=Unit'"                       "Filter by trait"
fi

if [[ "$TOPIC" == "publish" || "$TOPIC" == "all" ]]; then
print_section "PUBLISH"
cmd "dotnet publish src/MyApp.Web -c Release -o ./publish"                       "Framework-dependent"
cmd "dotnet publish src/MyApp.Web -c Release -r linux-x64 --self-contained -o ./publish" \
    "Self-contained Linux"
cmd "dotnet publish src/MyApp.Web -c Release -r win-x64  --self-contained -o ./publish" \
    "Self-contained Windows"
cmd "dotnet publish src/MyApp.Web -c Release -r osx-arm64 --self-contained -o ./publish" \
    "Self-contained macOS Apple Silicon"
fi

if [[ "$TOPIC" == "docker" || "$TOPIC" == "all" ]]; then
print_section "DOCKER"
cmd "docker build -t myapp:latest ."                             "Build image"
cmd "docker run -d -p 8080:8080 --name myapp myapp:latest"      "Run container"
cmd "docker logs -f myapp"                                       "Stream logs"
cmd "docker exec -it myapp /bin/sh"                              "Shell into container"
cmd "docker-compose up -d --build"                               "Start full stack"
cmd "docker-compose down -v"                                     "Stop & remove volumes"
cmd "docker system prune -f"                                     "Remove unused resources"
fi

if [[ "$TOPIC" == "git" || "$TOPIC" == "all" ]]; then
print_section "GIT FLOW"
cmd "git checkout -b feature/APP-101-slug develop"              "Start feature branch"
cmd "git rebase origin/develop"                                  "Sync with develop"
cmd "git checkout -b hotfix/APP-999-slug main"                  "Start hotfix from main"
cmd "git tag -a v1.3.0 -m 'Release v1.3.0'"                    "Create annotated tag"
cmd "git push origin main develop --tags"                        "Push after release"
fi

echo -e "\n\033[2mRun with topic for focused output: bash aspnet-cheatsheet.sh ef\033[0m\n"