#!/bin/bash

#########################
##### configuration #####
#########################

RADARGUN_VERSION=2.0.0-SNAPSHOT

TARGET_DIR=/tmp
REPORTS_DIR=/tmp/reports

# only one can be enabled
YOURKIT_ENABLED=false
JACOCO_ENABLED=false

# ssh username
USER=$(whoami)

# kill java switch
KILL_JAVA=all
KILL_JAVA_SUDO=false

# skip unzip if file will not be uploaded
SKIP_UNZIP_IF_UPLOAD_SKIPPED=true

# the machines that make up the test cluster, the first one is used as master
MACHINES=('192.168.2.101' '192.168.2.102' '192.168.2.103' '192.168.2.104')

# benchmark configuration
CONFIGURATION=latest
SCENARIO=atomic

DURATION=5m
NUMBER_OF_THREADS=128
NUMBER_OF_ITERATIONS=1

GET_RATIO=4
PUT_RATIO=1

KEY_GENERATOR=LongKeyGenerator #StringKeyGenerator
VALUE_GENERATOR=IntValueGenerator #ByteArrayValueGenerator

LOAD_DATA_NUM_ENTRIES=100000

KEY_TOTAL_ENTRIES=100000
KEY_NUM_ENTRIES_PER_THREAD=0
VALUE_ENTRY_SIZE=8

# other configuration

SHOW_CONFIG=false
DRY=false

DO_BATCH=false
BATCH_NAME=''

# override settings with local-settings file
if [ -f local-settings ]; then
    source local-settings
fi

# read in any command-line params
while ! [ -z $1 ]
do
    case "$1" in
        "--show-config")
            SHOW_CONFIG=true
            ;;
        "--dry")
            DRY=true
            ;;
        "--batch-name")
            DO_BATCH=true
            BATCH_NAME="$2"
            shift
            ;;
        "--single-plugin")
            CONFIGURATION="configuration-tmp"
            if ! [ -e benchmark-configurations/${CONFIGURATION}.xml ]; then
                echo "Can't find configuration file: benchmark-configurations/${CONFIGURATION}.xml"
                exit 1
            fi
            ;;
        "--configuration")
            CONFIGURATION="$2"
            if [ "single-template" = "${CONFIGURATION}" ]; then
                echo "Can't use template file as configuration!"
                exit 1
            fi
            if ! [ -e benchmark-configurations/${CONFIGURATION}.xml ]; then
                echo "Can't find configuration file: benchmark-configurations/${CONFIGURATION}.xml"
                exit 1
            fi
            shift
            ;;
        "--scenario")
            SCENARIO="$2"
            if ! [ -e benchmark-scenarios/${SCENARIO}.xml ]; then
                echo "Can't find configuration file: benchmark-scenarios/${SCENARIO}.xml"
                exit 1
            fi
            shift
            ;;
        "--duration")
            DURATION="$2"
            shift
            ;;
        "--threads")
            NUMBER_OF_THREADS="$2"
            shift
            ;;
        "--iterations")
            NUMBER_OF_ITERATIONS="$2"
            shift
            ;;
        "--get-ratio")
            GET_RATIO="$2"
            shift
            ;;
        "--put-ratio")
            PUT_RATIO="$2"
            shift
            ;;
        "--key-generator")
            KEY_GENERATOR="$2"
            shift
            ;;
        "--value-generator")
            VALUE_GENERATOR="$2"
            shift
            ;;
        "--load-data-num-entries")
            LOAD_DATA_NUM_ENTRIES="$2"
            shift
            ;;
        "--key-total-entries")
            KEY_TOTAL_ENTRIES="$2"
            KEY_NUM_ENTRIES_PER_THREAD=0
            shift
            ;;
        "--key-num-entries-per-thread")
            KEY_TOTAL_ENTRIES=0
            KEY_NUM_ENTRIES_PER_THREAD="$2"
            shift
            ;;
        "--value-entry-size")
            VALUE_ENTRY_SIZE="$2"
            shift
            ;;
        *)
            echo "Warning: unknown argument ${1}"
            exit 1
            ;;
    esac
    shift
