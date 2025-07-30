#!/bin/bash
# This script checks for a cached container image and pulls it if not found.
set -e

SHARED_IMAGE_DIR="/home/groups/russpold/singularity_images"
mkdir -p "$SHARED_IMAGE_DIR"

# Check if a container image is specified for the job.
if [ ! -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]; then
  # Construct the expected path for the SIF file.
  SANITIZED_IMAGE_NAME=$(echo "$CUSTOM_ENV_CI_JOB_IMAGE" | tr ':/' '_')
  SIF_FILE="$SHARED_IMAGE_DIR/${SANITIZED_IMAGE_NAME}.sif"

  # Check if the required SIF file exists in the shared directory.
  if [ ! -f "$SIF_FILE" ]; then
    # If the file does not exist, attempt to pull it from the registry.
    echo "Cached SIF file not found. Attempting to pull 'docker://$CUSTOM_ENV_CI_JOB_IMAGE'..."
    apptainer pull --dir "$SHARED_IMAGE_DIR" "docker://$CUSTOM_ENV_CI_JOB_IMAGE"
    echo "Pull successful."
  else
    # If the file exists, use the cached version.
    echo "Found cached container image: $SIF_FILE"
  fi
fi

echo "Preparation stage complete."
exit 0
