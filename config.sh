#!/bin/bash
set -ex

export GITHUB_USER_NAME=mareklibra
export WEB_UI_COMPONENTS_REPO=https://github.com/${GITHUB_USER_NAME}/kubevirt-web-ui-components
export WEB_UI_REPO=https://github.com/${GITHUB_USER_NAME}/web-ui

export DISTGIT=~/packaging/kubevirt-web-ui # result of rhpkg clone containers/kubevirt-web-ui

mkdir -p ~/tmp

