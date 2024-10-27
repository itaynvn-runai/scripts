### expected env vars:
# WEBSERVER_URL=""
# WEBSERVER_BASIC_AUTH="" # base64 encoded string of access_key:secret_key
# PROJECT_NAME=""
# QUEUE_NAME=""
# TASK_NAME=""
# TASK_GIT_REPO=""
# TASK_GIT_BRANCH=""
# TASK_ENTRYPOINT=""
# TASK_IMAGE=""
# TASK_PRERUN_SCRIPT=""

### optional env vars:
### (if provided, project and queue creation will be skipped, and only task will be created)
# PROJECT_ID=""
# QUEUE_ID=""

# 1) login using default user & retrieve token:
CLEARML_TOKEN=$(curl -s --location --request POST "$WEBSERVER_URL/api/v2.30/auth.login" \
--header "Authorization: Basic $WEBSERVER_BASIC_AUTH" \
--header "Origin: $WEBSERVER_URL" \
--header "Referer: $WEBSERVER_URL/login" \
--header 'X-Allegro-Client: Webapp-1.16.2-502' \
--header 'X-Clearml-Impersonate-As: __tests__' | jq -r '.data.token')

echo "CLEARML_TOKEN: $CLEARML_TOKEN"
echo

# 2) create project
if [ -z "$PROJECT_ID" ]; then
    echo "PROJECT_ID is not set, creating new project: $PROJECT_NAME"
    PROJECT_ID=$(curl -s --location "$WEBSERVER_URL/api/v2.30/projects.create" \
    --header "Cookie: clearml-token-k8s=$CLEARML_TOKEN" \
    --header 'Content-Type: application/json' \
    --data "{
        \"name\": \"$PROJECT_NAME\",
        \"description\": \"test in progress\",
        \"system_tags\": [],
        \"default_output_destination\": null
    }" | jq -r '.data.id')
    echo "PROJECT_ID: $PROJECT_ID"
else
    echo "PROJECT_ID is set to: $PROJECT_ID"
fi
echo

# 3) create queue
if [ -z "$QUEUE_ID" ]; then
    echo "QUEUE_ID is not set, creating new queue: $QUEUE_NAME"
    QUEUE_ID=$(curl -s --location "$WEBSERVER_URL/api/v2.30/queues.create" \
    --header "Cookie: clearml-token-k8s=$CLEARML_TOKEN" \
    --header 'Content-Type: application/json' \
    --data "{
        \"name\": \"$QUEUE_NAME\"
    }" | jq -r '.data.id')
    echo "QUEUE_ID: $QUEUE_ID"
else
    echo "QUEUE_ID is set to: $QUEUE_ID"
fi
echo


# 4) create task
TASK_ID=$(curl -s --location "$WEBSERVER_URL/api/v2.30/tasks.create" \
--header "Cookie: clearml-token-k8s=$CLEARML_TOKEN" \
--header 'Content-Type: application/json' \
--data "{
    \"project\": \"$PROJECT_ID\",
    \"name\": \"$TASK_NAME\",
    \"type\": \"training\",
    \"script\": {
        \"repository\": \"$TASK_GIT_REPO\",
        \"branch\": \"$TASK_GIT_BRANCH\",
        \"working_dir\": \".\",
        \"entry_point\": \"$TASK_ENTRYPOINT\",
        \"requirements\": null
    },
    \"hyperparams\": {
        \"Args\": {}
    },
    \"container\": {
        \"image\": \"$TASK_IMAGE\",
        \"arguments\": \"-e CLEARML_AGENT_FORCE_TASK_INIT=1 -e CLEARML_AGENT_FORCE_POETRY\",
        \"setup_shell_script\": \"$TASK_PRERUN_SCRIPT\"
    }
}" | jq -r '.data.id')

echo "TASK_ID: $TASK_ID"
echo

# 5) enqueue task
curl -s --location "$WEBSERVER_URL/api/v2.30/tasks.enqueue" \
--header "Cookie: clearml-token-k8s=$CLEARML_TOKEN" \
--header 'Content-Type: application/json' \
--data "{
    \"queue\": \"$QUEUE_ID\",
    \"task\": \"$TASK_ID\",
    \"verify_watched_queue\": true
}" | jq