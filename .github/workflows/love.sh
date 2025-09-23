#!/bin/sh

latest_tag=$(git describe --tags --abbrev=0)

gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/love2d/love/actions/artifacts > artifacts.json

artifact_name="love-linux-X64.AppImage"
artifact_download_url=$(cat ./artifacts.json | jq -r ".artifacts | map(select(.expired != true and .name == \"${artifact_name}\"))[0].archive_download_url")

if [ $? -ne 0 ] || [ -z "$artifact_download_url" ]; then
  echo "Error: could not get latest artifact download URL of type '${artifact_name}'"
  exit 1
fi

echo "Downloading artifact from '${artifact_download_url}' as '${artifact_name}.zip'"

rm -rf ./bin
mkdir -p ./bin

curl -L \
  -H "Authorization: Bearer $(gh auth token)" \
  "${artifact_download_url}" \
  -o "./bin/${artifact_name}.zip"

if [ $? -ne 0 ]; then
  echo "Could not download artifact."
  exit 1
fi

cd ./bin
unzip "${artifact_name}.zip"
mv love-*.AppImage ../love-12.0-x86_64.AppImage
chmod +x ../love-12.0-x86_64.AppImage
