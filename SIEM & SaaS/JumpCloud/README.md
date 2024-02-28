# JumpCloud integration to Coralogix - Docker
Integrate JumpCloud logs to Coralogix via Docker

### Build docker image

```docker build -t <Docker-Image-Name> .```


### Run the docker container

```
docker run --name jumpcloud-coralogix -d -e JumpCloud_API_KEY="<Jumpcloud API KEY>" -e Coralgix_Domain="<Coralogix Domain>" -e CORALOGIX_API_KEY="<Coralogix API KEY>" -e Coralogix_Application_Name="<Application Name>" -e Coralogix_Subsystem_Name="<Subsystem Name>" <Docker-Image-Name>
```

Note: Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

---

# JumpCloud integration to Coralogix (Without Docker)
Integrate JumpCloud logs to Coralogix

### powershell.config.json
In non Windows systems, copy this file the `PShome` directory
to find the full path, type `echo $PSHome` in `pwsh`
1. In ubuntu (PowerShell 7) - `/opt/microsoft/powershell/7`
2. MacOS - `/usr/local/microsoft/powershell/7`
### for additional information 
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_logging_non-windows


