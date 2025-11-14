#!/usr/bin/env pwsh
# =========================================
#   .NET Clean Architecture Bootstrap
#   Author: Cyberax / Vijay
#   Version: 1.6 (PowerShell)
#   Features:
#     - Safety overwrite check
#     - Defaults: Minimal API + EF=yes + Tests=no
#     - .github/copilot-instructions.md (with your Goal for Copilot)
#     - Multilingual/emoji-safe .editorconfig
#     - Git init + first commit
#     - Interactive .NET version selection
# =========================================

[CmdletBinding()]
param(
    [string]$Name,
    [switch]$Controllers,
    [switch]$NoEF,
    [switch]$Tests,
    [string]$DotNetVersion,
    [ValidateSet('sln', 'slnx')]
    [string]$SolutionFormat,
    [ValidateSet('flat', 'grouped')]
    [string]$FolderStructure
)

$ErrorActionPreference = "Stop"

Write-Host "🧭 Welcome to the .NET Clean Architecture Bootstrap" -ForegroundColor Cyan
Write-Host ""

# --- Defaults ---
$SOLUTION_NAME = $Name
$API_TYPE = if ($Controllers) { "Controllers" } else { "Minimal" }
$INCLUDE_EF = if ($NoEF) { "n" } else { "y" }
$INCLUDE_TESTS = if ($Tests) { "y" } else { "n" }

# --- Name ---
if ([string]::IsNullOrWhiteSpace($SOLUTION_NAME)) {
    do {
        $SOLUTION_NAME = Read-Host "Enter the Solution Name (e.g., ModernAstro)"
        if ([string]::IsNullOrWhiteSpace($SOLUTION_NAME)) {
            Write-Host "❌ Solution name cannot be empty" -ForegroundColor Red
        }
        elseif ($SOLUTION_NAME -match '[<>:"/\\|?*]') {
            Write-Host "❌ Solution name contains invalid characters" -ForegroundColor Red
            $SOLUTION_NAME = $null
        }
    } while ([string]::IsNullOrWhiteSpace($SOLUTION_NAME))
}

# --- Detect available .NET SDKs ---
$availableSDKs = @()
try {
    $sdkList = dotnet --list-sdks
    foreach ($sdk in $sdkList) {
        if ($sdk -match '^([\d\\.]+)') {
            $version = $matches[1]
            $majorVersion = $version.Split('.')[0]
            $availableSDKs += [PSCustomObject]@{
                Version = $version
                Major = [int]$majorVersion
                Display = ".NET $majorVersion ($version)"
            }
        }
    }
    $availableSDKs = $availableSDKs | Sort-Object Major -Descending
} catch {
    Write-Host "⚠️  Could not detect installed SDKs" -ForegroundColor Yellow
}

# --- Select .NET Version ---
$DOTNET_VERSION = $DotNetVersion
if ([string]::IsNullOrWhiteSpace($DOTNET_VERSION) -and $availableSDKs.Count -gt 0) {
    Write-Host ""
    Write-Host "Available .NET SDKs:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $availableSDKs.Count; $i++) {
        $sdk = $availableSDKs[$i]
        $defaultMarker = if ($i -eq 0) { " (latest)" } else { "" }
        Write-Host "  [$($i + 1)] $($sdk.Display)$defaultMarker"
    }
    Write-Host ""
    
    $defaultChoice = 1
    $defaultDisplay = $availableSDKs[0].Display
    $selection = Read-Host "Select .NET version [1-$($availableSDKs.Count)] (default: $defaultChoice - $defaultDisplay)"
    
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $selection = $defaultChoice
    }
    
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $availableSDKs.Count) {
        $DOTNET_VERSION = $availableSDKs[$index].Version
        $DOTNET_MAJOR = $availableSDKs[$index].Major
    } else {
        Write-Host "❌ Invalid selection" -ForegroundColor Red
        exit 1
    }
} elseif ([string]::IsNullOrWhiteSpace($DOTNET_VERSION)) {
    # Fallback if no SDKs detected
    $DOTNET_VERSION = "8.0.100"
    $DOTNET_MAJOR = 8
    Write-Host "⚠️  Using default: .NET $DOTNET_MAJOR" -ForegroundColor Yellow
} else {
    # Version specified via parameter
    $DOTNET_MAJOR = $DOTNET_VERSION.Split('.')[0]
}

