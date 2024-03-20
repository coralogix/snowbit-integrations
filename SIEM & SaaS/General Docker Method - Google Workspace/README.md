# Google Workspace integration to Coralogix - Docker
Integrate Google Workspace logs/events to Coralogix via Docker

### Build docker image

```
docker build -t gws . --no-cache
```


### Run the docker container

```
docker run --name gws-cgx -d gws
```

Note: 

	Update the google email address in filebeat.yml
	
	Update the url, private key, application name and subsystem name in logstash.conf
      
	Place gws-creds.json on same path as Dockerfile and config files.

	Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

