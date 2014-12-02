#!/bin/bash

# file to execute
BATCH_FILE=''

# path to the deployment folder
BATCH_RADARGUN_DEPLOYMENT_DIR=./radargun/deployment

BATCH_SOURCE_DIR=/tmp/reports/batch
BATCH_TARGET_DIR=./reports/batch

BATCH_USER=$(whoami)
BATCH_HOST='192.168.2.101'

DOWNLOAD_RESULTS=false
RUN_LOCAL=false
COMPILE=false

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--compile")
            COMPILE=true
            ;;
        "--user")
            BATCH_USER="$2"
            shift
            ;;
        "--host")
            BATCH_HOST="$2"
            shift
            ;;
        "--download")
            DOWNLOAD_RESULTS=true
            ;;
        "--source")
            BATCH_SOURCE_DIR="$2"
            shift
            ;;
        "--target")
            BATCH_TARGET_DIR="$2"
            shift
            ;;
        "--local")
            RUN_LOCAL=true
            ;;
        "--batch-file")
            BATCH_FILE="$2"
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

ADDRESS=$(address ${BATCH_HOST})
PORT=$(port ${BATCH_HOST})

if [ "${DOWNLOAD_RESULTS}" = true ]; then
    BATCH_TARGET_DIR=$(readlink -mv ${BATCH_TARGET_DIR})

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
fi

if ! [ -f tests/${BATCH_FILE} ]; then
    echo "Can't find batch file: tests/${BATCH_FILE}"
    exit 1
fi

cat benchmark-batch/batch-header.sh \
    | sed -e "s/COMPILE=false/COMPILE=${COMPILE}/g" \
    > benchmark-batch/batch-tmp.sh
cat tests/${BATCH_FILE} >> benchmark-batch/batch-tmp.sh
cat benchmark-batch/batch-footer.sh >> benchmark-batch/batch-tmp.sh

if [ "${RUN_LOCAL}" = true ]; then
    echo Copying batch file locally...
    cp benchmark-batch/batch-tmp.sh benchmark-batch/batch-execute.sh
    rm -rf benchmark-batch/batch-tmp.sh

    echo Starting local batch process...
    chmod +x benchmark-batch/batch-execute.sh
    ./benchmark-batch/batch-execute.sh${COMPILE}
else
    echo Copying batch file to remote server...
    scp -q -C -P ${PORT} benchmark-batch/batch-tmp.sh ${BATCH_USER}@${ADDRESS}:${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh &>/dev/null
    rm -rf benchmark-batch/batch-tmp.sh

    echo Starting remote batch process...
    ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "chmod +x ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"
    ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "screen -d -m ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"

    echo Done!
fi
