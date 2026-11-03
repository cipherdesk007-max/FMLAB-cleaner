// Pulizia dell'app File (Download, Sul mio iPhone, iCloud Drive...). iOS lascia entrare un'app solo nelle
// cartelle che scegli tu una volta: FMLAB Cleaner se le ricorda e le analizza dall'interno.
// I file tolti vanno nel cestino dell'app File ("Eliminati di recente", 30 giorni), non spariscono subito.
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FileTrovato: Identifiable, Hashable {
    let url: URL
    let byte: Int64
    let data: Date?
    let soloICloud: Bool
    var gruppo = 0
    var daTenere = false
    var id: String { url.path }
    var nome: String { url.lastPathComponent }
}

enum TipoFile: String, CaseIterable, Identifiable {
    case grandi, doppioni, installazioni, vecchi
    var id: String { rawValue }
    var titolo: String {
        switch self {
        case .grandi: return L("File grandi")
        case .doppioni: return L("File doppi")
        case .installazioni: return L("Archivi e installazioni")
        case .vecchi: return L("File vecchi")
        }
    }
    var icona: String {
        switch self {
        case .grandi: return "doc.badge.ellipsis"
        case .doppioni: return "doc.on.doc"
        case .installazioni: return "archivebox"
        case .vecchi: return "clock.arrow.circlepath"
        }
    }
    var spiegazione: String {
        switch self {
        case .grandi: return L("File da 50 MB in su, dal più pesante.")
        case .doppioni: return L("File identici (stesso contenuto). Il più vecchio resta, gli altri sono già selezionati.")
        case .installazioni: return L(".ipa, .zip, .rar, .7z, .dmg, .apk: di solito servono una volta sola.")
        case .vecchi: return L("File non modificati da più di 6 mesi, dal più pesante.")
        }
    }
}

enum AnalisiFile {
    static let estensioniArchivi: Set<String> = ["ipa", "tipa", "zip", "rar", "7z", "dmg", "apk", "pkg", "tar", "gz", "xz", "iso"]

    /// Cartelle interne di LiveContainer (app installate e loro dati): non sono file dell'utente
    static let escluseLC: Set<String> = ["Applications", "Data", "Tweaks", "Frameworks", "TweakLoader", "Cache", "Caches"]

