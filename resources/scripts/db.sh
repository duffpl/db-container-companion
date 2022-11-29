#!/bin/bash
declare -A services

for configFile in /tmp/configs/*; do
  source "${configFile}"
done

ANONYMIZED=${ANONYMIZED:-1}
COMPRESSED=${COMPRESSED:-0}


info() {
  service=${1}
  if ! [ ${services[$service,username]+_} ]; then
    >&2 echo "Database configuration missing for $service"
    exit 1
  fi
  username=${services[$service,username]}
  schema=${services[$service,schema]}
  echo "${username}" "${schema}"
}

dump()
{
  service=${1}
  destination_username=${2}
  destination_schema=${3}
  if ! [ ${services[$service,username]+_} ]; then
    >&2 echo "Database configuration missing for $service"
    exit 1
  fi
  anonymization_config_file="${ANONYMIZATION_CONFIGS_FOLDER}/${service}/config.json"
  if [ ! -f ${anonymization_config_file} ]; then
    >&2 echo "Anonymization configuration missing for $service at ${anonymization_config_file}"
    exit 1
  fi
  username=${services[$service,username]}
  password=${services[$service,password]}
  schema=${services[$service,schema]}
  host=${services[$service,host]}
  port=${services[$service,port]}

  connection_params="-u\"${username}\" -p\"${password}\" -h\"${host}\" -P${port} ${schema}"

  local dump_command="(mysqldump --no-data --skip-lock-tables ${connection_params} ; mysqldump --no-create-info --skip-lock-tables ${connection_params} "

  if [ -n "${destination_username}" ] && [ "${destination_username}" != "${username}" ]; then
    dump_command_suffix+=" | sed -e 's/DEFINER=\`${username}\`/DEFINER=\`${destination_username}\`/'"
  fi
  if [ -n "${destination_schema}" ] && [ "${destination_schema}" != "${schema}" ]; then
    dump_command_suffix+=" | sed -e 's/\`${schema}\`\./\`${destination_schema}\`\./g'"
  fi
  if [[ $ANONYMIZED == 1 ]]; then
      skip_tables=( $(gojq -r ".skipTables[]" ${anonymization_config_file}))
      for table_name in "${skip_tables[@]}";
      do
          ignore_tables="${ignore_tables} --ignore-table ${schema}.$table_name"
      done
      dump_command+=" ${ignore_tables})"
      mdp_config=`gojq ".mdp" ${anonymization_config_file} | gzip | base64 -w 0`
      dump_command_suffix+=" | go-mdp -z -f ${mdp_config}"
  else
    dump_command+=")"
  fi
  if [[ $COMPRESSED == 1 ]]; then
    dump_command_suffix+=" | pigz "
  fi

 eval "${dump_command} ${dump_command_suffix}"
}

import()
{
  service=${1}
  if ! [ ${services[$service,username]+_} ]; then
    >&2 echo "Database configuration missing for $service"
    exit 1
  fi
  username=${services[$service,username]}
  password=${services[$service,password]}
  schema=${services[$service,schema]}
  host=${services[$service,host]}
  port=${services[$service,port]}

  connection_params="-u\"${username}\" -p\"${password}\" -h\"${host}\" -P${port} ${schema}"
  mysql_command="mysql ${connection_params}"
  if [ -n "${DROPDB}" ]; then
    drop_query="DROP DATABASE IF EXISTS ${schema}"
    eval "${mysql_command} -e \"${drop_query}\""
  fi
  local cat_command="cat"
  if [[ $COMPRESSED == 1 ]]; then
    cat_command+=" | pigz -d"
  fi
  import_command="${cat_command} | ${mysql_command}"
  eval "${import_command}"
}

command=${1}
case ${command} in
info) info ${@:2};;
dump) dump ${@:2};;
import) import ${@:2};;
esac