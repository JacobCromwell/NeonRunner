#!/usr/bin/env bash
# Builds the web demo's engine templates (README.md here): Godot's own web templates, without threads, at the
# pinned version, with gles3_lazy_compile.patch applied, written next to this script as
# godot-<version>-web_nothreads_{release,debug}.zip, the files the "Web (demo)" preset names.
#
#   tools/web/engine_template/build.sh                 both templates (about 30 minutes on 4 CPUs)
#   tools/web/engine_template/build.sh release         only one of them (release or debug)
#
# Needs git, python3 with scons (pip install scons) and about 6 GB free. Emscripten is installed into the work
# folder (build/engine_template, git-ignored; WORK=DIR for another), so nothing is installed system-wide.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
PINNED="$(sed -nE 's/^PINNED="([^"]+)"/\1/p' "$ROOT/tools/godot.sh")"
# The Emscripten the official templates of the pinned version are built with (the engine prints it at start:
# "Build configuration: Emscripten 4.0.20"). Change it with the pinned version.
EMSDK_VERSION="4.0.20"
WORK="${WORK:-$ROOT/build/engine_template}"
TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
	TARGETS=(release debug)
fi

for tool in git python3 scons; do
	command -v "$tool" >/dev/null 2>&1 || { echo "Missing '$tool' (scons: pip install scons)." >&2; exit 1; }
done
mkdir -p "$WORK"

if [[ ! -d "$WORK/emsdk" ]]; then
	git clone -q --depth 1 https://github.com/emscripten-core/emsdk.git "$WORK/emsdk"
fi
(cd "$WORK/emsdk" && ./emsdk install "$EMSDK_VERSION" >/dev/null && ./emsdk activate "$EMSDK_VERSION" >/dev/null)
# shellcheck disable=SC1091
source "$WORK/emsdk/emsdk_env.sh" >/dev/null 2>&1

SRC="$WORK/godot-$PINNED"
if [[ ! -d "$SRC" ]]; then
	git -c advice.detachedHead=false clone -q --depth 1 --branch "$PINNED-stable" https://github.com/godotengine/godot.git "$SRC"
fi
(cd "$SRC" && git checkout -q -- . && git apply "$HERE/gles3_lazy_compile.patch")

for target in "${TARGETS[@]}"; do
	case "$target" in
		release|debug) ;;
		*) echo "Unknown target '$target'. Use release or debug." >&2; exit 1 ;;
	esac
	echo "Building the $target web template of Godot $PINNED (patched) ..."
	(cd "$SRC" && scons platform=web target="template_$target" threads=no production=yes -j"$(nproc)" >"$WORK/build_$target.log" 2>&1) \
		|| { echo "The build failed: see $WORK/build_$target.log" >&2; exit 1; }
	out="$HERE/godot-$PINNED-web_nothreads_$target.zip"
	cp "$SRC/bin/godot.web.template_$target.wasm32.nothreads.zip" "$out"
	echo "  $out ($(du -h "$out" | cut -f1))"
done
echo "Done. If the version changed, point the \"Web (demo)\" preset's custom_template/* at the new files."
