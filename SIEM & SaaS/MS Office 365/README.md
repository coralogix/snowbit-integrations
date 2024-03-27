# MS Office 365 integration to Coralogix - Docker
Integrate MS Office 365 logs/events to Coralogix via Docker

### Build docker image

```
docker build -t ms365 . --no-cache
```


### Run the docker container

```
docker run --name o365 -d ms365
```

Note: 

	Update the application_id, client_secret, logical_name, tenet_id in filebeat.yml
	
	Update the url, private key, application name and subsystem name in logstash.conf

	Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

