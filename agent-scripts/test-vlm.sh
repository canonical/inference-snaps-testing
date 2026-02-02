#!/bin/bash -eu

#if [ -z "${CI:-}" ]; then
#  _run() {
#    ssh olga.local "$@"
#  }
#
#  _put() {
#    PREFIX="olga.local"
#
#    TARGET=${@: -1}
#    [[ "${TARGET:0:1}" != ":" ]] && TARGET=":${TARGET}"
#    TARGET=${PREFIX}${TARGET}
#
#    # Extract the sources (remove the target) from the argument list
#    SOURCES_ARRAY=("${@:1:$#-1}")
#    SOURCES="${SOURCES_ARRAY[@]}"
#    scp $SOURCES $TARGET
#  }
#fi

echo "::group::Getting model name"

status_json=$(_run "$SNAP_NAME" status --format=json)
api_url=$(echo "$status_json" | jq -r '.endpoints.openai')
echo "API URL: $api_url"

# TODO check to see if server is ready.
# This can be difficult as the models endpoint can be ready, but inferencing not yet.
# Simply prompting the model with text is also not possible, as some models require an image.
# Perhaps we should fetch the models endpoint in a loop until success or timeout,
# then we prompt the model with the image in a loop until success or timeout.
# For now we sleep a minute.
sleep 60

set +e
models_result=$(_run curl "$api_url"/models)
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
  echo "Get logs"
  _run sudo snap logs "$SNAP_NAME" -n 300
  echo "::error::Failed to look up models: $models_result"
  echo "::endgroup::"
  exit 1
fi

model_name=$(echo "$models_result" | jq -r .data[0].id)
echo "Model name: $model_name"
if [ -z "$model_name" ]; then
  echo "::error::Failed to look up model name: $models_result"
  echo "::endgroup::"
  exit 1
fi

echo "::endgroup::"

echo "::group::Prompting model"

image_data=$(base64 <"$1" | tr -d '\n')

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

# The _run macro has issues handling quotes and newlines. To work around this we add the
# curl command and its parameters to a script, upload the script to the DUT, and then execute
# this script with the _run command.
echo "#!/bin/bash -eux" >dut-script.sh
echo "curl $api_url/chat/completions -H 'Content-Type: application/json' -d '$payload'" >>dut-script.sh
chmod +x dut-script.sh
_put dut-script.sh :

set +e
response=$(_run ./dut-script.sh)
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
  echo "Get logs"
  _run sudo snap logs "$SNAP_NAME" -n 300
  echo "::error::Failed to prompt model: $models_result"
  echo "::endgroup::"
  exit 1
fi

echo "Response: $response"

# Validate response is valid JSON
if ! echo "$response" | jq empty 2>/dev/null; then
  echo "::error::Response is not valid JSON: $response"
  echo "::endgroup::"
  exit 1
fi

response_content=$(echo "$response" | jq -r .choices[0].message.content)

if [ -z ${#response_content} ]; then
  echo "::error::Response message empty: $response"
  echo "::endgroup::"
  exit 1
fi

# Convert response to lower case and check if it contains the word "circle"
if [[ "${response_content,,}" != *circle* ]]; then
  echo "::notice::Response does not contain the word 'circle' $response_content"
  echo "$response"
  echo "::endgroup::"
  exit 1
fi

echo "Received expected response"

echo "::endgroup::"
