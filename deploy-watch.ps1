param(
    [string[]]$WatchNamePatterns = @(
        "EPIX PRO - 51mm"
    )
)

$ErrorActionPreference = "Stop"

$sourceFile = Join-Path $PSScriptRoot "build.prg"

if (-not (Test-Path -LiteralPath $sourceFile)) {
    throw "Missing build output: $sourceFile - run build-win.bat first."
}

$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)

if (-not $computer) {
    throw "Failed to access This PC shell namespace."
}

$watch = $null
foreach ($pattern in $WatchNamePatterns) {
    $match = $computer.Items() | Where-Object { $_.Name -like "*$pattern*" } | Select-Object -First 1
    if ($match) {
        $watch = $match
        break
    }
}

if (-not $watch) {
    $patterns = $WatchNamePatterns -join ", "
    throw "No watch found matching: $patterns. Connect your Epix 2 Pro via USB and wait for Internal Storage to appear."
}

$internal = $watch.GetFolder.Items() | Where-Object { $_.Name -eq "Internal Storage" } | Select-Object -First 1
if (-not $internal) {
    throw "Internal Storage not found on '$($watch.Name)'."
}

$garmin = $internal.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
if (-not $garmin) {
    throw "GARMIN folder not found on '$($watch.Name)'."
}

$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq "APPS" } | Select-Object -First 1
if (-not $apps) {
    throw "GARMIN\APPS folder not found on '$($watch.Name)'."
}

$appsFolder = $apps.GetFolder
Write-Host "Copying to $($watch.Name)\Internal Storage\GARMIN\APPS ..."
$appsFolder.CopyHere($sourceFile, 16)

$deadline = (Get-Date).AddSeconds(20)
do {
    Start-Sleep -Milliseconds 500
    $copied = $appsFolder.Items() | Where-Object { $_.Name -eq "build.prg" } | Select-Object -First 1
} until ($copied -or (Get-Date) -ge $deadline)

if (-not $copied) {
    throw "Copy did not complete within 20 seconds."
}

Write-Host "Done! On your Epix 2 Pro: Hold UP, Watch Face, Add New" -ForegroundColor Green
