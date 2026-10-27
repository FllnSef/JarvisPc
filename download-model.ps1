$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$models = Join-Path $root 'models'
$archive = Join-Path $models 'vosk-model-small-ru-0.22.zip'
$target = Join-Path $models 'vosk-model-small-ru-0.22'
$url = 'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip'

if (Test-Path -LiteralPath $target) {
    Write-Host 'Модель уже установлена.' -ForegroundColor Green
    exit 0
}

Write-Host 'Скачивание русской модели Vosk (около 45 МБ)...' -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $models -Force
Remove-Item -LiteralPath $archive
Write-Host "Модель установлена: $target" -ForegroundColor Green
