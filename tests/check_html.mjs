// Extrai o <script> inline do index.html e valida a sintaxe do JavaScript (sem executar).
import { readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
const html = readFileSync("index.html", "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (scripts.length === 0) { console.error("nenhum <script> inline encontrado"); process.exit(1); }
scripts.forEach((code, i) => {
  const f = `tests/.inline-${i}.js`;
  writeFileSync(f, code);
  execFileSync(process.execPath, ["--check", f], { stdio: "inherit" });
});
for (const must of ["function parseWorkbook", "function autoLoad", "async function decryptEnc", "<title>Tesouraria da Formatura</title>", 'name="viewport"']) {
  if (!html.includes(must)) { console.error("faltando no index.html: " + must); process.exit(1); }
}
if (/[0-9a-f]{40}|@gmail|@hotmail/.test(html)) { console.error("index.html contém id/e-mail suspeito"); process.exit(1); }
console.log(`OK: ${scripts.length} script(s) com sintaxe válida`);
