#!/bin/bash

cd "$(dirname "$0")"

DOWNLOAD_TARGET=./reports
DOWNLOAD_REMOTE_REPORTS_DIR=/tmp/reports

DOWNLOAD_USER=$(whoami)
DOWNLOAD_HOST='192.168.2.101'

# override settings with local-settings file
if [ -f conf-local/local-settings ]; then
    source conf-local/local-settings
fi

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

ADDRESS=$(address ${DOWNLOAD_HOST})
PORT=$(port ${DOWNLOAD_HOST})

cd ${DOWNLOAD_TARGET}
if [ -d "latest" ]; then
    rm -rf latest
fi
if [ -f "latest.zip" ]; then
    rm latest.zip
fi

echo Downloading latest reports...
scp -C -P ${PORT} -q -r ${DOWNLOAD_USER}@${ADDRESS}:${DOWNLOAD_REMOTE_REPORTS_DIR}/latest.zip .
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