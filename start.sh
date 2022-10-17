#!/usr/bin/env bash
docker-gen -watch -notify-output -notify "bash /tmp/update-db" update-db.tmpl /tmp/update-db