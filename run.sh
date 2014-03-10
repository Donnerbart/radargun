#!/bin/bash

RADARGUN_VERSION=2.0.0-SNAPSHOT
ARTIFACT_NAME=RadarGun-${RADARGUN_VERSION}
ARTIFACT_DIR=target/distribution/
TARGET_DIR=/tmp
RADARGUN_DIR=${TARGET_DIR}/${ARTIFACT_NAME}
MASTER=192.168.2.101

#the machines that make up the test cluster, this should include the master.
MACHINES='192.168.2.101 192.168.2.102 192.168.2.104'
USER=peter
REPORTS_DIR=/tmp/reports

function address {
	MACHINE=$1	

	if echo ${MACHINE}| grep ':' > /dev/null; then
		ADDRESS=${MACHINE%:*}
		echo ${ADDRESS}
	else
		echo ${MACHINE}	
	fi 
}

function port {	
	MACHINE=$1	

	if echo ${MACHINE}| grep ':' > /dev/null; then
		PORT=${MACHINE:$(expr index "$MACHINE" ":")}
		echo ${PORT}
	else
		echo 22		
	fi 	
}

function install {	
	MACHINE=$1	
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )

	echo ===============================================================
	echo Installing Radargun on ${MACHINE}
	echo ===============================================================
	
	ssh ${USER}@${ADDRESS} -p ${PORT} "killall -9 java"	
	ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}"
	scp -P ${PORT} ${ARTIFACT_DIR}/${ARTIFACT_NAME}.zip ${USER}@${ADDRESS}:${TARGET_DIR}/${ARTIFACT_NAME}.zip
	echo Unzipping ${ARTIFACT_NAME}.zip
	ssh ${USER}@${ADDRESS} -p ${PORT}  "unzip -q ${TARGET_DIR}/${ARTIFACT_NAME}.zip -d ${TARGET_DIR}"
	

	# Comment out these 2 lines of yourkit profiler should not be used.	
	scp -P ${PORT} libyjpagent.so ${USER}@${ADDRESS}:/tmp/
	scp -P ${PORT} environment.sh ${USER}@${ADDRESS}:${RADARGUN_DIR}/bin
	ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ~/Snapshots"
	
	echo ===============================================================
	echo Finished installing Radargun on ${MACHINE}
	echo ===============================================================
}

function start_master {
	MACHINE=$1	
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )
	
	echo ===============================================================
	echo Starting Radargun Master on ${MACHINE}
	echo ===============================================================

	ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${RADARGUN_DIR} ; bin/master.sh -c benchmark.xml"
	
	#nasty hack to give server time to startup
	echo "Waiting for master to be started"
	sleep 5s
	echo "Master fully started"

	echo ===============================================================
	echo Radargun Master started on ${MACHINE}
	echo ===============================================================
}

function start_slave {
	MACHINE=$1	
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )
	
	echo ===============================================================
	echo Starting Radargun Slave on ${MACHINE}
	echo ===============================================================

	ssh ${USER}@${ADDRESS} -p ${PORT} "cd ${RADARGUN_DIR} ; bin/slave.sh -m ${MASTER}:2103"

	echo ===============================================================
	echo Radargun Slave started on ${MACHINE}
	echo ===============================================================
}

function wait_completion {
	MACHINE=$1	
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )
	
	while [ 1 ];
	do 	
		ssh ${USER}@${ADDRESS} -p ${PORT} "cd $RADARGUN_DIR ; bin/master.sh -status | grep -q not"
		rc=$?
		if [[ $rc == 0 ]] ; 
		then
			return
		fi
  		sleep 5;
	done	
}

function tail_log {
	MACHINE=$1	
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )
	
	ssh  -t ${USER}@${ADDRESS} -p ${PORT} "tail -f $RADARGUN_DIR/radargun.log" &
}

function download_reports {
	MASTER=$1	
	DESTINATION_DIR=$2
	ADDRESS=$( address ${MACHINE} )	
	PORT=$( port ${MACHINE} )
		
	scp -P ${PORT} -q -r ${USER}@${ADDRESS}:${RADARGUN_DIR}/reports ${DESTINATION_DIR}
}

function download_logs {
	SLAVE=$1	
	DESTINATION_DIR=$2
	ADDRESS=$( address ${SLAVE} )	
	PORT=$( port ${SLAVE} )
	
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
	ADDRESS=$( address ${MASTER} )	
	PORT=$( port ${MASTER} )
		
	echo ===============================================================
	echo Starting Benchmark: ${BECHMARK_NAME}
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

	for SLAVE in $SLAVES
	do
		start_slave ${SLAVE}
	done

	tail_log ${MASTER} 
	wait_completion ${MASTER}
	
	echo Downloading reports and logs
	download_reports ${MASTER} ${DESTINATION_DIR}	
	for SLAVE in $SLAVES
	do
		download_logs ${SLAVE} ${DESTINATION_DIR}
	done	

	echo ===============================================================
	echo Benchmark Completed		
	echo Report for benchmark ${BENCHMARK_NAME} can be found in ${DESTINATION_DIR}
	echo ===============================================================
}

for machine in $MACHINES
do
	install $machine
done

# ================================================================

#benchmark dummy 'benchmark-4nodes-dummy.xml' '127.0.0.1 127.0.0.1 127.0.0.1 127.0.0.1' 
#benchmark 2-nodes 'benchmark-2nodes.xml' '127.0.0.1 127.0.0.1' 
benchmark 2-nodes 'benchmark-2nodes.xml' '192.168.2.101 192.168.2.102'
benchmark 3-nodes 'benchmark-3nodes.xml' '192.168.2.101 192.168.2.102 192.168.2.104' 
#benchmark 4-nodes 'benchmark-4nodes.xml' '127.0.0.1:22 127.0.0.1:22 127.0.0.1:22 127.0.0.1:22' 

#benchmark localbenchmark 'local-benchmark.xml' '127.0.0.1' 

# todo: option to kill all slaves/master on remote machines
