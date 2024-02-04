#!/bin/bash
# v.0.0.4

OPTIONS=$(getopt -o f:l: -l app-name:,sub-name:,cx-region:,api-key: -n "$0" -- "$@")
if [ $? -ne 0 ]; then
    echo "Invalid option"
    exit 1
fi
eval set -- "$OPTIONS"

cx_region_endpoint_resolver() {
    case "$1" in
        "Europe")
            echo "coralogix.com"
            ;;
        "Europe2")
            echo "eu2.coralogix.com"
            ;;
        "India")
            echo "coralogix.in"
            ;;
        "US")
            echo "coralogix.us"
            ;;
        "US2")
            echo "cx498.coralogix.com"
            ;;
        "Singapore")
            echo "coralogixsg.com"
            ;;
    esac
}

app_name=""
sub_name=""
cx_region=""
api_key=""

while true; do
    case "$1" in
        --app-name) app_name="$2"; shift 2;;
        --sub-name) sub_name="$2"; shift 2;;
        --cx-region) cx_region=$(cx_region_endpoint_resolver "$2"); shift 2;;
        --api-key) api_key="$2"; shift 2;;
        *) break;;
    esac
done

if [ -z "$app_name" ] || [ -z "$sub_name" ] || [ -z "$cx_region" ] || [ -z "$api_key" ]; then
    echo "Usage: $0 --app-name <App_Name> --sub-name <Sub_Name> --cx-region <CX_Region> --api-key <API_Key>"
    exit 1
fi

fluentd_conf="<system>
  log_level info
</system>

<source>
  @type tail
  @id tail_var_logs
  @label @CORALOGIX
  path /var/log/*.log
  pos_file /var/log/all.pos
        path_key path
  tag all
  read_from_head true
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
    applicationName \"$app_name\"
    subsystemName \"$sub_name\"
    text \${record.to_json}
  </record>
  </filter>

<match **>
  @type http
  @id http_to_coralogix
  endpoint \"https://ingress.$cx_region/logs/v1/singles\"
  headers {\"authorization\":\"Bearer $api_key\"}
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
  <secondary>
    #If any messages fail to send they will be send to STDOUT for debug.
    @type stdout
  </secondary>
</match>
</label>"

os_release_file="/etc/os-release"
os_id=$(cat "$os_release_file" | grep -E "^ID=" | awk -F'=' '{print $2}' | tr -d '"')

if [ "$os_id" = "ubuntu" ]; then
  os_codename=$(lsb_release -sc)
  curl -fsSL https://toolbelt.treasuredata.com/sh/install-ubuntu-$os_codename-fluent-package5-lts.sh | sh

elif [ "$os_id" = "rhel" ]; then
  curl -fsSL https://toolbelt.treasuredata.com/sh/install-redhat-fluent-package5-lts.sh | sh

elif [ "$os_id" = "amzn" ]; then
  amzn_version=$(cat "$os_release_file" | grep -E "^VERSION_ID=" | awk -F'=' '{print $2}' | tr -d '"')
  curl -fsSL https://toolbelt.treasuredata.com/sh/install-amazon"$amzn_version"-fluent-package5-lts.sh | sh
fi

touch /var/log/all.pos
chmod 777 /var/log/all.pos
chmod 644 /var/log/*.log
echo "$fluentd_conf" > /etc/fluent/fluentd.conf
systemctl enable fluentd
systemctl restart fluentd
