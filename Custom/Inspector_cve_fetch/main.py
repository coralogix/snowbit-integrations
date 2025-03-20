import os
from modules.findings_from_aws_inspector import FindingsFromAwsInspector
from modules.send_to_coralogix import SendToCoralogix
import time

aws_profile = os.getenv("AWS_PROFILE")
aws_regions = [region.strip() for region in os.getenv("REGIONS_AWS").split(",")]
cx_region = os.getenv("CX_REGION")
api_key = os.getenv("API_KEY")
application = os.getenv("APPLICATION")
subsystem = os.getenv("SUBSYSTEM")
start_time = time.time()


def lambda_handler(event, context):
    for aws_region in aws_regions:
        findings_found = FindingsFromAwsInspector(profile=aws_profile, aws_region=aws_region).main()
        if findings_found and len(findings_found) > 0:
            successful_sent = SendToCoralogix(findings_found, cx_region, api_key, application, subsystem).main()
            if successful_sent:
                end_time = time.time()
                elapsed_time = end_time - start_time
                print("** Finished Successfully **")
                print(f"Script finished in {elapsed_time:.2f} seconds.")
