#!/usr/bin/env bash
# Runs this project with the pinned Godot, without the project manager or a manual import.
#
#   tools/godot.sh play [game args]   play the current working tree (e.g. play --lanes=6 --god)
#   tools/godot.sh edit               open the Godot editor on this project
#   tools/godot.sh test --gate [--jobs=N] [--plan]   the gate tier: what an agent runs before reporting a
#                                     task done. The smoke run, then the fast suites plus the suites that
#                                     cover the files changed on this branch (tests/suite_map.json,
#                                     tools/test_plan.py); a changed core file raises it to the full tier.
#                                     --plan only prints what would run; --paths=a,b plans for those files
#                                     instead of the branch's changes; --base=REF diffs against REF
#                                     (default: the merge base with main). Jobs default to half the CPUs
#                                     (at most 3).
#   tools/godot.sh test --tier=merge  before a branch merges: everything but the slow sweeps and fight
#                                     simulations, plus the suites for the changed files
#   tools/godot.sh test --tier=full   every suite (the same as plain `test --jobs=N`)
#   tools/godot.sh test [--suite=x] [--jobs=N]   run the headless tests (exit code 0 = pass); --suite=x
#                                     runs only the suites whose file name contains x. --jobs=N (default 1,
#                                     unchanged behaviour) splits the suites across N Godot processes,
#                                     balanced by each suite's last measured time: use it on a machine with
#                                     CPUs to spare, since the suites are not otherwise run in parallel
#   tools/godot.sh smoke [game args]  40 s headless quick play (or the --level=/--boss= run, past its intro);
#                                     prints only problems (exit code 1 if any)
#   tools/godot.sh sfx [--review]     regenerate assets/sfx/*.wav from tools/asset_gen/sfx_gen.gd
#   tools/godot.sh music [--review]   regenerate assets/music/*.wav from tools/asset_gen/music_gen.gd
#                                     (--review writes images to build/sfx_review/, build/music_review/)
#   tools/godot.sh citizens           regenerate assets/sprites/citizens/*.png (the Marketplace
#                                     citizens' flipbooks) from tools/asset_gen/citizen_sheet_gen.gd
#   tools/godot.sh web [--debug] [--serve]  export the web demo to exports/web/ (--debug: a debug build to
#                                     exports/web_debug/) and check its pack; --serve then serves it at
#                                     http://localhost:8060 (needs python3 and the web export templates)
#   tools/godot.sh import             force a resource import
#
# Godot is found via $GODOT, then godot4/godot on PATH (the native Linux build: under WSL, install
# it with tools/install_godot_wsl.sh), then the path remembered in .godot-path (git-ignored), then
# (under WSL) the Windows user folders. A native build is always preferred: a Windows .exe reading
# the project over \\wsl.localhost is ~15x slower to start (docs/PERFORMANCE_AUDIT.md). Resources
# are re-imported automatically whenever a project file changed since the last import.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED="4.7.2"
PATH_CACHE="$ROOT/.godot-path"
STAMP="$ROOT/.godot/.import-stamp"

find_godot() {
	if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
	local found=""
	for name in godot4 godot; do
		if command -v "$name" >/dev/null 2>&1; then found="$(command -v "$name")"; break; fi
	done
	if [[ -z "$found" && -f "$PATH_CACHE" ]]; then
		local cached; cached="$(cat "$PATH_CACHE")"
		if [[ -x "$cached" || -f "$cached" ]]; then echo "$cached"; return; fi
	fi
	if [[ -z "$found" && -d /mnt/c/Users ]]; then
		# WSL: fall back to the Windows build in the usual places. Prefer the console build so
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
	# Only rewrite the cache when it changes: a rewrite would make import_if_stale re-import every run.
	if [[ ! -f "$PATH_CACHE" || "$(cat "$PATH_CACHE")" != "$found" ]]; then
		echo "$found" > "$PATH_CACHE"
	fi
	echo "$found"
}

GODOT_BIN="$(find_godot)"

# A Windows build needs Windows paths.
PROJECT="$ROOT"
if [[ "$GODOT_BIN" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
	PROJECT="$(wslpath -w "$ROOT")"
fi

# A native Linux build in a WSLg window: Ubuntu's Mesa has no Vulkan driver for WSL's virtual GPU,
# so Forward+ falls back to software rendering (llvmpipe). OpenGL does reach the real GPU through
# Mesa's D3D12 driver when asked for, so windowed commands (play, edit) use the Compatibility
# renderer on it. The project's own renderer setting is untouched (exports keep Forward+/Mobile);
# pass --rendering-method or --rendering-driver yourself to override. Note that opening the editor
# (any platform) rewrites project.godot in Godot's normalized form: it drops keys at their default
# value and replaces the header comment. The effective settings are identical; `git checkout
# project.godot` if you don't want that diff.
WINDOW_ARGS=()
if [[ "$GODOT_BIN" != *.exe && -n "${WSL_DISTRO_NAME:-}${WSL_INTEROP:-}" ]]; then
	if [[ -e /dev/dxg ]]; then
		export GALLIUM_DRIVER="${GALLIUM_DRIVER:-d3d12}"
	fi
	WINDOW_ARGS=(--rendering-method gl_compatibility)
fi

# Strips --rendering-* from "$@" into ENGINE_ARGS (they belong before `--`), leaving game args in GAME_ARGS.
split_engine_args() {
	ENGINE_ARGS=()
	GAME_ARGS=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--rendering-method|--rendering-driver|--display-driver)
				ENGINE_ARGS+=("$1" "${2:-}"); WINDOW_ARGS=(); shift 2 ;;
			--rendering-method=*|--rendering-driver=*|--display-driver=*)
				ENGINE_ARGS+=("$1"); WINDOW_ARGS=(); shift ;;
			*) GAME_ARGS+=("$1"); shift ;;
		esac
	done
}

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

