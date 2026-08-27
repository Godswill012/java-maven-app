#!/bin/bash

echo "Removing Terraform backend object versions..."

VERSION_IDS=$(aws s3api list-object-versions \
  --bucket "$TF_STATE_BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output text)

if [ -n "$VERSION_IDS" ]; then
  while read -r KEY VERSION_ID; do
    aws s3api delete-object \
      --bucket "$TF_STATE_BUCKET" \
      --key "$KEY" \
      --version-id "$VERSION_ID"
  done <<< "$VERSION_IDS"
fi

echo "Removing delete markers..."

DELETE_MARKERS=$(aws s3api list-object-versions \
  --bucket "$TF_STATE_BUCKET" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
  --output text)

if [ -n "$DELETE_MARKERS" ]; then
  while read -r KEY VERSION_ID; do
    aws s3api delete-object \
      --bucket "$TF_STATE_BUCKET" \
      --key "$KEY" \
      --version-id "$VERSION_ID"
  done <<< "$DELETE_MARKERS"
fi

echo "Deleting Terraform backend bucket..."

aws s3api delete-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$AWS_DEFAULT_REGION"
