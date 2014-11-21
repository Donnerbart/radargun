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

echo Downloading latest reports...
scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${REPORTS_DIR}/latest.zip .
echo Done!

if [ -f "latest.zip" ]; then
    echo Unpacking latest reports...
    unzip latest.zip
    echo Done!

    exit 0
else
    echo Could not download latest reports!
    exit 1
fi