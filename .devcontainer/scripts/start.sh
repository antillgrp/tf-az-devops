#!/bin/bash

export AGENT_VERSION=2.218.1
cd /home/vscode/azure-pipelines                                                                                     && 
curl -O -L https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz && 
tar xzf /home/vscode/azure-pipelines/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz                                   && 
sudo /home/vscode/azure-pipelines/bin/installdependencies.sh

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

[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh remove --auth PAT --token "${ADO_PAT}"

[ -f /home/vscode/azure-pipelines/config.sh ]        && 
/home/vscode/azure-pipelines/config.sh --unattended \
--agent "${AGENT_NAME}" \
--url "${ADO_URL}" \
--auth PAT \
--token "${ADO_PAT}" \
--pool "${ADO_POOL_NAME}" \
--acceptTeeEula

[ -f /home/vscode/azure-pipelines/run.sh ] && 
/home/vscode/azure-pipelines/run.sh > agent-run.log &