import boto3
import os

role_name = os.getenv("role_name")
iam_client = boto3.client('iam')
org_client = boto3.client('organizations')

try:
    iam_client.delete_role_policy(PolicyName='STS', RoleName=role_name)
except iam_client.exceptions.NoSuchEntityException as error:
    print(f"ERROR: {error}")


def lambda_handler(event, context):
    if "Accounts" in org_client.list_accounts() and len((org_client.list_accounts())["Accounts"]) > 0:
        accounts = org_client.list_accounts()["Accounts"]
        current_account_id = boto3.client('sts').get_caller_identity().get('Account')
        roles_arns = []
        for account in accounts:
            if account["Id"] != current_account_id:
                roles_arns.append(f'arn:aws:iam::{account["Id"]}:role/CSPM-Role')
        comma_separated_role_arns = ','.join(roles_arns)

    iam_client.put_role_policy(PolicyName='STS',
                               RoleName=role_name,
                               PolicyDocument='{"Version":"2012-10-17",'
                                              '"Statement":{"Effect":"Allow","Action":"sts:AssumeRole",'
                                              '"Resource":"' + comma_separated_role_arns + '"}}')