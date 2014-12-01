#!/bin/bash
cd "$(dirname "$0")/.."

COMPILE=false

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--compile")
            COMPILE=true
            ;;
        *)
            echo "Warning: unknown argument ${1}"
            exit 1
            ;;
    esac
    shift
done

if [ "${COMPILE}" = true ]; then
    git pull
    ./compile.sh
fi

BATCH_START_TIME=$(date +%s)
