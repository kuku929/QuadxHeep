#!/usr/bin/env bash
set -e

VIVADO_MOUNT="/tools/vivado-${VIVADO_VERSION}"
SETTINGS="${VIVADO_MOUNT}/settings64.sh"

if [ -f "$SETTINGS" ]; then
    # Extract XILINX_VIVADO in a subshell so errors from missing sub-settings
    # (DocNav, HLS, etc.) don't abort us yet.
    ORIG_PATH=$(bash -c "source \"$SETTINGS\" 2>/dev/null; echo \$XILINX_VIVADO")

    # Symlink original host install path → container mount point so every
    # hardcoded path inside settings64.sh and the Vivado binaries resolves.
    if [ -n "$ORIG_PATH" ] && [ "$ORIG_PATH" != "$VIVADO_MOUNT" ]; then
        mkdir -p "$(dirname "$ORIG_PATH")"
        ln -sfn "$VIVADO_MOUNT" "$ORIG_PATH"
    fi

    # settings64.sh sources sibling tool settings (DocNav, HLS, …) that are
    # not mounted in this container. Create empty stubs so sourcing doesn't fail.
    grep -Eo '/[^[:space:]]+\.sh' "$SETTINGS" | while read -r dep; do
        if [ ! -f "$dep" ]; then
            mkdir -p "$(dirname "$dep")"
            touch "$dep"
        fi
    done

    source "$SETTINGS"
fi

exec "$@"
