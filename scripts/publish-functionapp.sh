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
        function_app_name=${OPTARG}
        ;;   
  esac
done

if [[ -z "${function_app_name}" ]]; then
    if [[ -z "${FUNCTIONAPP_NAME}" ]]; then
    echo "Could not find FUNCTIONAPP_NAME. Please set it as an environment variable or specify using the -n option when launching the publish-functionapp script."
    exit 1
    else
        function_app_name="$FUNCTIONAPP_NAME"
        echo "Using function app name environment variable"
    fi
fi   

azLogin

pushd "${REPO_ROOT}" || return
  echo "Starting app publishing"
  func azure functionapp publish "${function_app_name}"
popd || return
  

  



