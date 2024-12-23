import json
import asyncio
from grpclib.client import Channel
from modules.dataprime import (
    DataprimeQueryServiceStub,
    Metadata,
    MetadataQuerySyntax,
    MetadataTier,
    QueryRequest
)
from datetime import (datetime, timedelta, timezone)


class Main:
    def __init__(self, event, api_key, grpc_endpoint):
        self.time_window = event["timewindow"]
        self.query = event["queryText"]
        self.timestamp = event["timestampISO"]
        self.group_by = event["alertGroupByValues"]
        self.endpoint = grpc_endpoint
        self.metadata = [('authorization', api_key)]
        self.app = event["applicationName"]
        self.group_by_used = False

    @staticmethod
    def to_timestamp(date):
        datetime_obj = datetime.strptime(date, "%Y-%m-%dT%H:%M:%S.%fZ")
        aware_datetime_obj = datetime_obj.replace(tzinfo=timezone.utc)
        return aware_datetime_obj

    def group_bys(self):
        try:
            raw_gbs = json.loads(self.group_by)
            str_gbs = []
            for k, v in raw_gbs.items():
                str_gbs.append(f"{k}: \"{v}\"")
                self.group_by_used = True
            return str_gbs
        except:
            return None

    async def get_raw_grpc_output(self, payload=None):
        channel = Channel(host=self.endpoint, port=443, ssl=True)
        stub = DataprimeQueryServiceStub(channel)

        # Aligning time window
        raw_to_date = self.to_timestamp(self.timestamp)
        raw_from_date = raw_to_date - timedelta(minutes=int(self.time_window))

        try:
            query_request = QueryRequest(
                query=payload,
                metadata=Metadata(
                    start_date=raw_from_date,
                    end_date=raw_to_date,
                    tier=MetadataTier.TIER_ARCHIVE,
                    syntax=MetadataQuerySyntax.QUERY_SYNTAX_LUCENE,
                    limit=2000,
                    strict_fields_validation=True)
            )

            async for response in stub.query(query_request=query_request, metadata=self.metadata):
                if "result" in response.to_dict():
                    return response.to_dict()["result"]["results"]

        except Exception as e:
            print(f"Failed to get a response from Coralogix:\n  {e.__dict__}")
            exit(2)

        finally:
            channel.close()

    def main(self):
        group_bys = self.group_bys()
        if self.group_by_used:
            gb_len = len(group_bys)
            query = f"{self.query}"
            for i in range(gb_len):
                query += f" AND {group_bys[i]}"
        else:
            query = self.query
        run = asyncio.run(self.get_raw_grpc_output(payload=f"{query} AND coralogix.metadata.applicationName: {self.app}"))
        logs = [log["userData"] for log in run]
        return logs
