FROM ubuntu

RUN apt-get update
RUN apt-get install -y wget curl systemctl

# Install shippers
RUN wget https://artifacts.elastic.co/downloads/logstash/logstash-8.12.2-amd64.deb && \
    dpkg -i logstash-8.12.2-amd64.deb
RUN curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.2-amd64.deb &&  \
    dpkg -i filebeat-8.12.2-amd64.deb

# Cleanup
RUN rm logstash-8.12.2-amd64.deb filebeat-8.12.2-amd64.deb

RUN mkdir "/Office365"
COPY ./logstash.conf /Office365/logstash.conf
COPY ./o365.yml /Office365/o365.yml
RUN chmod go-w /Office365/o365.yml  /Office365/logstash.conf

RUN echo 'filebeat.config:' > /etc/filebeat/filebeat.yml && \
    echo '  modules:' >> /etc/filebeat/filebeat.yml && \
    echo '    path: /Office365/*.yml' >> /etc/filebeat/filebeat.yml && \
    echo '    reload.enabled: false' >> /etc/filebeat/filebeat.yml && \
    echo 'fields_under_root: true' >> /etc/filebeat/filebeat.yml && \
    echo '' >> /etc/filebeat/filebeat.yml && \
    echo 'logging:' >> /etc/filebeat/filebeat.yml && \
    echo '  level: debug' >> /etc/filebeat/filebeat.yml && \
    echo '  to_files: true' >> /etc/filebeat/filebeat.yml && \
    echo '  files:' >> /etc/filebeat/filebeat.yml && \
    echo '  path: /var/log/filebeat' >> /etc/filebeat/filebeat.yml && \
    echo '  name: filebeat.log' >> /etc/filebeat/filebeat.yml && \
    echo '  keepfiles: 10' >> /etc/filebeat/filebeat.yml && \
    echo '  permissions: 0644' >> /etc/filebeat/filebeat.yml && \
    echo '' >> /etc/filebeat/filebeat.yml && \
    echo 'output.logstash:' >> /etc/filebeat/filebeat.yml && \
    echo '  hosts: ["localhost:2024"]' >> /etc/filebeat/filebeat.yml

RUN chmod 644 /etc/filebeat/filebeat.yml

RUN echo "#!/bin/bash" > /internal.sh && \
    echo "/usr/share/filebeat/bin/filebeat -c /etc/filebeat/filebeat.yml -e &" >> /internal.sh && \
    echo "/usr/share/logstash/bin/logstash -f /Office365/logstash.conf &" >> /internal.sh && \
    echo "sleep 5" >> /internal.sh && \
    echo "" >> /internal.sh && \
    echo "while true; do" >> /internal.sh && \
    echo '    if ! echo "$(ps -eo command)" | grep -E "^/usr/share/filebeat/bin/filebeat -c /etc/filebeat/filebeat.yml" > /dev/null; then' >> /internal.sh && \
    echo "        echo 'Filebeat process is not running. exiting...'" >> /internal.sh && \
    echo "        exit 3" >> /internal.sh && \
    echo "    fi" >> /internal.sh && \
    echo '    if ! echo "$(ps -eo command)" | grep -E "^/usr/share/logstash/jdk/bin/java" > /dev/null; then' >> /internal.sh && \
    echo "        echo 'Logstash process is not running. exiting...'" >> /internal.sh && \
    echo "        exit 3" >> /internal.sh && \
    echo "    fi" >> /internal.sh && \
    echo "    sleep 5" >> /internal.sh && \
    echo "done" >> /internal.sh

RUN chmod +x /internal.sh

CMD ["/internal.sh"]
