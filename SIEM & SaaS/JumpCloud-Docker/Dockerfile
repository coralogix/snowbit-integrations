FROM  mcr.microsoft.com/powershell

# Install wget
RUN apt update && apt install wget -y

# Install JumpCloud Module
RUN pwsh -Command Install-Module -Name JumpCloud -Force -Scope AllUsers

# Setting the log level for powershell
RUN echo '{ "LogLevel": "Critical" }' > /opt/microsoft/powershell/7/powershell.config.json

# Download the ps1 script file from coralogix repository
RUN wget -O /JC-DI2SIEM.ps1 https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/JumpCloud/JC-DI2SIEM.ps1

# Download the config template file from coralogix repository
RUN wget -O /config_coralogix.json https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/JumpCloud/config_coralogix.json

# Copy entrypoint script into the container
COPY entrypoint.sh /entrypoint.sh

# Set execute permissions for the entrypoint script
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
