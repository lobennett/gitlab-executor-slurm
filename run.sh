#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# usage: file_watch PATH PREFIX
function file_watch
{
    touch "$1"
    tail -f "$1" > >(stdbuf -o0 awk -vP="$2| " '{ print P $0 }' ) & # monitor output log file
    PID_FILE_WATCH=$!
}

echo "Checking for required args passed from gitlab ..."

# Check for required arguments
if [ $# -lt 2 ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: $0 <SCRIPT_TO_RUN> <RUN_STAGE>"
    echo "  SCRIPT_TO_RUN: Path to the script to execute"
    echo "  RUN_STAGE: Stage name (e.g., build_script, before_script, after_script)"
    exit 1
fi

if [ -z "$1" ]; then
    echo "ERROR: SCRIPT_TO_RUN (first argument) is empty"
    exit 1
fi

if [ -z "$2" ]; then
    echo "ERROR: RUN_STAGE (second argument) is empty"
    exit 1
fi

# args from gitlab
SCRIPT_RUN=$1
RUN_STAGE=$2

# directory where all run content will live
DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$GITLAB_USER_LOGIN/$CUSTOM_ENV_CI_PROJECT_NAME/$CUSTOM_ENV_CI_JOB_STAGE/$CUSTOM_ENV_CI_JOB_NAME/$CUSTOM_ENV_CI_JOB_ID

echo "SCRIPT RUN: $SCRIPT_RUN; RUN STAGE: $RUN_STAGE; DIR_JOB: $DIR_JOB"

PIDS=()

SHARED_IMAGE_DIR="/home/groups/russpold/singularity_images" # This can also be passed from prepare.sh if needed

# if the main execution script, send to slurm queue
if [[ $RUN_STAGE == "build_script" ]] || [[ $RUN_STAGE == "step_script" ]]
then
    cp "$SCRIPT_RUN" "$DIR_JOB" # copy script to output directory
    cd /tmp # go to tmp, avoid being stuck in some gitlab host tmp space
    mv "$DIR_JOB"/$(basename "$SCRIPT_RUN") "$DIR_JOB"/$RUN_STAGE

    # submit slurm job with -W (wait, makes sbatch blocking)
    if [ -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]
    then
      # no container image specified, just run directly without apptainer/singularity
      echo "No container image specified. Running directly with apptainer..."
      sbatch -W $CUSTOM_ENV_SLURM_PARAMETERS -o "$DIR_JOB"/out.log -e "$DIR_JOB"/err.log "$DIR_JOB"/$RUN_STAGE &
    else
      SIF_FILE=$(cat "$DIR_JOB/sif.txt")
      echo "Using SIF_FILE: $SIF_FILE" # Confirm the path being used

      SBATCH_SCRIPT="$DIR_JOB"/sbatch_script
      echo "#!/bin/sh" >> "$SBATCH_SCRIPT"
      echo "apptainer exec $CUSTOM_ENV_APPTAINER_PARAMETERS \"$SIF_FILE\" \"$DIR_JOB\"/$RUN_STAGE" >> "$SBATCH_SCRIPT"
      
      echo "-----------------SBATCH SCRIPT---------------------"
      cat "$SBATCH_SCRIPT"
      echo "---------------------------------------------------"
      
      # This is the actual sbatch command that needs to be uncommented
      sbatch -W $CUSTOM_ENV_SLURM_PARAMETERS -o "$DIR_JOB"/out.log -e "$DIR_JOB"/err.log "$SBATCH_SCRIPT" &
    fi
    PID_SBATCH=$! # get sbatch PID

    file_watch "$DIR_JOB"/out.log O
    PIDS+=($PID_FILE_WATCH)
    file_watch "$DIR_JOB"/err.log E
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
    echo
    echo "$RUN_STAGE is not build_script"
    echo "Running job locally on gitlab-runner host system..."
    echo
    "$SCRIPT_RUN"
fi