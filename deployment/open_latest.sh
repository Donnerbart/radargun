#!/bin/bash

cd "$(dirname "$0")"

TARGET_DIR=./reports

cd ${TARGET_DIR}
(nautilus latest &> /dev/null) &