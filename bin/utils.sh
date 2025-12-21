#!/usr/bin/env bash

set -euo pipefail

echoerr() {
  printf "\033[0;31m%s\033[0m\n" "$1" >&2
}

info() {
  printf "\033[0;34m%s\033[0m\n" "$1" >&2
}

default_packages_file() {
  echo "${ASDF_PYTHON_DEFAULT_PACKAGES_FILE:-$HOME/.default-python-packages}"
}

archive_flavor() {
  local flavor=${ASDF_PYTHON_STANDALONE_ARCHIVE:-install_only}

  case "$flavor" in
    install_only|install_only_stripped)
      echo "$flavor"
      ;;
    *)
      echoerr "Unsupported archive flavor '$flavor'. Valid values: install_only, install_only_stripped."
      exit 1
      ;;
  esac
}

linux_libc() {
  local libc=${ASDF_PYTHON_STANDALONE_LIBC:-gnu}

  case "$libc" in
    gnu|musl)
      echo "$libc"
      ;;
    *)
      echoerr "Unsupported Linux libc '$libc'. Valid values: gnu, musl."
      exit 1
      ;;
  esac
}

detect_target_triple() {
  if [[ -n "${ASDF_PYTHON_STANDALONE_TARGET:-}" ]]; then
    echo "$ASDF_PYTHON_STANDALONE_TARGET"
    return
  fi

  local os arch libc
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$arch" in
    x86_64|amd64)
      arch="x86_64"
      ;;
    arm64|aarch64)
      arch="aarch64"
      ;;
    *)
      echoerr "Unsupported architecture '$arch'. Override with ASDF_PYTHON_STANDALONE_TARGET."
      exit 1
      ;;
  esac

  case "$os" in
    Darwin)
      echo "${arch}-apple-darwin"
      ;;
    Linux)
      libc=$(linux_libc)
      echo "${arch}-unknown-linux-${libc}"
      ;;
    *)
      echoerr "Unsupported OS '$os'. Override with ASDF_PYTHON_STANDALONE_TARGET."
      exit 1
      ;;
  esac
}

latest_release_tag() {
  curl -fsSL "https://raw.githubusercontent.com/astral-sh/python-build-standalone/latest-release/latest-release.json" \
    | awk -F\" '/"tag"/ {print $4; exit}'
}

release_list_from_env() {
  if [[ -z "${ASDF_PYTHON_STANDALONE_RELEASES:-}" ]]; then
    return
  fi

  echo "$ASDF_PYTHON_STANDALONE_RELEASES" | tr ', ' '\n' | sed '/^$/d'
}

release_tags_to_search() {
  local env_tags latest tags
  env_tags=$(release_list_from_env)
  if [[ -n "$env_tags" ]]; then
    echo "$env_tags" | sed '/^$/d'
    return
  fi

  latest=$(latest_release_tag)
  if [[ -z "$latest" ]]; then
    echoerr "Could not determine latest release tag."
    exit 1
  fi

  echo "$latest"
}

release_assets_json() {
  local release=$1
  curl -fsSL "https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/${release}"
}

asset_names_from_json() {
  grep -o '"name":[^,]*' | cut -d'"' -f4 || true
}

parse_version_and_release() {
  local version=$1

  if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9A-Za-z0-9]+)\+([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  else
    echoerr "Invalid version '$version'. Expected format: <python-version>+<build-date> (e.g. 3.12.1+20251217)."
    exit 1
  fi
}

asset_matches_selection() {
  local asset=$1
  local python_version=$2
  local release=$3
  local target=$4
  local flavor=$5

  case "$asset" in
    "cpython-${python_version}+${release}-${target}-"*"-full.tar."*)
      return 1
      ;;
    "cpython-${python_version}+${release}-${target}-${flavor}.tar."*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

select_asset_name() {
  local assets_json=$1
  local python_version=$2
  local release=$3
  local target=$4
  local flavor=$5

  local asset
  while read -r asset; do
    if asset_matches_selection "$asset" "$python_version" "$release" "$target" "$flavor"; then
      echo "$asset"
      return
    fi
  done <<<"$(echo "$assets_json" | asset_names_from_json)"

  echoerr "No asset found for Python ${python_version}+${release} (${target}, ${flavor})."
  exit 1
}

extract_versions_for_target() {
  local assets_json=$1
  local target=$2
  local flavor=$3

  echo "$assets_json" \
    | asset_names_from_json \
    | while read -r asset; do
        if [[ "$asset" =~ ^cpython-([0-9]+\.[0-9]+\.[0-9A-Za-z0-9]+)\+([0-9]+)-${target}-${flavor}\.tar\.(gz|zst)$ ]]; then
          echo "${BASH_REMATCH[1]}+${BASH_REMATCH[2]}"
        fi
      done \
    | sort -V \
    | uniq
}

download_archive() {
  local url=$1
  local destination=$2

  curl -fL "$url" -o "$destination"
}

extract_archive() {
  local archive=$1
  local destination=$2

  mkdir -p "$destination"

  case "$archive" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$destination"
      ;;
    *.tar.zst|*.tar.zstd)
      tar --zstd -xf "$archive" -C "$destination"
      ;;
    *)
      echoerr "Unknown archive format: $archive"
      exit 1
      ;;
  esac
}