Write-Host ""
Write-Host "📦 Selected .NET $DOTNET_MAJOR (SDK: $DOTNET_VERSION)" -ForegroundColor Green

# --- Solution Format ---
$SOLUTION_FORMAT = $SolutionFormat
if ([string]::IsNullOrWhiteSpace($SOLUTION_FORMAT)) {
    Write-Host ""
    Write-Host "Solution Format:" -ForegroundColor Cyan
    Write-Host "  [1] .sln (Classic)"
    Write-Host "  [2] .slnx (New XML format)"
    Write-Host ""
    
    $formatInput = Read-Host "Select format [1-2] (default: 2 - slnx)"
    
    if ([string]::IsNullOrWhiteSpace($formatInput) -or $formatInput -eq "2") {
        $SOLUTION_FORMAT = "slnx"
    } elseif ($formatInput -eq "1") {
        $SOLUTION_FORMAT = "sln"
    } else {
        Write-Host "❌ Invalid selection, using default: slnx" -ForegroundColor Yellow
        $SOLUTION_FORMAT = "slnx"
    }
}

Write-Host "📄 Solution format: .$SOLUTION_FORMAT" -ForegroundColor Green

# --- Folder Structure ---
$FOLDER_STRUCTURE = $FolderStructure
if ([string]::IsNullOrWhiteSpace($FOLDER_STRUCTURE)) {
    Write-Host ""
    Write-Host "Project Organization:" -ForegroundColor Cyan
    Write-Host "  [1] Flat (all projects in src/)"
    Write-Host "  [2] Grouped (organized in Core/Infrastructure/Presentation/)"
    Write-Host ""
    
    $structureInput = Read-Host "Select structure [1-2] (default: 1 - flat)"
    
    if ([string]::IsNullOrWhiteSpace($structureInput) -or $structureInput -eq "1") {
        $FOLDER_STRUCTURE = "flat"
    } elseif ($structureInput -eq "2") {
        $FOLDER_STRUCTURE = "grouped"
    } else {
        Write-Host "❌ Invalid selection, using default: flat" -ForegroundColor Yellow
        $FOLDER_STRUCTURE = "flat"
    }
}

Write-Host "📂 Structure: $FOLDER_STRUCTURE" -ForegroundColor Green

# --- Base dir ---
$baseInput = Read-Host "Base directory [default: C:\Projects]"
if ([string]::IsNullOrWhiteSpace($baseInput)) {
    $BASE_DIR = "C:\Projects"
} else {
    # Handle ~ and relative paths properly
    $baseInput = $baseInput.Replace("~", $HOME)
    $BASE_DIR = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($baseInput)
}
$ROOT_DIR = Join-Path $BASE_DIR $SOLUTION_NAME

# --- Validate base directory ---
if (-not (Test-Path $BASE_DIR)) {
    Write-Host "📁 Base directory doesn't exist. Creating: $BASE_DIR" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $BASE_DIR -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "❌ Failed to create base directory: $_" -ForegroundColor Red
        exit 1
    }
}

# --- Safety ---
if (Test-Path $ROOT_DIR) {
    Write-Host "⚠️  Folder already exists: $ROOT_DIR" -ForegroundColor Yellow
    Write-Host "❌ Aborting to prevent overwriting. Delete/rename it and rerun." -ForegroundColor Red
    exit 1
}

# --- Interactive defaults ---
Write-Host ""
$apiInput = Read-Host "API Type [Minimal/Controllers] (default: $API_TYPE)"
if (-not [string]::IsNullOrWhiteSpace($apiInput)) {
    $API_TYPE = $apiInput
}
$API_TYPE = (Get-Culture).TextInfo.ToTitleCase($API_TYPE.ToLower())

$efInput = Read-Host "Include Entity Framework? (y/n, default: $INCLUDE_EF)"
if (-not [string]::IsNullOrWhiteSpace($efInput)) {
    $INCLUDE_EF = $efInput
}

$testsInput = Read-Host "Include Test Project? (y/n, default: $INCLUDE_TESTS)"
if (-not [string]::IsNullOrWhiteSpace($testsInput)) {
    $INCLUDE_TESTS = $testsInput
}

