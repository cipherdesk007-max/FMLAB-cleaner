// Spazio delle app dentro LiveContainer. Le app ospitate condividono la "cartella" di LiveContainer,
// quindi FMLAB Cleaner puo' vedere quanto occupa ognuna e togliere SOLO cio' che si ricrea da solo:
// cache e file temporanei, i file di installazione (.ipa) rimasti, i dati di app gia' disinstallate.
// Documenti e dati delle app non si toccano mai. Fuori da LiveContainer questa scheda non c'e':
// le altre app dell'iPhone e i file di iOS non sono raggiungibili da nessuna app (regola di iOS).
import Foundation
import SwiftUI

struct Cartella: Identifiable, Hashable {
    let url: URL
    let nome: String
    var byte: Int64
    var cache: Int64 = 0
    var dettaglio = ""
    var id: String { url.path }
}

struct AppOspitata: Identifiable {
    let nome: String
    let bundle: URL
    let bundleId: String
    let byteApp: Int64
    var dati: [Cartella]
    /// File che l'app riscarica da sola (es. foto e video di Telegram: restano sul cloud di Telegram)
    var scaricabili: [URL] = []
    var byteScaricabili: Int64 = 0
    /// Solo da mostrare: media delle chat di WhatsApp (non sono su un cloud: si tolgono da WhatsApp)
    var byteMediaChat: Int64 = 0
    var id: String { bundle.path }
    var totale: Int64 { byteApp + dati.reduce(0) { $0 + $1.byte } }
    var cache: Int64 { dati.reduce(0) { $0 + $1.cache } }
    var isTelegram: Bool { bundleId.hasPrefix("ph.telegra") || bundleId.lowercased().contains("telegram") }
    var isWhatsApp: Bool { bundleId.lowercased().contains("whatsapp") }
}

enum Disco {
    static func peso(_ u: URL) -> Int64 {
        let fm = FileManager.default
        var tot: Int64 = 0
        let chiavi: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let e = fm.enumerator(at: u, includingPropertiesForKeys: chiavi, options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let f as URL in e {
            guard let v = try? f.resourceValues(forKeys: Set(chiavi)), v.isRegularFile == true else { continue }
            tot += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return tot
    }

    static func svuota(_ u: URL) {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: f)
        }
    }

    static func cacheDi(_ dati: URL) -> [URL] {
        [dati.appendingPathComponent("Library/Caches"), dati.appendingPathComponent("tmp")]
    }
}

@MainActor
final class SpazioLC: ObservableObject {
    @Published var app: [AppOspitata] = []
    @Published var orfani: [Cartella] = []
    @Published var installazioni: [Cartella] = []
    @Published var analisi = false
    @Published var liberato: Int64 = 0

    /// Documents di LiveContainer (dove stanno Applications e Data/Application), se giriamo li' dentro.
    static var radice: URL? {
        guard let h = getenv("LC_HOME_PATH") else { return nil }
        let d = URL(fileURLWithPath: String(cString: h)).appendingPathComponent("Documents")
        return FileManager.default.fileExists(atPath: d.appendingPathComponent("Applications").path) ? d : nil
    }
    static var disponibile: Bool { radice != nil }

    func analizza() async {
        guard let r = Self.radice, !analisi else { return }
        analisi = true
        let ris = await Task.detached(priority: .userInitiated) { Self.leggi(r) }.value
        app = ris.0; orfani = ris.1; installazioni = ris.2
        analisi = false
    }

