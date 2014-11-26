#!/bin/bash

#########################
##### configuration #####
#########################

# ssh username
SSH_USER=$(whoami)

# the remote machines
SSH_MACHINES=('192.168.2.101' '192.168.2.102' '192.168.2.103' '192.168.2.104')

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

MACHINE_INDEX=1
if [ -n "$1" ]; then
    MACHINE_INDEX=$1
fi

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

MACHINE=${SSH_MACHINES[((${MACHINE_INDEX} - 1))]}
ADDRESS=$(address ${MACHINE})
PORT=$(port ${MACHINE})

echo Connecting to ${ADDRESS}:${PORT}
ssh ${SSH_USER}@${ADDRESS} -p ${PORT}