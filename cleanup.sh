#!/bin/bash

shopt -s extglob

DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$USER/$CUSTOM_ENV_CI_BUILD_ID
SCRIPT_CLEANUP="${@:(-2):1}" # second to last argument is the run script

$SCRIPT_CLEANUP

rm $DIR_JOB/!(*.log)
