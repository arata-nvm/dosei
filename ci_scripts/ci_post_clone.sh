#!/bin/sh
# Xcode Cloud がリポジトリを取ってきた直後に動く。
# .xcodeproj は Git に入れていないので、ここで XcodeGen で作る。
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"
brew install xcodegen
xcodegen
