#!/bin/bash

echo ""
echo "=== Cache Benchmark Framework ==="
echo " This script is used to launch the local slave process."
echo ""

help_and_exit() {
  echo "Usage: "
  echo '  $ launch_local_slave.sh -m MASTER_IP:PORT'
  echo ""
  echo "   -m     Connection to MASTER server.  IP address and port is needed.  This is REQUIRED."
  echo ""
  echo "   -h     Displays this help screen"
  echo ""
  exit 0
}

### read in any command-line params
while ! [ -z $1 ] 
do
  case "$1" in
    "-m")
      MASTER=$2
      shift
      ;;
    *)
      help_and_exit
      ;;
  esac
  shift
done

if [ -z $MASTER ] ; then
  echo "FATAL: required information missing!"
  help_and_exit
fi

echo "Master: $MASTER"

cp="target/classes"
for jar in target/lib/*.jar ; do 
  cp=$cp:$jar
done
nohup java -cp $cp org.cachebenchfwk.slave.Slave $MASTER > out.txt 2>&1 &

echo ""
echo "... done! Slave process started!"
echo ""
