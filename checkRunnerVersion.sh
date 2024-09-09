#!/bin/bash

# Check latest Runner release version
curl -sSI "https://github.com/actions/runner/releases/latest" | grep "^location:" | grep -Eo "[0-9]+[.][0-9]+[.][0-9]+"
