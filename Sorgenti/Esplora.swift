// Esplora una cartella dell'app File: cosa c'e' dentro e quanto pesa, dal piu' pesante.
// Le sottocartelle si aprono toccandole; un file si toglie scorrendo a sinistra (va nel cestino di File).
import SwiftUI

struct VoceCartella: Identifiable, Hashable {
    let url: URL
    let nome: String
    let cartella: Bool
    let byte: Int64
    let elementi: Int
    let data: Date?
    let soloICloud: Bool
    var id: String { url.path }
}

enum Esploratore {
    /// Contenuto di primo livello con il peso di ogni voce (le cartelle contano tutto quello che hanno dentro)
    static func leggi(_ u: URL) -> [VoceCartella] {
        let fm = FileManager.default
        let chiavi: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey,
                                        .contentModificationDateKey, .isPackageKey]
        let voci = (try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: chiavi, options: [])) ?? []
        var out: [VoceCartella] = []
        for v in voci {
            var nome = v.lastPathComponent
            let segnaposto = nome.hasPrefix(".") && nome.hasSuffix(".icloud")
            if segnaposto { nome = String(nome.dropFirst().dropLast(7)) } else if nome.hasPrefix(".") { continue }
            let r = try? v.resourceValues(forKeys: Set(chiavi))
            let dir = r?.isDirectory == true && r?.isPackage != true
            if dir {
                let n = (try? fm.contentsOfDirectory(atPath: v.path))?.filter { !$0.hasPrefix(".") || $0.hasSuffix(".icloud") }.count ?? 0
                out.append(VoceCartella(url: v, nome: nome, cartella: true, byte: Disco.peso(v), elementi: n,
                                        data: r?.contentModificationDate, soloICloud: false))
            } else {
                let b = r?.isPackage == true ? Disco.peso(v) : Int64(r?.fileSize ?? r?.totalFileAllocatedSize ?? 0)
                out.append(VoceCartella(url: v, nome: nome, cartella: false, byte: b, elementi: 0,
                                        data: r?.contentModificationDate, soloICloud: segnaposto))
            }
        }
        return out.sorted { $0.byte != $1.byte ? $0.byte > $1.byte : $0.nome.localizedCompare($1.nome) == .orderedAscending }
    }
}

struct EsploraCartella: View {
    @EnvironmentObject var archivio: ArchivioFile
    let url: URL
    /// cartella scelta dall'utente: va "aperta" perche' iOS dia il permesso di leggere e togliere
    let base: URL?
    @State private var voci: [VoceCartella] = []
    @State private var caricamento = true
    @State private var daTogliere: VoceCartella?
    @State private var errore: String?

    var totale: Int64 { voci.reduce(0) { $0 + $1.byte } }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(caricamento ? L("Calcolo…") : contaElementi(voci.count)).foregroundColor(.secondary)
                    Spacer()
                    if caricamento { ProgressView() } else { Text(formatoByte(totale)).bold().monospacedDigit() }
                }
                if let e = errore { Text(e).font(.footnote).foregroundColor(.orange) }
            } footer: {
                Text(L("Dal più pesante. Tocca una cartella per aprirla, scorri a sinistra su un file per toglierlo."))
            }
            if !caricamento && voci.isEmpty {
                Text(L("Cartella vuota")).foregroundColor(.secondary)
            }
            ForEach(voci) { v in
                if v.cartella {
                    NavigationLink(destination: EsploraCartella(url: v.url, base: base)) { riga(v) }
                } else {
                    riga(v)
                        .swipeActions { Button(L("Togli"), role: .destructive) { daTogliere = v } }
                }
            }
        }
        .navigationTitle(nomeCartella(url))
        .navigationBarTitleDisplayMode(.inline)
        .task { await carica() }
        .refreshable { await carica() }
        .confirmationDialog(L("Togliere %@ (%@)?", daTogliere?.nome ?? "", formatoByte(daTogliere?.byte ?? 0)),
                            isPresented: Binding(get: { daTogliere != nil }, set: { if !$0 { daTogliere = nil } }),
                            titleVisibility: .visible) {
            Button(L("Sposta nel cestino di File"), role: .destructive) {
                if let v = daTogliere { Task { await togli(v) } }
            }
        } message: { Text(L("Di solito finiscono in File → Eliminati di recente (30 giorni). Dove iOS non ha il cestino, vengono cancellati subito.")) }
    }

    func riga(_ v: VoceCartella) -> some View {
        HStack(spacing: 12) {
            Image(systemName: v.cartella ? "folder.fill" : (v.soloICloud ? "icloud" : icona(v.url)))
                .foregroundColor(v.cartella ? Tema.rosso : .secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.nome).lineLimit(2)
                Text([v.cartella ? contaElementi(v.elementi) : nil,
                      v.data.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) },
                      v.soloICloud ? L("solo su iCloud") : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(v.byte > 0 ? formatoByte(v.byte) : "—").foregroundColor(.secondary).monospacedDigit()
        }
    }

    func icona(_ u: URL) -> String {
        switch u.pathExtension.lowercased() {
        case "ipa", "tipa", "zip", "rar", "7z", "gz", "tar", "xz", "dmg", "pkg", "apk", "iso": return "archivebox"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo"
        case "mov", "mp4", "m4v", "avi", "mkv": return "film"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    func carica() async {
        caricamento = true
        let u = url, b = base
        voci = await Task.detached(priority: .userInitiated) { () -> [VoceCartella] in
            let aperta = b?.startAccessingSecurityScopedResource() ?? false
            defer { if aperta { b?.stopAccessingSecurityScopedResource() } }
            return Esploratore.leggi(u)
        }.value
        caricamento = false
    }

    func togli(_ v: VoceCartella) async {
        let b = base
        let f = FileTrovato(url: v.url, byte: v.byte, data: v.data, soloICloud: v.soloICloud)
        let e = await Task.detached { () -> String? in
            let aperta = b?.startAccessingSecurityScopedResource() ?? false
            defer { if aperta { b?.stopAccessingSecurityScopedResource() } }
            return ArchivioFile.eliminaUno(f)
        }.value
        if let e { errore = "\(v.nome): \(e)" } else {
            errore = nil
            archivio.liberato += v.byte
            voci.removeAll { $0.id == v.id }
            Vibrazione.fatto()
        }
    }
}
