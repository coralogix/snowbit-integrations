# JumpCloud integration to Coralogix - Docker
Integrate JumpCloud logs to Coralogix via Docker

### Build docker image

```docker build -t <Docker-Image-Name> .```


### Run the docker container

```
docker run --name jumpcloud-coralogix -d -e JumpCloud_API_KEY="<Jumpcloud API KEY>" -e Coralgix_Domain="<Coralogix Domain>" -e CORALOGIX_API_KEY="<Coralogix API KEY>" -e Coralogix_Application_Name="<Application Name>" -e Coralogix_Subsystem_Name="<Subsystem Name>" <Docker-Image-Name>
```

Note: Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.
