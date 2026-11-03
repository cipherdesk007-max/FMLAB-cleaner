#!/usr/bin/env python3
"""Controllo prima della compilazione: il file inglese e' scritto bene e ogni testo L("...") ha la sua traduzione.
Le frasi dentro Text("...") con valori non si controllano qui (le chiavi le genera SwiftUI)."""
import glob, re, sys
FILE = "theos/Resources/en.lproj/Localizable.strings"
riga = re.compile(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$')
chiavi, errori = set(), []
for n, l in enumerate(open(FILE, encoding="utf-8"), 1):
    l = l.rstrip("\n")
    if not l.startswith('"'):
        continue
    m = riga.match(l)
    if not m:
        errori.append(f"{FILE}:{n}: riga scritta male")
        continue
    k = m.group(1).replace('\\"', '"')
    if k in chiavi:
        errori.append(f"{FILE}:{n}: chiave doppia: {k[:60]}")
    chiavi.add(k)
    # gli stessi segnaposto (%@, %lld) nello stesso ordine
    if re.findall(r"%(?:lld|@|d)", m.group(1)) != re.findall(r"%(?:lld|@|d)", m.group(2)):
        errori.append(f"{FILE}:{n}: segnaposto diversi: {k[:60]}")
codice = "".join(open(f, encoding="utf-8").read() for f in glob.glob("Sorgenti/*.swift"))
codice = re.sub(r"^\s*///.*$", "", codice, flags=re.M)   # niente commenti di documentazione
for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', codice):
    k = m.group(1).replace('\\"', '"')
    if k not in chiavi:
        errori.append(f"manca la traduzione inglese: {k[:70]}")
print("\n".join(sorted(set(errori))) or f"traduzioni a posto ({len(chiavi)} testi)")
sys.exit(1 if errori else 0)
