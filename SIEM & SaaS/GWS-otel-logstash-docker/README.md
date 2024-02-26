# Google Workspace integration to Coralogix - Docker
Integrate Google Workspace logs/events to Coralogix via Docker

### Build docker image

```docker build -t <Docker-Image-Name> .```


### Run the docker container

```
docker run --name gws-coralogix -d <Docker-Image-Name>
```

Note: Update the google email id in filbeat.yml
      Update the url, private key , application name and subsystem name in logstash.conf
      Place gws-creds.json on same path as Dockerfile and config files.
      Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

