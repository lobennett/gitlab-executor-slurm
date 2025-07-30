#!/bin/bash

# This script prepares the environment for a custom executor job.
# Its primary role is to ensure the necessary container image is available.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the base directory for the image cache.
if [ -n "$CUSTOM_ENV_IMAGE_PATH" ]; then
  # Use custom image path if set
  IMAGE_PATH="$CUSTOM_ENV_IMAGE_PATH"
elif [ -n "$APPTAINER_CACHEDIR" ]; then
  # Use apptainer cachedir if set
  IMAGE_PATH="$APPTAINER_CACHEDIR/container"
else
  # Default to a directory in the user's home
  IMAGE_PATH="$HOME/.container"
fi

# Ensure the image cache directory exists.
mkdir -p "$IMAGE_PATH"

# Check if a container image is specified for the job.
if [ ! -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]; then
  echo "Pulling container image: $CUSTOM_ENV_CI_JOB_IMAGE"
  # Use --force to prevent errors if the image already exists in the cache.
  apptainer pull --force --dir "$IMAGE_PATH" "docker://$CUSTOM_ENV_CI_JOB_IMAGE"
fi

echo "Preparation stage complete."

exit 0
