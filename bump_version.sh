#!/bin/sh

function has_version() {
    echo $1 | sed -n 's/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/\1/p'
}

function escape_version() {
    echo $1 | sed -n 's/\./\\\./gp'
}

function update_version() {
    spaces_pattern=$'[ \t]*'
    filename=$1
    version=$2
    
    echo $filename
    echo $version
    echo $spaces_pattern

    sed -i .bak "s/_VERSION$spaces_pattern=$spaces_pattern\".*\"/_VERSION = \"$(escape_version $version)\"/g" $filename
    rm $filename.bak
    git add $filename
}

version=$(has_version $1)
if [ -z "$version" ]; then
    echo "Need a version in the format major.minor.revision (e.g., 1.0.0)"
    exit 1
fi

has_pending_changes=$(git status --porcelain)

if [ ! -z "$has_pending_changes" ]; then
    echo "Cannot bump version when current directory has pending changes!"
    exit 1
fi

release_branch="release-v${version}"
has_release_branch=$(git rev-parse --verify $release_branch 2> /dev/null)

if [ "$has_release_branch" ]; then
    echo "Delete ${has_release_branch} first then run this command."
    exit 1
fi

git checkout main
git pull origin

set -e

git checkout -b $release_branch

update_version "./slick/meta/init.lua" $version

git commit -m "Bump version to ${version}."
git push origin

github_pr_url=$(gh pr create --fill)

set +e

which xdg-open
if [ $? -eq 0 ]; then
    xdg-open "$github_pr_url"
else
    which open
    if [ $? -eq 0 ]; then
        open "$github_pr_url"
    fi
fi

echo "Bumped version to ${version}. Now do a PR: ${github_pr_url}!"
