#!/usr/bin/env bash
# Installs the pinned native Linux Godot for WSL (or any Linux) so tools/godot.sh and play.sh use it
# instead of a Windows .exe reading the project over \\wsl.localhost (~15x slower to start; see
# docs/PERFORMANCE_AUDIT.md).
#
#   tools/install_godot_wsl.sh            install to ~/.local/godot and link ~/.local/bin/godot4
#   tools/install_godot_wsl.sh --prefix=DIR   install under DIR instead (binary in DIR/godot, link in DIR/bin)
#
# Needs curl and unzip. ~/.local/bin must be on PATH (it is by default on Ubuntu). Sound in the game
# window also needs the PulseAudio client library: `sudo apt install libpulse0` (WSLg provides the
# server); without it Godot uses a silent dummy audio driver, which is fine for tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED="$(sed -nE 's/^PINNED="([^"]+)"/\1/p' "$ROOT/tools/godot.sh")"
PREFIX="$HOME/.local"
for arg in "$@"; do
	case "$arg" in
		--prefix=*) PREFIX="${arg#--prefix=}" ;;
		*) echo "Unknown option '$arg'. Use --prefix=DIR." >&2; exit 1 ;;
	esac
done

NAME="Godot_v${PINNED}-stable_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${PINNED}-stable/${NAME}.zip"
DEST_DIR="$PREFIX/godot"
LINK="$PREFIX/bin/godot4"

if [[ -x "$DEST_DIR/$NAME" ]]; then
	echo "Already installed: $DEST_DIR/$NAME"
else
	for tool in curl unzip; do
		command -v "$tool" >/dev/null 2>&1 || { echo "Missing '$tool' (sudo apt install $tool)." >&2; exit 1; }
	done
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	echo "Downloading Godot $PINNED (Linux x86_64)..."
	curl -fL --progress-bar -o "$tmp/godot.zip" "$URL"
	unzip -q "$tmp/godot.zip" -d "$tmp"
	mkdir -p "$DEST_DIR"
	mv "$tmp/$NAME" "$DEST_DIR/$NAME"
	chmod +x "$DEST_DIR/$NAME"
fi

mkdir -p "$PREFIX/bin"
ln -sfn "$DEST_DIR/$NAME" "$LINK"
echo "Linked $LINK -> $DEST_DIR/$NAME"

# A remembered Windows .exe would otherwise win over PATH only if PATH has no godot4; drop it anyway
# so nothing stale is left behind.
if [[ -f "$ROOT/.godot-path" ]] && grep -q '\.exe$' "$ROOT/.godot-path"; then
	rm -f "$ROOT/.godot-path"
	echo "Removed the remembered Windows Godot path (.godot-path)."
fi

version="$("$LINK" --version 2>/dev/null | tail -n 1)"
echo "Installed: $version"
if ! command -v godot4 >/dev/null 2>&1; then
	echo "Note: $PREFIX/bin is not on PATH. Add it, or set GODOT=$LINK." >&2
fi
if ! ldconfig -p 2>/dev/null | grep -q 'libpulse\.so\.0'; then
	echo "Note: no PulseAudio client library; the game window will be silent. Fix: sudo apt install libpulse0" >&2
fi
echo "Importing project resources with the native build..."
"$ROOT/tools/godot.sh" import
echo "Done. Try: ./play.sh  or  tools/godot.sh test --suite=movement"
