# Office 365 integration to Coralogix - Docker
Integrate Office 365 audit logs to Coralogix via Docker

For the integration to work, please follow the [Coralogix documentation](https://coralogix.com/docs/office-365-audit-logs/) and create the required Azure Application
### Configurations
Edit the provided `o365.yml` file for the following parameters:
* var.application_id - the application ID that you created in Azure
* id - your Azure tenet ID
* client_secret - the secret you created during the application creation process

Edit the provided `logstash.conf` file for the following parameters:
* `<coralogix_domain>` - The domain your Coralogix account is located
* `<coralogix_private_key>` - Your 'Send Your Data' API key from Coralogix
* `applicationName` and `subsystemName` were pre-populated, feel free to change to your liking
### Build the Docker image

```bash
docker build -t o365 .
```


### Run the Docker container

```bash
docker run --name office365 -d o365
```
