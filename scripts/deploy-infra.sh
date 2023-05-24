#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

# Load utils.sh
. "$SCRIPT_DIR"/utils.sh

# The next steps require the tenant + subscription ids 
# and the resource group name environment variables
loadEnvVariables

if [[ -z "${TENANT_ID}" ]]; then
  echo "TENANT_ID environment not set in config/.env"
  exit 1 
fi
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "SUBSCRIPTION_ID environment not set in config/.env"
  exit 1 
fi
if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
  echo "RESOURCE_GROUP_NAME environment not set in config/.env"
  exit 1 
fi



while getopts ":n:" options; do                                           
  case "${options}" in                     
    n)                               
        name_deployment=${OPTARG}
        ;;   
  esac
done

if [[ -z "${name_deployment}" ]]; then
    if [[ -z "${DEPLOYMENT_NAME}" ]]; then
    echo "Could not find DEPLOYMENT_NAME. Please set it as an environment variable or specify using the -n option when launching the deploy-infra script."
    exit 1
    else
        name_deployment="$DEPLOYMENT_NAME"
        echo "Using deployment name environment variable"
    fi
fi   


echo "Using TENANT_ID = $TENANT_ID"
echo "Using SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "Using RESOURCE_GROUP_NAME = $RESOURCE_GROUP_NAME"
echo "Using name_deployment = $name_deployment"

azLogin

echo "Deploying the infrastructure ..." 

az deployment group create \
  --name $name_deployment \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --template-file "${REPO_ROOT}/infra/main.bicep"



FUNCTIONAPP_NAME=$(az deployment group show \
  -g "$RESOURCE_GROUP_NAME" \
  -n "$name_deployment" \
  --query properties.outputs.functionAppName.value --output tsv)

COSMOSDB_CONNECTION_STRING=$(az deployment group show \
  -g "$RESOURCE_GROUP_NAME" \
  -n "$name_deployment" \
  --query properties.outputs.cosmosConnectionString.value --output tsv)


echo "Setting FUNCTIONAPP_NAME = $FUNCTIONAPP_NAME..."
setEnvVariable "FUNCTIONAPP_NAME" "${FUNCTIONAPP_NAME}" "${REPO_ROOT}"/config/.env
echo "Setting COSMOSDB_CONNECTION_STRING = $COSMOSDB_CONNECTION_STRING..."
setEnvVariable "COSMOSDB_CONNECTION_STRING" "${COSMOSDB_CONNECTION_STRING}" "${REPO_ROOT}"/config/.env

echo "Uploading sample data..."
python3 "${REPO_ROOT}"/scripts/upload-data.py -d "${REPO_ROOT}/data" -e "${REPO_ROOT}/config/.env"


echo "Fetching remote app settings"

func azure functionapp fetch-app-settings "${FUNCTIONAPP_NAME}" --output local.settings.json --resource-group "$RESOURCE_GROUP_NAME"

# az storage blob upload-batch --destination ${blobContainerName} --source "${REPO_ROOT}/data" --account-name storageAccountName --auth-mode login
echo "Deployment complete!"