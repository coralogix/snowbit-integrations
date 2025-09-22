import os
import boto3
import pkgutil
import importlib
import concurrent.futures
from datetime import datetime
from utils.coralogix import SendToCoralogix
from utils.aws_request_throttling_handler import handle_request


class NonHumanIdentities:
    def __init__(self):
        self.code_dir = os.path.dirname(__file__)
        self.cx_api_key = os.getenv("CX_API_KEY")
        self.cx_endpoint = self.coralogix_endpoint_convert(os.getenv("CX_ENDPOINT"))
        self.profile = os.getenv("AWS_PROFILE")
        self.aws_regions_to_scan = os.getenv("AWS_REGIONS")

    def get_client(self, service, region="us-east-1"):
        if self.profile and len(self.profile) > 0:
            client = boto3.Session(profile_name=self.profile).client(service_name=service, region_name=region)
        else:
            client = boto3.client(service, region_name=region)
        return handle_request(lambda: client)

    @staticmethod
    def coralogix_endpoint_convert(endpoint):
        if endpoint == "EU1":
            return "eu1.coralogix.com"
        elif endpoint == "EU2":
            return "eu2.coralogix.com"
        elif endpoint == "US1":
            return "us1.coralogix.com"
        elif endpoint == "US2":
            return "us2.coralogix.com"
        elif endpoint == "AP1":
            return "ap1.coralogix.com"
        elif endpoint == "AP2":
            return "ap2.coralogix.com"
        elif endpoint == "AP3":
            return "ap3.coralogix.com"
        else:
            return "eu1.coralogix.com"

    @staticmethod
    def get_available_regions(client):
        regions_raw = client("ec2").describe_regions()["Regions"]
        regions = [region["RegionName"] for region in regions_raw]
        return regions

    def init_aws(self):
        client = self.get_client
        regions = []
        aws_regions = self.aws_regions_to_scan
        if type(aws_regions) is str:
            if aws_regions and len(aws_regions) > 0:
                regions = [region.strip() for region in aws_regions.split(",")]
            else:
                regions = self.get_available_regions(client=client)
        elif type(aws_regions) is list:
            regions = aws_regions
        elif not aws_regions:
            regions = self.get_available_regions(client=client)
        if "global" not in regions:
            regions.append("global")
        account_id = client("sts").get_caller_identity()["Account"]
        return client, regions, account_id

    def load_services_for_provider(self):
        services = []
        all_services = {}
        testers_dir = os.path.join(self.code_dir, "aws_modules", "tests")

        def load_module(module_to_load):
            if hasattr(module_to_load, 'Service'):
                service_class = getattr(module_to_load, 'Service')
                return service_class

        for finder, module_name, is_pkg in pkgutil.iter_modules([testers_dir]):
            all_services.update({module_name: f"aws_modules.tests.{module_name}"})

        for name, cur_module in all_services.items():
            module = importlib.import_module(cur_module)
            services.append(load_module(module))

        return services

    @staticmethod
    def run_service(service_class, client, account_id: str, region: str,
                    shipper: SendToCoralogix):
        service_class(
            client=client,
            region=region,
            account_id=account_id,
            shipper=shipper
        ).run()

    def run(self):
        start_timestamp = datetime.now()
        client, regions, account_id = self.init_aws()
        discovered_services = self.load_services_for_provider()
        future_to_task = {}

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            for service_class in discovered_services:
                cur_service_name = str(service_class).split(".")[2].upper()

                special_names = ["Secret_Manager"]
                for special_name in special_names:
                    if cur_service_name == special_name.upper():
                        cur_service_name = special_name

                shipper = SendToCoralogix(
                    endpoint=self.cx_endpoint,
                    api_key=self.cx_api_key,
                    application="AWS_NHI",
                    subsystem=cur_service_name
                )
                for region in regions:
                    future = executor.submit(
                        self.run_service,
                        service_class,
                        client,
                        account_id,
                        region,
                        shipper
                    )
                    future_to_task[future] = (cur_service_name, region)
        duration = (datetime.now() - start_timestamp).total_seconds()
        print(f"\n✅ Code completed in {duration} seconds")