Write-Host ""
Write-Host "🧱 Summary" -ForegroundColor Cyan
Write-Host "  Name:        $SOLUTION_NAME"
Write-Host "  Base:        $BASE_DIR"
Write-Host "  .NET:        $DOTNET_MAJOR"
Write-Host "  Solution:    .$SOLUTION_FORMAT"
Write-Host "  Structure:   $FOLDER_STRUCTURE"
Write-Host "  API:         $API_TYPE"
Write-Host "  EF:          $INCLUDE_EF"
Write-Host "  Tests:       $INCLUDE_TESTS"
Write-Host ""

# --- Create structure ---
$SRC_DIR = Join-Path $ROOT_DIR "src"
$TESTS_DIR = Join-Path $ROOT_DIR "tests"
New-Item -ItemType Directory -Path $SRC_DIR -Force | Out-Null

# Define project paths based on structure
if ($FOLDER_STRUCTURE -eq "grouped") {
    $CORE_DIR = Join-Path $SRC_DIR "Core"
    $INFRASTRUCTURE_DIR = Join-Path $SRC_DIR "Infrastructure"
    $PRESENTATION_DIR = Join-Path $SRC_DIR "Presentation"
    
    New-Item -ItemType Directory -Path $CORE_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $INFRASTRUCTURE_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $PRESENTATION_DIR -Force | Out-Null
    
    $API_PATH = "src/Presentation/$SOLUTION_NAME.Api"
    $APPLICATION_PATH = "src/Core/$SOLUTION_NAME.Application"
    $DOMAIN_PATH = "src/Core/$SOLUTION_NAME.Domain"
    $INFRASTRUCTURE_PATH = "src/Infrastructure/$SOLUTION_NAME.Infrastructure"
} else {
    $API_PATH = "src/$SOLUTION_NAME.Api"
    $APPLICATION_PATH = "src/$SOLUTION_NAME.Application"
    $DOMAIN_PATH = "src/$SOLUTION_NAME.Domain"
    $INFRASTRUCTURE_PATH = "src/$SOLUTION_NAME.Infrastructure"
}

Set-Location $ROOT_DIR

# --- Solution ---
if ($SOLUTION_FORMAT -eq "slnx") {
    dotnet new sln -n $SOLUTION_NAME --format slnx
} else {
    dotnet new sln -n $SOLUTION_NAME
}

# --- Projects ---
if ($FOLDER_STRUCTURE -eq "grouped") {
    Set-Location $PRESENTATION_DIR
    if ($API_TYPE -ieq "Controllers") {
        dotnet new webapi --use-controllers -n "$SOLUTION_NAME.Api"
    } else {
        dotnet new webapi -n "$SOLUTION_NAME.Api"
    }
    
    Set-Location $CORE_DIR
    dotnet new classlib -n "$SOLUTION_NAME.Application"
    dotnet new classlib -n "$SOLUTION_NAME.Domain"
    
    Set-Location $INFRASTRUCTURE_DIR
    dotnet new classlib -n "$SOLUTION_NAME.Infrastructure"
} else {
    Set-Location $SRC_DIR
    if ($API_TYPE -ieq "Controllers") {
        dotnet new webapi --use-controllers -n "$SOLUTION_NAME.Api"
    } else {
        dotnet new webapi -n "$SOLUTION_NAME.Api"
    }
    dotnet new classlib -n "$SOLUTION_NAME.Application"
    dotnet new classlib -n "$SOLUTION_NAME.Domain"
    dotnet new classlib -n "$SOLUTION_NAME.Infrastructure"
}

# --- Add to solution ---
Set-Location $ROOT_DIR
dotnet sln add "$API_PATH/$SOLUTION_NAME.Api.csproj"
dotnet sln add "$APPLICATION_PATH/$SOLUTION_NAME.Application.csproj"
dotnet sln add "$DOMAIN_PATH/$SOLUTION_NAME.Domain.csproj"
dotnet sln add "$INFRASTRUCTURE_PATH/$SOLUTION_NAME.Infrastructure.csproj"

