#!/bin/bash

BATCH_SOURCE_DIR=/tmp/results/batch
BATCH_TARGET_DIR=./reports

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

ADDRESS=$(address ${BATCH_HOST})
PORT=$(port ${BATCH_HOST})

echo Starting remote batch process...
echo Executing: screen -d -m ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh
ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "chmod +x ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"
ssh -a ${BATCH_USER}@${ADDRESS} -p ${PORT} "screen -d -m ${BATCH_RADARGUN_DEPLOYMENT_DIR}/benchmark-batch/batch-execute.sh"

echo Done!