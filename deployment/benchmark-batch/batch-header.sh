#!/bin/bash
cd "$(dirname "$0")/.."

COMPILE=false
if [ "${COMPILE}" = true ]; then
    git pull
    ./compile.sh
fi

BATCH_START_TIME=$(date +%s)

