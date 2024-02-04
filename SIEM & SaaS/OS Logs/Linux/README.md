# Linux OS logs

## Description
This script is using Fluent-D to automatically ship logs to Coralogix by providing 4 arguments.
The script supports operation-systems based on Ubuntu (Jammy and Focal), Red Hat or Amazon Linux (version 2 and 2023)

#### Arguments
|   Argument    | Description                                          |
|:-------------:|------------------------------------------------------|
|  `app-name`   | Coralogix Application Name                           |
|  `sub-name`   | Coralogix Subsystem Name                             |
|  `cx-region`  | The region where your Coralogix account is set up in |
|   `api-key`   | The Coralogix "Send Your Data" API key               |

#### Coralogix Region
| Region name | example URL                 |
|:-----------:|-----------------------------|
|   Europe    | my-team.coralogix.com       |
|  Europe 2   | my-team.eu2.coralogix.com   |
|     US      | my-team.us.coralogix.com    |
|     US2     | my-team.cx498.coralogix.com |
|    India    | my-team.app.coralogix.in    |
|  Singapore  | my-team.coralogixsg.com     |
NOTE: the command requires the region's name for the `cx-region` argument 

## Usage

### From URL
Upload to a location of your choosing, or use the raw script directly from GitHub 

Add the following line to your existing user-data script
```bash
curl -sS https://raw.githubusercontent.com/coralogix/snowbit-integrations/feature/os-logs-script/SIEM%20%26%20SaaS/OS%20Logs/Linux/linux.sh | bash -s -- --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123
```

### From a file
Download the script and save it to the linux server.

Run the script 
```bash
./linux.sh --app-name MyApp --sub-name SubApp --cx-region US --api-key abc123
```

## External links
* [Coralogix](https://coralogix.com/)
* [Fluent-D](https://docs.fluentd.org/)
