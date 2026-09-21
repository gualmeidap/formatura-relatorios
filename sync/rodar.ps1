# Roda o robô no PC: baixa a planilha do Keeper, criptografa e publica no GitHub (Pages).
# Também publica status.json (sucesso ou falha) para o app e o histórico de commits mostrarem
# quando o robô rodou pela última vez.
#
# Uso manual:   powershell -NoProfile -ExecutionPolicy Bypass -File sync\rodar.ps1
# Agendado:     ver LEIA-ME.md (Agendador de Tarefas do Windows)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$log = Join-Path $PSScriptRoot "ultimo-log.txt"
Start-Transcript -Path $log -Force | Out-Null

$resultado = "erro"; $mensagem = ""
try {
    # Carrega as variáveis do .env (KEEPER_EMAIL, KEEPER_SENHA, DATA_KEY)
    $envFile = Join-Path $root ".env"
    if (-not (Test-Path $envFile)) { throw "Arquivo .env não encontrado em $root" }
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process") }
    }

    # Chromium do Playwright e Python do ambiente virtual ficam no D:
    if (-not $env:PLAYWRIGHT_BROWSERS_PATH) { $env:PLAYWRIGHT_BROWSERS_PATH = "D:\sistemas\ms-playwright" }
    $py = Join-Path $root ".venv\Scripts\python.exe"
    if (-not (Test-Path $py)) { $py = "python" }

    Write-Host "[$(Get-Date -Format 'dd/MM/yyyy HH:mm')] Baixando planilha do Keeper..."
    $saida = & $py (Join-Path $PSScriptRoot "sync.py") 2>&1 | Tee-Object -Variable saidaPy
    $saida | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw (($saidaPy | Select-Object -Last 1) -replace '\s+', ' ') }

    $resultado = "ok"
    $mensagem = ($saidaPy | Where-Object { $_ -match '^OK:' } | Select-Object -Last 1) -replace '^OK:\s*', ''
} catch {
    $mensagem = "$_"
    Write-Host "ERRO: $mensagem"
}

# status.json: sempre publicado, para o app e o histórico mostrarem a última execução
$status = @{
    ultimaExecucao = (Get-Date).ToString("o")
    resultado      = $resultado
    mensagem       = ($mensagem -replace '[\r\n]+', ' ').Substring(0, [Math]::Min(160, $mensagem.Length))
    maquina        = $env:COMPUTERNAME
} | ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $root "status.json"), $status, (New-Object Text.UTF8Encoding $false))

try {
    Write-Host "Publicando no GitHub..."
    git pull -q --rebase origin main
    git add dados.enc status.json
    if (git status --porcelain dados.enc status.json) {
        $prefixo = if ($resultado -eq "ok") { "dados" } else { "robô falhou" }
        git commit -q -m "${prefixo}: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push -q origin main
        Write-Host "Publicado ($resultado)."
    }
} catch {
    Write-Host "ERRO ao publicar: $_"
    $resultado = "erro"
}

Stop-Transcript | Out-Null
if ($resultado -ne "ok") { exit 1 }
