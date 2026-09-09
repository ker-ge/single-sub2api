#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_COUNT=0 GIT_ALLOW_PROTOCOL=https GIT_NO_REPLACE_OBJECTS=1 GIT_ATTR_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
REPOSITORY="https://github.com/ker-ge/single-sub2api.git"
TAG="${1:-}"
EXPECTED_COMMIT="${2:-}"
TARGET="${3:-}"
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$ ]] || fail "Invalid version tag"
[[ "$EXPECTED_COMMIT" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || fail "Invalid commit"
[[ "$TARGET" = /* ]] && [ -f "$TARGET" ] && [ ! -L "$TARGET" ] || fail "Invalid executable path"
[ "$(uname -s)" = Linux ] || fail "Only Linux is supported"
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) fail "Unsupported CPU architecture: $(uname -m)" ;;
esac
for tool in git flock od timeout cp mv; do command -v "$tool" >/dev/null || fail "Missing dependency: $tool"; done
TARGET_DIR="$(dirname -- "$TARGET")"
exec 9>"$TARGET_DIR/.git-update.lock"
flock -n 9 || fail "Another Git update is running"
TEMP_DIR="$(mktemp -d "$TARGET_DIR/.sub2api-git-update.XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
REPO_DIR="$TEMP_DIR/repository"
printf '[STEP] git pull: downloading %s from the prebuilt repository (timeout: 7 minutes)\n' "$TAG"
git init -q "$REPO_DIR"
git -C "$REPO_DIR" remote add origin "$REPOSITORY"
timeout --foreground --kill-after=5 420 git -C "$REPO_DIR" -c credential.helper= -c core.hooksPath=/dev/null -c core.autocrlf=false -c fetch.fsckObjects=true -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=45 pull --ff-only --no-tags --depth=1 --progress origin "$EXPECTED_COMMIT" || fail "git pull failed or timed out; check server GitHub connectivity and proxy settings"
ACTUAL_COMMIT="$(git -C "$REPO_DIR" rev-parse 'HEAD^{commit}')"
[ "$ACTUAL_COMMIT" = "$EXPECTED_COMMIT" ] || fail "Downloaded commit does not match selected tag"
git -C "$REPO_DIR" fsck --strict --no-reflogs "$EXPECTED_COMMIT" >/dev/null
printf '[STEP] Verifying Git commit and binary architecture\n'
REMOTE_REFS="$(timeout --foreground --kill-after=5 30 git -c credential.helper= -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=20 ls-remote "$REPOSITORY" "refs/tags/$TAG" "refs/tags/$TAG^{}")"
REMOTE_COMMIT="$(printf '%s\n' "$REMOTE_REFS" | awk -v tag="refs/tags/$TAG" '$2 == tag { direct=$1 } $2 == tag "^{}" { peeled=$1 } END { print peeled ? peeled : direct }')"
[ "$REMOTE_COMMIT" = "$EXPECTED_COMMIT" ] || fail "Tag was moved or deleted; check updates again"
BINARY_NAME="sub2api-$ARCH"
ENTRY="$(git -C "$REPO_DIR" ls-tree "$EXPECTED_COMMIT" -- "$BINARY_NAME")"
if [ -z "$ENTRY" ]; then
  BINARY_NAME=sub2api
  ENTRY="$(git -C "$REPO_DIR" ls-tree "$EXPECTED_COMMIT" -- "$BINARY_NAME")"
fi
[[ "$ENTRY" =~ ^100(644|755)[[:space:]]blob[[:space:]][0-9a-f]+[[:space:]]$BINARY_NAME$ ]] || fail "Tag must contain a regular binary named sub2api-$ARCH or sub2api at repository root"
printf '[STEP] Using %s for Linux %s\n' "$BINARY_NAME" "$ARCH"
SIZE="$(git -C "$REPO_DIR" cat-file -s "$EXPECTED_COMMIT:$BINARY_NAME")"
[ "$SIZE" -gt 0 ] && [ "$SIZE" -le 524288000 ] || fail "Invalid binary size"
NEW_BINARY="$TEMP_DIR/sub2api"
git -C "$REPO_DIR" cat-file blob "$EXPECTED_COMMIT:$BINARY_NAME" > "$NEW_BINARY"
MAGIC="$(od -An -N4 -tx1 "$NEW_BINARY" | tr -d ' \n')"
CLASS="$(od -An -j4 -N1 -tu1 "$NEW_BINARY" | tr -d ' \n')"
ENDIAN="$(od -An -j5 -N1 -tu1 "$NEW_BINARY" | tr -d ' \n')"
MACHINE="$(od -An -j18 -N2 -tx1 "$NEW_BINARY" | tr -d ' \n')"
[ "$MAGIC" = 7f454c46 ] && [ "$CLASS" = 2 ] && [ "$ENDIAN" = 1 ] || fail "Not a 64-bit little-endian Linux ELF binary (Git LFS pointers are unsupported)"
case "$ARCH:$MACHINE" in amd64:3e00|arm64:b700) ;; *) fail "Binary architecture does not match server; publish sub2api-$ARCH for $TAG" ;; esac
chmod 750 "$NEW_BINARY"
VERSION_OUTPUT="$(timeout 10 "$NEW_BINARY" -version 2>&1)" || fail "Cannot read binary version"
VERSION="$(printf '%s\n' "$VERSION_OUTPUT" | sed -nE 's/.*Sub2API ([^ ]+) .*/\1/p' | head -n 1)"
[ "$VERSION" = "${TAG#v}" ] || fail "Binary version ($VERSION) does not match tag ($TAG); rebuild with -X main.Version=${TAG#v}"
printf '[STEP] Backing up and installing the verified binary; database and ports remain unchanged\n'
cp -p -- "$TARGET" "$TEMP_DIR/previous"
mv -fT -- "$TEMP_DIR/previous" "$TARGET.backup"
mv -fT -- "$NEW_BINARY" "$TARGET"
printf '[OK] Installed %s at commit %s. Restart the service to activate it.\n' "$TAG" "$EXPECTED_COMMIT"
