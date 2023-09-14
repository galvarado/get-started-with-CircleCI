#!/bin/bash

# This script interacts with the CircleCI API to perform actions related to workflows and pipelines.

# CIRCLE_TOKEN his environment variable is required to authenticate with the CircleCI API.
# It should contain your CircleCI Personal API token as Project-specific tokens are currently not supported on API v2 
# https://discuss.circleci.com/t/v2-api-cannot-be-accessed-with-project-api-token/35914

# Set options for error handling
set -eu -o pipefail # Causes this script to terminate if any command returns an error

# Step 1: Get the name of the workflow and the related pipeline number
curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}" -o current_workflow.json
WF_NAME=$(jq -r '.name' current_workflow.json)
CURRENT_PIPELINE_NUM=$(jq -r '.pipeline_number' current_workflow.json)

# Step 2: Get the IDs of pipelines created by the current user on the same branch
PIPE_IDS=$(curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_REPONAME/pipeline?branch=$CIRCLE_BRANCH"|jq -r --argjson CURRENT_PIPELINE_NUM "$CURRENT_PIPELINE_NUM" '.items[] | select(.state == "created") | select(.number < $CURRENT_PIPELINE_NUM)|.id')

# Step 3: Get the IDs of currently running/on_hold workflows with the same name in previously created pipelines
if [ ! -z "$PIPE_IDS" ]; then
  for PIPE_ID in $PIPE_IDS
  do
    curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/pipeline/${PIPE_ID}/workflow"|jq -r --arg WF_NAME "${WF_NAME}" '.items[]|select(.status == "running") | select(.name == $WF_NAME) | .id' >> OTHER_WF.txt
  done
fi

# Step 4: Cancel currently running workflow with the same name as there is other running with a previous creation time:
if [ -s OTHER_WF.txt ]; then
  echo "Cancelling this execution as there is other running with a previous creation time:"
  cat OTHER_WF.txt 
  # exit 1  used to indicate an error or unsuccessful execution intentionally.
  exit 1 
  else
    echo "Nothing to cancel"
fi