from aws_modules.aws import AWS
from datetime import datetime, timezone


class Service(AWS):
    def __init__(self, client, account_id, region, shipper):
        self.service_name = "Secret Manager"
        self.region = region
        self.secrets_manager_client = client("secretsmanager", self.region)
        self.account_id = account_id
        self.shipper = shipper.send_bulk
        self.list_secrets = None

    def _init_secret_manager(self):
        try:
            list_secrets = self.secrets_manager_client.list_secrets()
            if "SecretList" in list_secrets:
                self.list_secrets = list_secrets["SecretList"]
        except Exception as e:
            print(f"ERROR :: {self.service_name} :: {e}")

    def test_get_secrets(self):
        test_name = "secrets"
        results = []

        if self.list_secrets and len(self.list_secrets) > 0:
            for secret in self.list_secrets:
                now = datetime.now(timezone.utc)
                secret_name = secret["Name"]
                secret["LastChangedDate"] = self._datetime_handler(secret["LastChangedDate"])
                if "LastAccessedDate" in secret:
                    last_retrieval = (now - secret["LastAccessedDate"]).days
                    secret["LastAccessedDate"] = self._datetime_handler(secret["LastAccessedDate"])
                else:
                    last_retrieval = "Never retrieved"

                secret_age = (now - secret["CreatedDate"]).days
                secret["CreatedDate"] = self._datetime_handler(secret["CreatedDate"])

                secret.update({"secret_age": secret_age, "last_retrieval": last_retrieval})

                results.append(
                    self._generate_results(self.account_id, self.service_name, test_name, secret_name, self.region,
                                           secret))
        return results

    def run(self):
        global_tests, regional_tests = self._get_all_tests()
        if self.region != "global":
            self._init_secret_manager()
            self.run_test(self.service_name, regional_tests, self.shipper, self.region)
        if self.region == "global":
            self.run_test(self.service_name, global_tests, self.shipper, self.region)
