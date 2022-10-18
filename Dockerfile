FROM nginxproxy/docker-gen:0.9.0 AS docker-gen
FROM alpine:latest

RUN apk add --no-cache --virtual .bin-deps \
    bash \
    curl \
    wget \
    jq \
    mysql-client

WORKDIR /app
ADD . /app

COPY --from=docker-gen /usr/local/bin/docker-gen /usr/local/bin/

ENV DOCKER_HOST unix:///tmp/docker.sock

ENTRYPOINT ["/usr/local/bin/docker-gen"]

CMD ["-watch","-notify-output", "-notify", "bash /tmp/update-db", "update-db.tmpl", "/tmp/update-db"]