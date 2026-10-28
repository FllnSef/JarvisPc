param([string]$Microphone = '')

$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Виртуальное окружение не найдено. Сначала запустите .\setup.ps1'
}

Push-Location $PSScriptRoot
try {
    if ($Microphone) {
        & $python .\run.py --mic $Microphone
    } else {
        & $python .\run.py
    }
} finally {
    Pop-Location
}
