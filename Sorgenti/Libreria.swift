// FMLAB Cleaner - analisi della libreria Foto dell'iPhone, tutta sul telefono.
// Niente rete, niente abbonamenti: si legge la libreria con PhotoKit e si cancella solo cio' che
// scegli tu. iOS chiede sempre conferma e tutto finisce in "Eliminati di recente" (30 giorni).
import Foundation
import Photos
import SwiftUI

enum Categoria: String, CaseIterable, Identifiable {
    case videoGrandi, doppioni, registrazioni, screenshot, raffiche

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .videoGrandi: return "Video grandi"
        case .doppioni: return "Doppioni"
        case .registrazioni: return "Registrazioni dello schermo"
        case .screenshot: return "Screenshot"
        case .raffiche: return "Scatti a raffica in più"
        }
    }

    var icona: String {
        switch self {
        case .videoGrandi: return "film"
        case .doppioni: return "square.on.square"
        case .registrazioni: return "record.circle"
        case .screenshot: return "camera.viewfinder"
        case .raffiche: return "square.stack.3d.down.right"
        }
    }

    var spiegazione: String {
        switch self {
        case .videoGrandi:
            return "I video da 50 MB in su, dal più pesante. Puoi toglierli oppure comprimerli: restano uguali sul telefono e pesano circa la metà."
        case .doppioni:
            return "Foto e video identici (stesse dimensioni e stesso peso). Il più vecchio di ogni gruppo resta: gli altri sono già selezionati."
        case .registrazioni:
            return "Le registrazioni dello schermo: di solito servono una volta sola."
        case .screenshot:
            return "Tutti gli screenshot, dal più vecchio."
        case .raffiche:
            return "Gli scatti di una raffica che non hai scelto come preferiti. Quello principale resta."
        }
    }

    /// Nelle categorie "sicure" gli elementi partono gia' selezionati.
    var preselezione: Bool { self == .doppioni || self == .raffiche }
}

struct Elemento: Identifiable, Hashable {
    let asset: PHAsset
    let byte: Int64
    let gruppo: Int        // doppioni: numero del gruppo (0 = nessun gruppo)
    let daTenere: Bool     // doppioni: l'originale da tenere

    var id: String { asset.localIdentifier }

    static func == (a: Elemento, b: Elemento) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Risultato {
    var categorie: [Categoria: [Elemento]] = [:]
    var totale: Int64 = 0
    var foto = 0
    var video = 0
}

func formatoByte(_ b: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = [.useKB, .useMB, .useGB]
    return f.string(fromByteCount: b)
}

enum Analizzatore {
    static let sogliaVideo: Int64 = 50 * 1024 * 1024

    /// Peso di un elemento: somma delle sue risorse (una Live Photo ha foto + video).
    /// Per le foto ottimizzate su iCloud e' il peso dell'originale.
    static func peso(_ a: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: a).reduce(0) { somma, r in
            somma + ((r.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0)
        }
    }

    /// Registrazione dello schermo: iOS 17+ la marca con un sottotipo; prima si riconosce dal nome
    /// che iOS da' sempre a questi file (RPReplay_...).
    static func registrazione(_ a: PHAsset) -> Bool {
        if a.mediaSubtypes.contains(PHAssetMediaSubtype(rawValue: 1 << 15)) { return true }
        return PHAssetResource.assetResources(for: a).contains { $0.originalFilename.hasPrefix("RPReplay") }
    }

    static func esegui(progresso: @escaping (Double) -> Void) -> Risultato {
        var ris = Risultato()
        let opzioni = PHFetchOptions()
        opzioni.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let tutti = PHAsset.fetchAssets(with: opzioni)
        let n = tutti.count
        var video: [Elemento] = []
        var registrazioni: [Elemento] = []
        var screenshot: [Elemento] = []
        var raffiche: [Elemento] = []
        var perChiave: [String: [Elemento]] = [:]

        for i in 0..<n {
            let a = tutti.object(at: i)
            let b = peso(a)
            ris.totale += b
            let e = Elemento(asset: a, byte: b, gruppo: 0, daTenere: false)
            if a.mediaType == .video {
                ris.video += 1
                if registrazione(a) {
                    registrazioni.append(e)
                } else if b >= sogliaVideo {
                    video.append(e)
                }
            } else if a.mediaType == .image {
                ris.foto += 1
                if a.mediaSubtypes.contains(.photoScreenshot) { screenshot.append(e) }
                if a.representsBurst, let id = a.burstIdentifier {
                    raffiche.append(contentsOf: scartiRaffica(id, principale: a))
                }
            }
            if b > 0 {
                // identici: stesso tipo, stesse dimensioni, stesso peso esatto (e stessa durata per i video)
                let durata = a.mediaType == .video ? Int(a.duration.rounded()) : 0
                let chiave = "\(a.mediaType.rawValue)-\(a.pixelWidth)x\(a.pixelHeight)-\(b)-\(durata)"
                perChiave[chiave, default: []].append(e)
            }
            if i % 150 == 0 { progresso(Double(i) / Double(max(n, 1))) }
        }

        var doppioni: [Elemento] = []
        var g = 0
        for gruppo in perChiave.values where gruppo.count > 1 {
            g += 1
            // gia' in ordine di data: il primo (il piu' vecchio) e' l'originale
            for (k, e) in gruppo.enumerated() {
                doppioni.append(Elemento(asset: e.asset, byte: e.byte, gruppo: g, daTenere: k == 0))
            }
        }
        // gruppi con piu' spazio da recuperare per primi
        let recuperabile = Dictionary(grouping: doppioni, by: \.gruppo)
            .mapValues { $0.filter { !$0.daTenere }.reduce(0) { $0 + $1.byte } }
        doppioni.sort {
            let ra = recuperabile[$0.gruppo] ?? 0, rb = recuperabile[$1.gruppo] ?? 0
            if ra != rb { return ra > rb }
            if $0.gruppo != $1.gruppo { return $0.gruppo < $1.gruppo }
            return $0.daTenere && !$1.daTenere
        }

        ris.categorie[.videoGrandi] = video.sorted { $0.byte > $1.byte }
        ris.categorie[.doppioni] = doppioni
        ris.categorie[.registrazioni] = registrazioni.sorted { $0.byte > $1.byte }
        ris.categorie[.screenshot] = screenshot
        ris.categorie[.raffiche] = raffiche
        progresso(1)
        return ris
    }

