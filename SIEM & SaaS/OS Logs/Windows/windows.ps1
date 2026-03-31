# @licence     Apache-2.0
# @version     0.0.6
# @since       0.0.1

param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({$_ -match '^[\w\-\\\/\@]{3,50}$'})]
    [string]$app_name = "Windows",

    [Parameter(Mandatory=$false)]
    [ValidateScript({$_ -match '^[\w\-\\\/\@]{3,50}$'})]
    [string]$sub_name = "${COMPUTERNAME}",

    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^(?:(?:EU|US|AP)[1-3]{1})+$'})]
    [string]$cx_region,

    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^cxt[ph]_\w{30}|[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'})]
    [string]$api_key,

    [Parameter(Mandatory=$false)]
    [switch]$enable_iis,

    [Parameter(Mandatory=$false)]
    [string]$iis_log_path = "C:\inetpub\logs\LogFiles\W3SVC*\*.log",

    [Parameter(Mandatory=$false)]
    [switch]$enable_dotnet_app,

    [Parameter(Mandatory=$false)]
    [string]$dotnet_stdout_path = "C:\inetpub\logs\stdout\*.log",

    [Parameter(Mandatory=$false)]
    [switch]$enable_dotnet_backend,

    [Parameter(Mandatory=$false)]
    [string]$dotnet_backend_log_path = "C:\Logs\**\*.log",

    [Parameter(Mandatory=$false)]
    [switch]$enable_active_directory
)

# Validate that all arguments are provided
if (-not $app_name -or -not $sub_name -or -not $cx_region -or -not $api_key) {
    Write-Host "Error: All arguments (app_name, sub_name, cx_region, api_key) must be provided."
    return
}

$region_mapping = @{
    'EU1' = 'eu1.coralogix.com'
    'EU2' = 'eu2.coralogix.com'
    'US1' = 'us1.coralogix.com'
    'US2' = 'us2.coralogix.com'
    'AP1' = 'ap1.coralogix.com'
    'AP2' = 'ap2.coralogix.com'
    'AP3' = 'ap3.coralogix.com'
}

if ($region_mapping.ContainsKey($cx_region)) {
    $translated_region = $region_mapping[$cx_region]
} else {
    Write-Error "Invalid cx_region value. Please choose from: $($region_mapping.Keys -join ', ')"
    Exit 1
}

# Create a directory in C:\Program Files
$installDirectory = "C:\otel-contrib"
Write-Host "Creating directory: $installDirectory"
New-Item -ItemType Directory -Path $installDirectory -ErrorAction SilentlyContinue

# Download and install the file into the created directory
$downloadUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.148.0/otelcol-contrib_0.148.0_windows_amd64.tar.gz"
$outputPath = Join-Path $installDirectory "otelcol-contrib_0.148.0_windows_amd64.tar.gz"
Write-Host "Downloading file from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath
Write-Host "Extracting contents to $installDirectory..."
tar -xzf $outputPath -C $installDirectory

# Build dynamic receivers configuration
$receivers = @"
receivers:
  windowseventlog/application:
    channel: application
  windowseventlog/system:
    channel: system
  windowseventlog/security:
    channel: security
"@

# Add IIS logs receiver if enabled
if ($enable_iis) {
    Write-Host "Enabling IIS log collection from: $iis_log_path"
    $receivers += @"

  filelog/iis:
    include:
      - $iis_log_path
    start_at: end
    include_file_path: true
"@
}

# Add .NET Application logs receiver if enabled (stdout logs)
if ($enable_dotnet_app) {
    Write-Host "Enabling .NET Application log collection"
    Write-Host "  - stdout logs from: $dotnet_stdout_path"
    $receivers += @"

  filelog/dotnet_stdout:
    include:
      - $dotnet_stdout_path
    start_at: end
    include_file_path: true
"@
}

# Add .NET Backend/Engine logs receiver if enabled
if ($enable_dotnet_backend) {
    Write-Host "Enabling .NET Backend/Engine log collection from: $dotnet_backend_log_path"
    $receivers += @"

  filelog/dotnet_backend:
    include:
      - $dotnet_backend_log_path
    start_at: end
    include_file_path: true
"@
}

# Active Directory / DC-related Windows Event Log channels (enable on domain controllers; channels must exist)
if ($enable_active_directory) {
    Write-Host "Enabling Active Directory event log channels (Directory Service, DFS Replication, DNS Server)"
    $receivers += @"

  windowseventlog/ad_directory_service:
    channel: "Directory Service"
  windowseventlog/ad_dfs_replication:
    channel: "DFS Replication"
  windowseventlog/ad_dns_server:
    channel: "DNS Server"
"@
}

# One Coralogix exporter per pipeline (same app/subsystem for all; edit config.yaml after deploy to split)
$coralogixExporterBlock = @"
    domain: "$translated_region"
    private_key: "$api_key"
    application_name: "$app_name"
    subsystem_name: "$sub_name"
    timeout: 30s
"@

$exporters = @"
exporters:
  coralogix/windows-events:
$coralogixExporterBlock
"@

$pipelines = @"
    logs/windows-events:
      receivers: [ windowseventlog/application, windowseventlog/system, windowseventlog/security ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix/windows-events ]
"@

if ($enable_active_directory) {
    $exporters += @"

  coralogix/active-directory:
$coralogixExporterBlock
"@
    $pipelines += @"

    logs/active-directory:
      receivers: [ windowseventlog/ad_directory_service, windowseventlog/ad_dfs_replication, windowseventlog/ad_dns_server ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix/active-directory ]
"@
}

if ($enable_iis) {
    $exporters += @"

  coralogix/iis:
$coralogixExporterBlock
"@
    $pipelines += @"

    logs/iis:
      receivers: [ filelog/iis ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix/iis ]
"@
}

if ($enable_dotnet_app) {
    $exporters += @"

  coralogix/dotnet-app:
$coralogixExporterBlock
"@
    $pipelines += @"

    logs/dotnet-app:
      receivers: [ filelog/dotnet_stdout ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix/dotnet-app ]
"@
}

if ($enable_dotnet_backend) {
    $exporters += @"

  coralogix/dotnet-backend:
$coralogixExporterBlock
"@
    $pipelines += @"

    logs/dotnet-backend:
      receivers: [ filelog/dotnet_backend ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix/dotnet-backend ]
"@
}

# Update the content of the config.yaml file
$configFilePath = Join-Path $installDirectory "config.yaml"
@"
$receivers

processors:
  resourcedetection:
    detectors: ["system"]
    system:
      hostname_sources: ["os"]
  batch:

$exporters

service:
  pipelines:
$pipelines
"@ | Set-Content -Path $configFilePath
Write-Host "Updating content of $configFilePath..."

# Run sc.exe command to convert into a service
$scCommand = "sc.exe create cx-otelcol displayname=cx-otelcol start=delayed-auto binPath=""C:\\otel-contrib\\otelcol-contrib.exe --config C:\\otel-contrib\\config.yaml"""
Write-Host "Creating service..."
Invoke-Expression $scCommand
Invoke-Expression "sc.exe failure cx-otelcol reset= 86400 actions= restart/5000/restart/5000/restart/5000"
Invoke-Expression "sc.exe start cx-otelcol"

Write-Host "Done."
