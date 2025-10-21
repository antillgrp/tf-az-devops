#!/bin/bash

echo "start.sh: Starting Azure DevOps Agent setup..." | tee agent-start.log
env | egrep -q 'AZURE_|ADO_|GH_' || {
    unset GH_OWNER GH_REPOSITORY GH_TOKEN AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID ADO_ORG ADO_PAT ADO_POOL_NAME &&
    [ -f /home/vscode/azure-pipelines/.env ]                                                                                &&  
    chmod +x /home/vscode/azure-pipelines/.env                                                                              &&
    source /home/vscode/azure-pipelines/.env
}
env | egrep -q 'AZURE_|ADO_|GH_' || {
  echo 'start.sh ERROR: No AZURE_*, ADO_* or GH_* environment variables found. Exiting.' | tee agent-start.log >&2
  exit 1
} 

export AGENT_VERSION=2.218.1
echo "start.sh: Downloading Azure DevOps Agent version ${AGENT_VERSION}..." | tee -a agent-start.log
cd /home/vscode/azure-pipelines                                                                                         &&
curl -sS -O -L https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz && 
tar xzf /home/vscode/azure-pipelines/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz                                       && 

echo "start.sh: Installing dependencies for Azure DevOps Agent..." | tee -a agent-start.log
sudo /home/vscode/azure-pipelines/bin/installdependencies.sh >> agent-start.log 2>&1

echo "start.sh: Configuring Azure DevOps Agent '${AGENT_NAME}'..." | tee -a agent-start.log
ADO_ORG=$ADO_ORG
ADO_PAT=$ADO_PAT
ADO_POOL_NAME=$ADO_POOL_NAME

HOSTNAME=$(hostname)
AGENT_SUFFIX="ADO-agent"
AGENT_NAME="${HOSTNAME}-${AGENT_SUFFIX}"
ADO_URL="https://dev.azure.com/${ADO_ORG}"
USER_NAME_LABEL=$( (git config --get user.name) | sed -e 's/ //g')
#REPO_NAME_LABEL="$GH_REPOSITORY"

# !!!Ignore sensitive tokens from capabilities!!!
export VSO_AGENT_IGNORE=ADO_PAT,GH_TOKEN,GITHUB_CODESPACE_TOKEN,GITHUB_TOKEN

echo "start.sh: Removing any existing configuration for Azure DevOps Agent '${AGENT_NAME}'..." | tee -a agent-start.log
[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh remove --auth PAT --token "${ADO_PAT}" >> agent-start.log 2>&1

echo "start.sh: Setting up Azure DevOps Agent '${AGENT_NAME}'..." | tee -a agent-start.log
[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh --unattended \
--agent "${AGENT_NAME}" \
--url "${ADO_URL}" \
--auth PAT \
--token "${ADO_PAT}" \
--pool "${ADO_POOL_NAME}" \
--acceptTeeEula >> agent-start.log 2>&1

echo "start.sh: Starting Azure DevOps Agent '${AGENT_NAME}'..." | tee -a agent-start.log
[ -f /home/vscode/azure-pipelines/run.sh ] && 
/home/vscode/azure-pipelines/run.sh >> agent-start.log 2>&1 &