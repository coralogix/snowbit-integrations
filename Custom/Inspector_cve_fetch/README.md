# Inspector CVE Fetcher
The attached code is fetching all CVEs and other vulnerability information from AWS Inspector

## Motivation
The logic behind building this code is to have all vulnerability information in a continuations manor and to have this data presented in a Coralogix custom dashboard

## Usage
The code is build to run inside AWS Lambda with a lambda layer already zipped and ready

1. Create a Lambda function with a Python3.13 runtime
2. Import the code from `lambda/code.zip`
3. Create a Lambda layer from `lambda/layer.zip` and attach it to the Lambda
4. Add the `list_findings` permissions for the `inspector` service to the Lambda
5. Add the following environment variables to the Lambda
   * `REGIONS_AWS` - regions you have inspector deployed and wish to fetch its findings
   * `CX_REGION` - Coralogix cluster region (e.g. "coralogix.com")
   * `API_KEY` - Send your data API key of Coralogix
   * `APPLICATION` - Application name in Coralogix platform
   * `SUBSYSTEM` - Subsystem name in Coralogix platform
6. Create an EventBridge rule to run the code in the desired frequency (we recommend once a day)
