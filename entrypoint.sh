#!/bin/bash
set -e
# Check for required environment variables
if [ -z "$CERTIFICATE" ]; then
  echo "Error: CERTIFICATE environment variable is required."
  echo "Description: Path to certificate file or a PKCS#11 URI for hardware/software tokens."
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: PRIVATE_KEY environment variable is required."
  echo "Description: Specifies the private key to use for signing. Can be a path to a plaintext private key file, a PKCS#11 URI, or a TPM wrapped key."
  exit 1
fi

if [ -z "$TRUST_ANCHOR_ARN" ]; then
  echo "Error: TRUST_ANCHOR_ARN environment variable is required."
  echo "Description: Trust anchor to use for authentication."
  exit 1
fi

if [ -z "$PROFILE_ARN" ]; then
  echo "Error: PROFILE_ARN environment variable is required."
  echo "Description: Profile to pull policies, attribute mappings, and other data from."
  exit 1
fi

if [ -z "$ROLE_ARN" ]; then
  echo "Error: ROLE_ARN environment variable is required."
  echo "Description: The target role to assume."
  exit 1
fi
# Function to cleanup background processes
cleanup() {
    echo "Cleaning up processes..."
    if [ ! -z "$AWS_SIGNING_HELPER_PID" ]; then
        kill -TERM "$AWS_SIGNING_HELPER_PID" 2>/dev/null || true
    fi
    if [ ! -z "$GO_FILE_SECRET_SYNC_PID" ]; then
        kill -TERM "$GO_FILE_SECRET_SYNC_PID" 2>/dev/null || true
    fi
    exit 1
}

# Trap signals to cleanup processes
trap cleanup SIGTERM SIGINT

# Function to check if process is running
is_running() {
    kill -0 "$1" 2>/dev/null
}

# Function to wait for process and return exit code
wait_for_process() {
    local pid=$1
    local name=$2
    
    if wait "$pid"; then
        echo "$name exited normally"
        return 0
    else
        local exit_code=$?
        echo "$name crashed with exit code $exit_code"
        return $exit_code
    fi
}

echo "Starting aws-signing-helper..."
# Start aws-signing-helper in background
/usr/local/bin/aws_signing_helper update \
    --certificate "$CERTIFICATE" \
    --private-key "$PRIVATE_KEY" \
    --trust-anchor-arn "$TRUST_ANCHOR_ARN" \
    --profile-arn "$PROFILE_ARN" \
    --role-arn "$ROLE_ARN" &

AWS_SIGNING_HELPER_PID=$!
echo "aws-signing-helper started with PID: $AWS_SIGNING_HELPER_PID"

# Give aws-signing-helper a moment to start
sleep 2

# Check if aws-signing-helper is still running
if ! is_running "$AWS_SIGNING_HELPER_PID"; then
    echo "aws-signing-helper failed to start"
    exit 1
fi

echo "Starting go-file-secret-sync..."
# Start go-file-secret-sync in background
/usr/local/bin/go-file-secret-sync &

GO_FILE_SECRET_SYNC_PID=$!
echo "go-file-secret-sync started with PID: $GO_FILE_SECRET_SYNC_PID"

# Give go-file-secret-sync a moment to start
sleep 2

# Check if go-file-secret-sync is still running
if ! is_running "$GO_FILE_SECRET_SYNC_PID"; then
    echo "go-file-secret-sync failed to start"
    cleanup
fi

echo "Both processes started successfully"
echo "aws-signing-helper PID: $AWS_SIGNING_HELPER_PID"
echo "go-file-secret-sync PID: $GO_FILE_SECRET_SYNC_PID"

# Monitor both processes
while true; do
    # Check if aws-signing-helper is still running
    if ! is_running "$AWS_SIGNING_HELPER_PID"; then
        echo "aws-signing-helper has stopped running"
        cleanup
    fi
    
    # Check if go-file-secret-sync is still running
    if ! is_running "$GO_FILE_SECRET_SYNC_PID"; then
        echo "go-file-secret-sync has stopped running"
        cleanup
    fi
    
    # Wait a bit before checking again
    sleep 5
done