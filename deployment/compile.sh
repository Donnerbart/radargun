#!/bin/bash

cd "$(dirname "$0")"

cd ..
mvn -DskipTests=true clean install