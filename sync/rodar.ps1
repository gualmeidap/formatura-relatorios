# Roda o robô no PC: baixa a planilha do Keeper, criptografa e publica no GitHub (Pages).
# Uso manual:   powershell -NoProfile -ExecutionPolicy Bypass -File sync\rodar.ps1
# Agendado:     ver LEIA-ME.md (Agendador de Tarefas do Windows)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$log = Join-Path $PSScriptRoot "ultimo-log.txt"
Start-Transcript -Path $log -Force | Out-Null

try {
    # Carrega as variáveis do .env (KEEPER_EMAIL, KEEPER_SENHA, DATA_KEY)
    $envFile = Join-Path $root ".env"
    if (-not (Test-Path $envFile)) { throw "Arquivo .env não encontrado em $root" }
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process") }
    }

    Write-Host "[$(Get-Date -Format 'dd/MM/yyyy HH:mm')] Baixando planilha do Keeper..."
    python (Join-Path $PSScriptRoot "sync.py")
    if ($LASTEXITCODE -ne 0) { throw "sync.py falhou (código $LASTEXITCODE)" }

    Write-Host "Publicando no GitHub..."
    git pull -q --rebase origin main
    git add dados.enc
    $mudou = git status --porcelain dados.enc
    if ($mudou) {
        git commit -q -m "dados: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push -q origin main
        Write-Host "OK: dados.enc publicado."
    } else {
        Write-Host "Sem mudanças no dados.enc."
    }
} catch {
    Write-Host "ERRO: $_"
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
