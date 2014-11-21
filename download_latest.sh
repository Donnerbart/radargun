#!/bin/bash

cd "$(dirname "$0")"

TARGET_DIR=./reports
REPORTS_DIR=/tmp/reports

USER=$(whoami)
MACHINE1='192.168.2.101'

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

MASTER=${MACHINE1}

function address {
	MACHINE=$1

	if echo ${MACHINE} | grep ':' > /dev/null; then
		ADDRESS=${MACHINE%:*}
		echo ${ADDRESS}
	else
		echo ${MACHINE}
	fi
}

function port {
	MACHINE=$1

	if echo ${MACHINE} | grep ':' > /dev/null; then
		PORT=${MACHINE:$(expr index "$MACHINE" ":")}
		echo ${PORT}
	else
		echo 22
	fi
}

ADDRESS=$(address ${MASTER})
PORT=$(port ${MASTER})

cd ${TARGET_DIR}
if [ -d "latest" ]; then
    rm -rf latest
fi
if [ -f "latest.zip" ]; then
    rm latest.zip
fi

scp -C -P ${PORT} -r ${USER}@${ADDRESS}:${REPORTS_DIR}/latest.zip .

if [ -f "latest.zip" ]; then
    unzip latest.zip
else
    echo Could not download latest reports!
fi