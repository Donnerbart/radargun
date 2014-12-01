#!/bin/bash

BATCH_SOURCE_DIR=/tmp/reports/batch
BATCH_TARGET_DIR=./reports/batch

BATCH_USER=$(whoami)
BATCH_HOST='192.168.2.101'

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--user")
            BATCH_USER="$2"
            shift
            ;;
        "--host")
            BATCH_HOST="$2"
            shift
            ;;
        "--source")
            BATCH_SOURCE_DIR="$2"
            shift
            ;;
        "--target")
            BATCH_TARGET_DIR="$2"
            shift
            ;;
        *)
            echo "Warning: unknown argument ${1}"
            exit 1
            ;;
    esac
    shift
done

#####################
##### functions #####
#####################

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

###########################
##### batch execution #####
###########################

BATCH_TARGET_DIR=$(readlink -mv ${BATCH_TARGET_DIR})

ADDRESS=$(address ${BATCH_HOST})
PORT=$(port ${BATCH_HOST})

mkdir -p ${BATCH_TARGET_DIR}
cd ${BATCH_TARGET_DIR}

if [ -f "batch.zip" ]; then
    rm batch.zip
fi

echo Zipping batch reports...
ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "cd ${BATCH_SOURCE_DIR}; zip -r batch.zip ."

echo Downloading batch reports...
scp -C -P ${PORT} -r ${DOWNLOAD_USER}@${ADDRESS}:${BATCH_SOURCE_DIR}/batch.zip batch.zip

if [ -f "batch.zip" ]; then
    echo Unpacking batch reports...
    unzip batch.zip
    echo Done!

    exit 0
else
    echo Could not download batch reports!
    exit 1
fi

echo Done!