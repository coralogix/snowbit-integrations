# Stale Non-Human Resources in AWS
The following code identifies non-human identities and resources in the AWS platform and sends its findings to Coralogix in the form of logs.

# Motivation
This application is designed to be used as a Lambda in AWS to help identify stale resources in the AWS platform

The supported AWS resources are
- IAM users
- KMS Keys
- Secrets Manager's secrets

# Usage
In the `deploy` directory there are two files - `code.zip` and `layer.zip`

1. Create a new Lambda function from scratch with the runtime of `Python3.13`
2. Upload the code from the `code.zip` as the source code
3. Create a new Lambda layer from `layer.zip`. use `Python3.13` as the runtime and choose the same architecture which you used in the function
4. Attach the layer to the function
5. Under the configuration section on the function
   1. Under general configuration increase the Timeout to `5 min` and the memory to `1024`
   2. Under `Environment variables`
      * `CX_API_KEY` - the Coralogix API key
      * `CX_ENDPOINT` - The Coralogix region (can be either `EU1`, `EU2`, `US1`, `US2`, `AP1`, `AP2` or `AP3`)
   3. Under `permissions` click on the default role created for the function and add the following permissions
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": [
                    "kms:ListKeys",
                    "ec2:DescribeRegions",
                    "iam:GetAccessKeyLastUsed",
                    "kms:DescribeKey",
                    "iam:ListUsers",
                    "secretsmanager:ListSecrets",
                    "iam:GetLoginProfile",
                    "iam:ListAccessKeys"
                ],
                "Resource": "*"
            }
        ]
    }
    ```
6. Add a trigger for the Lambda
   1. For source choose `EventBridge (CloudWatch Events)`
   2. Mark `Create a new rule` and give it a name
   3. In the Schedule expression box, insert `rate(1 day)`

# Outcome
If all is done correctly, you should receive the Stale Non-Human Resources logs to your selected Coralogix account.<br>
Import the `aws_nhi_resources.json` as a custom dashboard to parse the log results.

The results should look like the following examples

### IAM
```json
{
    "additional_data": {
        "Path": "/",
        "UserName": "foo",
        "UserId": "AIDA3LV44N67TAQFJ35WZ",
        "Arn": "arn:aws:iam::123456789012:user/foo",
        "CreateDate": "2025-03-23T15:07:14+00:00",
        "PasswordLastUsed": "2025-03-23T15:18:01+00:00",
        "console_access": true,
        "user_has_access_keys": false,
        "user_age": 142
    },
    "account_id": "123456789012",
    "service": "IAM",
    "region": "global",
    "test_name": "users"
}
```

### KMS
```json
{
    "additional_data": {
        "AWSAccountId": "123456789012",
        "KeyId": "66ae1211-d20f-4cdf-a74a-...",
        "Arn": "arn:aws:kms:us-east-1:123456789012:key\/66ae3211-d20f-4cdf-a74a-123456789012",
        "CreationDate": "2022-06-16T14:11:10.900000+00:00",
        "Enabled": true,
        "Description": "Default key that protects my SQS messages when no other key is defined",
        "KeyUsage": "ENCRYPT_DECRYPT",
        "KeyState": "Enabled",
        "Origin": "AWS_KMS",
        "KeyManager": "AWS",
        "CustomerMasterKeySpec": "SYMMETRIC_DEFAULT",
        "KeySpec": "SYMMETRIC_DEFAULT",
        "EncryptionAlgorithms": [
            "SYMMETRIC_DEFAULT"
        ],
        "MultiRegion": false
    },
    "account_id": "123456789012",
    "service": "KMS",
    "region": "us-east-1",
    "test_name": "kms keys"
}
```

### Secret Manager
```json
{
    "additional_data": {
        "ARN": "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret",
        "Name": "my-secret",
        "LastChangedDate": "2025-04-09T14:54:00.103000+00:00",
        "LastAccessedDate": "2025-04-29T00:00:00+00:00",
        "Tags": [
            {
                "Key": "aws:secretsmanager:owningService",
                "Value": "events"
            }
        ],
        "SecretVersionsToStages": {
            "83FA12AE-B263-487D-B9E3-878ABBE9D331": [
                "AWSCURRENT"
            ],
            "BEBD3E62-FFB2-4671-AFA4-93BC7C4F9EEC": [
                "AWSPREVIOUS"
            ]
        },
        "OwningService": "events",
        "CreatedDate": "2025-04-09T14:17:14.287000+00:00",
        "secret_age": 25,
        "last_retrieval": 6
    },
    "account_id": "123456789012",
    "service": "Secret Manager",
    "region": "us-east-1",
    "test_name": "secrets"
}
```