# --- References ---
Set-Location "$ROOT_DIR/$API_PATH"
if ($FOLDER_STRUCTURE -eq "grouped") {
    dotnet add reference "../../Core/$SOLUTION_NAME.Application/$SOLUTION_NAME.Application.csproj"
    dotnet add reference "../../Infrastructure/$SOLUTION_NAME.Infrastructure/$SOLUTION_NAME.Infrastructure.csproj"
} else {
    dotnet add reference "../$SOLUTION_NAME.Application/$SOLUTION_NAME.Application.csproj"
    dotnet add reference "../$SOLUTION_NAME.Infrastructure/$SOLUTION_NAME.Infrastructure.csproj"
}

Set-Location "$ROOT_DIR/$APPLICATION_PATH"
dotnet add reference "../$SOLUTION_NAME.Domain/$SOLUTION_NAME.Domain.csproj"

Set-Location "$ROOT_DIR/$INFRASTRUCTURE_PATH"
if ($FOLDER_STRUCTURE -eq "grouped") {
    dotnet add reference "../../Core/$SOLUTION_NAME.Domain/$SOLUTION_NAME.Domain.csproj"
} else {
    dotnet add reference "../$SOLUTION_NAME.Domain/$SOLUTION_NAME.Domain.csproj"
}

# --- Tests (optional) ---
if ($INCLUDE_TESTS -ieq "y") {
    Write-Host "🧪 Adding test project..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $TESTS_DIR -Force | Out-Null
    Set-Location $TESTS_DIR
    dotnet new xunit -n "$SOLUTION_NAME.UnitTests"
    dotnet sln "$ROOT_DIR/$SOLUTION_NAME.$SOLUTION_FORMAT" add "$SOLUTION_NAME.UnitTests/$SOLUTION_NAME.UnitTests.csproj"
}

# --- EF (optional) ---
if ($INCLUDE_EF -ieq "y") {
    Write-Host "🗃️  Adding EF Core packages..." -ForegroundColor Cyan
    Set-Location "$ROOT_DIR/$INFRASTRUCTURE_PATH"
    dotnet add package Microsoft.EntityFrameworkCore.Sqlite
    dotnet add package Microsoft.EntityFrameworkCore.Design
}

# --- Root files ---
Set-Location $ROOT_DIR
dotnet new gitignore

@"
{
  "sdk": {
    "version": "$DOTNET_VERSION"
  }
}
"@ | Out-File -FilePath "global.json" -Encoding UTF8

# Multilingual & emoji-safe .editorconfig
@"
# =========================================
#   .editorconfig for $SOLUTION_NAME
#   Multilingual, emoji-safe, clean defaults
# =========================================
root = true

[*]
charset = utf-8-bom
end_of_line = crlf
insert_final_newline = true
indent_style = space
indent_size = 4
trim_trailing_whitespace = true

# Unicode/emoji friendly
dotnet_allow_unsafe_characters_in_string_literals = true
csharp_allow_unicode_literals = true

# Multilingual intent (hints for AI/tools)
csharp_style_allow_multiple_languages = true
csharp_prefer_utf8_literals = true

# Typing style
csharp_style_var_elsewhere = true:suggestion
csharp_style_var_for_built_in_types = false:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion

# Modern C#
csharp_prefer_static_local_function = true:suggestion
csharp_style_expression_bodied_methods = when_on_single_line
csharp_style_prefer_collection_expression = true:suggestion
csharp_style_namespace_declarations = file_scoped:suggestion

# Minimal header example
file_header_template = "© Cyberax Media – $SOLUTION_NAME"

[*.json]
indent_size = 2

[*.cs]
insert_final_newline = true
"@ | Out-File -FilePath ".editorconfig" -Encoding UTF8

# --- Copilot instructions ---
New-Item -ItemType Directory -Path ".github" -Force | Out-Null
@"
# 🧭 $SOLUTION_NAME – Copilot Coding Guide

## Overview
This repository follows **Clean Architecture** on **.NET $DOTNET_MAJOR** with four key layers:

``````
src/
 ├── $SOLUTION_NAME.Api/             → Presentation Layer (Minimal API / Controllers)
 ├── $SOLUTION_NAME.Application/     → Business Logic (CQRS, Validation, Use Cases)
 ├── $SOLUTION_NAME.Domain/          → Entities, Value Objects, Domain Rules
 └── $SOLUTION_NAME.Infrastructure/  → Database, EF Core, External Services
