import boto3
import subprocess
import argparse

if __name__ == "__main__":
    client_organizations = boto3.client('organizations')

    args_parser = argparse.ArgumentParser(description="CSPM auto arn populator")
    args_parser.add_argument("--company-id", required=True,
                             help="The Coralogix company ID", type=str)
    args_parser.add_argument("--api-key", required=True,
                             help="The 'Send Your Data' api key from Coralogix", type=str)
    args_parser.add_argument("--alert_api-key", required=False,
                             help="The 'Alerts, Rules and Tags API Key' api key from Coralogix", type=str,
                             default="")
    args_parser.add_argument("--application-name", required=False,
                             help="The application name to display in Coralogix", type=str,
                             default="CSPM")
    args_parser.add_argument("--subsystem-name", required=False,
                             help="The subsystem name to display in Coralogix", type=str,
                             default="CSPM")
    args_parser.add_argument("--grpc-endpoint", required=False,
                             help="The GRPC endpoint url - Available values are: 'ng-api-grpc.coralogix.com'"
                                  " for Europe. 'ng-api-grpc.coralogix.us' for US. 'ng-api-grpc.app.coralogix.in' "
                                  "for India. 'ng-api-grpc.coralogixsg.com' for Singapore. "
                                  "'ng-api-grpc.eu2.coralogix.com' for Stockholm", type=str,
                             default="ng-api-grpc.coralogix.us")
    args = args_parser.parse_args()
    if not args.company_id:
        args_parser.print_help()
    try:
        if "Accounts" in client_organizations.list_accounts() and len(
                (client_organizations.list_accounts())["Accounts"]) > 0:
            accounts = client_organizations.list_accounts()["Accounts"]
            current_account_id = boto3.client('sts').get_caller_identity().get('Account')
            roles_arns = []
            for account in accounts:
                if account["Id"] != current_account_id:
                    roles_arns.append(f'arn:aws:iam::{account["Id"]}:role/CSPM-Role')
            comma_separated_role_arns = ','.join(roles_arns)
            command = f'docker rm snowbit-cspm ; docker rmi coralogixrepo/snowbit-cspm ;\
             docker run --name snowbit-cspm -d \
             -e ROLE_ARN_LIST="{comma_separated_role_arns}" \
             -e API_KEY="{args.api_key}" \
             -e TESTER_LIST="" \
             -e REGION_LIST="" \
             -e CLOUD_PROVIDER="aws" \
             -e PYTHONUNBUFFERED=1 \
             -e COMPANY_ID={args.company_id} \
             -e SUBSYSTEM_NAME="{args.subsystem_name}" \
             -e AWS_DEFAULT_REGION="eu-west-1" \
             -e CORALOGIX_ENDPOINT_HOST="{args.grpc_endpoint}" \
             -e APPLICATION_NAME={args.application_name} \
             -e CORALOGIX_ALERT_API_KEY="{args.alert_api_key}" \
             --network host \
             -v ~/.aws/credentials:/root/.aws/credentials \
             coralogixrepo/snowbit-cspm'

            with open("/home/ubuntu/output.log", "w") as output:
                subprocess.call(command, shell=True, stdout=output, stderr=output)

            print("""Docker is running - you may read the log file at '/home/ubuntu/output.log'""")

        else:
            print(f"'Accounts' object doesn't exists in the Organization object response")
    except client_organizations.exceptions.AccessDeniedException as error:
        print(f"ERROR: {error}")
