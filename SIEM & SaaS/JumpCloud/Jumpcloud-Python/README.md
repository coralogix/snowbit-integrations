# JumpCloud integration to Coralogix - Docker (Python)
Integrate JumpCloud logs to Coralogix via Docker

### Build docker image

```docker build -t <Docker-Image-Name> .```


### Run the docker container

```
sudo docker run -e JUMPCLOUD_API_KEY="<JUMPCLOUD_API_KEY>" -e CORALOGIX_PRIVATE_KEY="<CORALOGIX_PRIVATE_KEY>" -e CORALOGIX_DOMAIN="<CORALOGIX_DOMAIN>" -e CORALOGIX_APP_NAME="<CORALOGIX_APP_NAME>" -e CORALOGIX_SUBSYSTEM_NAME="<CORALOGIX_SUBSYSTEM_NAME>" --restart=always <Docker-Image-Name>
```
```CORALOGIX_DOMAIN``` - the region-specific endpoint associated with your Coralogix Account. [You can find your Domain here](https://coralogix.com/docs/user-guides/account-management/account-settings/coralogix-domain/)

Note: Remember to substitute the placeholders with your actual API keys, coralogix domain, application name, and subsystem name.

---

