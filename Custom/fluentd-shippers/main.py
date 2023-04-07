import subprocess
import argparse
import json

args_parser = argparse.ArgumentParser(description="Multiple fluent-d shippers")
args_parser.add_argument("--api_key", required=True, type=str, default=0)
args_parser.add_argument("--domain", required=True, type=str, default="domain-test")
args = args_parser.parse_args()

with open("/home/ubuntu/shipper_details.json", "r") as f:
    input_json = f.read()

data = json.loads(input_json)
start_port = 5980

for key, value in data.items():
    shipper_type = value["type"]
    if shipper_type == "file":
        conf = f"""<source>
    @type tail
    @label @CORALOGIX
    path /fluentd/log/file.log
    pos_file /fluentd/file.pos
    tag cx.file
    <parse>
        @type {value["format"]}
    </parse>
</source>

<label @CORALOGIX>
    <filter **>
        @type record_transformer
        @log_level warn
        enable_ruby true
        auto_typecast true
        renew_record true
        <record>
            applicationName "{value["app_name"]}"
            subsystemName "{value["sub_name"]}"
            text $""" + """{record.to_json}
        """ + f"""</record>
    </filter>

    <match **>
        @type http
        @id http_to_coralogix
        endpoint "https://api.{args.domain}/logs/rest/singles"
        headers""" + """ {"private_key":""" + f""" "{args.api_key}" """ + """}
        retryable_response_codes 503
        error_response_as_unrecoverable false
        <buffer>
            @type memory
            chunk_limit_size 10MB
            compress gzip
            flush_interval 1s
            retry_max_times 5
            retry_type periodic
            retry_wait 2
        </buffer>
    </match>
</label>
"""
        with open(f"/home/ubuntu/{key}.conf", "w") as file:
            file.write(conf)
        command = f"docker run -d --name {key} -v {value['log_file_path']}:/fluentd/log/file.log -v /home/ubuntu/{key}.conf:/fluentd/etc/fluent.conf fluent/fluentd:edge-debian"
        subprocess.call(command, shell=True)
    elif shipper_type == "http":
        conf = f"""<source>
    @type http
    @label @CORALOGIX
    port {start_port}
    bind 0.0.0.0
    body_size_limit 32m
    keepalive_timeout 10s
</source>

<label @CORALOGIX>
    <filter **>
        @type record_transformer
        @log_level warn
        enable_ruby true
        auto_typecast true
        renew_record true
        <record>
            applicationName "{value["app_name"]}"
            subsystemName "{value["sub_name"]}"
            text $""" + """{record.to_json}
        """ + f"""</record>
    </filter>

    <match **>
        @type http
        @id http_to_coralogix
        endpoint "https://api.{args.domain}/logs/rest/singles"
        headers""" + """ {"private_key":""" + f""" "{args.api_key}" """ + """}
        retryable_response_codes 503
        error_response_as_unrecoverable false
        <buffer>
            @type memory
            chunk_limit_size 10MB
            compress gzip
            flush_interval 1s
            retry_max_times 5
            retry_type periodic
            retry_wait 2
        </buffer>
    </match>
</label>
"""
        with open(f"/home/ubuntu/{key}.conf", "w") as file:
            file.write(conf)
        command = f"docker run -d --name {key} -p {start_port}:{start_port} -v /home/ubuntu/{key}.conf:/fluentd/etc/fluent.conf fluent/fluentd:edge-debian"
        subprocess.call(command, shell=True)
        start_port += 5
    elif shipper_type == "tcp":
        conf = f"""<source>
    @type tcp
    @label @CORALOGIX
    port {start_port}
    bind 0.0.0.0
    body_size_limit 32m
    keepalive_timeout 10s
    tag cx.tcp
    <parse>
        @type none
    </parse>
</source>

<label @CORALOGIX>
    <filter **>
        @type record_transformer
        @log_level warn
        enable_ruby true
        auto_typecast true
        renew_record true
        <record>
            applicationName "{value["app_name"]}"
            subsystemName "{value["sub_name"]}"
            text $""" + """{record["message"]}
        """ + f"""</record>
    </filter>

    <match **>
        @type http
        @id http_to_coralogix
        endpoint "https://api.{args.domain}/logs/rest/singles"
        headers""" + """ {"private_key":""" + f""" "{args.api_key}" """ + """}
        retryable_response_codes 503
        error_response_as_unrecoverable false
        <buffer>
            @type memory
            chunk_limit_size 10MB
            compress gzip
            flush_interval 1s
            retry_max_times 5
            retry_type periodic
            retry_wait 2
        </buffer>
    </match>
</label>
"""
        with open(f"/home/ubuntu/{key}.conf", "w") as file:
            file.write(conf)
        command = f"docker run -d --name {key} -p {start_port}:{start_port} -v /home/ubuntu/{key}.conf:/fluentd/etc/fluent.conf fluent/fluentd:edge-debian"
        subprocess.call(command, shell=True)
        start_port += 5
    elif shipper_type == "udp":
        conf = f"""<source>
    @type udp
    @label @CORALOGIX
    port {start_port}
    bind 0.0.0.0
    body_size_limit 32m
    keepalive_timeout 10s
    tag cx.tcp
    <parse>
        @type none
    </parse>
</source>

<label @CORALOGIX>
    <filter **>
        @type record_transformer
        @log_level warn
        enable_ruby true
        auto_typecast true
        renew_record true
        <record>
            applicationName "{value["app_name"]}"
            subsystemName "{value["sub_name"]}"
            text $""" + """{record["message"]}
        """ + f"""</record>
    </filter>

    <match **>
        @type http
        @id http_to_coralogix
        endpoint "https://api.{args.domain}/logs/rest/singles"
        headers""" + """ {"private_key":""" + f""" "{args.api_key}" """ + """}
        retryable_response_codes 503
        error_response_as_unrecoverable false
        <buffer>
            @type memory
            chunk_limit_size 10MB
            compress gzip
            flush_interval 1s
            retry_max_times 5
            retry_type periodic
            retry_wait 2
        </buffer>
    </match>
</label>
"""
        with open(f"/home/ubuntu/{key}.conf", "w") as file:
            file.write(conf)
        command = f"docker run -d --name {key} -p {start_port}:{start_port}/udp -v /home/ubuntu/{key}.conf:/fluentd/etc/fluent.conf fluent/fluentd:edge-debian"
        subprocess.call(command, shell=True)
        start_port += 5