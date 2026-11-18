# Infrastructure Health Check Tool

A PowerShell tool that runs a full health check on a Windows machine and produces structured reports. It validates system resources, network connectivity, critical services, recent Windows errors and external API endpoints, then summarizes everything into a single overall status (`OK`, `WARNING` or `CRITICAL`).

Built as a hands-on project while studying Windows administration, Microsoft 365 and automation.

## Features

- **System diagnostics:** OS name, version and last boot time (CIM/WMI)
- **RAM and disk monitoring:** free space with warning and critical thresholds
- **Network validation:** adapters, IPv4, DNS servers, default gateway reachability
- **Connectivity checks:** Internet reachability and DNS resolution
- **Critical services monitoring:** Spooler, WinRM and W32Time (easily customizable)
- **Windows Event Log analysis:** latest 10 errors from the System log
- **API endpoint monitoring:** HTTP status code validation and response time measurement, with performance classification
- **Overall summary:** detects problems and calculates a general status
- **Structured reporting:** human-readable `.txt`, machine-readable `.json` and timestamped `.log`
- **Error handling:** every check is isolated, so one failure never stops the full run

## Requirements

- Windows 10/11 or Windows Server
- PowerShell 5.1 or later
- Internet access (for connectivity and API checks)

## Usage

```powershell
# Clone the repository
git clone https://github.com/SergioBaudille/infrastructure-health-check.git
cd infrastructure-health-check

# Run with the default output folder (.\reports)
.\Infrastructure-HealthCheck.ps1

# Or choose a custom output folder
.\Infrastructure-HealthCheck.ps1 -OutputDir "C:\Temp\HealthCheck"
```

If script execution is blocked, allow it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Output

Each run generates three files in the output folder:

| File | Purpose |
|------|---------|
| `HealthCheckReport.txt` | Readable report with all results and the final summary |
| `HealthCheckDiagnostic.json` | Structured data, ready to be consumed by other tools or dashboards |
| `HealthCheckDiagnostic.log` | Timestamped log with `INFO`, `WARNING` and `ERROR` levels |

Sample outputs are available in the [`examples/`](examples/) folder.

<!-- Add screenshots here:
![Console output](docs/console.png)
![JSON report](docs/json-report.png)
-->

## How the status is calculated

| Check | Warning | Critical |
|-------|---------|----------|
| RAM free | < 20% | < 10% |
| Disk C: free | < 10 GB | n/a |
| Internet / DNS | n/a | Failure |
| Services | Not running | n/a |
| Event Log | Recent errors found | n/a |
| API endpoints | Any endpoint failing | n/a |

The overall status is `CRITICAL` if any critical condition is present, `WARNING` if there are other problems, and `OK` otherwise.

## Customization

- **Services to monitor:** edit the `$servicios` list in `Test-Servicios`
- **API endpoints:** edit the `$endpoints` list in `Test-ApiEndpoints`
- **Thresholds:** adjust the values in `Test-RAM` and `Test-Disco`

## Project structure

```
infrastructure-health-check/
├── Infrastructure-HealthCheck.ps1
├── examples/          # Sample reports (sanitized)
├── .gitignore
└── README.md
```

## Roadmap

- [ ] Parameters for custom services, endpoints and thresholds
- [ ] Support for all fixed drives, not only C:
- [ ] HTML report output
- [ ] Microsoft Graph integration (Microsoft 365 service health)
- [ ] Scheduled execution with Task Scheduler

## Author

**Sergio Ariel Baudille**
[LinkedIn](https://linkedin.com/in/sergio-ariel-baudille-a9bb823b0)
