#!/bin/bash

set -e

SHARED_IMAGE_DIR="/home/groups/russpold/singularity_images"

echo "Checking access to shared image directory for russpold group..."

# Check if directory exists and is accessible
if [ ! -d "$SHARED_IMAGE_DIR" ]; then
    echo "ERROR: Shared image directory does not exist: $SHARED_IMAGE_DIR"
    exit 1
fi

# Check if we can read the directory
if [ ! -r "$SHARED_IMAGE_DIR" ]; then
    echo "ERROR: No read access to shared image directory: $SHARED_IMAGE_DIR"
    exit 1
fi

# Check if we can write to the directory
if [ ! -w "$SHARED_IMAGE_DIR" ]; then
    echo "ERROR: No write access to shared image directory: $SHARED_IMAGE_DIR"
    exit 1
fi

echo "✓ Directory exists and is accessible: $SHARED_IMAGE_DIR"

# directory where all run content will live
DIR_JOB=$CUSTOM_ENV_CI_BUILDS_DIR/$GITLAB_USER_LOGIN/$CUSTOM_ENV_CI_PROJECT_NAME/$CUSTOM_ENV_CI_JOB_STAGE/$CUSTOM_ENV_CI_JOB_NAME/$CUSTOM_ENV_CI_JOB_ID
mkdir -p "$DIR_JOB"

if [ ! -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]; then
    case "$CUSTOM_ENV_CI_JOB_IMAGE" in
        docker://*)
            echo "Docker image detected: $CUSTOM_ENV_CI_JOB_IMAGE"
            # Remove docker:// prefix for sanitization
            IMAGE_WITHOUT_PREFIX="${CUSTOM_ENV_CI_JOB_IMAGE#docker://}"
            SANITIZED_IMAGE_NAME=$(echo "$IMAGE_WITHOUT_PREFIX" | tr ':/' '_')
            SIF_FILE="$SHARED_IMAGE_DIR/${SANITIZED_IMAGE_NAME}.sif"
            
            if [ ! -f "$SIF_FILE" ]; then
                echo "Cached SIF file not found. Pulling $CUSTOM_ENV_CI_JOB_IMAGE from Docker registry to $SHARED_IMAGE_DIR..."
                apptainer pull --dir "$SHARED_IMAGE_DIR" "$CUSTOM_ENV_CI_JOB_IMAGE"
                echo "Pull successful."
            else
                echo "Found cached container image: $SIF_FILE"
            fi
            ;;
            
        shared://*)
            echo "Shared image detected: $CUSTOM_ENV_CI_JOB_IMAGE"
            IMAGE_WITHOUT_PREFIX="${CUSTOM_ENV_CI_JOB_IMAGE#shared://}"
            SANITIZED_IMAGE_NAME=$(echo "$IMAGE_WITHOUT_PREFIX" | tr ':/' '_')
            SIF_FILE="$SHARED_IMAGE_DIR/${SANITIZED_IMAGE_NAME}.sif"
            
            if [ ! -f "$SIF_FILE" ]; then
                echo "ERROR: Shared image file not found: $SIF_FILE"
                exit 1
            fi
            
            echo "Using shared container image: $SIF_FILE"
            ;;
            
        *)
            echo "ERROR: Unsupported image format: $CUSTOM_ENV_CI_JOB_IMAGE"
            echo "Supported formats: docker://[registry/]image:tag or shared:///path/to/image.sif"
            exit 1
            ;;
    esac
    # Check if SIF_FILE was actually set
    if [ -z "$SIF_FILE" ]; then
        echo "ERROR: SIF_FILE could not be determined."
        exit 1
    fi
    # Save out sif path
    echo "$SIF_FILE" > "$DIR_JOB/sif.txt"
    echo "✓ SIF_FILE artifact created."
    echo "Preparation stage complete."
    exit 0
else
    echo "WARNING: No container image specified (CUSTOM_ENV_CI_JOB_IMAGE is empty)"
    exit 0
fi