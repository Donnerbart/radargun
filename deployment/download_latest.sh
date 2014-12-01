#!/bin/bash

cd "$(dirname "$0")"

DOWNLOAD_SOURCE_DIR=/tmp/reports
DOWNLOAD_TARGET_DIR=./reports

DOWNLOAD_USER=$(whoami)
DOWNLOAD_HOST='192.168.2.101'

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--user")
            DOWNLOAD_USER="$2"
            shift
            ;;
        "--host")
            DOWNLOAD_HOST="$2"
            shift
            ;;
        "--source")
            DOWNLOAD_SOURCE_DIR="$2"
            shift
            ;;
        "--target")
            DOWNLOAD_TARGET_DIR="$2"
            shift
            ;;
        *)
            echo "Warning: unknown argument ${1}"
            exit 1
            ;;
    esac
    shift
done

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

DOWNLOAD_TARGET_DIR=$(readlink -mv ${DOWNLOAD_TARGET_DIR})

ADDRESS=$(address ${DOWNLOAD_HOST})
PORT=$(port ${DOWNLOAD_HOST})

mkdir -p ${DOWNLOAD_TARGET_DIR}
cd ${DOWNLOAD_TARGET_DIR}

if [ -d "latest-remote" ]; then
    rm -rf latest-remote
fi
if [ -f "latest-remote.zip" ]; then
    rm latest-remote.zip
fi

echo Downloading latest reports...
scp -C -P ${PORT} -q -r ${DOWNLOAD_USER}@${ADDRESS}:${DOWNLOAD_SOURCE_DIR}/latest.zip ./latest-remote.zip
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
