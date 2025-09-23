#!/usr/bin/env sh

set -e

if [ -f "./.vscode/.env" ]; then
    set -a && source ./.vscode/.env && set +a
fi

"${LOVE_BINARY:-love}" test.lua
