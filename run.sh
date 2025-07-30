#!/bin/bash

# usage: file_watch PATH PREFIX
function file_watch
{
    touch "$1"
    tail -f "$1" > >(stdbuf -o0 awk -vP="$2| " '{ print P $0 }' ) & # monitor output log file
    PID_FILE_WATCH=$!
}

# directory where all run content will live
DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$GITLAB_USER_LOGIN/$CUSTOM_ENV_CI_PROJECT_NAME/$CUSTOM_ENV_CI_JOB_STAGE/$CUSTOM_ENV_CI_JOB_NAME/$CUSTOM_ENV_CI_JOB_ID
mkdir -p "$DIR_JOB"

SCRIPT_RUN=$1
RUN_STAGE=$2

PIDS=()

echo "RUN STAGE: $RUN_STAGE"

# send all jobs to slurm queue
cd /tmp # go to tmp, avoid being stuck in some gitlab host tmp space
cp "$SCRIPT_RUN" "$DIR_JOB" # copy script to output directory
mv "$DIR_JOB"/$(basename "$SCRIPT_RUN") "$DIR_JOB"/$RUN_STAGE # rename script to something more meaningful

# submit slurm job with -W (wait, makes sbatch blocking)
if [ -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]; then
  # no container image specified, just run directly without apptainer
  sbatch -W $CUSTOM_ENV_SLURM_PARAMETERS -o "$DIR_JOB"/out.log -e "$DIR_JOB"/err.log "$DIR_JOB"/$RUN_STAGE &
else
  # container specified
  if [ -n "$CUSTOM_ENV_IMAGE_PATH" ]; then
    # custom image path is set
    IMAGE_PATH="$CUSTOM_ENV_IMAGE_PATH"
  else
    if [ -n "$APPTAINER_CACHEDIR" ]; then
      # apptainer cachedir is set, use it
      IMAGE_PATH="$APPTAINER_CACHEDIR/container"
    else
      # no image path and no apptainer cache, put in home
      IMAGE_PATH="$HOME/.container"
    fi
  fi

  # Sanitize name to replace ":" and "/" with "_"
  SANITIZED_IMAGE_NAME=$(echo "$CUSTOM_ENV_CI_JOB_IMAGE" | tr ':/' '_')
  SIF_FILE="$IMAGE_PATH/${SANITIZED_IMAGE_NAME}.sif"

  SBATCH_SCRIPT="$DIR_JOB"/sbatch_script

  echo "#!/bin/sh" >> "$SBATCH_SCRIPT"
  echo "apptainer exec --cleanenv $CUSTOM_ENV_APPTAINER_PARAMETERS \"$SIF_FILE\" \"$DIR_JOB\"/$RUN_STAGE" >> "$SBATCH_SCRIPT"
  sbatch -W $CUSTOM_ENV_SLURM_PARAMETERS -o "$DIR_JOB"/out.log -e "$DIR_JOB"/err.log "$SBATCH_SCRIPT" &
fi
PID_SBATCH=$! # get sbatch PID

file_watch "$DIR_JOB"/out.log O
PIDS+=($PID_FILE_WATCH)
file_watch "$DIR_JOB"/err.log E
PIDS+=($PID_FILE_WATCH)

wait $PID_SBATCH # wait on sbatch to finish

for P in "${PIDS[@]}"; do
    kill $P # kill all file logs
done