done

cd "$(dirname "$0")"

TARGET_DIR=$(readlink -mv ${TARGET_DIR})
REPORTS_DIR=$(readlink -mv ${REPORTS_DIR})
ARTIFACT_DIR=$(readlink -mv ../target/distribution/)

ARTIFACT_NAME=RadarGun-${RADARGUN_VERSION}
RADARGUN_DIR=${TARGET_DIR}/${ARTIFACT_NAME}
BENCHMARK_FILE=benchmark-xml/benchmark-tmp.xml

NUMBER_OF_SLAVES=${#MACHINES[@]}

#####################
##### functions #####
#####################

function create_config {
	# create dynamic benchmark file
	rm -rf ${BENCHMARK_FILE}
	touch ${BENCHMARK_FILE}
	cat benchmark-xml/benchmark-header.xml \
	    | sed -e "s/{MASTER}/${MACHINES[0]}/g" \
	    | sed -e "s/{SLAVE_NUMBER}/${NUMBER_OF_SLAVES}/g" \
	    >> ${BENCHMARK_FILE}
	cat benchmark-configurations/${CONFIGURATION}.xml >> ${BENCHMARK_FILE}
	cat benchmark-scenarios/${SCENARIO}.xml \
	    | sed -e "s/{DURATION}/${DURATION}/g" \
	    | sed -e "s/{NUMBER_OF_THREADS}/${NUMBER_OF_THREADS}/g" \
	    | sed -e "s/{NUMBER_OF_ITERATIONS}/${NUMBER_OF_ITERATIONS}/g" \
	    | sed -e "s/{GET_RATIO}/${GET_RATIO}/g" \
	    | sed -e "s/{PUT_RATIO}/${PUT_RATIO}/g" \
	    | sed -e "s/{KEY_GENERATOR}/${KEY_GENERATOR}/g" \
	    | sed -e "s/{VALUE_GENERATOR}/${VALUE_GENERATOR}/g" \
	    | sed -e "s/{LOAD_DATA_NUM_ENTRIES}/${LOAD_DATA_NUM_ENTRIES}/g" \
	    | sed -e "s/{KEY_TOTAL_ENTRIES}/${KEY_TOTAL_ENTRIES}/g" \
	    | sed -e "s/{KEY_NUM_ENTRIES_PER_THREAD}/${KEY_NUM_ENTRIES_PER_THREAD}/g" \
	    | sed -e "s/{VALUE_ENTRY_SIZE}/${VALUE_ENTRY_SIZE}/g" \
	    >> ${BENCHMARK_FILE}
	cat benchmark-xml/benchmark-footer.xml >> ${BENCHMARK_FILE}
}

function benchmark_info {
	echo ===============================================================
	echo =================== Benchmark configuration ===================
	echo ===============================================================
	echo Master: ${MACHINES[0]}
	echo Slaves: ${MACHINES[@]}
	echo Benchmark configuration: ${CONFIGURATION}
	echo Benchmark scenario: ${SCENARIO}
	echo Duration: ${DURATION}
	echo Number of threads: ${NUMBER_OF_THREADS}
	echo Number of iterations: ${NUMBER_OF_ITERATIONS}
	echo GET ratio: ${GET_RATIO}
	echo PUT ratio: ${PUT_RATIO}
	echo Key generator: ${KEY_GENERATOR}
	echo Value generator: ${VALUE_GENERATOR}
	echo Load-data num-entries: ${LOAD_DATA_NUM_ENTRIES}
	echo Key generator total-entries: ${KEY_TOTAL_ENTRIES}
	echo Key generator num-entries-per-thread: ${KEY_NUM_ENTRIES_PER_THREAD}
	echo Value generator entry-size: ${VALUE_ENTRY_SIZE}
	echo Batch execution: ${DO_BATCH}
	if [ ${DO_BATCH} = true ]; then
	    echo Batch testname: ${BATCH_NAME}
	fi
	echo ===============================================================
}

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
    if [ "${DO_UPLOAD}" = true ] || [ "${SKIP_UNZIP_IF_UPLOAD_SKIPPED}" = false ]; then
        echo Unzipping ${ARTIFACT_NAME}.zip
        ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}"
        ssh ${USER}@${ADDRESS} -p ${PORT}  "unzip -qo ${TARGET_DIR}/${ARTIFACT_NAME}.zip -d ${TARGET_DIR}"
    else
        ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}/results; rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}/*.log; rm -fr ${TARGET_DIR}/${ARTIFACT_NAME}/*.out"
    fi

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
	MASTER=$2
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
	
	ssh ${USER}@${ADDRESS} -p ${PORT} "tail -f ${RADARGUN_DIR}/radargun.log" &
}

function download_results {
	MASTER=$1
	DESTINATION_DIR=$2
	ADDRESS=$(address ${MACHINE})
	PORT=$(port ${MACHINE})
		
	scp -C -P ${PORT} -q -r ${USER}@${ADDRESS}:${RADARGUN_DIR}/results ${DESTINATION_DIR}
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
    MASTER=${MACHINES[0]}
	BENCHMARK_NAME="${NUMBER_OF_SLAVES}-nodes"
	TIMESTAMP=$(date +%s)
	DESTINATION_DIR=${REPORTS_DIR}/${BENCHMARK_NAME}/${TIMESTAMP}

	echo ===============================================================
	echo Starting Benchmark: ${BENCHMARK_NAME}
	echo Output dir: ${DESTINATION_DIR}
	echo ===============================================================

    # parse master network configuration
  	ADDRESS=$(address ${MASTER})
    PORT=$(port ${MASTER})

	# start master
	scp -C -P ${PORT} ${BENCHMARK_FILE} ${USER}@${ADDRESS}:${RADARGUN_DIR}/benchmark.xml
	ssh ${USER}@${ADDRESS} -p ${PORT} "rm -fr ${RADARGUN_DIR}/reports"
	start_master ${MASTER}

	# start slaves
	for SLAVE in "${MACHINES[@]}"
	do
		start_slave ${SLAVE} ${MASTER}
	done

	# wait for benchmark completion
	tail_log ${MASTER}
	wait_completion ${MASTER}

	# download results
    mkdir -p ${DESTINATION_DIR}
	echo Downloading results and logs
	download_results ${MASTER} ${DESTINATION_DIR}
	for SLAVE in "${MACHINES[@]}"
	do
		download_logs ${SLAVE} ${DESTINATION_DIR}
	done

    if [ "${DO_BATCH}" = true ]; then
        # archive batch results
        BATCH_DIR="${REPORTS_DIR}/batch"
        mkdir -p ${BATCH_DIR}

        cd ${DESTINATION_DIR}
        zip -r ${BATCH_DIR}/${BATCH_NAME}.zip .
        mv ${DESTINATION_DIR} ${BATCH_DIR}
        mv ${BATCH_DIR}/${TIMESTAMP} ${BATCH_DIR}/${BATCH_NAME}
    else
        # create latest symlink
        LATEST="${REPORTS_DIR}/latest"
        rm -rf ${LATEST}
        ln -s $(readlink -mv ${DESTINATION_DIR}) ${LATEST}

        # zip latest.zip
        rm -rf ${REPORTS_DIR}/latest.zip
        cd ${LATEST}
        zip -r ${REPORTS_DIR}/latest.zip .
    fi

	echo ===============================================================
	echo Benchmark Completed
	echo Report for benchmark ${BENCHMARK_NAME} can be found in ${DESTINATION_DIR}
	echo ===============================================================
}

#####################
##### benchmark #####
#####################

benchmark_info

create_config

if [ "${SHOW_CONFIG}" = true ]; then
    less benchmark-xml/benchmark-tmp.xml
fi

if [ "${DRY}" = true ]; then
    exit 0
fi

START_TIME=$(date +%s)

# install on all slaves
for MACHINE in "${MACHINES[@]}"
do
    install ${MACHINE}
done

benchmark

END_TIME=$(date +%s)

benchmark_info

echo ===============================================================
echo Total runtime: $(echo "${END_TIME} - ${START_TIME}" | bc) seconds
echo ===============================================================
