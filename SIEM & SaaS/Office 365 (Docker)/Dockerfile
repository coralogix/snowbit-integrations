FROM ubuntu

RUN apt-get update
RUN apt-get install -y wget curl systemctl

RUN curl -L -O https://artifacts.elastic.co/downloads/logstash/logstash-8.12.2-amd64.deb && \
    dpkg -i logstash-8.12.2-amd64.deb
RUN curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.2-amd64.deb &&  \
    dpkg -i filebeat-8.12.2-amd64.deb
RUN rm logstash-8.12.2-amd64.deb filebeat-8.12.2-amd64.deb

RUN mkdir "/Office365"

COPY ./o365.yml /Office365/o365.yml
COPY ./logstash.conf /tmp/logstash.conf

RUN echo 'filebeat.config.modules:' > /tmp/filebeat.yml && \
    echo '  path: /Office365/*.yml' >> /tmp/filebeat.yml && \
    echo '  reload.enabled: false' >> /tmp/filebeat.yml && \
    echo 'fields_under_root: true' >> /tmp/filebeat.yml && \
    echo 'output.logstash:' >> /tmp/filebeat.yml && \
    echo '  hosts: ["localhost:2024"]' >> /tmp/filebeat.yml

RUN chmod 644 /tmp/filebeat.yml /Office365/o365.yml /tmp/logstash.conf

RUN echo '#!/bin/bash' > /internal.sh && \
    echo '# INTERNAL SCRIPT' >> /internal.sh && \
    echo '' >> /internal.sh && \
    echo '/usr/bin/filebeat -c /tmp/filebeat.yml &' >> /internal.sh && \
    echo '/usr/share/logstash/bin/logstash -f /tmp/logstash.conf &' >> /internal.sh && \
    echo 'sleep 5' >> /internal.sh && \
    echo 'while true; do' >> /internal.sh && \
    echo '    PS_OUTPUT=$(ps -eo command)' >> /internal.sh && \
    echo '    if ! echo "${PS_OUTPUT}" | grep -E "^/usr/share/filebeat/bin/filebeat" | grep -E "\-c /tmp/filebeat.yml" > /dev/null; then' >> /internal.sh && \
    echo '        echo "Filebeat process is not running. exiting..."' >> /internal.sh && \
    echo '        exit 3' >> /internal.sh && \
    echo '    fi' >> /internal.sh && \
    echo '    if ! echo "${PS_OUTPUT}" | grep -E "^/usr/share/logstash/jdk/bin/java" > /dev/null; then' >> /internal.sh && \
    echo '        echo "Logstash process is not running. exiting..."' >> /internal.sh && \
    echo '        exit 3' >> /internal.sh && \
    echo '    fi' >> /internal.sh && \
    echo '' >> /internal.sh && \
    echo '    sleep 5' >> /internal.sh && \
    echo 'done' >> /internal.sh

RUN chmod +x /internal.sh

CMD ["/internal.sh"]
