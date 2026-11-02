$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $env:LOCALAPPDATA 'Programs\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) {
	throw "Godot 4.7.2 was not found at $godot"
}

$version = (& $godot --version).Trim()
if (-not $version.StartsWith('4.7.2.stable.')) {
	throw "Expected Godot 4.7.2 stable, found $version"
}

$buildRoot = Join-Path $projectRoot 'build'
$targets = @(
	@{ Preset = 'Windows Desktop'; RelativePath = 'windows\TikhayaTropa.exe'; Package = 'TikhayaTropa-Windows-x86_64.zip' },
	@{ Preset = 'Linux'; RelativePath = 'linux\TikhayaTropa.x86_64'; Package = 'TikhayaTropa-Linux-x86_64.zip' }
)

foreach ($target in $targets) {
	$outputPath = Join-Path $buildRoot $target.RelativePath
	$outputDirectory = Split-Path -Parent $outputPath
	New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
	Write-Host "Exporting $($target.Preset) with Godot $version..."
	& $godot --headless --path $projectRoot --export-release $target.Preset $outputPath
	if ($LASTEXITCODE -ne 0) {
		throw "Godot export failed for preset '$($target.Preset)' with exit code $LASTEXITCODE. Install matching 4.7.2 export templates and retry."
	}
	if (-not (Test-Path -LiteralPath $outputPath)) {
		throw "Godot reported success but did not create $outputPath"
	}
	$packagePath = Join-Path $buildRoot $target.Package
	Compress-Archive -LiteralPath @($outputPath, (Join-Path $projectRoot 'README.md'), (Join-Path $projectRoot 'LICENSE'), (Join-Path $projectRoot 'CREDITS.md')) -DestinationPath $packagePath -Force
	Write-Host "Created $packagePath"
}

Write-Host 'Both release packages are ready in the build directory.'
