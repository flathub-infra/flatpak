#!/usr/bin/env bash

set -euo pipefail

DOCKERFILE="tests/test_unpriv.Dockerfile"
IMAGE="flatpak-unpriv:test"

checkcmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "$1 not found. Please install it from your distribution."
        exit 1
    fi
}

checkcmd docker

tmpdir="$(mktemp -d)"
export seccomp_json="$tmpdir/flatpak.seccomp.json"

curl -fsSL \
  "https://raw.githubusercontent.com/flathub-infra/vorarbeiter/refs/heads/main/flatpak.seccomp.json" \
  -o "$seccomp_json"

docker build -t "${IMAGE}" -f "$DOCKERFILE" --progress=plain .

docker run --pull never \
    --security-opt apparmor=unconfined \
    --cap-drop all \
    --security-opt seccomp="$seccomp_json" \
    -v /proc:/host/proc \
    --rm \
    --entrypoint= \
    "${IMAGE}" \
    bash -euxo pipefail -c '
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo

    flatpak install -y --user --noninteractive --no-related --no-deps \
        flathub org.freedesktop.Platform//25.08

    cat > manifest.yml <<EOF
id: org.flatpak.Hello
runtime: org.freedesktop.Platform
runtime-version: "25.08"
sdk: org.freedesktop.Platform
command: hello
modules:
  - name: hello
    buildsystem: simple
    build-commands:
      - install -Dm755 hello.sh /app/bin/hello
    sources:
      - type: script
        dest-filename: hello.sh
        commands:
          - echo "Hello world, from a sandbox"
EOF

    flatpak-builder --user --force-clean --repo=repo \
      --disable-rofiles-fuse --sandbox builddir manifest.yml

    flatpak install -y --user --noninteractive --no-related --no-deps \
      ./repo org.flatpak.Hello

    output="$(flatpak run org.flatpak.Hello)"

    printf "%s\n" "$output"

    if [ "$output" != "Hello world, from a sandbox" ]; then
        echo "ERROR: Unexpected output"
        exit 1
    fi

    echo "PASS"
'
