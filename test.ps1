$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Виртуальное окружение не найдено. Сначала запустите .\setup.ps1'
}

Push-Location $PSScriptRoot
try {
    & $python -m unittest discover -s tests -v
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host ''
    Write-Host 'Проверка путей приложений:' -ForegroundColor Cyan
    & $python .\run.py --check
    Write-Host ''
    Write-Host 'Проверка игрового режима без запуска приложений:' -ForegroundColor Cyan
    & $python .\run.py --command 'Джарвис, включи игровой режим' --dry-run --silent
} finally {
    Pop-Location
}
