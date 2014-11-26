#!/bin/bash

cd "$(dirname "$0")"

DOWNLOAD_TARGET=./reports
DOWNLOAD_REMOTE_REPORTS_DIR=/tmp/reports

DOWNLOAD_USER=$(whoami)
DOWNLOAD_HOST='192.168.2.101'

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
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

DOWNLOAD_TARGET=$(readlink -mv ${DOWNLOAD_TARGET})
DOWNLOAD_REMOTE_REPORTS_DIR=$(readlink -mv ${DOWNLOAD_REMOTE_REPORTS_DIR})

ADDRESS=$(address ${DOWNLOAD_HOST})
PORT=$(port ${DOWNLOAD_HOST})

mkdir -p ${DOWNLOAD_TARGET}
cd ${DOWNLOAD_TARGET}

if [ -d "latest-remote" ]; then
    rm -rf latest-remote
fi
if [ -f "latest-remote.zip" ]; then
    rm latest-remote.zip
fi

echo Downloading latest reports...
scp -C -P ${PORT} -q -r ${DOWNLOAD_USER}@${ADDRESS}:${DOWNLOAD_REMOTE_REPORTS_DIR}/latest.zip ./latest-remote.zip
echo Done!

if [ -f "latest-remote.zip" ]; then
    echo Unpacking latest reports...
    mkdir -p latest-remote
    cd latest-remote
    unzip ../latest-remote.zip
    echo Done!

    exit 0
else
    echo Could not download latest reports!
    exit 1
fi
