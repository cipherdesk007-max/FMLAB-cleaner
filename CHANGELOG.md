# Changelog — FMLAB Cleaner

## 1.9.0
- **Esplora le cartelle**: tocca una cartella (anche "Sul mio iPhone → LiveContainer") e vedi cosa c'è dentro,
  dal più pesante, con il peso di ogni sottocartella. Si entra nelle sottocartelle toccandole; un file si toglie
  scorrendo a sinistra (va nel cestino di File).
- **L'app consiglia "Sul mio iPhone"** finché non è nell'elenco: contiene Downloads e le cartelle di tutte le app,
  quindi vede tutto. Con i passi del selettore e un pulsante per aggiungerla.

*English*: explore folders (contents largest first, drill into subfolders, swipe to remove a file); the app now
recommends adding "On My iPhone", which contains everything.

## 1.8.7
- **Nomi giusti per le cartelle**: "File Provider Storage" ora si legge **Sul mio iPhone** (e la radice di iCloud
  **iCloud Drive**); le sottocartelle dirette diventano "Sul mio iPhone → Downloads". Vale anche per la cartella
  scritta sotto ogni file negli elenchi.
- Se una cartella è già dentro un'altra dell'elenco (es. Downloads dentro Sul mio iPhone), sotto c'è scritto
  "già compresa in …: puoi toglierla".

*English*: readable folder names ("On My iPhone", "iCloud Drive", "On My iPhone → Downloads"), and a hint when a
folder is already inside another one in the list.

## 1.8.6
*Provata sull'iPhone: file tolti davvero (38,2 MB liberati), grassetto a posto.*

- **Scheda File: "Sposta nel cestino" ora toglie davvero i file.** Dentro LiveContainer il coordinatore di file di
  iOS non rispondeva e i file restavano dov'erano senza nessun messaggio. Ora l'app prova prima direttamente
  (cestino di File, altrimenti eliminazione), e il coordinatore resta come ultima via con un limite di 8 secondi.
- Le cartelle scelte restano aperte per tutta la pulizia; i file solo su iCloud si tolgono dal loro segnaposto.
- Se qualche file non si può togliere, l'app lo dice con il motivo e lo lascia spuntato.

*English*: Files tab: "Move to Files trash" now really removes files inside LiveContainer (direct removal first,
file coordinator last with a timeout); iCloud-only files handled; failures are reported with the reason.

## 1.8.5
*Provata sull'iPhone: la cartella orfana ora si legge "LinuxRunner · dati vecchi".*

- **Scheda App → "Dati di app tolte" con nomi veri**: al posto del codice tagliato ("DAECCFC4-C87F-…") si vede
  l'app a cui appartenevano i dati (es. "YouTube"), letta da LiveContainer o dalle impostazioni dell'app, con
  l'identificativo sotto. Se l'app è ancora installata ma usa un'altra cartella, lo dice ("YouTube · dati vecchi").
  Solo se non c'è nessun indizio compare "App sconosciuta" con l'inizio del codice.

*English*: App tab: leftover data folders show the real app name (e.g. "YouTube") instead of a truncated code,
and say when they're old data of an app that is still installed.

## 1.8.4
- **Difetti estetici corretti**:
  - sotto "Aggiungi una cartella" si vedevano gli asterischi (`**Seleziona**`, `**Apri**`): ora sono in grassetto;
  - niente più "1 elementi": il cestino di Foto e le richieste di conferma ("Togliere…", "Cancellare per sempre…")
    usano il singolare quando l'elemento è uno solo;
  - "Acceso da" mostra "1 ora" invece di "1 ore"; in inglese "1 file" invece di "1 files".

*English*: cosmetic fixes: bold text instead of visible asterisks, correct singular forms ("1 item", "1 hour", "1 file").

## 1.8.3
*Provata sull'iPhone: "Aggiungi una cartella" aggiunge Downloads e l'analisi parte subito.*

