from datetime import datetime
import boto3


class FindingsFromAwsInspector:
    def __init__(self, profile, aws_region):
        self.session = boto3.Session(profile_name=profile) if (profile and len(profile) > 0) else boto3
        self.aws_region = aws_region

    def _get_client(self, service: str):
        client = self.session.client(service, region_name=self.aws_region)
        return client

    @staticmethod
    def _convert_datetime(obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Type {type(obj)} not serializable")

    def fetch_inspector_findings(self):
        print("INFO :: Fetch began")
        inspector_client = self._get_client("inspector2")
        findings = []
        next_token = None
        page_num = 1
        while True:
            page_num += 1
            params = {}
            if next_token:
                params['nextToken'] = next_token
            response = inspector_client.list_findings(**params)
            findings.extend(response.get('findings', []))
            next_token = response.get('nextToken')
            if not next_token:
                break

        return findings

    def filter_findings(self):
        raw_findings = self.fetch_inspector_findings()
        fields_to_fetch = ["awsAccountId", "exploitAvailable", "fixAvailable", "packageVulnerabilityDetails",
                           "severity", "resources", "type", "status", "description", "inspectorScore", "url", "logType"]
        filtered_findings = []
        for finding in raw_findings:
            cur_finding = {}
            for field in fields_to_fetch:
                try:
                    if field == "resources":
                        """
            "resources": [
                {
                    "details": {
                        "awsEc2Instance": {
                            "iamInstanceProfileArn": "arn:aws:iam::243629380105:instance-profile/SSM-Instance-Profile-dpdtm7",
                            "imageId": "ami-0d7240fb6988c108f",
                            "ipV4Addresses": [
                                "10.0.0.158",
                                "3.250.242.21"
                            ],
                            "ipV6Addresses": [],
                            "keyName": "devops-ireland",
                            "launchedAt": "2024-08-07T13:08:22+03:00",
                            "platform": "UBUNTU_20_04",
                            "subnetId": "subnet-0662ca06499206c9f",
                            "type": "t3a.small",
                            "vpcId": "vpc-0f547d1b6834bd5b9"
                        }
                    },
                    "id": "i-0f5e073186a69a21f",
                    "partition": "aws",
                    "region": "eu-west-1",
                    "tags": {
                        "Name": "Ninio - Benign 1 - IBM",
                        "Owner": "nir.limor@coralogix.com",
                        "Severity": "Low",
                        "Terraform-ID": "dpdtm7",
                        "purpose": "Demo env IBM",
                        "sta.sta-config-sta-uqgcmy1j.coralogix.com:mirror-filter-id": "tmf-0a83ac8c63f2c6356"
                    },
                    "type": "AWS_EC2_INSTANCE"
                }
            ]
            """
                        if len(finding["resources"]) == 1:
                            for resource in finding["resources"]:
                                resource_details = ["id", "region", "tags", "type"]
                                details = {}
                                for detail in resource_details:
                                    if detail == "type":
                                        details.update({"resource_type": resource[detail]})
                                    else:
                                        details.update({detail: resource[detail]})
                                cur_finding.update(details)
                        else:
                            print(f"'resources' array have more than one object")
                    elif field == "inspectorScore":
                        cur_finding.update(
                            {"baseScore": finding["inspectorScore"]})
                    elif field == "logType":
                        cur_finding.update(
                            {"logType": "inspectorFindings"})
                    elif field == "url":
                        cur_finding.update({
                            "cve_url": f"https://nvd.nist.gov/vuln/detail/{finding["packageVulnerabilityDetails"]["vulnerabilityId"]}"})
                    elif field == "packageVulnerabilityDetails":
                        cur_finding.update(
                            {"vulnerabilityId": finding["packageVulnerabilityDetails"]["vulnerabilityId"]})
                    else:
                        cur_finding.update(
                            {field: finding[field]})
                except:
                    pass
            filtered_findings.append(cur_finding)
        return filtered_findings

    def main(self):
        print(f"INFO :: Starting on '{self.aws_region}'")
        findings = self.filter_findings()
        if findings and len(findings) > 0:
            print(f"INFO :: Inspector findings fetched for region '{self.aws_region}'")
            return findings
        else:
            print(f"WARNING :: No Inspector findings in '{self.aws_region}'")
