#!/bin/bash
set -e

# Script to create Terraform state backends in AWS, GCP, or Azure

usage() {
    echo "Usage: $0 [aws|gcp|azure] [options]"
    echo ""
    echo "AWS Options:"
    echo "  $0 aws --bucket <bucket-name> --region <region> --dynamodb-table <table-name>"
    echo ""
    echo "GCP Options:"
    echo "  $0 gcp --bucket <bucket-name> --region <region> --project <project-id>"
    echo ""
    echo "Azure Options:"
    echo "  $0 azure --resource-group <rg-name> --storage-account <account-name> --container <container-name> --region <region>"
    echo ""
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

CLOUD=$1
shift

# Initialize variables
BUCKET=""
REGION=""
DYNAMODB_TABLE=""
PROJECT=""
RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
CONTAINER=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bucket) BUCKET="$2"; shift ;;
        --region) REGION="$2"; shift ;;
        --dynamodb-table) DYNAMODB_TABLE="$2"; shift ;;
        --project) PROJECT="$2"; shift ;;
        --resource-group) RESOURCE_GROUP="$2"; shift ;;
        --storage-account) STORAGE_ACCOUNT="$2"; shift ;;
        --container) CONTAINER="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

create_aws_backend() {
    if [ -z "$BUCKET" ] || [ -z "$REGION" ] || [ -z "$DYNAMODB_TABLE" ]; then
        echo "Missing required arguments for AWS."
        echo "Required: --bucket, --region, --dynamodb-table"
        exit 1
    fi

    echo "Creating AWS S3 bucket: $BUCKET in region: $REGION"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi

    echo "Enabling versioning on S3 bucket: $BUCKET"
    aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

    echo "Enabling server-side encryption on S3 bucket: $BUCKET"
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET" \
        --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

    echo "Creating DynamoDB table: $DYNAMODB_TABLE for state locking"
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" > /dev/null

    echo "AWS Backend creation complete!"
}

create_gcp_backend() {
    if [ -z "$BUCKET" ] || [ -z "$REGION" ] || [ -z "$PROJECT" ]; then
        echo "Missing required arguments for GCP."
        echo "Required: --bucket, --region, --project"
        exit 1
    fi

    echo "Creating GCP Storage bucket: $BUCKET in region: $REGION (Project: $PROJECT)"
    gcloud storage buckets create gs://"$BUCKET" --project="$PROJECT" --location="$REGION" --uniform-bucket-level-access

    echo "Enabling versioning on GCP Storage bucket: $BUCKET"
    gcloud storage buckets update gs://"$BUCKET" --versioning

    echo "GCP Backend creation complete!"
}

create_azure_backend() {
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$STORAGE_ACCOUNT" ] || [ -z "$CONTAINER" ] || [ -z "$REGION" ]; then
        echo "Missing required arguments for Azure."
        echo "Required: --resource-group, --storage-account, --container, --region"
        exit 1
    fi

    echo "Creating Azure Resource Group: $RESOURCE_GROUP in region: $REGION"
    az group create --name "$RESOURCE_GROUP" --location "$REGION"

    echo "Creating Azure Storage Account: $STORAGE_ACCOUNT in Resource Group: $RESOURCE_GROUP"
    az storage account create --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --location "$REGION" --sku Standard_LRS --encryption-services blob

    echo "Creating Azure Storage Container: $CONTAINER in Storage Account: $STORAGE_ACCOUNT"
    az storage container create --name "$CONTAINER" --account-name "$STORAGE_ACCOUNT"

    echo "Azure Backend creation complete!"
}

case $CLOUD in
    aws)
        create_aws_backend
        ;;
    gcp)
        create_gcp_backend
        ;;
    azure)
        create_azure_backend
        ;;
    *)
        echo "Invalid cloud provider: $CLOUD"
        usage
        ;;
esac
