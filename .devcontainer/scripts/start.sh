#!/bin/bash

echo "start.sh: Starting Azure DevOps Agent setup..." | tee "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
env | egrep -q 'AZURE_|ADO_|GH_' || {
    unset GH_OWNER GH_REPOSITORY GH_TOKEN AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID ADO_ORG ADO_PAT ADO_POOL_NAME &&
    [ -f /home/vscode/azure-pipelines/.env ]                                                                                &&  
    chmod +x /home/vscode/azure-pipelines/.env                                                                              &&
    source /home/vscode/azure-pipelines/.env
}
env | egrep -q 'AZURE_|ADO_|GH_' || {
  echo 'start.sh ERROR: No AZURE_*, ADO_* or GH_* environment variables found. Exiting.' | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log" >&2
  exit 1
} 

export AGENT_VERSION=2.218.1
echo "start.sh: Downloading Azure DevOps Agent version ${AGENT_VERSION}..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
cd /home/vscode/azure-pipelines                                                                                         &&

printf "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null
MAX_RETRIES=5; RETRY_DELAY=2; ATTEMPT=0
until curl -s -f -o /dev/null -O -L https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; do
  # The -s flag silences output, -f makes curl fail on HTTP errors (4xx/5xx), and -o /dev/null discards the output.
  ATTEMPT=$((ATTEMPT + 1)) && if [ $ATTEMPT -ge $MAX_RETRIES ]; then
    echo "Curl failed after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi
  echo "Curl failed. Retrying in $RETRY_DELAY seconds (Attempt $ATTEMPT/$MAX_RETRIES)..."
  sleep "$RETRY_DELAY"
done
tar xzf /home/vscode/azure-pipelines/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz                                        

echo "start.sh: Installing dependencies for Azure DevOps Agent..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
sudo /home/vscode/azure-pipelines/bin/installdependencies.sh &>/dev/null

AGENT_NAME="devcontainer-ado-agent"
echo "start.sh: Configuring Azure DevOps Agent '${AGENT_NAME}'..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
ADO_ORG=$ADO_ORG
ADO_PAT=$ADO_PAT
ADO_POOL_NAME=$ADO_POOL_NAME
ADO_URL="https://dev.azure.com/${ADO_ORG}"
USER_NAME_LABEL=$( (git config --get user.name) | sed -e 's/ //g')
#REPO_NAME_LABEL="$GH_REPOSITORY"

# !!!Ignore sensitive tokens from capabilities!!!
export VSO_AGENT_IGNORE='GH_TOKEN,AZURE_CLIENT_SECRET,ADO_PAT,export AZURE_CLIENT_SECRET,export ADO_PAT,export GH_TOKEN'

echo "start.sh: Removing any existing configuration for Azure DevOps Agent '${AGENT_NAME}'..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh remove --auth PAT --token "${ADO_PAT}" | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"

echo "start.sh: Setting up Azure DevOps Agent '${AGENT_NAME}'..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh --unattended \
--agent "${AGENT_NAME}" \
--url "${ADO_URL}" \
--auth PAT \
--token "${ADO_PAT}" \
--pool "${ADO_POOL_NAME}" \
--acceptTeeEula | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log" 

echo "start.sh: Starting Azure DevOps Agent '${AGENT_NAME}'..." | tee -a "$(dirname ${BASH_SOURCE[0]})/agent-start.log"
[ -f /home/vscode/azure-pipelines/run.sh ] && 
/home/vscode/azure-pipelines/run.sh >> "$(dirname ${BASH_SOURCE[0]})/agent-start.log" &