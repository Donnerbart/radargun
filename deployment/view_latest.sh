#!/bin/bash

cd "$(dirname "$0")"

cd reports
(firefox latest/results/html/index.html &> /dev/null) &