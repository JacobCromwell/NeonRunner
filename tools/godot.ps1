# Windows counterpart of tools/godot.sh (used by play.cmd): runs this project with the pinned
# Godot, without the project manager or a manual import.
#   godot.ps1 play [game args]   start the game (e.g. play --lanes=6 --god)
#   godot.ps1 edit               open the Godot editor on this project
#   godot.ps1 where              show which Godot and project folder would be used
# Godot is found via $env:GODOT, then godot4/godot on PATH, then the usual user folders.
# The path found is remembered in .godot-path-windows (git-ignored).
# No param block on purpose: game arguments such as --lanes=6 must reach Godot untouched.
$ErrorActionPreference = "Stop"
$Command = "play"
$GameArgs = @($args)
if ($GameArgs.Count -gt 0 -and $GameArgs[0] -in @("play", "edit", "where")) {
	$Command = $GameArgs[0]
	$GameArgs = @($GameArgs | Select-Object -Skip 1)
}
$Pinned = "4.7.2"
$Root = Split-Path -Parent $PSScriptRoot
$PathCache = Join-Path $Root ".godot-path-windows"
$Stamp = Join-Path $Root ".godot\.import-stamp"

function Find-Godot([string]$Pattern) {
	$dirs = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents",
		"$env:USERPROFILE\Apps", "C:\Tools", "C:\Program Files", "C:\Godot")
	foreach ($dir in $dirs) {
		if (-not (Test-Path $dir)) { continue }
		$hit = Get-ChildItem -Path $dir -Filter $Pattern -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($hit) { return $hit.FullName }
	}
	return $null
}

function Get-Godot {
	if ($env:GODOT) { return $env:GODOT }
	if (Test-Path $PathCache) {
		$cached = (Get-Content $PathCache -Raw).Trim()
		if (Test-Path $cached) { return $cached }
	}
	foreach ($name in @("godot4", "godot")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { Set-Content $PathCache $cmd.Source; return $cmd.Source }
	}
	# The windowed build is preferred for play: no extra console window.
	$found = Find-Godot "Godot_v$Pinned-stable_win64.exe"
	if (-not $found) { $found = Find-Godot "Godot_v$Pinned-stable_win64_console.exe" }
	if (-not $found) { throw "Could not find Godot $Pinned. Set the GODOT environment variable to its .exe and retry." }
	Set-Content $PathCache $found
	return $found
}

# The console build next to the windowed one, for headless work whose output we want to see.
function Get-ConsoleBuild([string]$Godot) {
	$console = $Godot -replace '\.exe$', '_console.exe'
	if (($console -ne $Godot) -and (Test-Path $console)) { return $console }
	return $Godot
}

function Import-IfStale([string]$Godot) {
	$stale = -not (Test-Path $Stamp)
	if (-not $stale) {
		$since = (Get-Item $Stamp).LastWriteTime
		$changed = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
			Where-Object { $_.FullName -notmatch '[\\/](\.godot|\.git|build)[\\/]' -and $_.LastWriteTime -gt $since } |
			Select-Object -First 1
		$stale = [bool]$changed
	}
	if ($stale) {
		Write-Host "Importing project resources..."
		$log = & (Get-ConsoleBuild $Godot) --headless --path $Root --import 2>&1 | Out-String
		$log -split "`n" | Where-Object { $_ -match 'ERROR|Parse Error' } | ForEach-Object { Write-Host $_ }
		New-Item -ItemType Directory -Force -Path (Join-Path $Root ".godot") | Out-Null
		New-Item -ItemType File -Force -Path $Stamp | Out-Null
	}
}

$godot = Get-Godot
switch ($Command) {
	"where" {
		Write-Host "Godot:   $godot"
		Write-Host "Project: $Root"
		Write-Host "Game arguments: $($GameArgs -join ' ')"
	}
	"play" {
		Import-IfStale $godot
		$argList = @("--path", "`"$Root`"", "--") + $GameArgs
		Start-Process -FilePath $godot -ArgumentList $argList
	}
	"edit" {
		Start-Process -FilePath $godot -ArgumentList @("--editor", "--path", "`"$Root`"")
	}
	default { throw "Unknown command '$Command'. Use play, edit or where." }
}
