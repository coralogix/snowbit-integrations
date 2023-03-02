# 1Password integration to Coralogix - Docker
Integrate 1Password to Coralogix via Docker

### Build docker image

```
docker build -t onepass . --no-cache
```


### Run the docker container

```
docker run --name onepassword-coralogix -d onepass
```

Note: 
       
	Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

	Update the auth_token in eventsapibeat.yml
	
	Update the url, private key, application name and subsystem name in logstash.conf
      


