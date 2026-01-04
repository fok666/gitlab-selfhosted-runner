#!/bin/bash

# Check latest GitLab Runner release version
curl -sSI "https://gitlab.com/api/v4/projects/250833/releases/permalink/latest" | grep "^location:" | grep -Eo "v[0-9]+[.][0-9]+[.][0-9]+" | sed 's/v//'
