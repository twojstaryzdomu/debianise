# debianise

Builds deb package(s) from code in a github repository. The debian configuration directory is required, whether in the repository or in an external *.tar.gz file.

## Usage

Minimal usage to build *.deb packages:

    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v2
        - id: debianise
          uses: twojstaryzdomu/debianise@HEAD

It is assumed here the checked out github repository is fully contained, including the debian build directory with the necessary build files. If it isn't, make sure to set `additional_archive` input parameter as the file path (not url) to an archive containing those.

The action provides convenience outputs that may be used as inputs to `softprops/action-gh-release`.

This is a minimal example making use of outputs to publish the *.deb files in a new release:

        - uses: softprops/action-gh-release@v1
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          with:
            files: ${{ steps.debianise.outputs.files }}
            name: ${{ steps.debianise.outputs.release_name }}
            tag_name: ${{ steps.debianise.outputs.tag_name }}

### Inputs

Most inputs are for convenience only and need not be set at all. The defaults are fine if the checked out repository is self-contained.

#### `path`

Path to the checked out sources to build. Not necessary if the checkout action is run without the path parameter. Unset by default.

#### `install_build_depends`

A boolean. if `true`, the packages listed under
Build-Depends in debian/control will be installed. Defaults to `true`.

#### `additional_build_depends`

A list of packages to install before build. Unset by default.

#### `additional_archive`

Path to an additional *.tar.gz file to extract prior to build. Unset by default.

#### `pre_build_cmds`

Commands to run just before the build. Unset by default.

### `package`

Package name to set as `${PACKAGE}`. If unset, the last component of `${GITHUB_REPOSITORY}` will be used.

#### `version`

Value to set as `${VERSION}`. If unset, defaults to `0.0`.

#### `create_changelog`

A boolean. Create changelog based on git commit entries. Defaults to `true`.

#### `release_name`

Contains the name for the repository release page on github. Defaults to
`${PACKAGE}_${GIT_DATE}.${SHORT_SHA}`

#### `tag_name`

Contains the tag name for the repository release page on github. Defaults to
`${GIT_DATE}.${SHORT_SHA}`.

#### `debug`

A boolean. Display executed commands as they are executed. Defaults to `true`.

### Outputs

#### `files`

Output value that may be provided to the `files` input parameter of the `softprops/action-gh-release` action. 

#### `release_name`

Output value that may be provided to the `name` input parameter of the `softprops/action-gh-release` action. 

#### `tag_name`

Output value that may be provided to the `tag_name` input parameter of the `softprops/action-gh-release` action. 
