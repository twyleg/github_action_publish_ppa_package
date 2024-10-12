#!/bin/bash

set -o errexit -o pipefail -o nounset

PACKAGE=$INPUT_PACKAGE
REPOSITORY=$INPUT_REPOSITORY
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

assert_non_empty inputs.package "$PACKAGE"
assert_non_empty inputs.repository "$REPOSITORY"
assert_non_empty inputs.upstream_version "$UPSTREAM_VERSION"
assert_non_empty inputs.gpg_private_key "$GPG_PRIVATE_KEY"
assert_non_empty inputs.gpg_passphrase "$GPG_PASSPHRASE"
assert_non_empty inputs.deb_email "$DEB_EMAIL"
assert_non_empty inputs.deb_fullname "$DEB_FULLNAME"

export DEBEMAIL="$DEB_EMAIL"
export DEBFULLNAME="$DEB_FULLNAME"

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
echo "Adding PPA: $REPOSITORY"
add-apt-repository -y ppa:$REPOSITORY || true
apt-get update || true
echo "::endgroup::"

if [[ -z "$SERIES" ]]; then
    SERIES=$(distro-info --supported)
fi

git config --global --add safe.directory /github/workspace

for s in $SERIES; do
    ubuntu_version=$(distro-info --series $s -r | cut -d' ' -f1)

    echo "::group::Building deb for: $ubuntu_version ($s)"

    changes="New upstream release"

    # Update the debian changelog
    dch --distribution $s --package $PACKAGE --newversion $UPSTREAM_VERSION-$REVISION~ubuntu$ubuntu_version "$changes"
    cat debian/changelog

    # Install build dependencies
    mk-build-deps --install --remove --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' debian/control

    gbp buildpackage \
       --git-upstream-tag=$UPSTREAM_VERSION \
       --git-ignore-new \
       --git-builder="debuild" -S -sa \
       -k"$GPG_KEY_ID" \
       -p"gpg --batch --passphrase "$GPG_PASSPHRASE" --pinentry-mode loopback"


    dput ppa:$REPOSITORY ../*.changes

    echo "Uploaded $PACKAGE to $REPOSITORY"

    echo "::endgroup::"
done
