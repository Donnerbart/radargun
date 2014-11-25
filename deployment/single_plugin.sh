#!/bin/bash

NAME="Hazelcast 3.4"
PLUGIN="hazelcast34"

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--name")
            NAME="$2"
            shift
            ;;
        "--plugin")
            PLUGIN="$2"
            shift
            ;;
        *)
            echo "Warning: unknown argument ${1}"
            exit 1
            ;;
    esac
    shift
done

# create dynamic benchmark file
BENCHMARK_FILE=benchmark-configurations/configuration-tmp.xml
rm -rf ${BENCHMARK_FILE}
touch ${BENCHMARK_FILE}
cat benchmark-configurations/single-template.xml \
    | sed -e "s/{NAME}/${NAME}/g" \
    | sed -e "s/{PLUGIN}/${PLUGIN}/g" \
    >> ${BENCHMARK_FILE}
