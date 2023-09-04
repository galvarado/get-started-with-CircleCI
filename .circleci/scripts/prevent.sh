#!/bin/bash

## Get the name of the workflow and the related pipeline number
curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}" -o current_workflow.json
WF_NAME=$(jq -r '.name' current_workflow.json)
CURRENT_PIPELINE_NUM=$(jq -r '.pipeline_number' current_workflow.json)

## Get the ID of the most recent pipeline created by the current user on the same branch.
LATEST_PIPELINE_ID=$(curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pipeline?branch=$CIRCLE_BRANCH"|jq -r '.items[0].id')

## Get the ID of the latest running/on_hold workflow in the latest pipeline with the same name as the current workflow.
if [ ! -z "$LATEST_PIPELINE_ID" ]; then
  LATEST_WORKFLOW_ID=$(curl --header "Circle-Token: $CIRCLE_TOKEN" --request GET "https://circleci.com/api/v2/pipeline/${LATEST_PIPELINE_ID}/workflow"|jq -r --arg WF_NAME "${WF_NAME}" '.items[] | select(.status == "running" or .status == "on_hold") | select(.name == $WF_NAME) | .id')
fi

## Cancel the latest running/on_hold workflow with the same name
if [ ! -z "$LATEST_WORKFLOW_ID" ]; then
  echo "Cancelling the latest running/on_hold workflow with the name: $WF_NAME (Workflow ID: $LATEST_WORKFLOW_ID)"
  curl --header "Circle-Token: $CIRCLE_TOKEN" --request POST https://circleci.com/api/v2/workflow/$LATEST_WORKFLOW_ID/cancel
else
  echo "No running/on_hold workflows with the name: $WF_NAME found in the latest pipeline."
fi
