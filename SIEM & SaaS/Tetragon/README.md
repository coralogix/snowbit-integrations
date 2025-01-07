# Tetragon Logs via Open-Telemetry

Download the following file and uncompress it


Create a file named `custom-values.yaml`

```YAML
namespace: security
domain: "your-domain" # e.g. coralogix.com
private_key: "your-private-key"
application_name: "app-name"
subsystem_name: "subsystem-name"
```

run the command

```bash
helm install tetragon-to-cx ./helm-chart -f custom-values.yaml -n security
```

you should get a response similar to this

```YAML
NAME: tetragon-to-cx
LAST DEPLOYED: Tue Jan  7 14:12:36 2025
NAMESPACE: security
STATUS: deployed
REVISION: 1
TEST SUITE: None
```