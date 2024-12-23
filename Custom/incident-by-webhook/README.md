# Coralogix Log Fetcher Per Incident 🚨

## Prerequisites 
* Setting up an outbound webhook in Coralogix
* Sending the webhook directly to the code (e.g. Lambda, API gateway, etc...)

## Setup
### Lambda Layer
1. Create a Lambda Layer with a name of your choosing
2. Upload the layer's content from the file named `lambda_layer.zip`
3. For runtime select `Python3.13`

### Lambda Function
1. Create a new function with the `Python3.13` runtime
2. Upload the provided zip file named `code.zip`
3. Add the previously created Lambda Layer to the function
4. Add 2 environment variables to the Lambda
   1. API_KEY - A Coralogix API key with permissions for query (`DATAQUERUYING`)
   2. CX_GRPC_REGION - One of the following
      1. EU1 - ng-api-grpc.coralogix.com
      2. EU2 - ng-api-grpc.eu2.coralogix.com
      3. US1 - ng-api-grpc.coralogix.us
      4. US2 - ng-api-grpc.cx498.coralogix.com
      5. AP1 - ng-api-grpc.app.coralogix.in
      6. AP2 - ng-api-grpc.coralogixsg.com

### Coralogix
1. In Coralogix go `Dataflow` > `Outbound Webhooks`
2. Select Generic Webhook and add new
3. You will need to provide the URL to your listener (e.g. Lambda's function URL)
4. For the webhook's message, replace the default with the following structure where the important fields are:
   1. `timewindow`
   2. `queryText`
   3. `timestampISO`
   4. `alertGroupByValues`
    ```json
    {
      "uuid": "69e600a8-48e2-...",
      "alert_id": "$ALERT_ID",
      "name": "$ALERT_NAME",
      "timewindow": "$ALERT_TIMEWINDOW_MINUTES",
      "queryText": "$QUERY_TEXT",
      "timestampISO": "$EVENT_TIMESTAMP_ISO",
      "alertGroupByValues": "$ALERT_GROUP_BY_VALUES",
      "threshold": "$ALERT_THRESHOLD",
      "alert_url": "$ALERT_URL",
      "log_url": "$LOG_URL",
      "icon_url": "$CORALOGIX_ICON_URL",
      "duration": "$DURATION",
      "application": "$APPLICATION_NAME",
      "subsystem": "$SUBSYSTEM_NAME",
      "priority": "$ALERT_PRIORITY",
      "companyId": "$COMPANY_ID",
      "severity": "$EVENT_SEVERITY",
      "metaLabels": "$META_LABELS",
      "metaLabelsList": "$META_LABELS_LIST"
    }
    ```
5. Save the Webhook
6. Add the Webhook to each alert you wish to fetch its triggering logs for

## Outcome & Next steps
* The code outputs a list of the fetched logs into a variable named `cur_run` under the `lambda_handler` function in the `lambda_function` py file.
* Additional manipulations and steps should be placed under the `cur_run` variable