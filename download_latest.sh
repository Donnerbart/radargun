#!/bin/bash

cd "$(dirname "$0")"

TARGET_DIR=reports
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

function download_latest_report {
	MACHINE=$1
	DESTINATION_DIR=$2
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})

	scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${REPORTS_DIR}/latest.zip ${DESTINATION_DIR}
}

cd ${TARGET_DIR}
rm -rf latest
rm latest.zip

download_latest_report ${MASTER} ${TARGET_DIR}

unzip latest.zip