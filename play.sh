#!/usr/bin/env bash
# Play the current version of the game: ./play.sh  (options: ./play.sh --lanes=6 --god --seed=4)
exec "$(dirname "${BASH_SOURCE[0]}")/tools/godot.sh" play "$@"
