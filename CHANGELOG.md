# Changelog — FMLAB Cleaner

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
