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
    args_parser.add_argument("--role-name", required=False,
                             help="The role name that exists in each additional account wished to scan",
                             default="CSPM-Role", type=str)

    args = args_parser.parse_args()
    if not args.company_id:
        args_parser.print_help()
    try:
        iam_client = boto3.client('iam')
        org_client = boto3.client('organizations')

        response = None
        next_token = None

        roles_arns = []
        while response is None or 'NextToken' in response:
            if next_token:
                response = org_client.list_accounts(NextToken=next_token)
            else:
                response = org_client.list_accounts()

            if "Accounts" in response and len(response) > 0:
                accounts = response["Accounts"]
                current_account_id = boto3.client('sts').get_caller_identity().get('Account')
                for account in accounts:
                    if account["Id"] != current_account_id:
                        roles_arns.append(f'arn:aws:iam::{account["Id"]}:role/{args.role_name}')
            else:
                print(f"'Accounts' object doesn't exists in the Organization object response")

            next_token = response.get("NextToken")

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
        print(len(roles_arns))
        with open("/home/ubuntu/output.log", "w") as output:
            subprocess.call(command, shell=True, stdout=output, stderr=output)

        print("""Docker is running - you may read the log file at '/home/ubuntu/output.log'""")

    except Exception as error:
        print(f"ERROR: {error}")