- **"Aggiungi una cartella" non si blocca più su "Apri"** (rotella che girava all'infinito, anche su "Sul mio iPhone").
  Il motivo: dentro LiveContainer il selettore di File provava a consegnare la cartella a un'app con il nome
  sbagliato e restava ad aspettare. Ora FMLAB Cleaner si ripara da solo, senza toccare le impostazioni di LiveContainer.
- Dopo **Apri** l'app dice sempre cosa è successo: cartella aggiunta (con vibrazione e analisi subito), file scelto
  al posto della cartella, oppure copia arrivata al posto della cartella vera (opzione Legacy di LiveContainer accesa).
- La stessa cartella non si aggiunge due volte; se iOS non la lascia ricordare viene comunque usata finché l'app è aperta.
- Se aggiungi una cartella mentre l'analisi è in corso, l'analisi riparte da sola con la cartella nuova.

*English*: "Add a folder" no longer hangs after "Open" inside LiveContainer (the app now fixes the picker by itself);
clear feedback after picking; no duplicate folders; analysis restarts when a folder is added mid-scan.

## 1.8.2
- **Scelta delle cartelle che funziona dentro LiveContainer**: LiveContainer allarga i tipi di file del selettore e
  sparisce il tasto per scegliere la cartella aperta. Ora il selettore è a selezione multipla: **Seleziona** →
  spunta la cartella (es. Download) → **Apri**. Si possono aggiungere più cartelle insieme.

*English*: folder picking works inside LiveContainer (multi-select picker: Select → check the folder → Open).

## 1.8.1
- **Cartella automatica** "Sul mio iPhone → LiveContainer": si pulisce senza scegliere niente. Impostando Safari
  perché scarichi lì (Impostazioni → App → Safari → Download), i download si puliscono da soli.
- Se il selettore di cartelle non risponde dentro LiveContainer, l'app lo dice e spiega la soluzione
  (FMLAB Cleaner → Impostazioni in LiveContainer → Ripara Selettore File).
- Messaggio onesto sul cestino: dove iOS non ha "Eliminati di recente", i file si cancellano subito.

*English*: automatic "On My iPhone → LiveContainer" folder (set Safari downloads there and they get cleaned with
no picking); clear guidance when the folder picker doesn't respond inside LiveContainer; honest trash message.

## 1.8.0
- **Nuova scheda File**: pulisce anche l'app File (Download, Sul mio iPhone, iCloud Drive). Aggiungi una cartella
  una volta (iOS vuole che sia tu a sceglierla) e l'app la analizza da sola ogni volta:
  - **File grandi** (50 MB in su), **File doppi** (stesso contenuto, verificato con SHA-256: il più vecchio resta),
    **Archivi e installazioni** (.ipa, .zip, .rar, .dmg...), **File vecchi** (più di 6 mesi);
  - i file tolti vanno nel cestino dell'app File (recuperabili per 30 giorni). Funziona anche con i file rimasti
    in "Errore" di caricamento su iCloud.

*English*: new Files tab: add a folder once (Downloads, On My iPhone, iCloud Drive) and the app finds large files,
SHA-256-verified duplicates, archives/installers and old files; removed files go to the Files trash (30 days).

## 1.7.0
- **Analisi approfondita** (a richiesta, tutta sul telefono con Vision di Apple):
  - **Foto simili**: scatti quasi uguali a pochi secondi di distanza; in ogni gruppo resta la più nitida (e le
    preferite), le altre sono preselezionate;
  - **Foto sfocate** e **Foto buie**: da controllare, mai preselezionate.
  Avanzamento, pulsante Ferma, schermo sempre acceso durante l'analisi.
- **WhatsApp, Telegram, Eliminati di recente**: iOS non permette di aprire una pagina interna di un'altra app, solo
  l'app stessa. Ora i passi sono numerati (1, 2, 3, 4) e il pulsante dice "Apri … e segui i passi".

*English*: on-device deep analysis (similar photos keeping the sharpest, blurry and dark photos); numbered steps
for WhatsApp, Telegram and Recently Deleted, since iOS can only open another app, not one of its inner pages.

## 1.6.1
- "Puoi liberare fino a" non conta più due volte lo stesso video (es. grande e doppione insieme).
- Accessibilità: le miniature si leggono con VoiceOver ("Foto, 3 MB", selezionata o no).
- Controllo automatico prima di ogni compilazione: file inglese scritto bene, nessun testo senza traduzione,
  stessi segnaposto (%@, %lld) in italiano e inglese.

*English*: no double counting in "You can free up to"; VoiceOver labels for thumbnails; pre-build check of the
English strings (syntax, missing translations, matching placeholders).

## 1.6.0 — versione completa
- **WhatsApp e Telegram puliti dentro l'app** quando sono installati in LiveContainer: l'app riconosce anche i
  loro contenitori condivisi (dove tengono quasi tutto) e con **Pulisci qui** toglie cache e, per Telegram, i
  media scaricati (restano sul cloud di Telegram). Le chat non si toccano. Per WhatsApp mostra quanto pesano foto e
  video delle chat (non sono su un cloud: si tolgono da WhatsApp).
- Se sono installate dall'App Store, iOS non lascia toccare i loro file a nessuna app: restano i passi e "Apri".
- **Ordine nuovo** della Pulizia: prima "Cosa togliere", poi Eliminati di recente, WhatsApp e Telegram, consigli.
- Eliminati di recente: spiegato in una frase perché si svuota solo dall'app Foto (iOS non lo apre alle app).

*English*: WhatsApp/Telegram cleaned inside the app when installed in LiveContainer (shared containers detected;
Telegram downloaded media cleared, chats untouched; WhatsApp chat media size shown); App Store installs stay
sandboxed by iOS; new Clean tab order; clearer Recently Deleted note.

## 1.5.0
- Pulsanti delle azioni distinti: **Comprimi** / **Trasforma in foto** bianchi, **Togli** rosso; uno sopra
  l'altro, leggibili anche con numeri lunghi.
- Pubblicate anche le versioni storiche (1.1.0 e 1.3.0) tra le release; la 1.2.0 e la 1.4.0 sono comprese
  nelle versioni successive (1.3.0 e 1.4.1).

*English*: distinct action buttons (white Compress/Convert, red Remove, stacked); historical releases published.

## 1.4.1
- **Eliminati di recente sempre visibile** in cima alla Pulizia: se iOS lascia leggere l'album, numero, peso e
  "Svuota tutto"; se no, i passi per "Elimina tutto" e il pulsante **Apri Foto**.
- **WhatsApp e Telegram**: pulsante **Apri** e i passi esatti per liberare spazio (Gestisci spazio, Svuota cache,
  Salva nel rullino spento). Nessuna app iOS può cancellare i loro file al posto loro.
- Rifiniture: "1 elemento" al singolare, "—" invece di "Zero KB", "meno di un'ora" invece di "0 ore",
  spazio libero dell'iPhone in cima alla Pulizia (si aggiorna dopo ogni pulizia).
- Scheda App: le cartelle di app tolte mostrano il nome dell'app quando si riconosce (dalle sue impostazioni)
  e la data dell'ultima modifica, invece di un codice.

*English*: Recently Deleted card always shown (empty-all when iOS allows it, otherwise the manual steps
and an Open Photos button); WhatsApp/Telegram cleanup guide with Open buttons; polish (singular/plural, "—" for empty, uptime under an hour, free iPhone space on top), orphaned
folders show the app name when recognizable plus last-modified date.

## 1.4.0
- **Colori FMLAB**: rosso del logo su nero, logo nell'app.
- **Aggiornamento senza file**: "Copia link di installazione" e in LiveContainer + → Installa dall'URL
  (niente cartella Download su iCloud, che può dare "Errore").
- **Live Photo → foto**: nuova categoria; il video di 3 secondi sparisce, la foto resta identica.
- **Analisi molto più veloce dalla seconda volta**: i pesi già calcolati si ricordano, si rilegge solo il nuovo.
- **In inglese** se l'iPhone è in inglese (italiano di base); vibrazione leggera alla selezione.

*English*: FMLAB red/black theme with logo; update by copying the install link (LiveContainer → + → Install from URL,
no iCloud Downloads errors); new Live Photo → still photo conversion; much faster re-scans thanks to a size cache;
English localization; selection haptics.

## 1.3.1
- Nuovo nome **FMLAB Cleaner** e repository dedicato: aggiornamenti, versioni e file .ipa sono qui.
- Logo FMLAB come icona.

## 1.3.0
- Svuota "Eliminati di recente" tutto in una volta dall'app (l'app Foto li carica a pezzi da circa 3000).

## 1.2.0
- **Comprimi video** (HEVC, al massimo 1080p): circa metà peso, data, luogo e preferiti restano.
- **Scheda App** (dentro LiveContainer): spazio di ogni app, svuota cache e file temporanei, .ipa rimasti,
  dati di app già disinstallate.

## 1.1.0
- Prima versione: video grandi, doppioni, registrazioni dello schermo, screenshot, raffiche;
  scheda Telefono (batteria, temperatura, spazio, consigli); controllo aggiornamenti da GitHub.
