#!/bin/bash -eu

# If not running in CI, override the _run function to allow manual testing
if [ -z "${CI:-}" ]; then
  _run() {
    "$@"
  }
fi


echo "::group::Getting model name"

status_json=$(_run "$SNAP_NAME" status --format=json)
api_url=$(echo "$status_json" | jq -r '.endpoints.openai')
echo "API URL: $api_url"

# TODO check to see if server is ready. For now we sleep a minute
sleep 60

models_result=$(_run curl "$api_url"/models)
model_name=$(echo "$models_result" | jq -r .data[0].id)

echo "Model name: $model_name"

if [ -z "$model_name" ]; then
  echo "::error::Failed to look up model name: $models_result"
  exit 1
fi

echo "::endgroup::"

echo "::group::Prompting model"

image_data=$(base64 < "$1" | tr -d '\n')

payload="{
  \"model\": \"$model_name\",
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"text\",
          \"text\": \"what is in this image\"
        },
        {
          \"type\": \"image_url\",
          \"image_url\": {
            \"url\": \"data:image/jpeg;base64,${image_data}\"
          }
        }
      ]
    }
  ],
  \"max_tokens\": 300
}"

# Minify the json payload to make it a single line
# The _run command has issues with line breaks
payload=$(echo "$payload" | jq -c .)

response=$(_run curl "$api_url"/chat/completions -H "Content-Type: application/json" -d "$payload")
echo "Response: $response"
response_content=$(echo "$response" | jq -r .choices[0].message.content)

if [ -z ${#response_content} ]; then
  echo "::error::Response message empty: $response"
  exit 1
fi

# Convert response to lower case and check if it contains the word "circle"
if [[ "${response_content,,}" != *circle* ]]; then
  echo "::notice::Response does not contain the word 'circle' $response_content"
  echo "$response"
  exit 1
fi

echo "::endgroup::"
