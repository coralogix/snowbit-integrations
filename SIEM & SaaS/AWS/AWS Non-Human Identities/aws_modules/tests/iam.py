from aws_modules.aws import AWS
from botocore.exceptions import ClientError
from datetime import datetime, timezone


class Service(AWS):
    def __init__(self, client, account_id, region, shipper):
        self.service_name = "IAM"
        self.iam_client = client("iam")
        self.account_id = account_id
        self.region = region
        self.shipper = shipper.send_bulk
        self.iam_users = None

    def _iam_init(self):
        try:
            users_paginator = self.iam_client.get_paginator('list_users')
            for response in users_paginator.paginate():
                self.iam_users = response["Users"] if "Users" in response else None

        except Exception as e:
            print(f"ERROR :: {self.service_name} :: {e}")

    def global_test_users(self):
        test_name = "users"
        results = []

        for user in self.iam_users:
            username = user["UserName"]
            now = datetime.now(timezone.utc)
            user_age_days = (now - user['CreateDate']).days
            user["CreateDate"] = self._datetime_handler(user["CreateDate"])
            if "PasswordLastUsed" in user:
                user["PasswordLastUsed"] = self._datetime_handler(user["PasswordLastUsed"])

            # Checking Console Login ->
            try:
                console_access = self.iam_client.get_login_profile(UserName=username)["LoginProfile"]
                if console_access and len(console_access) > 0:
                    user.update({"console_access": True})
            except ClientError as e:
                if e.response['Error']['Code'] == 'NoSuchEntity':
                    user.update({"console_access": False})
                else:
                    print(f"Error checking user {username}: {e}")

            # Checking Access Key ->
            try:
                access_keys = self.iam_client.list_access_keys(UserName=username)['AccessKeyMetadata']
                found_access_keys = []

                for key in access_keys:
                    key_age_days = (now - key['CreateDate']).days
                    key.update({"key_age": key_age_days})
                    key["CreateDate"] = self._datetime_handler(key["CreateDate"])

                    last_used_info = self.iam_client.get_access_key_last_used(AccessKeyId=key["AccessKeyId"])
                    last_used_date = last_used_info['AccessKeyLastUsed'].get('LastUsedDate')

                    if last_used_date:
                        last_used_age_days = (now - last_used_date).days
                        last_used_str = self._datetime_handler(last_used_date)
                    else:
                        last_used_age_days = 0
                        last_used_str = "Never Used"

                    key.update({"key_last_used_date": last_used_str, "key_last_used": last_used_age_days})
                    found_access_keys.append(key)
                if len(found_access_keys) > 0:
                    user.update({"user_has_access_keys": True, "user_access_keys_count": len(found_access_keys)})
                    for access_key in found_access_keys:
                        results.append(
                            self._generate_results(
                                self.account_id,
                                self.service_name,
                                "user_access_key",
                                username,
                                self.region,
                                access_key
                            ))
                else:
                    user.update({"user_has_access_keys": False})

            except Exception as e:
                print(f"ERROR :: {self.service_name} :: {e}")

            user.update({"user_age": user_age_days})
            results.append(
                self._generate_results(
                    self.account_id,
                    self.service_name,
                    test_name,
                    username,
                    self.region,
                    user
                ))

        return results

    def run(self):
        global_tests, regional_tests = self._get_all_tests()
        if self.region != "global":
            self.run_test(self.service_name, regional_tests, self.shipper, self.region)
        if self.region == "global":
            self._iam_init()
            self.run_test(self.service_name, global_tests, self.shipper, self.region)