    /// Dove LiveContainer tiene i contenitori condivisi delle app ospitate (vedi NSFileManager+GuestHooks.m)
    nonisolated static func gruppiBase(_ r: URL) -> [URL] {
        var out = [r.appendingPathComponent("Data/AppGroup")]
        let sel = NSSelectorFromString("lcAppGroupPath")
        if (UserDefaults.self as AnyObject).responds(to: sel),
           let p = (UserDefaults.self as AnyObject).perform(sel)?.takeUnretainedValue() as? String {
            out.append(URL(fileURLWithPath: p).appendingPathComponent("LiveContainer/Data/AppGroup"))
        }
        return out.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    nonisolated static func leggi(_ r: URL) -> ([AppOspitata], [Cartella], [Cartella]) {
        let fm = FileManager.default
        let dir = r.appendingPathComponent("Data/Application")
        var usati = Set<String>()
        var app: [AppOspitata] = []
        let bundle = (try? fm.contentsOfDirectory(at: r.appendingPathComponent("Applications"), includingPropertiesForKeys: nil)) ?? []
        for b in bundle where b.pathExtension == "app" {
            let info = NSDictionary(contentsOf: b.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
            let lc = NSDictionary(contentsOf: b.appendingPathComponent("LCAppInfo.plist")) as? [String: Any] ?? [:]
            let nome = (info["CFBundleDisplayName"] ?? info["CFBundleName"]) as? String ?? b.deletingPathExtension().lastPathComponent
            var cartelle: [(String, String)] = []
            // le versioni vecchie di LiveContainer tenevano queste chiavi in Info.plist
            let lcInfo = lc.isEmpty ? info : lc
            if let cs = lcInfo["LCContainers"] as? [[String: Any]] {
                for c in cs {
                    if let f = c["folderName"] as? String { cartelle.append((f, c["name"] as? String ?? f)) }
                }
            }
            if let u = lcInfo["LCDataUUID"] as? String, !cartelle.contains(where: { $0.0 == u }) { cartelle.append((u, "dati")) }
            let bundleId = (lcInfo["LCOrignalBundleIdentifier"] ?? info["CFBundleIdentifier"]) as? String ?? ""
            var dati: [Cartella] = []
            for (f, n) in cartelle {
                let u = dir.appendingPathComponent(f)
                guard fm.fileExists(atPath: u.path) else { continue }
                usati.insert(f)
                dati.append(Cartella(url: u, nome: n, byte: Disco.peso(u),
                                     cache: Disco.cacheDi(u).reduce(0) { $0 + Disco.peso($1) }))
            }
            // contenitori condivisi (app group) dell'app: Telegram e WhatsApp tengono li' quasi tutto
            var gruppi: [URL] = []
            if !bundleId.isEmpty {
                for base in gruppiBase(r) {
                    for g in (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
                    where g.lastPathComponent.contains(bundleId) {
                        gruppi.append(g)
                        dati.append(Cartella(url: g, nome: L("condivisi"), byte: Disco.peso(g),
                                             cache: Disco.cacheDi(g).reduce(0) { $0 + Disco.peso($1) }))
                    }
                }
            }
            var a = AppOspitata(nome: nome, bundle: b, bundleId: bundleId, byteApp: Disco.peso(b), dati: dati)
            if a.isTelegram {
                // foto, video e file scaricati nelle chat: Telegram li riscarica dal suo cloud quando servono
                for g in gruppi + dati.map(\.url) {
                    let td = g.appendingPathComponent("telegram-data")
                    for acc in (try? fm.contentsOfDirectory(at: td, includingPropertiesForKeys: nil)) ?? []
                    where acc.lastPathComponent.hasPrefix("account-") {
                        let m = acc.appendingPathComponent("postbox/media")
                        if fm.fileExists(atPath: m.path) { a.scaricabili.append(m); a.byteScaricabili += Disco.peso(m) }
                    }
                }
            }
            if a.isWhatsApp {
                for g in gruppi {
                    let m = g.appendingPathComponent("Message/Media")
                    if fm.fileExists(atPath: m.path) { a.byteMediaChat += Disco.peso(m) }
                }
            }
            app.append(a)
        }
        // dati di app non piu' installate in LiveContainer (solo se ho riconosciuto almeno un'app:
        // se non riesco a leggere le app, non dichiaro "orfano" niente)
        var orfani: [Cartella] = []
        if usati.isEmpty { return (app.sorted { $0.totale > $1.totale }, [], []) }
        for d in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where !usati.contains(d.lastPathComponent) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: d.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let infoC = NSDictionary(contentsOf: d.appendingPathComponent("LCContainerInfo.plist")) as? [String: Any] ?? [:]
            // LiveContainer chiama il contenitore come la cartella (un codice): quello non e' un nome
            let nomeC = (infoC["name"] as? String).flatMap { n in
                n.isEmpty || n == d.lastPathComponent || UUID(uuidString: n) != nil ? nil : n
            }
            // senza nome: provo a riconoscere l'app dalle sue impostazioni (Library/Preferences/<id app>.plist)
            let pref = ((try? fm.contentsOfDirectory(atPath: d.appendingPathComponent("Library/Preferences").path)) ?? [])
                .filter { $0.hasSuffix(".plist") && !$0.hasPrefix("com.apple.") && !$0.lowercased().contains("livecontainer") }
                .map { String($0.dropLast(6)) }.sorted { $0.count < $1.count }.first
            let idApp = (infoC["appIdentifier"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? pref
            let installata = idApp.flatMap { id in app.first { $0.bundleId == id } }
            let nomeApp = installata?.nome ?? idApp.map(nomeDaIdentificativo)
            let data = (try? fm.attributesOfItem(atPath: d.path)[.modificationDate] as? Date)
                .map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) }
            let nome: String
            if let n = nomeApp {
                nome = installata != nil ? L("%@ · dati vecchi", n) : (nomeC.map { "\(n) · \($0)" } ?? n)
            } else {
                nome = nomeC ?? L("App sconosciuta")
            }
            var c = Cartella(url: d, nome: nome, byte: Disco.peso(d))
            c.dettaglio = [installata != nil ? L("l'app è installata ma usa un'altra cartella") : idApp,
                           data.map { L("modificata il %@", $0) },
                           nomeApp == nil && nomeC == nil ? String(d.lastPathComponent.prefix(8)) : nil]
                .compactMap { $0 }.joined(separator: " · ")
            orfani.append(c)
        }
        // file .ipa rimasti da installazioni (Inbox di LiveContainer e file temporanei)
        var ipa: [Cartella] = []
        let casa = r.deletingLastPathComponent()
        for base in [r.appendingPathComponent("Inbox"), casa.appendingPathComponent("tmp"), r] {
            for f in (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
            where ["ipa", "tipa"].contains(f.pathExtension.lowercased()) {
                ipa.append(Cartella(url: f, nome: f.lastPathComponent, byte: (try? fm.attributesOfItem(atPath: f.path)[.size] as? NSNumber)?.int64Value ?? 0))
            }
        }
        return (app.sorted { $0.totale > $1.totale }, orfani.sorted { $0.byte > $1.byte }, ipa)
    }

    /// "com.google.ios.youtube" → "YouTube": app note per nome, le altre dall'ultima parte dell'identificativo
    nonisolated static func nomeDaIdentificativo(_ id: String) -> String {
        let noti: [String: String] = [
            "com.google.ios.youtube": "YouTube", "com.google.ios.youtubemusic": "YouTube Music",
            "net.whatsapp.WhatsApp": "WhatsApp", "ph.telegra.Telegraph": "Telegram",
            "com.burbn.instagram": "Instagram", "com.facebook.Facebook": "Facebook",
            "com.zhiliaoapp.musically": "TikTok", "com.atebits.Tweetie2": "X (Twitter)",
            "com.spotify.client": "Spotify", "dev.linuxrunner.app": "LinuxRunner",
            "com.fmlab.puliziafoto": "FMLAB Cleaner", "com.netflix.Netflix": "Netflix",
            "com.reddit.Reddit": "Reddit", "com.hammerandchisel.discord": "Discord",
            "com.toyopagroup.picaboo": "Snapchat", "com.google.chrome.ios": "Chrome"]
        if let n = noti[id] ?? noti.first(where: { $0.key.lowercased() == id.lowercased() })?.value { return n }
        let generiche: Set<String> = ["app", "ios", "iphone", "mobile", "client", "main", "prod", "release", "lite"]
        let parti = id.split(separator: ".").map(String.init)
        let p = parti.reversed().first { !generiche.contains($0.lowercased()) && $0.count > 1 } ?? parti.last ?? id
        return p.prefix(1).uppercased() + p.dropFirst()
    }

    func svuotaCache(_ a: AppOspitata) async {
        let prima = a.cache
        await Task.detached { for d in a.dati { for c in Disco.cacheDi(d.url) { Disco.svuota(c) } } }.value
        liberato += prima
        await analizza()
    }

    func togliScaricabili(_ a: AppOspitata) async {
        let prima = a.byteScaricabili
        await Task.detached { for u in a.scaricabili { Disco.svuota(u) } }.value
        liberato += prima
        await analizza()
    }

    var whatsapp: AppOspitata? { app.first { $0.isWhatsApp } }
    var telegram: AppOspitata? { app.first { $0.isTelegram } }

    func elimina(_ c: Cartella) async {
        await Task.detached { try? FileManager.default.removeItem(at: c.url) }.value
        liberato += c.byte
        await analizza()
    }
}

struct SchedaApp: View {
    @EnvironmentObject var s: SpazioLC
    @State private var daEliminare: Cartella?
    @State private var cacheDi: AppOspitata?

    var body: some View {
        List {
            Section {
                Text("App installate in LiveContainer: quanto occupano e cosa si può togliere senza perdere niente. Chiudi le altre app prima di svuotarne la cache.")
                    .font(.footnote).foregroundColor(.secondary)
                if s.liberato > 0 {
                    Text("Liberati: \(formatoByte(s.liberato))").font(.headline).foregroundColor(.green)
                }
            }
            Section("App") {
                if s.app.isEmpty && s.analisi { ProgressView() }
                ForEach(s.app) { a in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(a.nome).font(.headline)
                            Spacer()
                            Text(formatoByte(a.totale)).monospacedDigit().foregroundColor(.secondary)
                        }
                        Text("App \(formatoByte(a.byteApp)) · dati \(formatoByte(a.totale - a.byteApp)) · cache \(formatoByte(a.cache))")
                            .font(.caption).foregroundColor(.secondary)
                        if a.cache > 1_000_000 {
                            Button("Svuota cache (\(formatoByte(a.cache)))") { cacheDi = a }
                                .font(.callout).buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if !s.installazioni.isEmpty {
                Section {
                    ForEach(s.installazioni) { c in riga(c) }
                } header: { Text("File di installazione rimasti") } footer: {
                    Text("I file .ipa già installati: l'app resta, il file non serve più.")
                }
            }
            if !s.orfani.isEmpty {
                Section {
                    ForEach(s.orfani) { c in riga(c) }
                } header: { Text("Dati di app tolte") } footer: {
                    Text("Cartelle di dati che nessuna app installata usa più. Controlla il nome prima di toglierle: se reinstalli l'app, i suoi dati vecchi non ci saranno.")
                }
            }
        }
        .navigationTitle("App")
        .refreshable { await s.analizza() }
        .task { if s.app.isEmpty { await s.analizza() } }
        .confirmationDialog("Togliere \(daEliminare?.nome ?? "")?", isPresented: Binding(get: { daEliminare != nil }, set: { if !$0 { daEliminare = nil } }), titleVisibility: .visible) {
            Button("Togli \(formatoByte(daEliminare?.byte ?? 0))", role: .destructive) {
                if let c = daEliminare { Task { await s.elimina(c) } }
            }
        } message: { Text("Non si può annullare.") }
        .confirmationDialog("Svuotare la cache di \(cacheDi?.nome ?? "")?", isPresented: Binding(get: { cacheDi != nil }, set: { if !$0 { cacheDi = nil } }), titleVisibility: .visible) {
            Button("Svuota \(formatoByte(cacheDi?.cache ?? 0))", role: .destructive) {
                if let a = cacheDi { Task { await s.svuotaCache(a) } }
            }
        } message: { Text("Sono file che l'app ricrea da sola quando servono. Documenti e impostazioni restano.") }
    }

    func riga(_ c: Cartella) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(c.nome).lineLimit(1)
                Text(c.dettaglio.isEmpty ? formatoByte(c.byte) : "\(formatoByte(c.byte)) · \(c.dettaglio)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("Togli") { daEliminare = c }.buttonStyle(.bordered).tint(.red)
        }
    }
}
