import boto3
import subprocess
import argparse
import datetime

log_file = "/root/docker-logs.log"


def logger(level, message):
    with open(log_file, "a") as file:
        file.write(f"{datetime.datetime.now()} :: {level} :: {message}\n")


def remove_container():
    try:
        subprocess.check_output(["docker", "rm", "snowbit-cspm"])
    except subprocess.CalledProcessError as e:
        logger("WARN", f"There is no container to remove - {e}")


def remove_image():
    try:
        subprocess.check_output(["docker", "rmi", "coralogixrepo/snowbit-cspm"])
    except subprocess.CalledProcessError as e:
        logger("WARN", f"There is no image to remove - {e}")


def docker_run(comma_separated_role_arns):
    docker_run_command = f'docker run -d --name snowbit-cspm \
    -e ROLE_ARN_LIST="{comma_separated_role_arns}" \
    -e API_KEY="{privateKey}" -e TESTER_LIST={args.tester_list} \
    -e REGION_LIST={args.region_list} -e CLOUD_PROVIDER="aws" \
    -e PYTHONUNBUFFERED=1 -e COMPANY_ID={args.company_id} \
    -e SUBSYSTEM_NAME="{args.subsystem_name}" \
    -e AWS_DEFAULT_REGION="{args.default_region}" \
    -e CORALOGIX_ENDPOINT_HOST="{args.grpc_endpoint}" \
    -e APPLICATION_NAME={args.application_name} \
    -e CORALOGIX_ALERT_API_KEY="{args.alert_api_key}" \
    --network host \
    -v ~/.aws/credentials:/root/.aws/credentials \
    coralogixrepo/snowbit-cspm'

    try:
        subprocess.call(docker_run_command, shell=True)
    except Exception as e:
        with open(log_file, "a") as err_file:
            logger("ERROR", f"Failed to run container - {e}")


if __name__ == "__main__":
    client_organizations = boto3.client('organizations')

    args_parser = argparse.ArgumentParser(description="CSPM auto arn populator")

    args_parser.add_argument("--company-id", required=True, help="The Coralogix company ID",
                             type=str)
    args_parser.add_argument("--role-name", required=False,
                             help="The fixed role name for all additional accounts", type=str, default="CSPM-Role")
    args_parser.add_argument("--api-key", required=True, type=str,
                             help="The 'Send Your Data' api key from Coralogix", )
    args_parser.add_argument("--alert_api-key", required=False,
                             help="The 'Alerts, Rules and Tags API Key' api key from Coralogix", type=str, default="")
    args_parser.add_argument("--application-name", required=False,
                             help="The application name to display in Coralogix", type=str, default="CSPM")
    args_parser.add_argument("--tester-list", required=False, type=str,
                             help="The testers list you want to limit the scan for (comma separated)", default="")
    args_parser.add_argument("--region-list", required=False, type=str,
                             help="The regions list you want to limit the scan for (comma separated)", default="")
    args_parser.add_argument("--subsystem-name", required=False,
                             help="The subsystem name to display in Coralogix", type=str, default="CSPM")
    args_parser.add_argument("--secret-name", required=False, help="Secret name from Secret manager", type=str,
                             default="")
    args_parser.add_argument("--default-region", required=True, type=str, default="eu-west-1")
    args_parser.add_argument("--grpc-endpoint", required=False,
                             help="The GRPC endpoint url - Available values are: 'ng-api-grpc.coralogix.com'"
                                  " for Europe. 'ng-api-grpc.coralogix.us' for US. 'ng-api-grpc.app.coralogix.in' "
                                  "for India. 'ng-api-grpc.coralogixsg.com' for Singapore. "
                                  "'ng-api-grpc.eu2.coralogix.com' for Stockholm", type=str,
                             default="ng-api-grpc.coralogix.us")
    args_parser.add_argument("--excluded-accounts", required=False, type=str)

    args = args_parser.parse_args()

    logger("INFO", "Run started ==>")
    if not args.company_id:
        args_parser.print_help()
    privateKey = ""
    secret_name = args.secret_name
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager')
    if secret_name:
        try:
            logger("INFO", "Pulling private key from secret manager")
            get_secret_value_response = client.get_secret_value(SecretId=secret_name)
            privateKey = get_secret_value_response['SecretString']
        except Exception as error:
            logger("ERROR", f"SECRET_MANAGER_NAME - {error}")
    else:
        privateKey = args.api_key

    try:
        iam_client = boto3.client('iam')
        org_client = boto3.client('organizations')

        response = None
        next_token = None

        roles_arns = []
        logger("INFO", "Creating ARN list")
        while response is None or 'NextToken' in response:
            if next_token:
                response = org_client.list_accounts(NextToken=next_token)
            else:
                response = org_client.list_accounts()

            if "Accounts" in response and len(response) > 0:
                accounts = response["Accounts"]

                comma_separated_excluded_account = str(args.excluded_accounts).split(",") if len(
                    args.excluded_accounts) > 0 else []

                current_account_id = [boto3.client('sts').get_caller_identity().get('Account')] + comma_separated_excluded_account

                for account in accounts:
                    if account["Id"] not in current_account_id:
                        roles_arns.append(f'arn:aws:iam::{account["Id"]}:role/{args.role_name}')
            else:
                logger("ERROR", "'Accounts' object doesn't exists in the Organization object response")

            next_token = response.get("NextToken")
        logger("INFO", "Finished creating ARN list")

        logger("INFO", "Attempting to remove existing CSPM container")
        remove_container()

        logger("INFO", "Attempting to remove existing CSPM image")
        remove_image()

        logger("INFO", "Running the CSPM container - check container logs for more information")
        docker_run(','.join(roles_arns))

    except Exception as error:
        logger("ERROR", error)
        logger("INFO", "Trying to run on the local account only - check container logs for more information")

        remove_container()
        remove_image()
        docker_run("")

    with open(log_file, "a") as log_file:
        log_file.write("\n")
