import boto3
import json
import os

role_name = os.getenv("role_name")
additional_account_role_name = os.getenv("additional_account_role_name")

iam_client = boto3.client('iam')
org_client = boto3.client('organizations')

try:
    iam_client.delete_role_policy(PolicyName='STS', RoleName=role_name)
except iam_client.exceptions.NoSuchEntityException as error:
    print(f"ERROR: {error}")


def lambda_handler(event, context):
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
                    roles_arns.append(f'arn:aws:iam::{account["Id"]}:role/{additional_account_role_name}')
        next_token = response.get("NextToken")

    policy = {
        "Version": "2012-10-17",
        "Statement":
            {
                "Effect": "Allow",
                "Action": "sts:AssumeRole",
                "Resource": roles_arns
            }
    }

    iam_client.put_role_policy(PolicyName='STS',
                               RoleName=role_name,
                               PolicyDocument=json.dumps(policy))
