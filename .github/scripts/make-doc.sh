#!/usr/bin/env bash

set -ex

DOC_DIR=.
HTML_DIR=${DOC_DIR}/_build/html

# backup the old version's doc as later we do make clean, they all gone.
cd ${HTML_DIR}
mkdir -p ../../bak
rsync -rzvh --ignore-missing-args ./v* ../../bak
rsync -rzvh --ignore-missing-args ./latest ../../bak
cd -

cd ${DOC_DIR} && rm -rf api && pip install -r requirements.txt && make clean && cd -

# require docker installed https://github.com/pseudomuto/protoc-gen-doc
mkdir -p $(pwd)/jina/proto
cd $(pwd)/jina/proto
wget https://raw.githubusercontent.com/jina-ai/jina/master/jina/proto/jina.proto
cd -

docker pull pseudomuto/protoc-gen-doc
docker run --rm \
  -v $(pwd)/chapters/proto:/out \
  -v $(pwd)/jina/proto:/protos \
  pseudomuto/protoc-gen-doc --doc_opt=markdown,docs.md
cd -

# sync contributing.md, release.md and changelog.md to chapters/
wget https://raw.githubusercontent.com/jina-ai/jina/master/CONTRIBUTING.md -P $(pwd)/chapters/
wget https://raw.githubusercontent.com/jina-ai/jina/master/RELEASE.md -P $(pwd)/chapters/
wget https://raw.githubusercontent.com/jina-ai/jina/master/CHANGELOG.md -P $(pwd)/chapters/
cd -
# create markdown for List [X] drivers in Jina & List [X] executors in Jina to chapters/
cd ${DOC_DIR} && jina check --summary-driver chapters/all_driver.md && cat chapters/all_driver.md && cd -
cd ${DOC_DIR} && jina check --summary-exec chapters/all_exec.md && cat chapters/all_exec.md && cd -
cd ${DOC_DIR} && make html && cd -

if [[ $1 == "commit" ]]; then
  cd ${DOC_DIR}
  cp README.md jinahub.jpg jina-logo-dark.png _build/html/
  cd -
  cd ${HTML_DIR}
  mkdir master
  rsync -avr . master  # sync everything under the root to master/
  cd -
  cd ${DOC_DIR}/bak
  rsync -avr --ignore-missing-args ./v* ../_build/html/ --ignore-existing  # revert backup back
  rsync -avr --ignore-missing-args ./latest ../_build/html/ --ignore-existing  # revert backup back
  cd -
  cd ${HTML_DIR}
  rm -rf bak
  echo docs.jina.ai > CNAME
  git init
  git config --local user.email "dev-bot@jina.ai"
  git config --local user.name "Jina Dev Bot"
  touch .nojekyll
  git add .
  git commit -m "$2" -a
  git status
  cd -
elif [[ $1 == "release" ]]; then
  cd ${DOC_DIR}
  cp README.md jinahub.jpg jina-logo-dark.png _build/html/
  cd -
  cd ${HTML_DIR}
  rsync -avr . master  # sync everything under the root to master/
  rsync -avr --exclude=master . latest  # sync everything under the root to master/
  rsync -avr --exclude=master --exclude=latest . "v${JINA_VERSION}"  # sync to versions
  cd -
  cd ${DOC_DIR}/bak
  rsync -avr --ignore-missing-args ./v* ../_build/html/ --ignore-existing  # revert backup back
  cd -
  cd ${HTML_DIR}
  rm -rf bak
  echo docs.jina.ai > CNAME
  git init
  git config --local user.email "dev-bot@jina.ai"
  git config --local user.name "Jina Dev Bot"
  touch .nojekyll
  git add .
  git commit -m "$2" -a   # commit before tagging, otherwise throw fatal: Failed to resolve 'HEAD' as a valid ref.
  git tag ${V_JINA_VERSION}
  git status
  cd -
elif [[ $1 == "serve" ]]; then
    python -m http.server $2 -d ${HTML_DIR}
fi
