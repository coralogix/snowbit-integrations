# Linux OS logs

## Description
This script is using OpenTelemetry to automatically ship OS logs to Coralogix by providing 4 basic arguments.
The script supports operation-systems based on Ubuntu (Jammy and Focal), Red Hat or Amazon Linux (version 2 and 2023)

#### Arguments
|       Argument       | Description                                                                       | Required |
|:--------------------:|-----------------------------------------------------------------------------------|:--------:|
|      `app-name`      | Coralogix Application Name                                                        |   Yes    |
|      `sub-name`      | Coralogix Subsystem Name                                                          |   Yes    |
|     `cx-region`      | The region where your Coralogix account is set up in                              |   Yes    |
|      `api-key`       | The Coralogix "Send Your Data" API key                                            |   Yes    |
| `monitor-containers` | whether to collect container logs. <br/>Can be set to `true` or `false` (default) |    No    |

DISCLAIMER: The script can automate the collection of container logs running on the machine.
To collect those container logs, OpeTelemetry needs to run as Root.
when using the `monitor-containers` as `true` you will be prompted with the same disclaimer message.

#### Coralogix Region
| Region name | example URL                 |
|:-----------:|-----------------------------|
|     EU1     | my-team.coralogix.com       |
|     EU2     | my-team.eu2.coralogix.com   |
|     US1     | my-team.us.coralogix.com    |
|     US2     | my-team.cx498.coralogix.com |
|     AP1     | my-team.app.coralogix.in    |
|     AP2     | my-team.coralogixsg.com     |

NOTE: the command requires the region's name for the `cx-region` argument

Example:
```bash
... --cx-region EU2 ...
```

## Usage

### From URL
Upload to a location of your choosing, or use the raw script directly from GitHub 

```bash
curl -sS https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/OS%20Logs/Linux/linux.sh | bash -s -- --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123
```

### From a file
Download the script and save it to the linux server.

Run the script 
```bash
./linux.sh --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123
```
### From the User-Data startup script
Add the following line to your existing user-data script
```bash
curl -sS https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/OS%20Logs/Linux/linux.sh | bash -s -- --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123
```
Note: in case `monitor-containers` is set to `true`, pipe the command to the disclaimer response before the command itself:
```bash
echo "yes" | curl -sS https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/OS%20Logs/Linux/linux.sh | bash -s -- --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123 --monitor-containers true
```

## External links
* [Coralogix](https://coralogix.com/)
* [OpenTelemetry](https://opentelemetry.io/)
