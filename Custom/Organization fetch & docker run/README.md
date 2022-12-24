# Organization fetch & Docker run
This script is used for automatically fetch all AWS accounts in the organization and build an ARN for each account so that Snowbit CSPM can scan them.

The script replaces the regular `crontab` command used in the original deployment.  
## Prerequisites
### On the Docker machine 
1. Make sure to have [Docker](https://docs.docker.com/engine/install/ubuntu/) installed
2. Make sure all other steps for Snowbit CSPM are done for this machine - follow [this link](https://coralogix.com/docs/cloud-security-posture-cspm/) for more info
3. Copy the `code.py` file to the CSPM machine

### On the master AWS account
1. Deploy the `lambda.py` in the master AWS account in order to automatically update the CSPM permissions for the additional accounts
2. Use the following iam policy for the lambda
3. The lambda needs one environmental variable - `role_name` who is the role name used for the CSPM
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CSPMRole",
            "Effect": "Allow",
            "Action": [
                "iam:DeleteRolePolicy",
                "iam:PutRolePolicy"
            ],
            "Resource": "<cspm-role-ARN>"
        },
        {
            "Sid": "Organization",
            "Effect": "Allow",
            "Action": "organizations:ListAccounts",
            "Resource": "*"
        }
    ]
}
```
## Installation

On the EC2 used for the CSPM, use the package manager [pip](https://pip.pypa.io/en/stable/) to install boto3.

```bash
sudo apt-get install python3-pip -y
pip install boto3
```


Create a cronjob by typing `sudo crontab-e` and paste the following command:
```crontab
0 0 * * * python3 code.py --company-id <COMPANY_ID> --api-key <API_KEY>
```
Note: the default `GRPC_ENDPOINT` is US (look at Usage section for details)
## Usage
You can add additional parameters to the job by using the help menu
```bash
optional arguments:
  -h, --help            show this help message and exit
  --company-id COMPANY_ID
                        The Coralogix company ID
  --api-key API_KEY     The 'Send Your Data' api key from Coralogix
  --alert_api-key ALERT_API_KEY
                        The 'Alerts, Rules and Tags API Key' api key from Coralogix
  --application-name APPLICATION_NAME
                        The application name to display in Coralogix
  --subsystem-name SUBSYSTEM_NAME
                        The subsystem name to display in Coralogix
  --grpc-endpoint GRPC_ENDPOINT
                        The GRPC endpoint url - Available values are: 
                        - 'ng-api-grpc.coralogix.com' for Europe.
                        - 'ng-api-grpc.coralogix.us' for US. 
                        - 'ng-api-grpc.app.coralogix.in' for India. 
                        - 'ng-api-grpc.coralogixsg.com' for Singapore. 
                        - 'ng-api- grpc.eu2.coralogix.com' for Stockholm.

```
