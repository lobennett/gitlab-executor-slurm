#!/bin/bash

DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$GITLAB_USER_LOGIN/$CUSTOM_ENV_CI_PROJECT_NAME/$CUSTOM_ENV_CI_JOB_STAGE/$CUSTOM_ENV_CI_JOB_NAME/$CUSTOM_ENV_CI_JOB_ID
SCRIPT_PREPARE="${@:(-2):1}" # second to last argument is the run script

mkdir -p "$DIR_JOB"

if [ -n "$CUSTOM_ENV_IMAGE_PATH" ]
then
  # custom image path is set
  IMAGE_PATH="$CUSTOM_ENV_IMAGE_PATH"
else
  if [ -n "$APPTAINER_CACHEDIR" ]
  then
    # apptainer cachedir is set, use it
    IMAGE_PATH="$APPTAINER_CACHEDIR/container"
  else
    # no image path and no apptainer cache, put in home
    IMAGE_PATH="$HOME/.container"
  fi
fi

if [ ! -d "$IMAGE_PATH" ]
then
  mkdir -p "$IMAGE_PATH"
fi

# check for container image
if [ ! -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]
then
  singularity pull --dir "$IMAGE_PATH" docker://$CUSTOM_ENV_CI_JOB_IMAGE
fi

$SCRIPT_PREPARE
