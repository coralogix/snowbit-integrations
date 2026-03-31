# Windows Event Logs

## Description

This script installs the [OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) (**v0.148.0**, `windows_amd64`) and ships logs to Coralogix. It writes `C:\otel-contrib\config.yaml`, registers the **cx-otelcol** Windows service, and starts the collector.

Configuration uses **separate pipelines** so each log type has its own receiver and Coralogix exporter. By default, every exporter uses the same `application_name` and `subsystem_name` (from script parameters). After deployment you can edit `C:\otel-contrib\config.yaml` to set different application or subsystem names per exporter without changing receivers or pipeline names.

**Default log types**

- **Windows Event Logs** — Application, System, and Security channels (always on).
- **IIS logs** — Optional (`-enable_iis`); file paths under IIS log directories.
- **.NET web app stdout logs** — Optional (`-enable_dotnet_app`); ASP.NET Core stdout files when enabled in IIS.
- **.NET backend / engine file logs** — Optional (`-enable_dotnet_backend`); paths you configure (for example Serilog/NLog file output).
- **Active Directory (domain controllers)** — Optional (`-enable_active_directory`); classic AD-related event channels (Directory Service, DFS Replication, DNS Server). Use on DCs where those logs exist.

**.NET in the Application event log** (for example `.NET Runtime`, ASP.NET) is collected by the **windows-events** pipeline, not by `-enable_dotnet_app`. The `-enable_dotnet_app` switch only adds the **filelog** receiver for stdout log files.

**File log behavior:** optional `filelog` receivers use `start_at: end` so only lines written **after** the collector starts are sent (not historical file content).

## Collector layout (pipelines and exporters)

Each pipeline connects one logical source to one Coralogix exporter. Processors `resourcedetection` and `batch` apply to every pipeline.

| Pipeline ID           | Receivers | Coralogix exporter      | When |
|----------------------|-----------|-------------------------|------|
| `logs/windows-events` | `windowseventlog/application`, `windowseventlog/system`, `windowseventlog/security` | `coralogix/windows-events` | Always |
| `logs/iis`           | `filelog/iis` | `coralogix/iis` | If `-enable_iis` |
| `logs/dotnet-app`    | `filelog/dotnet_stdout` | `coralogix/dotnet-app` | If `-enable_dotnet_app` |
| `logs/dotnet-backend`| `filelog/dotnet_backend` | `coralogix/dotnet-backend` | If `-enable_dotnet_backend` |
| `logs/active-directory` | `windowseventlog/ad_directory_service`, `windowseventlog/ad_dfs_replication`, `windowseventlog/ad_dns_server` | `coralogix/active-directory` | If `-enable_active_directory` |

To tune Coralogix metadata per source, edit the matching exporter block under `exporters:` in `C:\otel-contrib\config.yaml`, then restart the service:

```powershell
Restart-Service cx-otelcol
```

## Arguments

### Required arguments

| Argument    | Description                                          | Mandatory | Default |
|:-----------:|------------------------------------------------------|:---------:|:-------:|
| `cx_region` | Coralogix region code                                | True      | —       |
| `api_key`   | Coralogix "Send Your Data" API key                   | True      | —       |

### Optional arguments

| Argument                  | Description                                 | Default value |
|:-------------------------:|---------------------------------------------|---------------|
| `app_name`                | Coralogix application name (all exporters)  | `Windows`     |
| `sub_name`                | Coralogix subsystem name (all exporters)    | Computer name |
| `enable_iis`              | Enable IIS log collection                     | `false`       |
| `iis_log_path`            | IIS log include glob                          | `C:\inetpub\logs\LogFiles\W3SVC*\*.log` |
| `enable_dotnet_app`       | Enable .NET stdout file log collection      | `false`       |
| `dotnet_stdout_path`      | Stdout log glob                             | `C:\inetpub\logs\stdout\*.log` |
| `enable_dotnet_backend`   | Enable backend/engine file log collection   | `false`       |
| `dotnet_backend_log_path` | Backend log include glob                    | `C:\Logs\**\*.log` |
| `enable_active_directory` | AD / DC event channels (see below)          | `false`       |

