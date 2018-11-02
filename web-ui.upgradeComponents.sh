#!/bin/bash

# Upgrade web-ui-componennts version in web-ui project

set -ex

export UNIQUE=`date +%D_%T|sed 's/\//_/g'|sed 's/:/-/g'`
export WEB_UI_ROOT=~/tmp/web-ui-${UNIQUE}

export WEB_UI_REPO=https://github.com/mareklibra/web-ui
export WEB_UI_GIT=${WEB_UI_REPO}.git

export VERSION=$1
export WEB_UI_BRANCH="${2:-master}"

function usage {
  echo $0 [WEB_UI_COMPONENTS_VERSION] [[WEB_UI_BRANCH]]
  echo example: $0 0.1.5 master
}

if [ x${VERSION} = x ] ; then
  usage
  exit 1
fi

#####################
# prepare web-ui for later
rm -rf ${WEB_UI_ROOT}
git clone ${WEB_UI_GIT} ${WEB_UI_ROOT}
cd ${WEB_UI_ROOT}
git remote add upstream https://github.com/kubevirt/web-ui.git
git fetch --all
git checkout -b upgradeComponents.${VERSION}.${WEB_UI_BRANCH} -t remotes/upstream/${WEB_UI_BRANCH}

cd kubevirt
yarn upgrade -P web-ui-components -E ${VERSION}
git add package.json yarn.lock && git commit -m "Upgrade web-ui-components to ${VERSION}"
git push --set-upstream origin upgradeComponents.${VERSION}.${WEB_UI_BRANCH}

