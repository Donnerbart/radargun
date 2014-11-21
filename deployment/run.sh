#!/bin/bash

cd "$(dirname "$0")"

RADARGUN_VERSION=2.0.0-SNAPSHOT
TARGET_DIR=/tmp
REPORTS_DIR=/tmp/reports

ARTIFACT_NAME=RadarGun-${RADARGUN_VERSION}
ARTIFACT_DIR=../target/distribution/
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

# kill java switch
KILL_JAVA=all
KILL_JAVA_SUDO=false

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

    # killing Java processes

    JAVA_SUDO=""
    JAVA_SUDO_LOG=""
    if [ "${KILL_JAVA_SUDO}" = "true" ]; then
        JAVA_SUDO="sudo "
        JAVA_SUDO_LOG=" with sudo"
    fi
    if [ "${KILL_JAVA}" = "all" ]; then
        echo Stopping all Java processes${JAVA_SUDO_LOG}
        ssh ${USER}@${ADDRESS} -p ${PORT} -t "${JAVA_SUDO}killall -9 java"
    elif [ "${KILL_JAVA}" = "no_idea" ]; then
        echo Stopping all Java processes${JAVA_SUDO_LOG} except IDEA
        ssh ${USER}@${ADDRESS} -p ${PORT} -t "ps aux | grep java | grep -vi com.intellij.idea.Main | grep -v grep | awk '{print \$2}' | xargs ${JAVA_SUDO}kill -9"
    fi

    # uploading target file

    echo Checking checksum of target file...
	ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${TARGET_DIR} && rm -f ${ARTIFACT_NAME}.md5 && md5sum -b ${ARTIFACT_NAME}.zip > ${ARTIFACT_NAME}.md5 2>/dev/null"
	scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${TARGET_DIR}/${ARTIFACT_NAME}.md5 ${ARTIFACT_DIR}

    DO_UPLOAD=true
    if [ -s ${ARTIFACT_DIR}/${ARTIFACT_NAME}.md5 ]; then
        DO_UPLOAD=false
        CURR=$(pwd)
        cd ${ARTIFACT_DIR}
        md5sum --status -c ${ARTIFACT_NAME}.md5
        if [ $? -ne 0 ]; then
            DO_UPLOAD=true
        fi
        rm ${ARTIFACT_NAME}.md5
        cd ${CURR}
    fi

    if [ "${DO_UPLOAD}" = true ]; then
        echo Uploading target file...
	    ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}.zip"
	    scp -C -P ${PORT} ${ARTIFACT_DIR}/${ARTIFACT_NAME}.zip ${USER}@${ADDRESS}:${TARGET_DIR}/${ARTIFACT_NAME}.zip
	else
	    echo Target file is already uploaded!
	fi

	# unzipping target file

    echo Unzipping ${ARTIFACT_NAME}.zip
    ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}"
    ssh ${USER}@${ADDRESS} -p ${PORT}  "unzip -q ${TARGET_DIR}/${ARTIFACT_NAME}.zip -d ${TARGET_DIR}"

    # upload debugger

    if [ "${YOURKIT_ENABLED}" = "true" ]; then
	    echo YourKit is enabled
	    scp -C -P ${PORT} libyjpagent.so ${USER}@${ADDRESS}:/tmp/
	    scp -C -P ${PORT} environment-yourkit.sh ${USER}@${ADDRESS}:${RADARGUN_DIR}/bin/environment.sh
	    ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ~/Snapshots"
    elif [ "${JACOCO_ENABLED}" = "true" ]; then
	    echo Jacoco is enabled
            scp -C -P ${PORT} jacocoagent.jar ${USER}@${ADDRESS}:/tmp/
            scp -C -P ${PORT} environment-jacoco.sh ${USER}@${ADDRESS}:${RADARGUN_DIR}/bin/environment.sh
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
		
	scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${RADARGUN_DIR}/reports ${DESTINATION_DIR}
}

function download_logs {
	SLAVE=$1
	DESTINATION_DIR=$2
	ADDRESS=$(address ${SLAVE})
	PORT=$(port ${SLAVE})
	
	mkdir -p ${DESTINATION_DIR}/logs
	scp -C -P ${PORT} -q ${USER}@${ADDRESS}:${RADARGUN_DIR}/*.log ${DESTINATION_DIR}/logs
	scp -C -P ${PORT} -q ${USER}@${ADDRESS}:${RADARGUN_DIR}/*.out ${DESTINATION_DIR}/logs
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
	rm -rf ${REPORTS_DIR}/latest
	ln -s ${DESTINATION_DIR} ${REPORTS_DIR}/latest

	echo scp ${BENCHMARK_FILE} -P ${PORT} ${USER}@${ADDRESS}:${RADARGUN_DIR}/benchmark.xml
	scp -C -P ${PORT} ${BENCHMARK_FILE} ${USER}@${ADDRESS}:${RADARGUN_DIR}/benchmark.xml
	
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

	cd ${REPORTS_DIR}
	rm -rf latest.zip
	zip -r latest.zip ./latest/

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
    benchmark ${BENCHMARK_OPTS} "${MACHINES}"
    exit 0
fi

#benchmark 1-nodes benchmark-1nodes.xml "${MACHINE1}"
#benchmark 2-nodes benchmark-2nodes.xml "${MACHINE1} ${MACHINE2}"
#benchmark 3-nodes benchmark-3nodes.xml "${MACHINE1} ${MACHINE2} ${MACHINE4}"
benchmark 4-nodes benchmark-4nodes.xml "${MACHINE1} ${MACHINE2} ${MACHINE3} ${MACHINE4}"