### Coralogix region

| Region | Example host (team subdomain varies) |
|:------:|--------------------------------------|
| EU1    | `*.coralogix.com`                    |
| EU2    | `*.eu2.coralogix.com`                |
| US1    | `*.us.coralogix.com`                 |
| US2    | `*.cx498.coralogix.com`              |
| AP1    | `*.app.coralogix.in`                 |
| AP2    | `*.coralogixsg.com`                  |
| AP3    | `*.ap3.coralogix.com`                |

Use the region **code** for `cx_region` (for example `EU2`, `US1`).

## Usage

### Prerequisites

1. Run PowerShell **as Administrator**.
2. If needed, allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Basic usage (Windows Event Logs only)

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key"
```

### With IIS logs

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -enable_iis
```

### With .NET stdout file logs (IIS)

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -enable_dotnet_app
```

### With .NET backend or engine file logs

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -enable_dotnet_backend
```

### All optional file sources enabled

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -app_name "MyApp" -sub_name "Production" -enable_iis -enable_dotnet_app -enable_dotnet_backend
```

### Domain controller: Active Directory event channels

Use on servers that have the **Directory Service** (and usually **DFS Replication**) logs. The **DNS Server** log exists when the DNS Server role is installed; if the collector fails to start because a channel is missing, edit `C:\otel-contrib\config.yaml` and remove the receiver and pipeline entry for that channel, then restart **cx-otelcol**.

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -enable_active_directory
```

### Custom log paths

```powershell
.\windows.ps1 -cx_region US1 -api_key "your-api-key" `
    -enable_iis -iis_log_path "D:\IISLogs\W3SVC*\*.log" `
    -enable_dotnet_backend -dotnet_backend_log_path "D:\MyApp\Logs\**\*.log"
```

### From URL (user data)

```powershell
<powershell>
Invoke-WebRequest -Uri "https://path.to.script/windows.ps1" -OutFile "windows.ps1"
.\windows.ps1 -cx_region US1 -api_key "your-api-key" -enable_iis -enable_dotnet_app
</powershell>
```

## Log sources

### Windows Event Logs (default)

Collected on pipeline `logs/windows-events`:

- **Application** channel (includes many .NET-related providers when they write to this channel).
- **System** channel.
- **Security** channel.

### IIS logs (`-enable_iis`)

- Default include: `C:\inetpub\logs\LogFiles\W3SVC*\*.log`.
- Override with `-iis_log_path` if your IIS site uses a custom directory.

### .NET stdout file logs (`-enable_dotnet_app`)

- Default: `C:\inetpub\logs\stdout\*.log` (must match `stdoutLogFile` / stdout logging in your app).
- Does not replace Application channel collection; event log data stays on `logs/windows-events`.

### .NET backend or engine file logs (`-enable_dotnet_backend`)

- Default: `C:\Logs\**\*.log`.
- Point `-dotnet_backend_log_path` at wherever your app writes files (for example Serilog `path` in `appsettings.json`).

### Active Directory event logs (`-enable_active_directory`)

Collected on pipeline `logs/active-directory` (exporter `coralogix/active-directory`):

| Windows channel    | Receiver name | Typical use |
|--------------------|---------------|-------------|
| `Directory Service` | `windowseventlog/ad_directory_service` | AD DS operations, replication, LDAP-related diagnostics |
| `DFS Replication`   | `windowseventlog/ad_dfs_replication`    | SYSVOL / DFSR on domain controllers |
| `DNS Server`        | `windowseventlog/ad_dns_server`         | AD-integrated DNS (only if DNS Server role is present) |

These are separate from the **Security** channel on `logs/windows-events` (for example logon auditing). Enable `-enable_active_directory` only where the logs exist; see [AD and LDS diagnostic event logging](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-ad-and-lds-event-logging) for raising verbosity in the Directory Service log.

## External links

- [Coralogix](https://coralogix.com/)
- [OpenTelemetry](https://opentelemetry.io/)
- [OpenTelemetry Collector Contrib releases](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases)
