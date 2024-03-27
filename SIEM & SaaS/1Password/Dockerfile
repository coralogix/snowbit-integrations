FROM ubuntu
RUN apt-get update
RUN apt-get install -y wget curl gpg apt-utils systemctl unzip

# Determine architecture
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || [ "$ARCH" = "armv8l" ] || [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then \
        EVENTSAPIBEAT_ARCH="arm64"; \
        LOGSTASH_ARCH="arm64"; \
    else \
        EVENTSAPIBEAT_ARCH="amd64"; \
        LOGSTASH_ARCH="amd64"; \
    fi && \
    wget https://github.com/1Password/events-api-elastic/releases/download/v2.7.0/eventsapibeat_2.7.0_linux_$EVENTSAPIBEAT_ARCH.tar.gz && \
    tar -xf eventsapibeat_2.7.0_linux_$EVENTSAPIBEAT_ARCH.tar.gz && \
    mv linux_$EVENTSAPIBEAT_ARCH/eventsapibeat /eventsapibeat && \
    wget https://artifacts.elastic.co/downloads/logstash/logstash-8.12.0-$LOGSTASH_ARCH.deb && \
    dpkg -i logstash-8.12.0-$LOGSTASH_ARCH.deb


COPY ./eventsapibeat.yml /tmp/eventsapibeat.yml
RUN chmod 600 /tmp/eventsapibeat.yml
COPY ./logstash.conf /tmp/logstash.conf

RUN wget -O /internal.sh https://snowbit-devops-shared-resources.s3.eu-west-1.amazonaws.com/onepassword/intenal-script.sh
RUN chmod +x /internal.sh

CMD ["bash", "-x", "/internal.sh"]
