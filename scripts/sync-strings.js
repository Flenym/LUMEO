// sync-strings.js — Shared JSON-locale (RU/EN) -> iOS String Catalog.
// Без каталога String(localized:) возвращает сам ключ ("onboarding.title").
// Usage: node scripts/sync-strings.js [--check]
//   --check: только проверить синхрон (для CI), без записи.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const ru = require(path.join(root, 'Shared/src/locales/ru.json'));
const en = require(path.join(root, 'Shared/src/locales/en.json'));
const outPath = path.join(root, 'iOSApp/Sources/Resources/Localizable.xcstrings');

function unit(value) {
  return { stringUnit: { state: 'translated', value: String(value) } };
}
const strings = {};
for (const key of Object.keys(ru)) {
  strings[key] = { localizations: { en: unit(en[key] !== undefined ? en[key] : key), ru: unit(ru[key]) } };
}
for (const key of Object.keys(en)) {
  if (!strings[key]) strings[key] = { localizations: { en: unit(en[key]), ru: unit(en[key]) } };
}
const catalog = { sourceLanguage: 'en', strings, version: '1.0' };
const text = JSON.stringify(catalog, null, 2) + '\n';

if (process.argv.includes('--check')) {
  let current = null;
  try { current = fs.readFileSync(outPath, 'utf8'); } catch { /* missing */ }
  if (current !== text) {
    console.error('STRINGS OUT OF SYNC: run `node scripts/sync-strings.js` and commit Localizable.xcstrings');
    process.exit(1);
  }
  console.log('strings in sync: ' + Object.keys(strings).length + ' keys');
} else {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, text);
  console.log('wrote ' + outPath + ' (' + Object.keys(strings).length + ' keys)');
}
