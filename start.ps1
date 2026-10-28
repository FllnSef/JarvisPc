param([string]$Microphone = '')

$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Виртуальное окружение не найдено. Сначала запустите .\setup.ps1'
}

Push-Location $PSScriptRoot
try {
    if ($Microphone) {
        & $python .\run_gui.py --mic $Microphone
    } else {
        & $python .\run_gui.py
    }
} finally {
    Pop-Location
}
