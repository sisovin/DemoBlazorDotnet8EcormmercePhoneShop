# Section F — Cross-Platform & Cloud Skills

## Table of Contents
1. [ASP.NET Core on Linux / macOS / Windows](#1-aspnet-core-on-linux--macos--windows)
2. [Kestrel Web Server](#2-kestrel-web-server)
3. [Nginx Reverse Proxy](#3-nginx-reverse-proxy)
4. [Apache Reverse Proxy](#4-apache-reverse-proxy)
5. [IIS Deployment (MVC 5 & Core)](#5-iis-deployment-mvc-5--core)
6. [Docker Containerization](#6-docker-containerization)
7. [Docker Compose — Full Stack](#7-docker-compose--full-stack)
8. [Cloud Deployment](#8-cloud-deployment)
9. [CI/CD Pipelines](#9-cicd-pipelines)

---

## 1. ASP.NET Core on Linux / macOS / Windows

```bash
# Linux — publish self-contained binary
dotnet publish src/MyApp.Web -c Release -r linux-x64 --self-contained -o ./publish/linux

# macOS (arm64 — Apple Silicon)
dotnet publish src/MyApp.Web -c Release -r osx-arm64 --self-contained -o ./publish/macos

# Windows — framework-dependent (requires .NET runtime installed)
dotnet publish src/MyApp.Web -c Release -r win-x64 --self-contained false -o ./publish/windows

# Runtime identifiers: linux-x64, linux-arm64, osx-x64, osx-arm64, win-x64, win-arm64
```

### Environment-Specific Configuration

```bash
# Linux / macOS (bash)
export ASPNETCORE_ENVIRONMENT=Production
export ConnectionStrings__Default="Server=db;Database=myapp;User=myapp;Password=secret;"
export Jwt__Key="your-secret-key-here"

# Windows PowerShell
$env:ASPNETCORE_ENVIRONMENT = "Production"
$env:ConnectionStrings__Default = "Server=db;Database=myapp;..."
```

---

## 2. Kestrel Web Server

Kestrel is the cross-platform, high-performance HTTP server built into ASP.NET Core.
In production, always place it behind a reverse proxy (Nginx, Apache, or IIS).

```csharp
// Program.cs — Kestrel configuration
builder.WebHost.ConfigureKestrel(opt =>
{
    // HTTP on 5000, HTTPS on 5001
    opt.ListenLocalhost(5000);
    opt.ListenLocalhost(5001, listenOpt =>
    {
        listenOpt.UseHttps("cert.pfx", "certpassword");
    });

    // In production: listen on all interfaces
    opt.ListenAnyIP(8080);

    // Request limits
    opt.Limits.MaxRequestBodySize        = 10 * 1024 * 1024;  // 10 MB
    opt.Limits.MaxRequestHeadersTotalSize = 32 * 1024;         // 32 KB
    opt.Limits.KeepAliveTimeout          = TimeSpan.FromMinutes(2);
    opt.Limits.RequestHeadersTimeout     = TimeSpan.FromSeconds(30);
});
```

### Forwarded Headers (behind reverse proxy)

```csharp
// Required when behind Nginx/Apache — restores real client IP and proto
builder.Services.Configure<ForwardedHeadersOptions>(opt =>
{
    opt.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    opt.KnownNetworks.Clear();   // Trust proxy's headers
    opt.KnownProxies.Clear();
});

// Must be FIRST in middleware pipeline
app.UseForwardedHeaders();
```

---

## 3. Nginx Reverse Proxy

```bash
# Install on Ubuntu
sudo apt update && sudo apt install nginx -y
sudo systemctl enable nginx
```

```nginx
# /etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name myapp.com www.myapp.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name myapp.com www.myapp.com;

    # TLS (obtained via Certbot)
    ssl_certificate     /etc/letsencrypt/live/myapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options    nosniff                                        always;
    add_header X-Frame-Options           DENY                                           always;
    add_header Referrer-Policy           "strict-origin-when-cross-origin"              always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    gzip_min_length 1000;

    # Static files — served directly by Nginx, not ASP.NET Core
    location ~* \.(css|js|ico|png|jpg|jpeg|gif|svg|woff2|ttf)$ {
        root /var/www/myapp/wwwroot;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Proxy to Kestrel
    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        keep-alive;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Auto-renew TLS
sudo certbot --nginx -d myapp.com -d www.myapp.com
sudo systemctl enable certbot.timer
```

### Systemd Service

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=MyApp ASP.NET Core Web Application
After=network.target mysql.service

[Service]
Type=notify
WorkingDirectory=/var/www/myapp
ExecStart=/var/www/myapp/MyApp.Web
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=myapp
User=www-data
Group=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000
EnvironmentFile=/etc/myapp/environment   # Secrets in separate file (chmod 600)

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
sudo journalctl -u myapp -f   # Follow logs
```

---

## 4. Apache Reverse Proxy

```bash
sudo apt install apache2 -y
sudo a2enmod proxy proxy_http proxy_balancer headers rewrite ssl
```

```apache
# /etc/apache2/sites-available/myapp.conf
<VirtualHost *:443>
    ServerName myapp.com
    SSLEngine on
    SSLCertificateFile    /etc/letsencrypt/live/myapp.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/myapp.com/privkey.pem

    ProxyPreserveHost On
    ProxyPass         / http://localhost:5000/
    ProxyPassReverse  / http://localhost:5000/

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port  "443"

    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
</VirtualHost>

<VirtualHost *:80>
    ServerName myapp.com
    Redirect permanent / https://myapp.com/
</VirtualHost>
```

---

## 5. IIS Deployment (MVC 5 & Core)

```bash
# Prerequisites (PowerShell — run as admin)
# Install ASP.NET Core Hosting Bundle for Core on IIS
Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -OutFile dotnet-install.ps1
.\dotnet-install.ps1 -Runtime dotnet -Version 8.0

# Or download the Hosting Bundle manually from:
# https://dotnet.microsoft.com/download/dotnet/8.0
```

```xml
<!-- web.config — ASP.NET Core (auto-generated by dotnet publish) -->
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*"
             modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore
          processPath="dotnet"
          arguments=".\MyApp.Web.dll"
          stdoutLogEnabled="false"
          stdoutLogFile=".\logs\stdout"
          hostingModel="inprocess">
        <environmentVariables>
          <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
        </environmentVariables>
      </aspNetCore>
    </system.webServer>
  </location>
</configuration>
```

```powershell
# Publish and deploy
dotnet publish src/MyApp.Web -c Release -o C:\inetpub\myapp

# IIS Application Pool: No Managed Code (Core runs its own runtime)
# For MVC 5: .NET CLR Version = v4.0, Managed Pipeline = Integrated
```

---

## 6. Docker Containerization

### Multi-Stage Dockerfile

```dockerfile
# ── Stage 1: Restore (layer cache) ──────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS restore
WORKDIR /src

COPY ["src/MyApp.Domain/MyApp.Domain.csproj",          "MyApp.Domain/"]
COPY ["src/MyApp.Application/MyApp.Application.csproj","MyApp.Application/"]
COPY ["src/MyApp.Infrastructure/MyApp.Infrastructure.csproj","MyApp.Infrastructure/"]
COPY ["src/MyApp.Web/MyApp.Web.csproj",                "MyApp.Web/"]

RUN dotnet restore "MyApp.Web/MyApp.Web.csproj" --locked-mode

# ── Stage 2: Build ───────────────────────────────────────────────────
FROM restore AS build
COPY src/ .
WORKDIR /src/MyApp.Web
RUN dotnet build -c Release --no-restore -o /app/build

# ── Stage 3: Publish ─────────────────────────────────────────────────
FROM build AS publish
RUN dotnet publish "MyApp.Web.csproj" -c Release --no-build \
    /p:UseAppHost=false -o /app/publish

# ── Stage 4: Runtime (smallest possible image) ───────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

COPY --from=publish --chown=appuser:appgroup /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health/live || exit 1

ENTRYPOINT ["dotnet", "MyApp.Web.dll"]
```

```bash
# Build & run
docker build -t myapp:latest .
docker run -d -p 8080:8080 \
    -e ConnectionStrings__Default="Server=host.docker.internal;..." \
    -e Jwt__Key="super-secret" \
    --name myapp myapp:latest

# View logs
docker logs -f myapp

# Shell into running container (debugging only)
docker exec -it myapp /bin/sh
```

---

## 7. Docker Compose — Full Stack

```yaml
# docker-compose.yml
version: "3.9"

services:
  app:
    build: { context: ., dockerfile: Dockerfile }
    ports: ["8080:8080"]
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__Default=Server=db;Port=3306;Database=myapp_db;User=myapp;Password=${DB_PASSWORD};
      - Jwt__Key=${JWT_KEY}
    depends_on:
      db: { condition: service_healthy }
    networks: [myapp-net]
    restart: unless-stopped

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE:      myapp_db
      MYSQL_USER:          myapp
      MYSQL_PASSWORD:      ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "myapp", "-p${DB_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks: [myapp-net]
    restart: unless-stopped

  nginx:
    image: nginx:1.25-alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/ssl/certs:ro
    depends_on: [app]
    networks: [myapp-net]
    restart: unless-stopped

volumes:
  mysql-data:

networks:
  myapp-net:
```

```bash
# .env (never commit — add to .gitignore)
DB_PASSWORD=strongpassword
DB_ROOT_PASSWORD=rootstrongpassword
JWT_KEY=min-32-char-secret-key-here

# Commands
docker-compose up -d --build        # Start stack
docker-compose logs -f app          # Stream logs
docker-compose exec app dotnet ef database update  # Run migrations in container
docker-compose down -v              # Stop and remove volumes
```

---

## 8. Cloud Deployment

### Azure App Service (Core)

```bash
# Azure CLI
az login
az group create -n myapp-rg -l eastus
az appservice plan create -n myapp-plan -g myapp-rg --sku B2 --is-linux
az webapp create -n myapp -g myapp-rg -p myapp-plan --runtime "DOTNETCORE:8.0"

# Configure connection string
az webapp config appsettings set -n myapp -g myapp-rg \
    --settings ConnectionStrings__Default="Server=mysql.database.azure.com;..."

# Deploy via zip
dotnet publish -c Release -o ./publish
cd publish && zip -r ../myapp.zip .
az webapp deployment source config-zip -n myapp -g myapp-rg --src ../myapp.zip
```

### AWS Elastic Beanstalk

```bash
# Install EB CLI
pip install awsebcli

# Initialize & deploy
eb init myapp --platform dotnet-coreclr --region us-east-1
eb create myapp-prod --instance_type t3.small
eb deploy

# Environment variables
eb setenv ConnectionStrings__Default="..." Jwt__Key="..."
```

### GCP Cloud Run (containerized)

```bash
# Build and push to GCR
docker build -t gcr.io/PROJECT_ID/myapp:latest .
docker push gcr.io/PROJECT_ID/myapp:latest

# Deploy
gcloud run deploy myapp \
    --image gcr.io/PROJECT_ID/myapp:latest \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --set-env-vars ASPNETCORE_ENVIRONMENT=Production
```

---

## 9. CI/CD Pipelines

### GitHub Actions — Full CI/CD

```yaml
# .github/workflows/main.yml
name: CI/CD Pipeline

on:
  push:    { branches: [main, develop] }
  pull_request: { branches: [main] }

env:
  DOTNET_VERSION: "8.0.x"
  IMAGE_NAME: ghcr.io/${{ github.repository }}

jobs:
  # ─── Job 1: Test ───────────────────────────────────────
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_DATABASE:      myapp_test
          MYSQL_USER:          test
          MYSQL_PASSWORD:      test
          MYSQL_ROOT_PASSWORD: root
        ports: ["3306:3306"]
        options: --health-cmd="mysqladmin ping" --health-interval=10s

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: "${{ env.DOTNET_VERSION }}" }

      - name: Cache NuGet
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}

      - run: dotnet restore
      - run: dotnet build -c Release --no-restore
      - name: Test
        env:
          ConnectionStrings__Default: "Server=127.0.0.1;Port=3306;Database=myapp_test;User=test;Password=test;"
        run: dotnet test -c Release --no-build --logger trx --collect:"XPlat Code Coverage"

      - uses: codecov/codecov-action@v4

  # ─── Job 2: Build & Push Docker ────────────────────────
  docker:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions: { contents: read, packages: write }

    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=sha
            type=semver,pattern={{version}}
            type=raw,value=latest

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags:   ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to:   type=gha,mode=max

  # ─── Job 3: Deploy ─────────────────────────────────────
  deploy:
    needs: docker
    runs-on: ubuntu-latest
    environment: production   # Requires manual approval in GitHub UI

    steps:
      - uses: appleboy/ssh-action@v1
        with:
          host:     ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key:      ${{ secrets.PROD_SSH_KEY }}
          script: |
            docker pull ghcr.io/${{ github.repository }}:latest
            docker-compose -f /opt/myapp/docker-compose.prod.yml up -d --no-deps app
            docker image prune -f
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches: { include: [main] }

pool:
  vmImage: ubuntu-latest

variables:
  buildConfiguration: Release
  dotnetVersion: "8.0.x"

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          - task: UseDotNet@2
            inputs: { version: $(dotnetVersion) }
          - task: DotNetCoreCLI@2
            displayName: Restore
            inputs: { command: restore, projects: "**/*.csproj" }
          - task: DotNetCoreCLI@2
            displayName: Build
            inputs: { command: build, arguments: "-c $(buildConfiguration) --no-restore" }
          - task: DotNetCoreCLI@2
            displayName: Test
            inputs:
              command: test
              arguments: "--no-build -c $(buildConfiguration) --collect:\"XPlat Code Coverage\""
          - task: PublishCodeCoverageResults@1
            inputs: { codeCoverageTool: Cobertura, summaryFileLocation: "**/coverage.cobertura.xml" }

  - stage: Deploy
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployToProduction
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: MyAzureServiceConnection
                    appName: myapp-prod
                    package: $(Pipeline.Workspace)/**/*.zip
```