    static func esegui(_ cartelle: [URL], automatica: URL? = nil) -> [TipoFile: [FileTrovato]] {
        let fm = FileManager.default
        let chiavi: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey,
                                        .contentModificationDateKey, .ubiquitousItemDownloadingStatusKey]
        var tutti: [FileTrovato] = []
        var visti = Set<String>()
        for c in cartelle + [automatica].compactMap({ $0 }) {
            let aperta = c.startAccessingSecurityScopedResource()
            defer { if aperta { c.stopAccessingSecurityScopedResource() } }
            guard let e = fm.enumerator(at: c, includingPropertiesForKeys: chiavi, options: [.skipsPackageDescendants],
                                        errorHandler: { _, _ in true }) else { continue }
            for case let u as URL in e {
                if c == automatica, e.level == 1, escluseLC.contains(u.lastPathComponent) {
                    e.skipDescendants(); continue
                }
                guard let v = try? u.resourceValues(forKeys: Set(chiavi)), v.isRegularFile == true else { continue }
                var url = u
                // segnaposto iCloud (".nome.icloud"): il file vero e' solo sul cloud
                let nome = u.lastPathComponent
                let segnaposto = nome.hasPrefix(".") && nome.hasSuffix(".icloud")
                if segnaposto {
                    url = u.deletingLastPathComponent().appendingPathComponent(String(nome.dropFirst().dropLast(7)))
                } else if nome.hasPrefix(".") { continue }
                guard visti.insert(url.path).inserted else { continue }
                let soloCloud = segnaposto || v.ubiquitousItemDownloadingStatus == .notDownloaded
                let byte = Int64(v.fileSize ?? v.totalFileAllocatedSize ?? 0)
                tutti.append(FileTrovato(url: url, byte: byte, data: v.contentModificationDate, soloICloud: soloCloud))
            }
        }
        var ris: [TipoFile: [FileTrovato]] = [:]
        ris[.grandi] = tutti.filter { $0.byte >= 50 * 1024 * 1024 }.sorted { $0.byte > $1.byte }
        ris[.installazioni] = tutti.filter { estensioniArchivi.contains($0.url.pathExtension.lowercased()) }.sorted { $0.byte > $1.byte }
        let sei = Date().addingTimeInterval(-182 * 86400)
        ris[.vecchi] = tutti.filter { ($0.data ?? Date()) < sei && $0.byte >= 1024 * 1024 }.sorted { $0.byte > $1.byte }
        // doppioni: stesso peso, poi stessa impronta SHA-256 (solo file scaricati, almeno 100 KB)
        var perPeso: [Int64: [FileTrovato]] = [:]
        for f in tutti where !f.soloICloud && f.byte >= 100 * 1024 { perPeso[f.byte, default: []].append(f) }
        var doppi: [FileTrovato] = []
        var g = 0
        for gruppo in perPeso.values where gruppo.count > 1 {
            var perImpronta: [String: [FileTrovato]] = [:]
            for f in gruppo {
                let aperta = cartelle.first { f.url.path.hasPrefix($0.path) }?.startAccessingSecurityScopedResource() ?? false
                if let h = impronta(f.url) { perImpronta[h, default: []].append(f) }
                if aperta { cartelle.first { f.url.path.hasPrefix($0.path) }?.stopAccessingSecurityScopedResource() }
            }
            for uguali in perImpronta.values where uguali.count > 1 {
                g += 1
                let ordinati = uguali.sorted { ($0.data ?? .distantPast) < ($1.data ?? .distantPast) }
                for (k, el) in ordinati.enumerated() {
                    var f = el
                    f.gruppo = g
                    f.daTenere = k == 0
                    doppi.append(f)
                }
            }
        }
        ris[.doppioni] = doppi
        return ris
    }

    static func impronta(_ u: URL) -> String? {
        guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let blocco = h.readData(ofLength: 1 << 20)
            if blocco.isEmpty { break }
            hasher.update(data: blocco)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Nome leggibile di una cartella dell'app File: "File Provider Storage" e' "Sul mio iPhone",
/// "com~apple~CloudDocs" e' "iCloud Drive"; le sottocartelle dirette diventano "Sul mio iPhone → Downloads".
func nomeCartella(_ u: URL) -> String {
    func radice(_ n: String) -> String? {
        switch n {
        case "File Provider Storage": return L("Sul mio iPhone")
        case "com~apple~CloudDocs": return "iCloud Drive"
        default: return nil
        }
    }
    if let r = radice(u.lastPathComponent) { return r }
    if let r = radice(u.deletingLastPathComponent().lastPathComponent) { return "\(r) → \(u.lastPathComponent)" }
    return u.lastPathComponent
}

@MainActor
final class ArchivioFile: ObservableObject {
    @Published var cartelle: [URL] = []
    @Published var risultato: [TipoFile: [FileTrovato]] = [:]
    @Published var analisi = false
    @Published var liberato: Int64 = 0
    @Published var erroreSelettore: String?
    private let chiave = "cartelleFile"

    /// "Sul mio iPhone → LiveContainer": la cartella di LiveContainer si vede nell'app File e qui e' gia'
    /// raggiungibile, senza scegliere niente. Se Safari scarica li', i download si puliscono da soli.
    var automatica: URL? { SpazioLC.radice }

    init() { carica() }

    /// Cartelle che iOS non lascia ricordare (segnalibro non creato): valgono finche' l'app resta aperta.
    private var soloPerOra: [URL] = []

    func carica() {
        let dati = UserDefaults.standard.array(forKey: chiave) as? [Data] ?? []
        var lista: [URL] = []
        for d in dati {
            var vecchio = false
            if let u = try? URL(resolvingBookmarkData: d, options: [], relativeTo: nil, bookmarkDataIsStale: &vecchio),
               !lista.contains(where: { $0.path == u.path }) { lista.append(u) }
        }
        for u in soloPerOra where !lista.contains(where: { $0.path == u.path }) { lista.append(u) }
        cartelle = lista
    }

    /// Risposta del selettore: tiene solo le cartelle vere, scarta copie e file, e dice sempre cosa e' successo.
    func ricevi(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var copie = 0, file = 0, aggiunte = 0, temporanee = 0
        for u in urls {
            let aperta = u.startAccessingSecurityScopedResource()
            defer { if aperta { u.stopAccessingSecurityScopedResource() } }
            if RiparaSelettore.eUnaCopia(u) {
                copie += 1
                let p = u.path
                if p.contains("Inbox") || p.hasPrefix(FileManager.default.temporaryDirectory.path) {
                    try? FileManager.default.removeItem(at: u)   // la copia occupa solo spazio
                }
                continue
            }
            guard (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { file += 1; continue }
            if cartelle.contains(where: { $0.path == u.path }) { aggiunte += 1; continue }
            if let d = try? u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                var dati = UserDefaults.standard.array(forKey: chiave) as? [Data] ?? []
                dati.append(d)
                UserDefaults.standard.set(dati, forKey: chiave)
            } else {
                soloPerOra.append(u); temporanee += 1
            }
            aggiunte += 1
        }
        carica()
        if aggiunte == 0 {
            erroreSelettore = copie > 0
                ? L("È arrivata una copia, non la cartella vera. In LiveContainer tieni premuto FMLAB Cleaner → Impostazioni e spegni \"Sistema Selettore File (Legacy)\", poi riprova.")
                : L("Hai scelto un file, non una cartella: tocca Seleziona, spunta la cartella e poi Apri.")
        } else {
            erroreSelettore = temporanee > 0
                ? L("Cartella aggiunta, ma iOS non la lascia ricordare: dopo aver chiuso l'app andrà aggiunta di nuovo.")
                : nil
            Vibrazione.fatto()
            Task { await analizza() }
        }
    }

    func togliCartella(_ u: URL) {
        var dati = UserDefaults.standard.array(forKey: chiave) as? [Data] ?? []
        dati.removeAll { d in
            var vecchio = false
            return (try? URL(resolvingBookmarkData: d, options: [], relativeTo: nil, bookmarkDataIsStale: &vecchio))?.path == u.path
        }
        UserDefaults.standard.set(dati, forKey: chiave)
        soloPerOra.removeAll { $0.path == u.path }
        carica()
        risultato = [:]
    }

    private var daRifare = false

    func analizza() async {
        guard !cartelle.isEmpty || automatica != nil else { return }
        // se un'analisi e' gia' in corso (es. hai appena aggiunto una cartella) la rifaccio appena finisce
        guard !analisi else { daRifare = true; return }
        analisi = true
        repeat {
            daRifare = false
            let c = cartelle, auto = automatica
            risultato = await Task.detached(priority: .userInitiated) { AnalisiFile.esegui(c, automatica: auto) }.value
        } while daRifare
        analisi = false
    }

    /// Toglie un file; nil se ci riesce, altrimenti il motivo
    nonisolated static func eliminaUno(_ f: FileTrovato) -> String? {
        let fm = FileManager.default
        // un file solo su iCloud esiste sul telefono come segnaposto ".nome.icloud"
        let segnaposto = f.url.deletingLastPathComponent().appendingPathComponent("." + f.url.lastPathComponent + ".icloud")
        guard let u = [f.url, segnaposto].first(where: { fm.fileExists(atPath: $0.path) }) else { return nil } // gia' sparito
        var ultimo = ""
        do { try fm.trashItem(at: u, resultingItemURL: nil); return nil } catch { ultimo = error.localizedDescription }
        do { try fm.removeItem(at: u); return nil } catch { ultimo = error.localizedDescription }
        // ultima via: il coordinatore di file, con un limite di 8 secondi perche' puo' non rispondere
        final class Esito: @unchecked Sendable { var riuscito = false; var errore: String? }
        let esito = Esito()
        let coord = NSFileCoordinator()
        let fatto = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            var errore: NSError?
            coord.coordinate(writingItemAt: u, options: .forDeleting, error: &errore) { v in
                esito.riuscito = (try? FileManager.default.removeItem(at: v)) != nil
            }
            esito.errore = errore?.localizedDescription
            fatto.signal()
        }
        if fatto.wait(timeout: .now() + 8) == .timedOut { coord.cancel(); return L("iOS non risponde") }
        if let e = esito.errore { ultimo = e }
        let riuscito = esito.riuscito
        return riuscito || !fm.fileExists(atPath: u.path) ? nil : ultimo
    }

    func peso(_ t: TipoFile) -> Int64 { (risultato[t] ?? []).filter { !$0.daTenere }.reduce(0) { $0 + $1.byte } }

    /// Esito dell'ultima pulizia, mostrato sotto l'elenco
    @Published var esitoTogli: String?

    /// Sposta nel cestino dell'app File (recuperabile 30 giorni); se non si puo', cancella.
    /// Dentro LiveContainer il coordinatore di file di iOS spesso non risponde (l'app ha un identificativo
    /// diverso da quello che il sistema si aspetta): prima si prova direttamente, il coordinatore e' l'ultima via.
    func togli(_ scelti: [FileTrovato]) async -> Int {
        let c = cartelle + [automatica].compactMap { $0 }
        let (fatti, errori) = await Task.detached { () -> ([String], [String]) in
            var ok: [String] = [], errori: [String] = []
            // la cartella scelta va "aperta" per tutto il tempo (permesso di scrittura di iOS)
            let aperte = c.filter { $0.startAccessingSecurityScopedResource() }
            defer { aperte.forEach { $0.stopAccessingSecurityScopedResource() } }
            for f in scelti {
                if let e = ArchivioFile.eliminaUno(f) { errori.append("\(f.nome): \(e)") } else { ok.append(f.id) }
            }
            return (ok, errori)
        }.value
        esitoTogli = errori.isEmpty ? nil
            : L("%lld non tolti. %@", errori.count, errori.prefix(3).joined(separator: " · "))
        let via = Set(fatti)
        liberato += scelti.filter { via.contains($0.id) }.reduce(0) { $0 + $1.byte }
        for t in TipoFile.allCases { risultato[t] = (risultato[t] ?? []).filter { !via.contains($0.id) } }
        let conteggi = Dictionary(grouping: risultato[.doppioni] ?? [], by: \.gruppo).mapValues(\.count)
        risultato[.doppioni] = (risultato[.doppioni] ?? []).filter { (conteggi[$0.gruppo] ?? 0) > 1 }
        return fatti.count
    }
}

