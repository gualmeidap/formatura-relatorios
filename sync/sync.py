"""
Robô de sincronização: entra no Keeper, baixa a planilha "Vendas Parcelas Detalhado"
(Fluxo de Recebimento) e grava `dados.enc` criptografado (AES-256-GCM) para o app ler.

Variáveis de ambiente (nunca coloque no código):
  KEEPER_EMAIL  - e-mail de login (ou CPF) da conta no Keeper
  KEEPER_SENHA  - senha da conta
  DATA_KEY      - senha que o app vai pedir para abrir os dados (defina uma frase forte)
  OUT           - (opcional) caminho de saída, padrão: dados.enc na pasta do repositório

Uso local (para testar):
  pip install -r sync/requirements.txt
  playwright install chromium
  set KEEPER_EMAIL=... & set KEEPER_SENHA=... & set DATA_KEY=...   (PowerShell: $env:KEEPER_EMAIL="...")
  python sync/sync.py
"""
import base64
import os
import sys
import time
from pathlib import Path

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from playwright.sync_api import TimeoutError as PWTimeout
from playwright.sync_api import sync_playwright

SITE = "https://conta.keeperformaturas.com.br/"
REPORT = "https://reports.api.keeperformaturas.com.br/v1/report/sales/group/{gid}?sales_installments_detailed=1"
ROOT = Path(__file__).resolve().parent.parent


def env(name: str) -> str:
    v = os.environ.get(name, "").strip()
    if not v:
        sys.exit(f"Falta a variável de ambiente {name}")
    return v


def encrypt(data: bytes, passphrase: str) -> bytes:
    """Formato: salt(16) + iv(12) + ciphertext+tag. O app usa WebCrypto com os mesmos parâmetros."""
    salt, iv = os.urandom(16), os.urandom(12)
    key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=200_000).derive(passphrase.encode())
    return salt + iv + AESGCM(key).encrypt(iv, data, None)


def dismiss_popups(page):
    """Fecha o aviso do app e o de LGPD, se aparecerem (só o 'x', sem aceitar nada por ela)."""
    for sel in ("mat-dialog-container button:has-text('x')", "mat-dialog-container [aria-label='Close']",
                "mat-dialog-container button:has-text('×')"):
        try:
            page.locator(sel).first.click(timeout=1500)
            time.sleep(0.5)
        except PWTimeout:
            pass


def login(page, email: str, senha: str):
    page.goto(SITE, wait_until="networkidle")
    dismiss_popups(page)
    # Tela inicial -> "FAZER LOGIN"
    try:
        page.get_by_role("button", name="FAZER LOGIN").click(timeout=8000)
    except PWTimeout:
        pass  # já está na tela de login
    page.locator("input:not([type='password'])").first.fill(email)
    page.locator("input[type='password']").first.fill(senha)
    page.get_by_role("button", name="ENTRAR").click()
    # Logado quando o painel aparece
    page.wait_for_url(lambda u: "/home" in u or u.rstrip("/") == SITE.rstrip("/"), timeout=30000)
    page.wait_for_load_state("networkidle")
    dismiss_popups(page)


def download_report(page) -> bytes:
    gid = page.evaluate("localStorage.getItem('current_group')")
    if not gid:
        # Tenta descobrir pela chamada /auth/me
        gid = page.evaluate("""async () => {
            const r = await fetch('https://main.api.keeperformaturas.com.br/v1/auth/me', {credentials:'include'});
            const j = await r.json(); const c = (j.contributors||[])[0]; return c ? c.group_id : null; }""")
    if not gid:
        sys.exit("Não encontrei a turma (group_id) após o login.")
    b64 = page.evaluate("""async (url) => {
        const r = await fetch(url, {credentials:'include'});
        if (!r.ok) throw new Error('HTTP ' + r.status);
        const buf = new Uint8Array(await r.arrayBuffer());
        let s = ''; for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
        return btoa(s); }""", REPORT.format(gid=gid))
    data = base64.b64decode(b64)
    if data[:2] != b"PK":
        sys.exit("A resposta não parece ser um .xlsx (o login pode ter falhado).")
    return data


def main():
    email, senha, data_key = env("KEEPER_EMAIL"), env("KEEPER_SENHA"), env("DATA_KEY")
    out = Path(os.environ.get("OUT") or ROOT / "dados.enc")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(locale="pt-BR", viewport={"width": 1280, "height": 900})
        page = ctx.new_page()
        try:
            login(page, email, senha)
            xlsx = download_report(page)
        except Exception as e:  # deixa uma captura de tela para diagnosticar
            page.screenshot(path=str(ROOT / "sync-erro.png"), full_page=True)
            raise SystemExit(f"Falhou: {e} (veja sync-erro.png)")
        finally:
            browser.close()
    out.write_bytes(encrypt(xlsx, data_key))
    print(f"OK: {len(xlsx):,} bytes baixados -> {out} ({out.stat().st_size:,} bytes criptografados)")


if __name__ == "__main__":
    main()
