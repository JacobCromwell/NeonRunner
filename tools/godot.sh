#!/usr/bin/env bash
# Runs this project with the pinned Godot, without the project manager or a manual import.
#
#   tools/godot.sh play [game args]   play the current working tree (e.g. play --lanes=6 --god)
#   tools/godot.sh edit               open the Godot editor on this project
#   tools/godot.sh test [--suite=x]   run the headless tests (exit code 0 = pass); --suite=x runs only
#                                     the suites whose file name contains x
#   tools/godot.sh smoke [game args]  40 s headless quick play; prints only problems (exit code 1 if any)
#   tools/godot.sh sfx [--review]     regenerate assets/sfx/*.wav from tools/asset_gen/sfx_gen.gd
#   tools/godot.sh music [--review]   regenerate assets/music/*.wav from tools/asset_gen/music_gen.gd
#                                     (--review writes images to build/sfx_review/, build/music_review/)
#   tools/godot.sh web [--debug] [--serve]  export the web demo to exports/web/ (--debug: a debug build to
#                                     exports/web_debug/) and check its pack; --serve then serves it at
#                                     http://localhost:8060 (needs python3 and the web export templates)
#   tools/godot.sh import             force a resource import
#
# Godot is found via $GODOT, then godot4/godot on PATH, then (under WSL) the Windows user
# folders. The path found is remembered in .godot-path (git-ignored). Resources are re-imported
# automatically whenever a project file changed since the last import.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED="4.7.2"
PATH_CACHE="$ROOT/.godot-path"
STAMP="$ROOT/.godot/.import-stamp"

find_godot() {
	if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
	if [[ -f "$PATH_CACHE" ]]; then
		local cached; cached="$(cat "$PATH_CACHE")"
		if [[ -x "$cached" || -f "$cached" ]]; then echo "$cached"; return; fi
	fi
	local found=""
	for name in godot4 godot; do
		if command -v "$name" >/dev/null 2>&1; then found="$(command -v "$name")"; break; fi
	done
	if [[ -z "$found" && -d /mnt/c/Users ]]; then
		# WSL: look for the Windows build in the usual places. Prefer the console build so
		# logs and errors show up in this terminal.
		local dirs=(/mnt/c/Users/*/Downloads /mnt/c/Users/*/Desktop /mnt/c/Users/*/Documents
			/mnt/c/Users/*/Apps /mnt/c/Tools "/mnt/c/Program Files" /mnt/c/Godot)
		for pattern in "Godot_v${PINNED}-stable_win64_console.exe" "Godot_v${PINNED}-stable_win64.exe"; do
			for dir in "${dirs[@]}"; do
				[[ -d "$dir" ]] || continue
				found="$(find "$dir" -maxdepth 3 -type f -name "$pattern" 2>/dev/null | head -n 1)"
				[[ -n "$found" ]] && break 2
			done
		done
	fi
	if [[ -z "$found" ]]; then
		echo "Could not find Godot ${PINNED}. Set GODOT=/path/to/godot (or the Windows .exe) and retry." >&2
		exit 1
	fi
	echo "$found" > "$PATH_CACHE"
	echo "$found"
}

GODOT_BIN="$(find_godot)"

