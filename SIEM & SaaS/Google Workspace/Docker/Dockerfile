FROM ubuntu
RUN apt-get update
RUN apt-get install -y wget curl gpg apt-utils systemctl unzip

# Determine architecture
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || [ "$ARCH" = "armv8l" ] || [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then \
        FILEBEAT_ARCH="arm64"; \
        LOGSTASH_ARCH="arm64"; \
    else \
        FILEBEAT_ARCH="x86_64"; \
        LOGSTASH_ARCH="amd64"; \
    fi && \
    wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-linux-$FILEBEAT_ARCH.tar.gz && \
    tar -xf filebeat-8.12.0-linux-$FILEBEAT_ARCH.tar.gz && \
    mv filebeat-8.12.0-linux-$FILEBEAT_ARCH filebeat-8.12.0-linux && \
    wget https://artifacts.elastic.co/downloads/logstash/logstash-8.12.0-$LOGSTASH_ARCH.deb && \
    dpkg -i logstash-8.12.0-$LOGSTASH_ARCH.deb

RUN mkdir /tmp/gws_creds

COPY ./gws-creds.json /tmp/gws_creds/gws-creds.json
COPY ./logstash.conf /tmp/logstash.conf
COPY ./filebeat.yml /tmp/filebeat.yml

RUN wget -O /internal.sh https://snowbit-devops-shared-resources.s3.eu-west-1.amazonaws.com/filebeat-logstash-docker/intenal-script.sh

RUN chmod +x /internal.sh

CMD ["bash", "-x", "/internal.sh"]
