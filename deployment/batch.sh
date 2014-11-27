#!/bin/bash

# file to execute
BATCH_FILE=example

# path to the deployment folder
BATCH_RADARGUN_DEPLOYMENT_DIR=./radargun/deployment

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

if ! [ -e tests/${BATCH_FILE} ]; then
    echo "Can't find batch file: tests/${BATCH_FILE}"
    exit 1
fi

cat benchmark-batch/batch-header.sh > benchmark-batch/batch-tmp.sh
cat tests/${BATCH_FILE} >> benchmark-batch/batch-tmp.sh

echo Copying batch file to remote server...
scp -q -C -P ${PORT} benchmark-batch/batch-tmp.sh ${BATCH_USER}@${ADDRESS}:${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh &>/dev/null
rm -rf benchmark-batch/batch-tmp.sh

echo Starting remote batch process...
ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "chmod +x ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"
ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "screen -d -m ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"

echo Done!