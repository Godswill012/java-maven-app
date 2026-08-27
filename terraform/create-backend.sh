#!/bin/bash

echo "Checking Terraform backend bucket..."

if ! aws s3api head-bucket \
  --bucket "$TF_STATE_BUCKET" 2>/dev/null; then

  echo "Creating Terraform backend bucket..."

  aws s3api create-bucket \
    --bucket "$TF_STATE_BUCKET" \
    --region "$AWS_DEFAULT_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION"
fi

echo "Enabling S3 versioning..."

aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled
