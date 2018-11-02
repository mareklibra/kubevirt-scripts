#!/bin/bash

# Downstream build of web-ui

# prerequisities:
# - go get github.com/release-engineering/backvendor
# - dnf install rhpkg
# - dnf install git wget yarn
# - mkdir ~/packaging && cd ~/packaging && rhpkg clone containers/kubevirt-web-ui

export DISTGIT=~/packaging/kubevirt-web-ui # result of rhpkg clone containers/kubevirt-web-ui

export VERSION=$1  # example: 1.3
export RELEASE=$2  # example: 9
export BUILD_SUFFIX=$3 # in case of multiple builds from the same release

export YARN_VERSION=1.9.4 # keep in sync with distgit's Dockerfile
export BRANCH=cnv-1.3-rhel-7 # dist-git branch
export UPSTREAM_TGZ=kubevirt-${VERSION}-${RELEASE}.tar.gz # as in https://github.com/kubevirt/web-ui/releases
export UPSTREAM_TAG=kubevirt-${VERSION}-${RELEASE} # as in https://github.com/kubevirt/web-ui/releases

export TMP=~/tmp
mkdir -p ${TMP}

export YARN_RC=~/.yarnrc
export YARN_OFFLINE_DIR=`mktemp -d ${TMP}/yarn-offline-XXXX`
export FAKE_CHROMEDRIVER=${DISTGIT}/utils/fake_chromedriver.zip # simple "exit 0" wrapper

function usage {
  echo $0 [VERSION] [RELEASE] [[BUILD_SUFFIX]]
}

if [ x${RELEASE} = x ] ; then
  usage
  exit 1
fi

echo Downstream build of kubevirt/web-ui ${VERSION}-${RELEASE}
sleep 5

set -ex

# switch to distgit
cd ${DISTGIT}
git checkout ${BRANCH}
rhpkg sources # to get node-*-headers.tar.gz

# update "upstream" in distgit - get relevant web-ui sources from release
rm ${UPSTREAM_TGZ} || true
wget https://github.com/kubevirt/web-ui/archive/${UPSTREAM_TGZ}
tar -xzf ./${UPSTREAM_TGZ}
git rm -rf upstream
rm -rf upstream || true # potential leftovers
mv web-ui-kubevirt-${VERSION}-${RELEASE} upstream # dist-git web-ui sources are replaced by content of release .tgz
echo === apply downstream patches
sed -i "s/^GIT_TAG=.*$/GIT_TAG=${UPSTREAM_TAG}/g" upstream/build-backend.sh # sources are from .tgz, not cloned git repo
sed -i "s/^yarn install.*$/yarn install --offline --use-yarnrc \.\/\.yarnrc/g" upstream/build-frontend.sh # helps debugging in local Docker environment
git add upstream

# update sources (kubevirt/web-ui npm dependencies change regularly - at least for web-ui-components)
# in other words: prepare yarn offline mirror
mv ${YARNRC} ${YARN_RC}.backup || true
rm -rf ~/.cache/yarn || true
yarn config set yarn-offline-mirror ${YARN_OFFLINE_DIR}/npm-packages-offline-cache
# yarn config set yarn-offline-mirror-pruning true
# Let's reuse already present web-ui sources to update yarn offline mirror
cd ${DISTGIT}/upstream/frontend
sed -i 's/^.*"chromedriver".*$//g' package.json # not needed in d/s build. It's post-installation script is broken in offline environment so removing it from dependencies is the easiest workaround.
cp ${YARN_RC} ./
yarn install --use-yarnrc ${YARN_RC} # populate the offline mirror
yarn add yarn@${YARN_VERSION} --use-yarnrc ${YARN_RC}
# we keep using yarn.lock from openshift/console to avoid merge conflicts, so it lacks kubevirt-web-ui-components package.json
# CHANGE: web-ui/kubevirt/yarn.lock has been introduced to the project
# export WEB_UI_COMPONENTS_VERSION=`grep kubevirt-web-ui package.json | cut -d ':' -f 2 | cut -d '"' -f 2`
#echo "=== parsed kubevirt-web-ui-components version: ${WEB_UI_COMPONENTS_VERSION}"
#yarn add kubevirt-web-ui-components@${WEB_UI_COMPONENTS_VERSION} --use-yarnrc ${YARN_RC}
sed -i 's/ yarn install\",$/ yarn install --offline --use-yarnrc \.\.\/frontend\/\.yarnrc\",/g' package.json # the preinstall phase calls "yarn install" in kubevirt directory
git add yarn.lock # required
git add package.json # probably not needed but for consistency

# verify offline mirror
ls ${YARN_OFFLINE_DIR}/npm-packages-offline-cache
rm -rf node_modules
rm -rf ../kubevirt/node_modules
cp ${YARN_RC} ./
yarn install --offline --use-yarnrc ${YARN_RC}

# prepare yarn-offline.tar which will be committed to the distgit sources:
mkdir ${YARN_OFFLINE_DIR}/frontend/
cd ${YARN_OFFLINE_DIR}
cp ${YARN_RC} ./frontend/
sed -i 's/^yarn-offline-mirror .*$/yarn-offline-mirror "\/opt\/app-root\/src\/npm-packages-offline-cache"/' ./frontend/.yarnrc
cp ${FAKE_CHROMEDRIVER} ./
rm ${DISTGIT}/yarn-offline.tar
tar -cf ${DISTGIT}/yarn-offline.tar .
cd ${DISTGIT}
rhpkg new-sources yarn-offline.tar node-*

# clean-up
rm ${DISTGIT}/upstream/frontend/.yarnrc # will be populated from yarn-offline.tar
mv ${YARN_RC}.backup ${YARN_RC} || rm ${YARN_RC} || true
cd ${DISTGIT}
# git checkout upstream/frontend/package.json # modified for the chromedriver above
# git checkout upstream/frontend/yarn.lock # changed due to the chromedriver and yarn@${YARN_VERSION}

# update Dockerfile for version/release
cd ${DISTGIT}
sed -i "s/version=\".*\"/version=\"v${VERSION}\"/g" Dockerfile
sed -i "s/release=\".*\"/release=\"${RELEASE}${BUILD_SUFFIX}\"/g" Dockerfile
git add Dockerfile 

# regenerate rh-manifest.txt
cd ${DISTGIT}
backvendor upstream > rh-manifest.txt || true
cd upstream/frontend
yarn licenses list >> ../../rh-manifest.txt
# TODO: licences from kubevirt/package.json
git add ../../rh-manifest.txt

# commit & push changes
cd ${DISTGIT}
git commit -m "Bump ${VERSION}-${RELEASE}${BUILD_SUFFIX}"
rhpkg push

# start build
# docker build . -f Dockerfile.local # for debugging
rhpkg container-build --scratch
rhpkg container-build

