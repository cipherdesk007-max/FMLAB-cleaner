# FMLAB Cleaner 🧹📱

<p align="center"><img src="Risorse/logo-256.png" width="140" alt="Logo FMLAB"></p>

**FMLAB Cleaner** è un'app per iPhone che libera spazio in sicurezza e mostra lo stato vero del telefono.
Tutto resta sul telefono: niente internet (tranne il controllo aggiornamenti), niente abbonamenti, niente pubblicità.

<p align="center">
  <img src="screenshots/pulizia.png" width="32%" alt="Pulizia">
  <img src="screenshots/telefono.png" width="32%" alt="Telefono">
</p>

## Installazione

1. Dall'iPhone scarica **[FMLAB-Cleaner.ipa](https://github.com/cipherdesk007-max/FMLAB-cleaner/releases/download/ultima/FMLAB-Cleaner.ipa)**.
2. Apri **LiveContainer** → **+** in alto a destra → scegli il file.
3. Al primo avvio consenti l'accesso a **Tutte le foto** (la richiesta compare a nome di LiveContainer).

Gli aggiornamenti li segnala l'app stessa: un tocco scarica il file nuovo, che si installa sopra il vecchio
allo stesso modo (i dati restano). Funziona anche con SideStore/AltStore come app normale.

## Cosa fa

| Scheda | Cosa fa |
|---|---|
| **Pulizia** | Video grandi (dal più pesante, da togliere o **comprimere** a metà peso), doppioni identici (l'originale resta), registrazioni dello schermo, screenshot, scatti a raffica non scelti. **Svuota "Eliminati di recente"** tutto in una volta |
| **App** | Solo dentro LiveContainer: quanto occupa ogni app ospitata, svuota cache e file temporanei, toglie i file .ipa rimasti e i dati di app già disinstallate |
| **Telefono** | Batteria, risparmio energetico, temperatura come la comunica iOS, spazio, memoria, da quanto è acceso, consigli in ordine di effetto |

**Sicurezza**: niente si cancella senza la tua scelta; iOS chiede sempre conferma e foto e video vanno in
*Eliminati di recente* (30 giorni). Nella scheda App si tolgono solo cache, temporanei, .ipa e dati orfani, mai
documenti o dati delle app installate.

**Cosa nessuna app per iPhone può fare** (e chi lo promette non fa niente di vero): liberare la RAM, chiudere le
altre app, "riparare" la batteria, cancellare file di iOS o di app fuori da LiveContainer.

## Come è fatta

- SwiftUI + PhotoKit, iOS 15 o successivo. Sorgenti in [`Sorgenti/`](Sorgenti/).
- Compilata da GitHub Actions su Linux con [Theos](https://github.com/theos/theos) (nessun Mac necessario):
  a ogni modifica su `main` esce una versione numerata e la pubblicazione **ultima**, da cui l'app si aggiorna.
- `project.yml` serve per aprirla in Xcode con XcodeGen, se un giorno si usa un Mac.
- Storico: [CHANGELOG.md](CHANGELOG.md). Licenza: [MIT](LICENSE).

Parte del mondo FMLAB, insieme a [FMlab - RunnerKit](https://github.com/cipherdesk007-max/FMlab---RunnerKit)
(Linux sull'iPhone con LinuxRunner).