# A Windows build needs Windows paths.
PROJECT="$ROOT"
if [[ "$GODOT_BIN" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
	PROJECT="$(wslpath -w "$ROOT")"
fi

check_version() {
	local version
	version="$("$GODOT_BIN" --version 2>/dev/null | tr -d '\r' | tail -n 1)"
	if [[ "$version" != "$PINNED".* ]]; then
		echo "Warning: this project is pinned to Godot $PINNED, but $GODOT_BIN is '$version'." >&2
	fi
}

# Import when a project file is newer than the last import (or there was none).
import_if_stale() {
	local changed=""
	if [[ -f "$STAMP" ]]; then
		changed="$(find "$ROOT" \( -path "$ROOT/.godot" -o -path "$ROOT/.git" -o -path "$ROOT/build" \) -prune \
			-o -type f -newer "$STAMP" -print -quit)"
	fi
	if [[ ! -f "$STAMP" || -n "$changed" ]]; then
		run_import
	fi
}

run_import() {
	# build/ holds rendered frames and review images; keep Godot from importing them.
	mkdir -p "$ROOT/build" && touch "$ROOT/build/.gdignore"
	echo "Importing project resources..." >&2
	local log
	log="$("$GODOT_BIN" --headless --path "$PROJECT" --import 2>&1 | tr -d '\r')" || true
	# Show only real problems, not the progress lines.
	grep -E "ERROR|SCRIPT ERROR|Parse Error" <<<"$log" >&2 || true
	mkdir -p "$ROOT/.godot"
	touch "$STAMP"
}

# Filters Godot's banner and import progress from command output.
quiet() {
	tr -d '\r' | grep -vE '^Godot Engine v|^\s*$|^\[ *[0-9]+% \]|^\[ DONE \]' || true
}

command="${1:-play}"
[[ $# -gt 0 ]] && shift

case "$command" in
	play)
		check_version
		import_if_stale
		exec "$GODOT_BIN" --path "$PROJECT" -- "$@"
		;;
	edit)
		check_version
		exec "$GODOT_BIN" --editor --path "$PROJECT"
		;;
	test)
		import_if_stale
		set +e
		"$GODOT_BIN" --headless --path "$PROJECT" --fixed-fps 60 -s res://tests/run_tests.gd -- "$@" 2>&1 | quiet
		status=${PIPESTATUS[0]}
		exit "$status"
		;;
	smoke)
		import_if_stale
		# Quick play (the prototype level, restarting on death) unless other game args are given.
		[[ $# -eq 0 ]] && set -- --quick
		out="$("$GODOT_BIN" --headless --path "$PROJECT" --fixed-fps 60 --quit-after 2400 -- "$@" 2>&1 | quiet)"
		if [[ -n "$out" ]]; then echo "$out"; exit 1; fi
		echo "Smoke run clean."
		;;
	sfx)
		import_if_stale
		"$GODOT_BIN" --headless --path "$PROJECT" -s res://tools/asset_gen/sfx_gen.gd -- "$@" 2>&1 | quiet
		run_import
		;;
	music)
		import_if_stale
		"$GODOT_BIN" --headless --path "$PROJECT" -s res://tools/asset_gen/music_gen.gd -- "$@" 2>&1 | quiet
		run_import
		;;
	web)
		import_if_stale
		mode="release"
		out="$ROOT/exports/web"
		serve=""
		for arg in "$@"; do
			case "$arg" in
				--debug) mode="debug"; out="$ROOT/exports/web_debug" ;;
				--serve) serve=1 ;;
			esac
		done
		# The export filter comes from the data (the tracks and riffs the demo never plays).
		"$GODOT_BIN" --headless --path "$PROJECT" -s res://tools/web/update_filter.gd 2>&1 | quiet
		mkdir -p "$out"
		rm -f "$out"/index.*
		target="$out/index.html"
		script="$ROOT/tools/web/check_pack.gd"
		if [[ "$GODOT_BIN" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
			target="$(wslpath -w "$target")"
			script="$(wslpath -w "$script")"
		fi
		echo "Exporting the web demo ($mode) to $out ..."
		# (The export's progress lines are coloured: strip the colours, then the progress.)
		"$GODOT_BIN" --headless --path "$PROJECT" "--export-$mode" "Web (demo)" "$target" 2>&1 \
			| sed -E 's/\x1b\[[0-9;]*m//g' | quiet | grep -vE 'first_scan_filesystem|savepack|^\[ *[0-9]+% \]' || true
		if [[ ! -f "$out/index.pck" ]]; then
			echo "The export failed. Are the web export templates for Godot $PINNED installed? (README.md, Web demo)" >&2
			exit 1
		fi
		# The pack, run from its own folder so res:// is the pack alone (not this project's files).
		set +e
		(cd "$out" && "$GODOT_BIN" --headless --main-pack index.pck --fixed-fps 60 -s "$script" 2>&1 | quiet)
		status=$?
		set -e
		echo "Files (bytes; gzip -9 as a web server would send them):"
		for f in "$out"/index.*; do
			printf '  %-32s %10d %10d\n' "$(basename "$f")" "$(wc -c <"$f")" "$(gzip -9 -c "$f" | wc -c)"
		done
		[[ $status -ne 0 ]] && exit "$status"
		if [[ -n "$serve" ]]; then
			echo "Serving $out at http://localhost:8060 (Ctrl+C stops it)"
			exec python3 -m http.server 8060 --bind 127.0.0.1 --directory "$out"
		fi
		;;
	import)
		run_import
		;;
	*)
		sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
		exit 2
		;;
esac
