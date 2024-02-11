# @licence     Apache-2.0
# @version     0.0.1
# @since       0.0.1

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^[\w\-\\\/\@]{3,50}$'})]
    [string]$app_name,

    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^[\w\-\\\/\@]{3,50}$'})]
    [string]$sub_name,

    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^(?:(?:EU|US|AP)[12])+$'})]
    [string]$cx_region,

    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match '^cxt[ph]_\w{30}|[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'})]
    [string]$api_key
)

# Validate that all arguments are provided
if (-not $app_name -or -not $sub_name -or -not $cx_region -or -not $api_key) {
    Write-Host "Error: All arguments (app_name, sub_name, cx_region, api_key) must be provided."
    return
}

$region_mapping = @{
    'EU1' = 'coralogix.com'
    'EU2' = 'eu2.coralogix.com'
    'US1' = 'coralogix.us'
    'US2' = 'cx498.coralogix.com'
    'AP1' = 'coralogix.in'
    'AP2' = 'coralogixsg.com'
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
$downloadUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.93.0/otelcol-contrib_0.93.0_windows_386.tar.gz"
$outputPath = Join-Path $installDirectory "otelcol-contrib_0.93.0_windows_386.tar.gz"
Write-Host "Downloading file from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath
Write-Host "Extracting contents to $installDirectory..."
tar -xzf $outputPath -C $installDirectory

# Update the content of the config.yaml file
$configFilePath = Join-Path $installDirectory "config.yaml"
@"
receivers:
    windowseventlog/application:
        channel: application
    windowseventlog/system:
        channel: system
    windowseventlog/security:
        channel: security

processors:
  resourcedetection:
    detectors: ["system"]
    system:
      hostname_sources: ["os"]
  batch:

exporters:
  coralogix:
    domain: "$translated_region"
    private_key: "$api_key"
    application_name: "$app_name"
    subsystem_name: "$sub_name"
    timeout: 30s

service:
  pipelines:
    logs:
      receivers: [ windowseventlog/application, windowseventlog/system, windowseventlog/security ]
      processors: [ resourcedetection, batch ]
      exporters: [ coralogix ]
"@ | Set-Content -Path $configFilePath
Write-Host "Updating content of $configFilePath..."

# Run sc.exe command to convert into a service
$scCommand = "sc.exe create cx-otelcol displayname=cx-otelcol start=delayed-auto binPath=""C:\\otel-contrib\\otelcol-contrib.exe --config C:\\otel-contrib\\config.yaml"""
Write-Host "Creating service..."
Invoke-Expression $scCommand
Invoke-Expression "sc.exe failure cx-otelcol reset= 86400 actions= restart/5000/restart/5000/restart/5000"
Invoke-Expression "sc.exe start cx-otelcol"

Write-Host "Done."
