#!/bin/bash

set -o errexit -o pipefail -o nounset

GIT_REPOSITORY=$INPUT_GIT_REPOSITORY
GIT_TOKEN=$INPUT_GIT_TOKEN
PPA_PACKAGE=$INPUT_PPA_PACKAGE
PPA_REPOSITORY=$INPUT_PPA_REPOSITORY
UPSTREAM_VERSION=$INPUT_UPSTREAM_VERSION
GPG_PRIVATE_KEY="$INPUT_GPG_PRIVATE_KEY"
GPG_PASSPHRASE=$INPUT_GPG_PASSPHRASE
SERIES=$INPUT_SERIES
REVISION=$INPUT_REVISION
DEB_EMAIL=$INPUT_DEB_EMAIL
DEB_FULLNAME=$INPUT_DEB_FULLNAME

assert_non_empty() {
    name=$1
    value=$2
    if [[ -z "$value" ]]; then
        echo "::error::Invalid Value: $name is empty." >&2
        exit 1
    fi
}

assert_non_empty inputs.ppa_package "$PPA_PACKAGE"
assert_non_empty inputs.ppa_repository "$PPA_REPOSITORY"
assert_non_empty inputs.upstream_version "$UPSTREAM_VERSION"
assert_non_empty inputs.gpg_private_key "$GPG_PRIVATE_KEY"
assert_non_empty inputs.gpg_passphrase "$GPG_PASSPHRASE"
assert_non_empty inputs.deb_email "$DEB_EMAIL"
assert_non_empty inputs.deb_fullname "$DEB_FULLNAME"

export DEBEMAIL="$DEB_EMAIL"
export DEBFULLNAME="$DEB_FULLNAME"

export GITMAIL="github-actions[bot]"
export GITFULLNAME="41898282+github-actions[bot]@users.noreply.github.com"
export GITURL="https://git:$GIT_TOKEN@github.com/$GIT_REPOSITORY.git"



echo "::group::Setup git..."

git config --global user.name "$GITFULLNAME"
git config --global user.email "$GITMAIL"
git config --global pull.rebase false 
git config --global --add safe.directory /github/workspace

git clone $GITURL .

git fetch --tags origin debian/latest
git checkout debian/latest
git pull --commit --no-edit origin master

echo "::endgroup::"



echo "::group::Importing GPG private key..."
echo "Importing GPG private key..."

GPG_KEY_ID=$(echo "$GPG_PRIVATE_KEY" | gpg --import-options show-only --import | sed -n '2s/^\s*//p')
echo $GPG_KEY_ID
echo "$GPG_PRIVATE_KEY" | gpg --batch --passphrase "$GPG_PASSPHRASE" --import

echo "Checking GPG expirations..."
if [[ $(gpg --list-keys | grep expired) ]]; then
    echo "GPG key has expired. Please update your GPG key." >&2
    exit 1
fi

echo "::endgroup::"



echo "::group::Adding PPA..."
echo "Adding PPA: $PPA_REPOSITORY"
add-apt-repository -y ppa:$PPA_REPOSITORY || true
apt-get update || true
echo "::endgroup::"




if [[ -z "$SERIES" ]]; then
    SERIES=$(distro-info --supported)
fi

for s in $SERIES; do
    ubuntu_version=$(distro-info --series $s -r | cut -d' ' -f1)

    echo "::group::Building deb for: $ubuntu_version ($s)"

    changes="New upstream release"

    # Update the debian changelog
    dch --distribution $s --package $PPA_PACKAGE --newversion $UPSTREAM_VERSION-$REVISION~ubuntu$ubuntu_version "$changes"
    cat debian/changelog

    # Install build dependencies
    mk-build-deps --install --remove --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' debian/control

    gbp buildpackage \
       --git-upstream-tag=$UPSTREAM_VERSION \
       --git-ignore-new \
       --git-builder="debuild" -S -sa \
       -k"$GPG_KEY_ID" \
       -p"gpg --batch --passphrase "$GPG_PASSPHRASE" --pinentry-mode loopback"


    dput ppa:$PPA_REPOSITORY ../*.changes

    echo "Uploaded $PPA_PACKAGE to $PPA_REPOSITORY"

    echo "::endgroup::"
done



echo "::group::Push debian latest branch and version tag"

git add debian/changelog
git commit -m "New version added"
git tag debian/$UPSTREAM_VERSION
git push --tags origin debian/latest


echo "::endgroup::"