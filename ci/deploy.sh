#!/usr/bin/env bash

export TRAVIS_TAG=1.5.0

ROOT_PATH=$PWD
VERSION=$TRAVIS_TAG
set -e # abort if anything fails

echo '####################'
echo 'Build Gems'
echo '####################'
echo ''

echo '##### rswag-api #####'
cd $ROOT_PATH/rswag-api
gem build rswag-api.gemspec

echo '##### rswag-specs #####'
cd $ROOT_PATH/rswag-specs
gem build rswag-specs.gemspec

echo '##### rswag-ui #####'
cd $ROOT_PATH/rswag-ui
gem build rswag-ui.gemspec

echo '##### rswag #####'
cd $ROOT_PATH/rswag
gem build rswag.gemspec

echo '####################'
echo 'Push to RubyGems'
echo '####################'
echo ''

echo '##### rswag-api #####'
cd $ROOT_PATH/rswag-api
gem push rswag-api-$VERSION.gem -k $RUBYGEMS_API_KEY

echo '##### rswag-specs #####'
cd $ROOT_PATH/rswag-specs
gem push rswag-specs-$VERSION.gem -k $RUBYGEMS_API_KEY

echo '##### rswag-ui #####'
cd $ROOT_PATH/rswag-ui
gem push rswag-ui-$VERSION.gem -k $RUBYGEMS_API_KEY

echo '##### rswag #####'
cd $ROOT_PATH/rswag
gem push rswag-$VERSION.gem -k $RUBYGEMS_API_KEY

# Cleanup
cd $ROOT_PATH
