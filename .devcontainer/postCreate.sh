#!/bin/bash
# this script is supposed to be called from the project root (e.g. sh .devcontainer/postCreate.sh)

# install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq
