#!/bin/bash

# Release & publish new version of web-ui-components

set -ex

export UNIQUE=`date +%D_%T|sed 's/\//_/g'|sed 's/:/-/g'`
export ROOT=~/tmp/web-ui-components-${UNIQUE}

export WEB_UI_COMPONENTS_REPO=https://github.com/mareklibra/kubevirt-web-ui-components
export WEB_UI_COMPONENTS_GIT=${WEB_UI_COMPONENTS_REPO}.git

export VERSION=$1 # example: 0.1.5
export WEB_UI_COMPONENTS_BRANCH="${2:-master}"
export WEB_UI_BRANCH="${3:-master}"

function usage {
  echo $0 [VERSION] [[WEB_UI_COMPONENTS_BRANCH]] [[WEB_UI_BRANCH]]
  echo example: $0 0.1.5 master master
}

if [ x${VERSION} = x ] ; then
  usage
  exit 1
fi

cd ~/IdeaProjects/web-ui-components
pwd
echo Bumping web-ui-components version to ${VERSION}
echo WEB_UI_COMPONENTS_BRANCH: ${WEB_UI_COMPONENTS_BRANCH}
echo WEB_UI_BRANCH: ${WEB_UI_BRANCH}

sleep 5

#############

rm -rf ${ROOT}
git clone ${WEB_UI_COMPONENTS_GIT} ${ROOT}

cd ${ROOT}
git remote add upstream https://github.com/kubevirt/web-ui-components.git
git fetch --all
git checkout -b release-${VERSION} -t remotes/upstream/${WEB_UI_COMPONENTS_BRANCH}
# intentionally skip "npm version" or so
sed -i "s/\"version\":.*\".*\".*$/\"version\": \"${VERSION}\",/g" package.json
git add package.json
git commit -m "Bump ${VERSION}"
git push --set-upstream origin release-${VERSION}

# TODO: improve following for branches
firefox ${WEB_UI_COMPONENTS_REPO}/pull/new/release-${VERSION} &

cat <<EOF
  Once PR is merged, create new release

  https://github.com/kubevirt/web-ui-components/releases/new
   - tag version: v${VERSION}
   - release title: web-ui-components-${VERSION}

  Then publish release via:
    cd ${ROOT} && \\
    git checkout ${WEB_UI_COMPONENTS_BRANCH} && git fetch --all && git reset --hard upstream/${WEB_UI_COMPONENTS_BRANCH} && rm -rf node_modules && yarn install && yarn build && \\
    npm publish && \\
    ./web-ui.upgradeComponents.sh ${VERSION} ${WEB_UI_BRANCH}
EOF

