#!/bin/bash

set -euo pipefail

. $(dirname $0)/libtest.sh

skip_revokefs_without_fuse

echo "1..1"

setup_repo
${FLATPAK} ${U} install -y test-repo org.test.Platform master >&2

RUNTIME_METADATA="${FL_DIR}/runtime/org.test.Platform/${ARCH}/master/active/metadata"
assert_has_file "${RUNTIME_METADATA}"

cat >> "${RUNTIME_METADATA}" <<EOF

[Context]
shared=network;ipc;
sockets=x11;wayland;pulseaudio;
devices=dri;all;
filesystems=home;host;
EOF

APP_DIR="$(mktemp -d)"
flatpak build-init "${APP_DIR}" org.test.app org.test.Platform org.test.Platform master >&2
mkdir -p "${APP_DIR}/files/bin"
echo '#!/bin/sh' > "${APP_DIR}/files/bin/app.sh"
chmod a+x "${APP_DIR}/files/bin/app.sh"
flatpak build-finish --command=app.sh "${APP_DIR}" >&2

APP_METADATA="${APP_DIR}/metadata"
assert_has_file "${APP_METADATA}"

assert_not_file_has_content "${APP_METADATA}" "^shared=.*network"
assert_not_file_has_content "${APP_METADATA}" "^sockets=.*x11"
assert_not_file_has_content "${APP_METADATA}" "^devices=.*dri"
assert_not_file_has_content "${APP_METADATA}" "^filesystems=.*home"

ok "permissions are not inherited from the runtime"
