#!/bin/bash

cd "$(dirname "$0")"

TARGET_DIR=./reports

cd ${TARGET_DIR}
(firefox latest/results/html/index.html &> /dev/null) &