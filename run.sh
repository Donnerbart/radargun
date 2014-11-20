#!/bin/bash

cd "$(dirname "$0")"

RADARGUN_VERSION=2.0.0-SNAPSHOT
TARGET_DIR=/tmp
REPORTS_DIR=/tmp/reports

ARTIFACT_NAME=RadarGun-${RADARGUN_VERSION}
ARTIFACT_DIR=target/distribution/
RADARGUN_DIR=${TARGET_DIR}/${ARTIFACT_NAME}

USER=$(whoami)
BENCHMARK_OPTS=""

# the machines that make up the test cluster, this should include the master
MACHINE1='192.168.2.101'
MACHINE2='192.168.2.102'
MACHINE3='192.168.2.103'
MACHINE4='192.168.2.104'
MACHINES="${MACHINE1} ${MACHINE2} ${MACHINE3} ${MACHINE4}"

# only one can be enabled
YOURKIT_ENABLED=false
JACOCO_ENABLED=false

# kill_java
KILL_JAVA=true

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

function install {
	MACHINE=$1
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})

	echo ===============================================================
	echo Installing Radargun on ${MACHINE}
	echo ===============================================================

	if [ "${KILL_JAVA}" = "true" ]; then
	    ssh ${USER}@${ADDRESS} -p ${PORT} "killall -9 java"
	fi
	ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}"
	scp -P ${PORT} ${ARTIFACT_DIR}/${ARTIFACT_NAME}.zip ${USER}@${ADDRESS}:${TARGET_DIR}/${ARTIFACT_NAME}.zip
	echo Unzipping ${ARTIFACT_NAME}.zip
	ssh ${USER}@${ADDRESS} -p ${PORT}  "unzip -q ${TARGET_DIR}/${ARTIFACT_NAME}.zip -d ${TARGET_DIR}"

    if [ "${YOURKIT_ENABLED}" = "true" ]; then
	    echo YourKit is enabled
	    scp -P ${PORT} libyjpagent.so ${USER}@${ADDRESS}:/tmp/
	    scp -P ${PORT} environment-yourkit.sh ${USER}@${ADDRESS}:${RADARGUN_DIR}/bin/environment.sh
	    ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ~/Snapshots"
    elif [ "${JACOCO_ENABLED}" = "true" ]; then
	    echo Jacoco is enabled
            scp -P ${PORT} jacocoagent.jar ${USER}@${ADDRESS}:/tmp/
            scp -P ${PORT} environment-jacoco.sh ${USER}@${ADDRESS}:${RADARGUN_DIR}/bin/environment.sh
    else
	    echo Jacoc and Yourkit are disabled
	fi

	echo ===============================================================
	echo Finished installing Radargun on ${MACHINE}
	echo ===============================================================
}

function start_master {
	MACHINE=$1
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})

	echo ===============================================================
	echo Starting Radargun Master on ${MACHINE}
	echo ===============================================================

	ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${RADARGUN_DIR}; bin/master.sh -c benchmark.xml"
	
	# nasty hack to give server time to startup
	echo "Waiting for master to be started"
	sleep 5s
	echo "Master fully started"

	echo ===============================================================
	echo Radargun Master started on ${MACHINE}
	echo ===============================================================
}

function start_slave {
	MACHINE=$1
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})
	
	echo ===============================================================
	echo Starting Radargun Slave on ${MACHINE}
	echo ===============================================================

	ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${RADARGUN_DIR}; bin/slave.sh -m ${MASTER}:2103"

	echo ===============================================================
	echo Radargun Slave started on ${MACHINE}
	echo ===============================================================
}

function wait_completion {
	MACHINE=$1
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})
	
	while [ 1 ];
	do
		ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${RADARGUN_DIR}; bin/master.sh -status | grep -q not"
		RC=$?
		if [[ ${RC} == 0 ]]; then
			return
		fi
  		sleep 5;
	done
}

function tail_log {
	MACHINE=$1
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})
	
	ssh -t ${USER}@${ADDRESS} -p ${PORT} "tail -f ${RADARGUN_DIR}/radargun.log" &
}

function download_reports {
	MASTER=$1
	DESTINATION_DIR=$2
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})
		
	scp -P ${PORT} -q -r ${USER}@${ADDRESS}:${RADARGUN_DIR}/reports ${DESTINATION_DIR}
}

function download_logs {
	SLAVE=$1
	DESTINATION_DIR=$2
	ADDRESS=$(address ${SLAVE})
	PORT=$(port ${SLAVE})
	
	mkdir -p ${DESTINATION_DIR}/logs
	scp -P ${PORT} -q ${USER}@${ADDRESS}:${RADARGUN_DIR}/*.log ${DESTINATION_DIR}/logs
	scp -P ${PORT} -q ${USER}@${ADDRESS}:${RADARGUN_DIR}/*.out ${DESTINATION_DIR}/logs
}

function benchmark {
	BENCHMARK_NAME=$1
	BENCHMARK_FILE=$2
	SLAVES=$3
	TIMESTAMP=$(date +%s)
	DESTINATION_DIR=${REPORTS_DIR}/${BENCHMARK_NAME}/${TIMESTAMP}
	ADDRESS=$(address ${MASTER})
	PORT=$(port ${MASTER})

	echo ===============================================================
	echo Starting Benchmark: ${BENCHMARK_NAME}
	echo Master: ${MASTER}
	echo Slaves: ${SLAVES}
	echo Benchmark file: ${BENCHMARK_FILE}
	echo Output dir: ${DESTINATION_DIR}
	echo ===============================================================

	mkdir -p ${DESTINATION_DIR}

	echo scp ${BENCHMARK_FILE} -P ${PORT} ${USER}@${ADDRESS}:${RADARGUN_DIR}/benchmark.xml
	scp -P ${PORT} ${BENCHMARK_FILE} ${USER}@${ADDRESS}:${RADARGUN_DIR}/benchmark.xml
	
	ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${RADARGUN_DIR}/reports"

	start_master ${MASTER}

	for SLAVE in ${SLAVES}
	do
		start_slave ${SLAVE}
	done

	tail_log ${MASTER}
	wait_completion ${MASTER}
	
	echo Downloading reports and logs
	download_reports ${MASTER} ${DESTINATION_DIR}
	for SLAVE in ${SLAVES}
	do
		download_logs ${SLAVE} ${DESTINATION_DIR}
	done

	echo ===============================================================
	echo Benchmark Completed
	echo Report for benchmark ${BENCHMARK_NAME} can be found in ${DESTINATION_DIR}
	echo ===============================================================
}

for MACHINE in ${MACHINES}
do
	install ${MACHINE}
done

# ================================================================

if [ -n "${BENCHMARK_OPTS}" ]; then
    echo Executing benchmark ${BENCHMARK_OPTS}
    benchmark ${BENCHMARK_OPTS}
    exit 0
fi

#benchmark 1-nodes 'benchmark-1nodes.xml' "${MACHINE1}"
#benchmark 2-nodes 'benchmark-2nodes.xml' "${MACHINE1} ${MACHINE2}"
#benchmark 3-nodes 'benchmark-3nodes.xml' "${MACHINE1} ${MACHINE2} ${MACHINE4}"
benchmark 4-nodes 'benchmark-4nodes.xml' "${MACHINE1} ${MACHINE2} ${MACHINE3} ${MACHINE4}"
