#!/bin/sh
###### This script is designed to be called from other scripts, to set environment variables including the bind
###### for cache products, as well as any JVM options.

### Set your bind address for the tests to use. Could be an IP, host name or a reference to an environment variable.

## Helper to grab the IP off a given interface.  In this case, eth0.  Replace eth0 with eth1, eth0:2, etc as desired
## and assign this to BIND_ADDRESS.

#ETH0_IP=`/sbin/ifconfig eth0 | grep inet | sed -e 's/^\s*//' -e 's/Bcast.*//' -e 's/inet addr://'`
ETH0_IP=$( ip addr list eth0 |grep "inet " |cut -d' ' -f6|cut -d/ -f1 )
echo ${ETH0_IP}

export BIND_ADDRESS=${ETH0_IP}
echo BIND_ADDRESS = ${BIND_ADDRESS}

JG_FLAGS="-Dorg.jboss.resolver.warning=true -Dresolve.dns=false -Djgroups.timer.num_threads=4"
#Yourkit settings
#JVM_OPTS="-server -Xmx1024M -Xms1024M  -agentpath:/tmp/libyjpagent.so=sampling,onexit=snapshot"
#Jacoco settings
JVM_OPTS="-server -Xmx1024M -Xms1024M -XX:PermSize=256M -XX:MaxPermSize=256M -javaagent:/tmp/jacocoagent.jar=destfile=/tmp/jacoco.exec"

JVM_OPTS="$JVM_OPTS $JG_FLAGS"
JPROFILER_HOME=${HOME}/jprofiler6
JPROFILER_CFG_ID=103

# Example slave definitions
w1_SLAVE_ADDRESS=127.0.0.1
w1_BIND_ADDRESS=127.0.0.2

w2_SLAVE_ADDRESS=127.0.0.1
w2_BIND_ADDRESS=127.0.0.3