    /// Gli scatti di una raffica diversi dal principale e non scelti dall'utente.
    static func scartiRaffica(_ id: String, principale: PHAsset) -> [Elemento] {
        let o = PHFetchOptions()
        o.includeAllBurstAssets = true
        let tutti = PHAsset.fetchAssets(withBurstIdentifier: id, options: o)
        var out: [Elemento] = []
        tutti.enumerateObjects { a, _, _ in
            if a.localIdentifier != principale.localIdentifier && !a.burstSelectionTypes.contains(.userPick) && !a.isFavorite {
                out.append(Elemento(asset: a, byte: peso(a), gruppo: 0, daTenere: false))
            }
        }
        return out
    }
}

@MainActor
final class Libreria: ObservableObject {
    @Published var permesso: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var analisiInCorso = false
    @Published var progresso: Double = 0
    @Published var risultato = Risultato()
    @Published var analizzata = false
    @Published var liberato: Int64 = 0

    var accesso: Bool { permesso == .authorized || permesso == .limited }

    func chiediPermesso() async {
        permesso = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if accesso { await analizza() }
    }

    func analizza() async {
        guard accesso, !analisiInCorso else { return }
        analisiInCorso = true
        progresso = 0
        let r = await Task.detached(priority: .userInitiated) { () -> Risultato in
            Analizzatore.esegui { p in
                Task { @MainActor in self.progresso = p }
            }
        }.value
        risultato = r
        analizzata = true
        analisiInCorso = false
        await leggiCestino()
    }

    // MARK: Eliminati di recente
    // L'app Foto carica a pezzi l'album "Eliminati di recente". iOS non lo elenca tra gli album pubblici:
    // si raggiunge col suo numero interno (1000000201). Se in questa versione di iOS non risponde,
    // l'app lo dice e spiega il modo manuale.
    @Published var cestino: (numero: Int, byte: Int64)?
    @Published var cestinoNonRaggiungibile = false
    @Published var cestinoInLettura = false

    nonisolated static func elementiCestino() -> [PHAsset] {
        guard let sub = PHAssetCollectionSubtype(rawValue: 1000000201),
              let album = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: sub, options: nil).firstObject
        else { return [] }
        let r = PHAsset.fetchAssets(in: album, options: nil)
        var out: [PHAsset] = []
        out.reserveCapacity(r.count)
        r.enumerateObjects { a, _, _ in out.append(a) }
        return out
    }

    func leggiCestino() async {
        guard accesso, !cestinoInLettura else { return }
        cestinoInLettura = true
        let r = await Task.detached(priority: .utility) { () -> (Int, Int64) in
            let a = Libreria.elementiCestino()
            return (a.count, a.reduce(0) { $0 + Analizzatore.peso($1) })
        }.value
        cestino = r.0 > 0 ? (r.0, r.1) : nil
        cestinoNonRaggiungibile = r.0 == 0 && liberato > 0
        cestinoInLettura = false
    }

    /// Cancella per sempre tutto "Eliminati di recente" in una volta (iOS chiede conferma).
    func svuotaCestino() async throws {
        let assets = await Task.detached { Libreria.elementiCestino() }.value
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
        await leggiCestino()
    }

    func elementi(_ c: Categoria) -> [Elemento] { risultato.categorie[c] ?? [] }

    func peso(_ c: Categoria) -> Int64 {
        elementi(c).filter { !$0.daTenere }.reduce(0) { $0 + $1.byte }
    }

    /// Cancella con la conferma di iOS. Gli elementi vanno in "Eliminati di recente".
    func elimina(_ scelti: [Elemento]) async throws {
        let assets = scelti.map(\.asset) as NSArray
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
        let via = Set(scelti.map(\.id))
        liberato += scelti.reduce(0) { $0 + $1.byte }
        for c in Categoria.allCases {
            risultato.categorie[c] = elementi(c).filter { !via.contains($0.id) }
        }
        // doppioni: un gruppo rimasto con un solo elemento non e' piu' un doppione
        let conteggi = Dictionary(grouping: elementi(.doppioni), by: \.gruppo).mapValues(\.count)
        risultato.categorie[.doppioni] = elementi(.doppioni).filter { (conteggi[$0.gruppo] ?? 0) > 1 }
        risultato.totale -= scelti.reduce(0) { $0 + $1.byte }
        await leggiCestino()
    }
}
