#!/bin/bash

## Get the name of the workflow and the related pipeline number
curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}" -o current_workflow.json
WF_NAME=$(jq -r '.name' current_workflow.json)
CURRENT_PIPELINE_NUM=$(jq -r '.pipeline_number' current_workflow.json)
echo $CIRCLE_PROJECT_USERNAME
## Get the IDs of pipelines created by the current user on the same branch. (Only consider pipelines that have a pipeline number inferior to the current pipeline)
PIPE_IDS=$(curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/project/gh/galvarado/git$CIRCLE_PROJECT_REPONAME/pipeline?branch=$CIRCLE_BRANCH"|jq -r --argjson CURRENT_PIPELINE_NUM "$CURRENT_PIPELINE_NUM" '.items[] | select(.state == "created") | select(.number < $CURRENT_PIPELINE_NUM)|.id')

## Get the IDs of currently running/on_hold workflows that have the same name as the current workflow, in all previously created pipelines.
if [ ! -z "$PIPE_IDS" ]; then
  for PIPE_ID in $PIPE_IDS
  do
    curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/pipeline/${PIPE_ID}/workflow"|jq -r --arg WF_NAME "${WF_NAME}" '.items[]|select(.status == "running") | select(.name == $WF_NAME) | .id' >> OTHER_WF.txt
  done
fi

## Cancel  currently running workflow with the same name
if [ -s OTHER_WF.txt ]; then
  echo "Cancelling this execution as there is other running with a previous creation time:"
  cat OTHER_WF.txt 
  curl --header "Circle-Token: $CIRCLE_TOKEN" --request POST https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/cancel
  ## Allowing some time to complete the cancellation
  sleep 2
  else
    echo "Nothing to cancel"
fi