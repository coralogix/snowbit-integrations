from aws_modules.aws import AWS


class Service(AWS):
    def __init__(self, client, account_id, region, shipper):
        self.service_name = "KMS"
        self.region = region
        self.kms_client = client("kms", self.region)
        self.account_id = account_id
        self.shipper = shipper.send_bulk
        self.all_keys = None

    def _kms_init(self):
        try:
            list_keys = self.kms_client.list_keys()
            keys = []
            for key in list_keys["Keys"]:
                keys.append(self.kms_client.describe_key(KeyId=key["KeyId"])["KeyMetadata"])
            self.all_keys = keys
        except Exception as e:
            print(f"ERROR :: {self.service_name} :: {e}")

    def test_get_keys(self):
        test_name = "kms keys"
        results = []

        if self.all_keys and len(self.all_keys) > 0:
            for key in self.all_keys:
                # print(key)
                key_id = key["KeyId"]
                key["CreationDate"] = self._datetime_handler(key["CreationDate"])
                if "DeletionDate" in key:
                    key["DeletionDate"] = self._datetime_handler(key["DeletionDate"])
                results.append(
                    self._generate_results(self.account_id, self.service_name, test_name, key_id, self.region,
                                           key))
        return results

    def run(self):
        global_tests, regional_tests = self._get_all_tests()
        if self.region != "global":
            self._kms_init()
            self.run_test(self.service_name, regional_tests, self.shipper, self.region)
        if self.region == "global":
            self.run_test(self.service_name, global_tests, self.shipper, self.region)