struct SchedaFile: View {
    @EnvironmentObject var archivio: ArchivioFile
    @State private var scegli = false

    var body: some View {
        List {
            Section {
                Text("Download, Sul mio iPhone, iCloud Drive: aggiungi una cartella una volta e l'app la analizza da sola. I file tolti vanno nel cestino dell'app File per 30 giorni.")
                    .font(.footnote).foregroundColor(.secondary)
                if archivio.liberato > 0 {
                    Text("Liberati: \(formatoByte(archivio.liberato))").font(.headline).foregroundColor(.green)
                }
            }
            Section {
                if archivio.automatica != nil {
                    Label(L("Sul mio iPhone → LiveContainer (automatica)"), systemImage: "folder.fill").foregroundColor(Tema.rosso)
                }
                ForEach(archivio.cartelle, id: \.path) { c in
                    let dentro = archivio.cartelle.first { $0.path != c.path && c.path.hasPrefix($0.path + "/") }
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nomeCartella(c)).lineLimit(1)
                            if let d = dentro {
                                Text(L("già compresa in %@: puoi toglierla", nomeCartella(d)))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    } icon: { Image(systemName: "folder") }
                        .swipeActions { Button(L("Togli"), role: .destructive) { archivio.togliCartella(c) } }
                }
                Button { scegli = true } label: { Label(L("Aggiungi una cartella"), systemImage: "folder.badge.plus") }
                TestoMd(L("Nel selettore: tocca **Seleziona** in alto, spunta la cartella (es. Download) e tocca **Apri**."))
                    .font(.caption).foregroundColor(.secondary)
                if RiparaSelettore.dentroLiveContainer && !RiparaSelettore.attiva {
                    Text(L("Se dopo \"Apri\" la rotella gira e basta: in LiveContainer tieni premuto FMLAB Cleaner → Impostazioni → accendi \"Ripara Selettore File\"."))
                        .font(.caption).foregroundColor(.orange)
                }
                if let e = archivio.erroreSelettore {
                    Text(e).font(.footnote).foregroundColor(.orange)
                }
            } header: { Text(L("Cartelle")) } footer: {
                Text(archivio.automatica != nil
                     ? L("Senza scegliere niente: in Impostazioni → App → Safari → Download scegli \"Sul mio iPhone → LiveContainer\": da lì in poi i download li pulisco da solo. Per altre cartelle (Download su iCloud) usa \"Aggiungi una cartella\".")
                     : L("Consiglio: aggiungi \"Download\" e \"Sul mio iPhone\". Scorri a sinistra su una cartella per toglierla dall'elenco."))
            }
            if !archivio.cartelle.isEmpty || archivio.automatica != nil {
                Section(L("Cosa togliere")) {
                    if archivio.analisi {
                        HStack { ProgressView(); Text(L("Analizzo i file…")).foregroundColor(.secondary) }
                    }
                    ForEach(TipoFile.allCases) { t in
                        NavigationLink(destination: ElencoFile(tipo: t)) {
                            HStack {
                                Image(systemName: t.icona).frame(width: 28).foregroundColor(Tema.rosso)
                                VStack(alignment: .leading) {
                                    Text(t.titolo)
                                    Text(contaElementi((archivio.risultato[t] ?? []).filter { !$0.daTenere }.count))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(archivio.peso(t) > 0 ? formatoByte(archivio.peso(t)) : "—")
                                    .foregroundColor(.secondary).monospacedDigit()
                            }
                        }
                        .disabled((archivio.risultato[t] ?? []).isEmpty)
                    }
                }
            }
        }
        .navigationTitle(L("File"))
        .refreshable { await archivio.analizza() }
        .task { if archivio.risultato.isEmpty { await archivio.analizza() } }
        .sheet(isPresented: $scegli) {
            SelettoreCartelle { urls in
                scegli = false
                archivio.ricevi(urls)
            }
            .ignoresSafeArea()
        }
    }
}

