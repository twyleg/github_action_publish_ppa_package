# Publish PPA Package

GitHub action to publish the Ubuntu PPA (Personal Package Archives) packages.

## Inputs

### `ppa_repository`
**Required** The PPA repository, e.g. `twyleg/hello-world`.

### `ppa_package`
**Required** The PPA package name, e.g. `hello-world`.

### `ppa_repository`
**Required** The PPA repository, e.g. `twyleg/hello-world`.

### `gpg_private_key`
**Required** GPG private key exported as an ASCII armored version or its base64 encoding, exported with the following command.

```sh
gpg --output private.pgp --armor --export-secret-key <KEY_ID or EMAIL>
```

### `gpg_passphrase`
**Optional** Passphrase of the GPG private key.

### `deb_email`
**Required** The email address of the maintainer.

### `deb_fullname`
**Required** The full name of the maintainer.

### `series`
**Optional** The series to which the package will be published, separated by space. e.g., `"bionic focal"`.

### `revision`
**Optional** The revision of the package, default to `1`.

### `upstream_version`
**Required** The upstream version numbers, e.g. `${{ github.event.release.tag_name }}`

## Example usage

```yaml
name: Upload PPA Package

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  publish-ppa:
    runs-on: ubuntu-latest
    steps:
    - name: Publish PPA
      uses: twyleg/github_action_publish_ppa_package@v2.0.1
      with:
        ppa_package: "hello-world"
        ppa_repository: "twyleg/ppa"
        deb_email: "mail@twyleg.de"
        deb_fullname: "Torsten Wylegala"
        gpg_private_key: ${{ secrets.PPA_GPG_PRIVATE_KEY }}
        gpg_passphrase: ${{ secrets.PPA_GPG_PASSPHRASE }}
        upstream_version: ${{ github.event.release.tag_name }}
        series: "oracular"
```

## Example

- [https://github.com/twyleg/playground_ubuntu_ppa_hello_world]([https://github.com/yuezk/GlobalProtect-openconnect](https://github.com/twyleg/playground_ubuntu_ppa_hello_world))

## LICENSE

[MIT](./LICENSE)
