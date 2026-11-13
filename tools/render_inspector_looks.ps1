# Photographs the Inspector looks in a REAL editor without touching the developer's own settings.
#
# The editor reads and writes its settings under %APPDATA%\Godot. This wrapper points APPDATA at a
# separate folder for the child process only, seeds that folder with the theme and scale of the
# variant asked for, and runs tools/render_inspector_looks.gd, which refuses to run unless the
# editor reports its config folder under that path.
#
#   $env:GODOT = "<path to the _console binary>"
#   powershell -File tools/render_inspector_looks.ps1 -Variant dark|light|scaled -Out <folder> [-Only a,b]
param(
	[ValidateSet("dark", "light", "scaled")][string]$Variant = "dark",
	[Parameter(Mandatory = $true)][string]$Out,
	[string]$Only = "",
	[int]$Width = 0,
	[string]$Sandbox = (Join-Path ([System.IO.Path]::GetTempPath()) "eventforge_look_photos")
)

$ErrorActionPreference = "Stop"
if (-not $env:GODOT) { throw "Set `$env:GODOT to the Godot console binary first." }
$config = Join-Path $Sandbox $Variant
New-Item -ItemType Directory -Force -Path (Join-Path $config "Godot") | Out-Null
$lines = @('[gd_resource type="EditorSettings" format=3]', '', '[resource]')
if ($Variant -eq "light") { $lines += 'interface/theme/color_preset = "Light"' }
if ($Variant -eq "scaled") {
	$lines += 'interface/editor/appearance/display_scale = 7'
	$lines += 'interface/editor/appearance/custom_display_scale = 1.5'
}
Set-Content -Path (Join-Path $config "Godot\editor_settings-4.7.tres") -Value $lines -Encoding utf8

$realAppData = $env:APPDATA
$env:APPDATA = $config
try {
	$extra = @("out=$Out", "tag=$Variant", "config=$config")
	if ($env:LOOK_DEBUG) { $extra += "debug=1" }
	if ($Only) { $extra += "only=$Only" }
	if ($Width -gt 0) { $extra += "width=$Width" }
	& $env:GODOT --editor --path . --script tools/render_inspector_looks.gd -- @extra
}
finally {
	$env:APPDATA = $realAppData
}
