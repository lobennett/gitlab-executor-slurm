#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/env.sh

cat << JSON
{
    "builds_dir" : "$GR_DIR_BASE/builds",
    "cache_dir" : "$GR_DIR_BASE/cache",
    "driver" : {
        "name" : "Slurm driver",
        "version" : "v01"
    }
}
JSON
