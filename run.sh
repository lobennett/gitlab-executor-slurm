#!/bin/bash

function file_watch
# usage: file_watch PATH PREFIX
{
    touch $1
    tail -f $1 > >(stdbuf -o0 awk -vP="$2| " '{ print P $0 }' ) & # monitor output log file
    PID_FILE_WATCH=$!
}

# directory where all run content will live
DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$USER/$CUSTOM_ENV_CI_BUILD_ID

RUN_STAGE="${@: -1}" # last argument is the run stage
SCRIPT_RUN="${@:(-2):1}" # second to last argument is the run script

PIDS=()

# if the main execution script, send to slurm queue
if [[ $RUN_STAGE == "build_script" ]]
then

    cd /tmp # go to tmp, avoid being stuck in some gitlab host tmp space
    cp $SCRIPT_RUN $DIR_JOB # copy script to output directory
    mv $DIR_JOB/script. $DIR_JOB/$RUN_STAGE # rename script to something more meaningful

    # submit slurm job with -W (wait, makes sbatch blocking)
    sbatch -W $CUSTOM_ENV_SCHEDULER_PARAMETERS -o $DIR_JOB/out.log -e $DIR_JOB/err.log $DIR_JOB/$RUN_STAGE &
    PID_SBATCH=$! # get sbatch PID

    file_watch $DIR_JOB/out.log O
    PIDS+=($PID_FILE_WATCH)
    file_watch $DIR_JOB/err.log E
    PIDS+=($PID_FILE_WATCH)

    wait $PID_SBATCH # wait on sbatch to finish
    # need to switch to sbatch --parsable to get job id, then monitoring job output via:
    # sacct -o state,exitcode -n -p -D -j <job id>
    # this method will allow for job cancelling

    for P in "${PIDS[@]}"
    do
        kill $P # kill all file logs
    done

else
    # otherwise run locally on gitlab-runner host system
    $SCRIPT_RUN
fi
