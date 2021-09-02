#!/bin/bash

DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$USER/$CUSTOM_ENV_CI_BUILD_ID
SCRIPT_PREPARE="${@:(-2):1}" # second to last argument is the run script

mkdir -p $DIR_JOB

$SCRIPT_PREPARE
