param([string]$Microphone = '')

$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Виртуальное окружение не найдено. Сначала запустите .\setup.ps1'
}

Push-Location $PSScriptRoot
try {
    Write-Host 'Доступные микрофоны:' -ForegroundColor Cyan
    & $python .\run.py --list-mics
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host ''
    Write-Host 'Скажите одну команду после фразы «Слушаю».' -ForegroundColor Cyan
    if ($Microphone) {
        & $python .\run.py --listen-once --mic $Microphone
    } else {
        & $python .\run.py --listen-once
    }
} finally {
    Pop-Location
}
