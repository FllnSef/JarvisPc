param([string]$PythonPath = '')

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $PythonPath) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        $PythonPath = $pythonCommand.Source
    } else {
        $pyCommand = Get-Command py -ErrorAction SilentlyContinue
        if ($pyCommand) { $PythonPath = $pyCommand.Source }
    }
}

if (-not $PythonPath) {
    throw 'Python не найден в PATH. Запустите: .\setup.ps1 -PythonPath "C:\путь\к\python.exe"'
}

Write-Host "Используется Python: $PythonPath" -ForegroundColor Cyan
if ((Split-Path $PythonPath -Leaf) -ieq 'py.exe') {
    & $PythonPath -3 -m venv (Join-Path $root '.venv')
} else {
    & $PythonPath -m venv (Join-Path $root '.venv')
}

$venvPython = Join-Path $root '.venv\Scripts\python.exe'
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r (Join-Path $root 'requirements.txt')
Write-Host 'Окружение готово.' -ForegroundColor Green
Write-Host 'Теперь запустите .\test.ps1, затем .\start.ps1' -ForegroundColor Green
