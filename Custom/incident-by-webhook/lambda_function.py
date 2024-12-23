import json
from main import Main
import os

raw_event = json.loads(open("sample_event.json").read())


if __name__ == "__main__":
    response = Main(raw_event, os.getenv("API_KEY"), os.getenv("CX_GRPC_REGION")).main()

    # TRANSFER 'response' TO XSOAR EVENT -->