# T-SPEED: `tools/godot.sh test --jobs=N [--suite=x]` runs the matching suites across N separate
# Godot processes, balanced by each suite's last measured time (tests/.suite_times.json, refreshed by
# every run of tests/run_tests.gd; a suite with no measurement yet is weighted as 1 s). Each process
# gets its own XDG_DATA_HOME (so its own user:// folder: saves and the test profile never collide
# between processes) and runs its own balanced slice (run_tests.gd's --files=, an exact file list, not
# --suite=x's substring match). Exit code is 0 only if every process passed; a failing suite's "FAIL:"
# lines are gathered at the end so they stay visible among several processes' interleaved output.
run_tests_parallel() {
	local jobs="$1"
	shift
	local suite_filter=""
	for arg in "$@"; do
		case "$arg" in
			--suite=*) suite_filter="${arg#--suite=}" ;;
		esac
	done
	local suites=()
	if [[ ${#PLAN_SUITES[@]} -gt 0 ]]; then
		suites=("${PLAN_SUITES[@]}")
	else
		while IFS= read -r f; do
			[[ -z "$suite_filter" || "$f" == *"$suite_filter"* ]] && suites+=("$f")
		done < <(cd "$ROOT/tests/suites" && ls test_*.gd 2>/dev/null | sort)
	fi
	if [[ ${#suites[@]} -eq 0 ]]; then
		echo "No test suites matched '$suite_filter'." >&2
		exit 1
	fi
	local times_file="$ROOT/tests/.suite_times.json"
	local groups=()
	mapfile -t groups < <(python3 - "$jobs" "$times_file" "${suites[@]}" <<'PYEOF'
import json, sys
jobs = int(sys.argv[1])
times = {}
try:
	times = json.load(open(sys.argv[2]))
except Exception:
	pass
suites = sys.argv[3:]
default = 1.0
order = sorted(suites, key=lambda s: -float(times.get(s, default)))
bins = [[] for _ in range(jobs)]
loads = [0.0] * jobs
for s in order:
	i = min(range(jobs), key=lambda k: loads[k])
	bins[i].append(s)
	loads[i] += float(times.get(s, default))
for b in bins:
	print(",".join(b))
PYEOF
	)
	mkdir -p "$ROOT/build"
	local tmp_dir; tmp_dir="$(mktemp -d "$ROOT/build/test_jobs.XXXXXX")"
	local pids=() outs=() n=0
	local started; started="$(date +%s)"
	for group in "${groups[@]}"; do
		[[ -z "$group" ]] && continue
		local out="$tmp_dir/job$n.log"
		outs+=("$out")
		(
			export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/godot_test_jobs/job$n"
			mkdir -p "$XDG_DATA_HOME"
			"$GODOT_BIN" --headless --path "$PROJECT" --fixed-fps 60 -s res://tests/run_tests.gd -- "--files=$group" \
				>"$out" 2>&1
			echo $? >"$out.status"
		) &
		pids+=("$!")
		n=$((n + 1))
	done
	local pid
	for pid in "${pids[@]}"; do
		wait "$pid" || true  # its own exit status is read from out.status below; set -e must not abort here
	done
	local ended; ended="$(date +%s)"
	local total_suites=0 total_checks=0 overall=0
	local fail_lines=()
	local out
	for out in "${outs[@]}"; do
		quiet <"$out"
		local st; st="$(cat "$out.status" 2>/dev/null || echo 1)"
		[[ "$st" != "0" ]] && overall=1
		local line; line="$(grep -E '^ALL TESTS PASSED' "$out" | tail -1 || true)"
		if [[ -n "$line" ]]; then
			local s c
			s="$(sed -E 's/.*\(([0-9]+) suites.*/\1/' <<<"$line")"
			c="$(sed -E 's/.*, ([0-9]+) checks.*/\1/' <<<"$line")"
			total_suites=$((total_suites + s))
			total_checks=$((total_checks + c))
		fi
		while IFS= read -r fl; do
			fail_lines+=("$fl")
		done < <(grep '^FAIL: ' "$out")
	done
	echo ""
	if [[ $overall -eq 0 ]]; then
		echo "ALL TESTS PASSED (${#suites[@]} suites, $total_checks checks, $((ended - started)) s wall, $n jobs)"
	else
		local fl
		for fl in "${fail_lines[@]}"; do
			echo "$fl"
		done
		echo "FAILED across $n jobs (${#fail_lines[@]} failing check line(s) above; see the suite(s) named)"
	fi
	rm -rf "$tmp_dir"
	exit "$overall"
}

command="${1:-play}"
[[ $# -gt 0 ]] && shift

case "$command" in
	play)
		check_version
		import_if_stale
		split_engine_args "$@"
		exec "$GODOT_BIN" --path "$PROJECT" "${WINDOW_ARGS[@]}" "${ENGINE_ARGS[@]}" -- "${GAME_ARGS[@]}"
		;;
	edit)
		check_version
		split_engine_args "$@"
		exec "$GODOT_BIN" --editor --path "$PROJECT" "${WINDOW_ARGS[@]}" "${ENGINE_ARGS[@]}"
		;;
	test)
		import_if_stale
		jobs=""
		tier=""
		plan_only=""
		plan_args=()
		rest=()
		for arg in "$@"; do
			case "$arg" in
				--jobs=*) jobs="${arg#--jobs=}" ;;
				--gate) tier="gate" ;;
				--tier=*) tier="${arg#--tier=}" ;;
				--base=*|--paths=*) plan_args+=("$arg") ;;
				--plan) plan_only=1 ;;
				*) rest+=("$arg") ;;
			esac
		done
		PLAN_SUITES=()
		if [[ -n "$tier" ]]; then
			# A tier run (docs/PERFORMANCE_AUDIT.md, 3.2): tools/test_plan.py picks the suites from
			# tests/suite_map.json and the files changed on this branch, raising the tier when a core file
			# changed. gate and merge start with the smoke run; `--plan` only prints what would run.
			plan_out="$(python3 "$ROOT/tools/test_plan.py" "--tier=$tier" "--root=$ROOT" "${plan_args[@]}")" || exit 2
			effective="${plan_out##*TIER }"
			while IFS= read -r f; do
				[[ "$f" == test_*.gd ]] && PLAN_SUITES+=("$f")
			done <<<"$plan_out"
			if [[ -z "$jobs" ]]; then
				jobs=$(( $(nproc 2>/dev/null || echo 2) / 2 ))
				(( jobs > 3 )) && jobs=3
				(( jobs < 1 )) && jobs=1
			fi
			echo "Test tier: $effective (${#PLAN_SUITES[@]} of $(ls "$ROOT"/tests/suites/test_*.gd | wc -l) suites, $jobs job(s))"
			if [[ -n "$plan_only" ]]; then
				printf '  %s\n' "${PLAN_SUITES[@]}"
				exit 0
			fi
			if [[ "$effective" != "full" ]]; then
				echo "Smoke run first..."
				if ! "$0" smoke; then
					echo "The smoke run failed: fix that before the suites." >&2
					exit 1
				fi
			fi
			run_tests_parallel "$jobs" "${rest[@]}"
		fi
		[[ -z "$jobs" ]] && jobs=1
		if [[ "$jobs" -le 1 ]]; then
			set +e
			"$GODOT_BIN" --headless --path "$PROJECT" --fixed-fps 60 -s res://tests/run_tests.gd -- "${rest[@]}" 2>&1 | quiet
			status=${PIPESTATUS[0]}
			exit "$status"
		fi
		run_tests_parallel "$jobs" "${rest[@]}"
		;;
	smoke)
		import_if_stale
		# Quick play (the prototype level, restarting on death) unless other game args are given.
		[[ $# -eq 0 ]] && set -- --quick
		# A campaign level or boss waits at its level introduction until PLAY is pressed: those run through
		# tools/smoke/smoke_play.gd, which presses it (App.begin_run) and reports a run that never started.
		driver=()
		for arg in "$@"; do
			case "$arg" in --level=*|--boss=*) driver=(-s res://tools/smoke/smoke_play.gd) ;; esac
		done
		frames=2400
		[[ ${#driver[@]} -gt 0 ]] && frames=2500   # the driver stops itself at 2400 and reports first
		out="$("$GODOT_BIN" --headless --path "$PROJECT" --fixed-fps 60 --quit-after "$frames" ${driver[@]+"${driver[@]}"} -- "$@" 2>&1 | quiet)" || true
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
	citizens)
		# Renders real 3D frames (the Marketplace citizens' flipbooks, task D3), so --headless won't
		# do: use Xvfb when there's no real display.
		import_if_stale
		if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
			xvfb-run -a -s "-screen 0 320x240x24" "$GODOT_BIN" --path "$PROJECT" --rendering-method gl_compatibility \
				-s res://tools/asset_gen/citizen_sheet_gen.gd -- "$@" 2>&1 | quiet
		else
			"$GODOT_BIN" --path "$PROJECT" --rendering-method gl_compatibility \
				-s res://tools/asset_gen/citizen_sheet_gen.gd -- "$@" 2>&1 | quiet
		fi
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