struct ElencoFile: View {
    @EnvironmentObject var archivio: ArchivioFile
    let tipo: TipoFile
    @State private var scelti: Set<String> = []
    @State private var conferma = false
    @State private var pronto = false

    var file: [FileTrovato] { archivio.risultato[tipo] ?? [] }
    var sceltiFile: [FileTrovato] { file.filter { scelti.contains($0.id) } }
    var peso: Int64 { sceltiFile.reduce(0) { $0 + $1.byte } }

    var body: some View {
        List {
            Text(tipo.spiegazione).font(.footnote).foregroundColor(.secondary)
            ForEach(file) { f in
                let s = scelti.contains(f.id)
                HStack(spacing: 12) {
                    Image(systemName: f.daTenere ? "lock.fill" : (s ? "checkmark.circle.fill" : "circle"))
                        .foregroundColor(f.daTenere ? .green : (s ? .red : .secondary)).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.nome).lineLimit(2)
                        Text([formatoByte(f.byte),
                              f.data.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) },
                              f.soloICloud ? L("solo su iCloud") : nil,
                              tipo == .doppioni ? L("gruppo %lld", f.gruppo) : nil,
                              f.daTenere ? L("TIENI") : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundColor(.secondary)
                        Text(nomeCartella(f.url.deletingLastPathComponent())).font(.caption2).foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !f.daTenere else { return }
                    Vibrazione.tocco()
                    if s { scelti.remove(f.id) } else { scelti.insert(f.id) }
                }
            }
            if let e = archivio.esitoTogli {
                Text(e).font(.footnote).foregroundColor(.orange)
            }
            Color.clear.frame(height: 70).listRowBackground(Color.clear)
        }
        .navigationTitle(tipo.titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button(L("Seleziona tutto")) { scelti = Set(file.filter { !$0.daTenere }.map(\.id)) }
                Button(L("Deseleziona tutto")) { scelti = [] }
            } label: { Image(systemName: "checkmark.circle") }
        }
        .safeAreaInset(edge: .bottom) {
            Button { conferma = true } label: {
                Text(scelti.isEmpty ? L("Tocca i file da togliere") : L("Togli %lld · %@", scelti.count, formatoByte(peso)))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(scelti.isEmpty ? .gray : .red)
            .disabled(scelti.isEmpty)
            .padding().background(.ultraThinMaterial)
        }
        .confirmationDialog(L("Togliere %@ (%@)?", contaFile(scelti.count), formatoByte(peso)), isPresented: $conferma, titleVisibility: .visible) {
            Button(L("Sposta nel cestino di File"), role: .destructive) {
                let lista = sceltiFile
                Task {
                    let n = await archivio.togli(lista)
                    scelti = Set(lista.map(\.id)).intersection(Set(file.map(\.id)))   // restano spuntati quelli non tolti
                    if n > 0 { Vibrazione.fatto() }
                }
            }
        } message: { Text(L("Di solito finiscono in File → Eliminati di recente (30 giorni). Dove iOS non ha il cestino, vengono cancellati subito.")) }
        .onAppear {
            if !pronto { pronto = true; if tipo == .doppioni { scelti = Set(file.filter { !$0.daTenere }.map(\.id)) } }
        }
    }
}

/// Selettore di cartelle con selezione multipla. Dentro LiveContainer il selettore normale di SwiftUI non
/// permette di scegliere una cartella (LiveContainer allarga i tipi di file ammessi e sparisce il tasto
/// "Apri" della cartella corrente): con "Seleziona" le cartelle diventano spuntabili e si possono aprire.
struct SelettoreCartelle: UIViewControllerRepresentable {
    let fine: ([URL]) -> Void

    func makeCoordinator() -> Coordinatore { Coordinatore(fine: fine) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        RiparaSelettore.applica()   // dentro LiveContainer: senza, "Apri" gira all'infinito
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        p.allowsMultipleSelection = true
        p.shouldShowFileExtensions = true
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinatore: NSObject, UIDocumentPickerDelegate {
        let fine: ([URL]) -> Void
        init(fine: @escaping ([URL]) -> Void) { self.fine = fine }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { fine(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { fine([]) }
    }
}
