@echo off
rem Play the current version of the game: double-click, or run "play.cmd --lanes=6 --god".
rem "play.cmd edit" opens the Godot editor on this project instead.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" %*
if errorlevel 1 pause
