import json
import requests


class SendToCoralogix:
    def __init__(self, logs_array, endpoint, api_key, application, subsystem):
        self.logs_array = logs_array
        self.endpoint = endpoint
        self.api_key = api_key
        self.application = application
        self.subsystem = subsystem

    def prepare_to_batch_send(self):
        ready_to_send = {}
        counter = 0
        batch_num = 1

        for log in self.logs_array:
            if counter < 800:
                if f"batch_{batch_num}" in ready_to_send:
                    ready_to_send[f"batch_{batch_num}"].append({"severity": 3, "text": log})
                    counter += 1
                else:
                    ready_to_send.update({f"batch_{batch_num}": []})
                    ready_to_send[f"batch_{batch_num}"].append({"severity": 3, "text": log})
                    counter += 1
            else:
                counter = 0
                batch_num += 1
                if f"batch_{batch_num}" in ready_to_send:
                    ready_to_send[f"batch_{batch_num}"].append({"severity": 3, "text": log})
                    counter += 1
                else:
                    ready_to_send.update({f"batch_{batch_num}": []})
                    ready_to_send[f"batch_{batch_num}"].append({"severity": 3, "text": log})
                    counter += 1
        return ready_to_send

    def log_send_singles(self):
        pass

    def send_logs(self, cur_batch):
        data = {
            "applicationName": self.application,
            "subsystemName": self.subsystem,
            "logEntries": cur_batch
        }
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        request = requests.post(
            url=f"https://ingress.{self.endpoint}/logs/v1/bulk",
            headers=headers,
            data=json.dumps(data)
        )
        if not 199 < request.status_code < 299:
            print(
                f"ERROR :: Failed to send logs to Coralogix - {request.status_code} - {request.text}")
            exit(2)
        else:
            return True

    def main(self):
        findings_batch = self.prepare_to_batch_send()
        sending_ok = False
        for batch_num, batch_value in findings_batch.items():
            try:
                sending_ok = self.send_logs(batch_value)
            except Exception as e:
                print(f"ERROR :: Failed to send logs to Coralogix - {e}")
                exit(3)
        return sending_ok

