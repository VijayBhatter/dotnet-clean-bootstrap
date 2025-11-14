# .NET Clean Architecture Bootstrap

A simple PowerShell script to quickly scaffold .NET solutions with Clean Architecture structure.

## Features

- Clean Architecture structure (Domain, Application, Infrastructure, API layers)
- Interactive setup with sensible defaults
- Minimal API or Controllers
- Optional xUnit tests
- Flat or grouped folder structure
- .sln or .slnx solution formats
- Automatic .NET SDK version detection

## Prerequisites

- PowerShell 5.1+ or PowerShell Core 7+
- .NET SDK 6.0 or later

## Usage

```powershell
# Interactive mode (recommended)
.\dotnet-clean-bootstrap.ps1

# Quick start with just a name
.\dotnet-clean-bootstrap.ps1 -Name "MyApp"

# With all options
.\dotnet-clean-bootstrap.ps1 -Name "MyApp" -Controllers -Tests -NoEF -FolderStructure grouped
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Name` | Solution name | *Interactive prompt* |
| `-Controllers` | Use Controllers instead of Minimal API | Minimal API |
| `-NoEF` | Skip Entity Framework Core | Include EF |
| `-Tests` | Include xUnit test project | No tests |
| `-DotNetVersion` | Specific .NET SDK version | Auto-detect latest |
| `-SolutionFormat` | `sln` or `slnx` | Interactive prompt |
| `-FolderStructure` | `flat` or `grouped` | Interactive prompt |

## Examples

**Basic minimal API with EF Core:**
```powershell
.\dotnet-clean-bootstrap.ps1 -Name "QuickStart"
```

**Controllers with tests:**
```powershell
.\dotnet-clean-bootstrap.ps1 -Name "MyApi" -Controllers -Tests
```

**Grouped structure without EF:**
```powershell
.\dotnet-clean-bootstrap.ps1 -Name "MyProject" -NoEF -FolderStructure grouped
```

## Generated Structure

```
YourApp/
├── src/
│   ├── YourApp.Api/             # Web API
│   ├── YourApp.Application/     # Business Logic
│   ├── YourApp.Domain/          # Core Domain
│   └── YourApp.Infrastructure/  # Data Access
├── tests/                       # (if -Tests)
│   └── YourApp.UnitTests/
├── .github/
│   └── copilot-instructions.md  # AI guidelines
├── .editorconfig                # Code style
├── .gitignore
├── global.json                  # SDK version
├── README.md
└── YourApp.sln(x)
```

## License

Free to use, no attribution required. Provided as-is with no warranty.

## Author

Created by [@vijaybhatter](https://github.com/vijaybhatter)
