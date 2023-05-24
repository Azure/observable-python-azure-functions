#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

# Utility function to load environment variables from .env file
function loadEnvVariables() {

    if [ -n "$1" ]; then
        envPath="$1"
    else
        SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
        envPath="$SCRIPT_DIR/../config/.env"
    fi

    if [ -f "$envPath" ]; then
        set -o allexport
        . "$envPath"
        set +o allexport
    fi
}

# Utility function to set environment variables in .env file
function setEnvVariable() {
    if [ -n "$3" ]; then
        envPath="$3"
    else
        SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
        envPath="$SCRIPT_DIR/../config/.env"
    fi
    sed -i "/^$1=/d" "$envPath"
    echo "$1=\"$2\"" >> "$envPath"
}

# Utility function to log in to the Azure account
# If already logged, nothing happens
function azLogin() {

    # Check if current process's user is logged on Azure
    # If no, then triggers az login
    azOk=true
    az account set -s "$SUBSCRIPTION_ID"  || azOk=false
    if [[ ${azOk} == false ]]; then
        echo -e "az login required"
        az login --tenant "$TENANT_ID"
    fi

    azOk=true
    az account set -s "$SUBSCRIPTION_ID"  || azOk=false
    if [[ ${azOk} == false ]]; then
        echo -e "Unknown error"
        exit 1
    fi
}