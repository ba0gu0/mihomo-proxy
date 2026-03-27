#!/usr/bin/env bash

set -euo pipefail

bump="${1:-patch}"
requested_version="${2:-}"

normalize_version() {
  local version="$1"
  version="${version#refs/tags/}"
  version="${version#v}"
  printf '%s\n' "$version"
}

validate_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid semantic version: ${version}" >&2
    exit 1
  fi
}

latest_tag="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -n 1 || true)"

if [[ -z "$latest_tag" ]]; then
  latest_version="0.0.0"
else
  latest_version="$(normalize_version "$latest_tag")"
fi

validate_version "$latest_version"

case "$bump" in
  patch | minor | major)
    IFS='.' read -r major minor patch <<< "$latest_version"
    case "$bump" in
      patch)
        patch=$((patch + 1))
        ;;
      minor)
        minor=$((minor + 1))
        patch=0
        ;;
      major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    esac
    printf '%s.%s.%s\n' "$major" "$minor" "$patch"
    ;;
  exact)
    if [[ -z "$requested_version" ]]; then
      echo "An exact version is required when bump=exact" >&2
      exit 1
    fi

    requested_version="$(normalize_version "$requested_version")"
    validate_version "$requested_version"

    highest_version="$(printf '%s\n%s\n' "$latest_version" "$requested_version" | sort -V | tail -n 1)"
    if [[ "$requested_version" != "$highest_version" || "$requested_version" == "$latest_version" ]]; then
      echo "Exact version ${requested_version} must be greater than the latest tag v${latest_version}" >&2
      exit 1
    fi

    printf '%s\n' "$requested_version"
    ;;
  *)
    echo "Unsupported bump type: ${bump}. Use patch, minor, major, or exact." >&2
    exit 1
    ;;
esac
