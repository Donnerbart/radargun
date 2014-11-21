#!/bin/bash

cd "$(dirname "$0")"

TARGET_DIR=reports
REPORTS_DIR=/tmp/reports

USER=$(whoami)

TESTNAME='local'
MACHINE1='192.168.2.101'
BENCHMARK_OPTS=''

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

    #ssh -t ${USER}@${ADDRESS} -p ${PORT} "cd ${REPORTS_DIR} && zip -r latest.zip latest/"
	scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${REPORTS_DIR}/latest.zip ${DESTINATION_DIR}
}

download_latest_report ${MASTER} ${TARGET_DIR}

cd ${TARGET_DIR}
unzip latest.zip