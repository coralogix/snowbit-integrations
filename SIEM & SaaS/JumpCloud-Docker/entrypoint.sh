#!/bin/bash

# Replacements in the config file using environment variables
sed -i "s|JumpCloud_API_KEY|$JumpCloud_API_KEY|g" /config_coralogix.json
sed -i "s|<domain>|$Coralgix_Domain|g" /config_coralogix.json
sed -i "s|CORALOGIX_API_KEY|$CORALOGIX_API_KEY|g" /config_coralogix.json
sed -i "s|<Application>>|$Coralogix_Application_Name|g" /config_coralogix.json
sed -i "s|<Subsystem>|$Coralogix_Subsystem_Name|g" /config_coralogix.json


pwsh /JC-DI2SIEM.ps1 -config_file:/config_coralogix.json
