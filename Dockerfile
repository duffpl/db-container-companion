FROM nginxproxy/docker-gen:0.9.0 AS docker-gen
FROM itchyny/gojq as gojq
FROM alpine:latest

RUN apk add --no-cache --virtual .bin-deps \
    bash \
    curl \
    wget \
    mysql-client \
    gcompat \
    pigz

ADD resources/bin /usr/local/bin
ADD resources/templates /app/templates
ADD resources/scripts /app/scripts

COPY --from=docker-gen /usr/local/bin/docker-gen /usr/local/bin/
COPY --from=gojq /gojq /usr/local/bin/gojq

ENV DOCKER_HOST unix:///tmp/docker.sock
ENV ANONYMIZATION_CONFIGS_FOLDER /var/run/anonymization_configs
ENTRYPOINT ["/usr/local/bin/docker-gen"]

CMD ["-watch","-notify-output", "-notify", "bash /tmp/update-db", "/app/templates/update-db.tmpl", "/tmp/update-db"]
