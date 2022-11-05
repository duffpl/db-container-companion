#!/bin/bash
source /tmp/config.sh
ANONYMIZED=${ANONYMIZED:-1}
COMPRESSED=${COMPRESSED:-1}
get_dump()
{
  service=$1
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
  local dump_command_suffix=""
  if [[ $ANONYMIZED == 1 ]]; then
      skip_tables=( $(gojq -r ".skipTables[]" ${anonymization_config_file}))
      for table_name in "${skip_tables[@]}";
      do
          ignore_tables="${ignore_tables} --ignore-table ${schema}.$table_name"
      done
      local mdp_config=`gojq ".mdp" ${anonymization_config_file} | gzip | base64 -w 0`
      dump_command_suffix="${dump_command_suffix}) | /usr/local/bin/build/go-mdp -z -f ${mdp_config}"
  fi
  dump_command="${dump_command} ${ignore_tables} ${dump_command_suffix}"
  if [[ $COMPRESSED == 1 ]]; then
    dump_command+=" | pigz "
  fi
 eval "${dump_command}"
}

import()
{
  service=$1
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
  local import_command="mysql ${connection_params}"
  local cat_command="cat"
  dump_command="${dump_command} ${ignore_tables} ${dump_command_suffix})"
  if [[ $COMPRESSED == 1 ]]; then
    cat_command+=" | pigz -d"
  fi
  import_command="${cat_command} | ${import_command}"
 eval "${import_command}"
}

ARG1=${1}
ARG2=${2}
case ${ARG1} in
dump) get_dump ${ARG2} ;;
import) import ${ARG2} ;;
esac