``````

## Defaults
API Type: $API_TYPE
EF Core: $INCLUDE_EF
Tests: $INCLUDE_TESTS
API docs (Swagger/Redoc/Scalar) are not included by default; add later as needed.

## Layer Responsibilities
Domain: Core entities, value objects, invariants. No external deps.
Application: Use cases, CQRS handlers, validation. Framework-agnostic.
Infrastructure: Persistence (EF Core), external services. Implements interfaces.
API: Routing, transport models, DI configuration. No business logic.

---

---

## Goal for Copilot

When Copilot generates code, it should:

Architecture:
- Follow Clean Architecture with strict layer boundaries
- Store ALL data in src/$SOLUTION_NAME.Infrastructure/Data/
- Keep Domain minimal (10%), Application complex (80%), Infrastructure lean (10%)
- Use dependency inversion pattern religiously

Code Quality:
- Produce optimized, clean C# 12 code ready for production
- Follow async/await conventions with CancellationToken
- Use dependency injection for all services
- Include comprehensive XML documentation
- Generate corresponding unit tests

Organization:
- Follow feature-first folder structure
- Use proper naming conventions (kebab-case JSON, PascalCase C#)
- Separate core data from translations
- Avoid redundant logic between API and Application

Best Practices:
- Apply SOLID, KISS, DRY principles
- Use records for immutable DTOs
- Implement proper error handling
- Add logging where appropriate
- Follow i18n zero-duplication pattern

Remember: Use the decision trees, anti-patterns guide, and pre-commit checklist above when generating any code. Quality over speed!

---

## Working Agreements
- Keep presentation thin; all business logic in Application.
- Validation via FluentValidation or .NET validation in Application.
- Prefer async I/O, structured logging, DI for all deps.
- Secrets via user-secrets/env vars; never commit credentials.

### Generated by: Cyberax Clean Architecture Bootstrap (v1.6)
"@ | Out-File -FilePath ".github/copilot-instructions.md" -Encoding UTF8

# --- README.md ---
@"
# $SOLUTION_NAME

> A clean architecture .NET $DOTNET_MAJOR application built with modern best practices.

## 🏛️ Architecture

This project follows **Clean Architecture** principles with clear separation of concerns:

$(if ($FOLDER_STRUCTURE -eq "grouped") { @"
``````
src/
├── Core/
│   ├── $SOLUTION_NAME.Domain/          # Core Domain Models & Rules
│   └── $SOLUTION_NAME.Application/     # Business Logic & Use Cases
├── Infrastructure/
│   └── $SOLUTION_NAME.Infrastructure/  # Data Access & External Services
└── Presentation/
    └── $SOLUTION_NAME.Api/             # REST API Endpoints
``````
"@ } else { @"
``````
src/
├── $SOLUTION_NAME.Api/             # Presentation Layer (REST API)
├── $SOLUTION_NAME.Application/     # Business Logic & Use Cases
├── $SOLUTION_NAME.Domain/          # Core Domain Models & Rules
└── $SOLUTION_NAME.Infrastructure/  # Data Access & External Services
``````
"@ })

### Layer Responsibilities

- **Domain**: Core business entities, value objects, and domain logic. No external dependencies.
- **Application**: Use cases, business workflows, validation, and application services. Framework-agnostic.
- **Infrastructure**: Database access (EF Core), external APIs, file system, and other I/O operations.
- **API**: HTTP endpoints, request/response models, dependency injection configuration.

## 🚀 Quick Start

### Prerequisites

- [.NET $DOTNET_MAJOR SDK](https://dotnet.microsoft.com/download/dotnet/$DOTNET_MAJOR)
- [Visual Studio Code](https://code.visualstudio.com/) or [Visual Studio 2022](https://visualstudio.microsoft.com/)
$(if ($INCLUDE_EF -ieq "y") { "- [SQLite](https://www.sqlite.org/) (included with EF Core)" } else { "" })

### Running the Application

``````bash
# Restore dependencies
dotnet restore

# Run the API
dotnet run --project $API_PATH

# Or with hot reload
dotnet watch --project $API_PATH
``````

The API will be available at:
- **HTTP**: http://localhost:5000
- **HTTPS**: https://localhost:5001
$(if ($API_TYPE -ieq "Minimal") { "- **Swagger UI**: https://localhost:5001/swagger" } else { "- **Swagger UI**: https://localhost:5001/swagger" })

$(if ($INCLUDE_TESTS -ieq "y") { @"

### Running Tests

``````bash
# Run all tests
dotnet test

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run specific test project
dotnet test tests/$SOLUTION_NAME.UnitTests
``````
"@ } else { "" })

## 📦 Project Structure

$(if ($FOLDER_STRUCTURE -eq "grouped") { @"
``````
$SOLUTION_NAME/
├── src/
│   ├── Core/
│   │   ├── $SOLUTION_NAME.Domain/
│   │   │   ├── Entities/                     # Domain entities
│   │   │   ├── ValueObjects/                 # Immutable value objects
│   │   │   └── Exceptions/                   # Domain exceptions
│   │   └── $SOLUTION_NAME.Application/
│   │       ├── Common/                       # Shared application logic
│   │       ├── Features/                     # Feature-based organization
│   │       └── Interfaces/                   # Application service contracts
│   ├── Infrastructure/
│   │   └── $SOLUTION_NAME.Infrastructure/
│   │       ├── Data/                         # Database context & migrations
│   │       ├── Repositories/                 # Data access implementations
│   │       └── Services/                     # External service integrations
│   └── Presentation/
│       └── $SOLUTION_NAME.Api/
│           ├── Program.cs                    # Application entry point
│           ├── appsettings.json              # Configuration
│           └── Properties/
"@ } else { @"
``````
$SOLUTION_NAME/
├── src/
│   ├── $SOLUTION_NAME.Api/
│   │   ├── Program.cs                    # Application entry point
│   │   ├── appsettings.json              # Configuration
│   │   └── Properties/
│   ├── $SOLUTION_NAME.Application/
│   │   ├── Common/                       # Shared application logic
│   │   ├── Features/                     # Feature-based organization
│   │   └── Interfaces/                   # Application service contracts
│   ├── $SOLUTION_NAME.Domain/
│   │   ├── Entities/                     # Domain entities
│   │   ├── ValueObjects/                 # Immutable value objects
│   │   └── Exceptions/                   # Domain exceptions
│   └── $SOLUTION_NAME.Infrastructure/
│       ├── Data/                         # Database context & migrations
│       ├── Repositories/                 # Data access implementations
│       └── Services/                     # External service integrations
"@ })
$(if ($INCLUDE_TESTS -ieq "y") { @"
├── tests/
│   └── $SOLUTION_NAME.UnitTests/        # Unit tests
"@ } else { "" })
├── .editorconfig                         # Code style rules
├── .gitignore                            # Git ignore rules
├── global.json                           # .NET SDK version
└── $SOLUTION_NAME.$SOLUTION_FORMAT                       # Solution file
``````

## 🛠️ Technology Stack

- **.NET $DOTNET_MAJOR**: Latest LTS runtime
- **ASP.NET Core**: $(if ($API_TYPE -ieq "Minimal") { "Minimal APIs" } else { "Web API with Controllers" })
$(if ($INCLUDE_EF -ieq "y") { "- **Entity Framework Core**: SQLite for development" } else { "" })
$(if ($INCLUDE_TESTS -ieq "y") { "- **xUnit**: Testing framework" } else { "" })
- **Clean Architecture**: Dependency inversion & separation of concerns

## 🔧 Configuration

### Development Settings

Edit ``src/$SOLUTION_NAME.Api/appsettings.Development.json``:

``````json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
``````

### User Secrets

Store sensitive configuration using user secrets:

``````bash
cd src/$SOLUTION_NAME.Api
dotnet user-secrets init
dotnet user-secrets set "ApiKey" "your-secret-key"
``````

$(if ($INCLUDE_EF -ieq "y") { @"
## 📊 Database

### Migrations

``````bash
# Add a new migration
dotnet ef migrations add InitialCreate --project $INFRASTRUCTURE_PATH --startup-project $API_PATH

# Update database
dotnet ef database update --project $INFRASTRUCTURE_PATH --startup-project $API_PATH

# Remove last migration
dotnet ef migrations remove --project $INFRASTRUCTURE_PATH --startup-project $API_PATH
``````

### Connection String

The default SQLite connection string is in ``appsettings.json``:

``````json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=$SOLUTION_NAME.db"
  }
}
``````
"@ } else { "" })

## 📝 Development Workflow

1. **Domain First**: Start by modeling your domain entities in ``$SOLUTION_NAME.Domain``
2. **Define Interfaces**: Create service contracts in ``$SOLUTION_NAME.Application/Interfaces``
3. **Implement Use Cases**: Add business logic in ``$SOLUTION_NAME.Application/Features``
4. **Add Infrastructure**: Implement data access in ``$SOLUTION_NAME.Infrastructure``
5. **Expose APIs**: Create endpoints in ``$SOLUTION_NAME.Api``
$(if ($INCLUDE_TESTS -ieq "y") { "6. **Write Tests**: Add unit tests in ``$SOLUTION_NAME.UnitTests``" } else { "" })

## 🤝 Contributing

1. Create a feature branch: ``git checkout -b feature/my-feature``
2. Make your changes following the existing code style
3. Write/update tests as needed
4. Commit with clear messages: ``git commit -m "feat: add new feature"``
5. Push and create a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Generated using [Cyberax Clean Architecture Bootstrap](https://github.com/cyberax)
- Follows principles from [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

**Built with ❤️ using .NET $DOTNET_MAJOR**
"@ | Out-File -FilePath "README.md" -Encoding UTF8

# --- Git init ---
git init -q
git add .

# Check if git is configured
$gitUserName = git config user.name 2>$null
$gitUserEmail = git config user.email 2>$null

if ([string]::IsNullOrWhiteSpace($gitUserName) -or [string]::IsNullOrWhiteSpace($gitUserEmail)) {
    Write-Host "⚠️  Git user not configured. Skipping initial commit." -ForegroundColor Yellow
    Write-Host "   Configure with: git config --global user.name 'Your Name'" -ForegroundColor Yellow
    Write-Host "   Configure with: git config --global user.email 'your.email@example.com'" -ForegroundColor Yellow
} else {
    try {
        git commit -m "🎯 Initial Clean Architecture setup for $SOLUTION_NAME" 2>&1 | Out-Null
        Write-Host "✅ Initial commit created" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not create initial commit: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ $SOLUTION_NAME setup complete!" -ForegroundColor Green
Write-Host "Structure:"
Write-Host "  $SOLUTION_NAME/"
if ($FOLDER_STRUCTURE -eq "grouped") {
    Write-Host "    ├─ src/"
    Write-Host "    │   ├─ Core/"
    Write-Host "    │   │   ├─ $SOLUTION_NAME.Domain/"
    Write-Host "    │   │   └─ $SOLUTION_NAME.Application/"
    Write-Host "    │   ├─ Infrastructure/"
    Write-Host "    │   │   └─ $SOLUTION_NAME.Infrastructure/"
    Write-Host "    │   └─ Presentation/"
    Write-Host "    │       └─ $SOLUTION_NAME.Api/"
} else {
    Write-Host "    ├─ src/"
    Write-Host "    │   ├─ $SOLUTION_NAME.Api/"
    Write-Host "    │   ├─ $SOLUTION_NAME.Application/"
    Write-Host "    │   ├─ $SOLUTION_NAME.Domain/"
    Write-Host "    │   └─ $SOLUTION_NAME.Infrastructure/"
}
if ($INCLUDE_TESTS -ieq "y") {
    Write-Host "    ├─ tests/"
    Write-Host "    │   └─ $SOLUTION_NAME.UnitTests/"
}
Write-Host "    ├─ .github/copilot-instructions.md"
Write-Host "    ├─ .editorconfig"
Write-Host "    ├─ .gitignore"
Write-Host "    ├─ global.json"
Write-Host "    └─ README.md"
Write-Host ""
Write-Host "Next:"
Write-Host "  cd `"$ROOT_DIR`""
Write-Host "  code ."
Write-Host "  dotnet run --project $API_PATH"
Write-Host ""
Write-Host "Happy coding 🚀" -ForegroundColor Cyan
