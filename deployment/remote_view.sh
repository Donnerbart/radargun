#!/bin/bash

cd "$(dirname "$0")"

cd reports
(firefox latest-remote/results/html/index.html &> /dev/null) &
