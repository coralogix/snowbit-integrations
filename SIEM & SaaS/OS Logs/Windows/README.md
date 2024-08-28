# Windows Event Logs

## Description
This script is using OpenTelemetry to automatically ship logs to Coralogix by providing 4 arguments.
The script supports operation-systems based on Windows. 

#### Arguments
|  Argument   | Description                                          | Mandatory |   Default Value   |
|:-----------:|------------------------------------------------------|:---------:|:-----------------:|
| `app_name`  | Coralogix Application Name                           |   False   |      Windows      |
| `sub_name`  | Coralogix Subsystem Name                             |   False   | The computer name |
| `cx_region` | The region where your Coralogix account is set up in |   True    |         -         |
|  `api_key`  | The Coralogix "Send Your Data" API key               |   True    |         -         |

#### Coralogix Region
| Region name | example URL                 |
|:-----------:|-----------------------------|
|     EU1     | my-team.coralogix.com       |
|     EU2     | my-team.eu2.coralogix.com   |
|     US1     | my-team.us.coralogix.com    |
|     US2     | my-team.cx498.coralogix.com |
|     AP1     | my-team.app.coralogix.in    |
|     AP2     | my-team.coralogixsg.com     |

NOTE: the command requires the region's name for the `cx_region` argument

Example:
```bash
... -cx_region EU2 ...
```

## Usage

### From URL
Upload to a location of your choosing, or use the raw script directly from GitHub 

Add the following line to your existing user-data script
```powershell
<powershell>
Invoke-WebRequest -Uri "https://path.to.script/script.ps1" -OutFile "windows.ps1"
./windows.ps1 -app_name MyApp -sub_name SubApp -cx_region US -api_key abc123
</powershell>
```

### From a file
Download the script and save it to the Windows server.

Run the script 
```powershell
./windows.ps1 -app_name MyApp -sub_name SubApp -cx_region US -api_key abc123
```

## External links
* [Coralogix](https://coralogix.com/)
* [OpenTelemetry](https://opentelemetry.io/)
