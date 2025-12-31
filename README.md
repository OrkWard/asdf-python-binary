# asdf-python-binary

Python plugin for [asdf](https://github.com/asdf-vm/asdf) that installs prebuilt interpreters from [python-build-standalone](https://github.com/astral-sh/python-build-standalone).

## Install

```sh
asdf plugin add python https://github.com/OrkWard/asdf-python-binary.git
```

## Usage

List available versions for your platform (architecture and libc are auto-detected unless overridden):

```sh
asdf list-all python
```

Version identifiers can be specified in two formats:

1. Simple version (major.minor or major.minor.patch) - automatically uses the latest available build:
   ```sh
   asdf install python 3.13
   asdf install python 3.12.1
   ```

2. Full version with build tag (major.minor.patch+build-date):
   ```sh
   asdf install python 3.12.1+20251217
   asdf global python 3.12.1+20251217
   python --version
   ```

### Default packages

After installation, the plugin will install packages from `$HOME/.default-python-packages` (one package per line). Override this path with `ASDF_PYTHON_DEFAULT_PACKAGES_FILE`.

### Configuration

- `ASDF_PYTHON_STANDALONE_ARCHIVE`: choose the archive flavor. Supported values: `install_only` (default) or `install_only_stripped`.
- `ASDF_PYTHON_STANDALONE_TARGET`: override the detected target triple (e.g. `x86_64-apple-darwin`).
- `ASDF_PYTHON_STANDALONE_LIBC`: when on Linux, choose `gnu` (default) or `musl`.
- `ASDF_PYTHON_STANDALONE_RELEASES`: comma-separated list of release tags to search (e.g. `20251217,20241105`). Use this to include older Python lines like 3.8 that are not present in the latest release.

### Notes

- Simple version formats (e.g., `3.13`, `3.12.1`) are now supported and will automatically use the latest available build
- Full version format with build tag (e.g., `3.12.1+20251217`) is still supported for specific build selection
- Builds are pulled from the latest python-build-standalone release.
- Archives are extracted directly into the asdf install path; binaries live under `bin/` as usual.
