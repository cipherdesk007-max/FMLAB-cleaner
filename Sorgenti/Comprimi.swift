// Compressione dei video: stesso video, molto piu' leggero (HEVC, al massimo 1080p).
// L'originale si toglie solo dopo che la copia compressa e' salvata in Foto, con data, luogo e
// preferito dell'originale; iOS chiede conferma e l'originale va in "Eliminati di recente".
import AVFoundation
import Photos
import SwiftUI
import UIKit

enum ErroreCompressione: LocalizedError {
    case video, esportazione(String), nonConviene
    var errorDescription: String? {
        switch self {
        case .video: return "Video non leggibile (forse ancora su iCloud senza rete)."
        case .esportazione(let m): return "Compressione non riuscita: \(m)"
        case .nonConviene: return "Già compresso: la copia non sarebbe più leggera."
        }
    }
}

enum Compressore {
    /// I rallentatori e i video Cinematografici perderebbero l'effetto: si saltano.
    static func adatto(_ a: PHAsset) -> Bool {
        a.mediaType == .video && !a.mediaSubtypes.contains(.videoHighFrameRate)
            && !a.mediaSubtypes.contains(PHAssetMediaSubtype(rawValue: 1 << 21)) // Cinematografico
    }

    static func avAsset(_ a: PHAsset) async -> AVAsset? {
        await withCheckedContinuation { (c: CheckedContinuation<AVAsset?, Never>) in
            let o = PHVideoRequestOptions()
            o.version = .current
            o.deliveryMode = .highQualityFormat
            o.isNetworkAccessAllowed = true
            var fatto = false
            PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                if !fatto { fatto = true; c.resume(returning: av) }
            }
        }
    }

    /// Comprime e salva la copia in Foto. Restituisce i byte della copia.
    static func comprimi(_ e: Elemento, avanzamento: @escaping (Double) -> Void) async throws -> Int64 {
        guard let av = await avAsset(e.asset) else { throw ErroreCompressione.video }
        let lato = max(e.asset.pixelWidth, e.asset.pixelHeight)
        let preset = lato > 1920 ? AVAssetExportPresetHEVC1920x1080 : AVAssetExportPresetHEVCHighestQuality
        guard let s = AVAssetExportSession(asset: av, presetName: preset) else {
            throw ErroreCompressione.esportazione("formato non supportato")
        }
        let uscita = FileManager.default.temporaryDirectory
            .appendingPathComponent("fmlab-\(UUID().uuidString).mov")
        s.outputURL = uscita
        s.outputFileType = .mov
        s.metadata = av.metadata
        s.shouldOptimizeForNetworkUse = false

        let timer = Task {
            while !Task.isCancelled {
                avanzamento(Double(s.progress))
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            s.exportAsynchronously { c.resume() }
        }
        timer.cancel()
        guard s.status == .completed else {
            try? FileManager.default.removeItem(at: uscita)
            throw ErroreCompressione.esportazione(s.error?.localizedDescription ?? "interrotta")
        }
        let nuovo = (try? FileManager.default.attributesOfItem(atPath: uscita.path)[.size] as? NSNumber)?.int64Value ?? 0
        // conviene solo se si risparmia almeno il 15%
        guard nuovo > 0, Double(nuovo) < Double(e.byte) * 0.85 else {
            try? FileManager.default.removeItem(at: uscita)
            throw ErroreCompressione.nonConviene
        }
        let originale = e.asset
        try await PHPhotoLibrary.shared().performChanges {
            let r = PHAssetCreationRequest.forAsset()
            let o = PHAssetResourceCreationOptions()
            o.shouldMoveFile = true
            r.addResource(with: .video, fileURL: uscita, options: o)
            r.creationDate = originale.creationDate
            r.location = originale.location
            r.isFavorite = originale.isFavorite
        }
        avanzamento(1)
        return nuovo
    }
}

struct VoceCompressione: Identifiable {
    let elemento: Elemento
    var stato = "in attesa"
    var avanzamento: Double = 0
    var nuovo: Int64 = 0
    var fatto = false
    var id: String { elemento.id }
}

struct Compressione: View {
    @EnvironmentObject var lib: Libreria
    @Environment(\.dismiss) var chiudi
    let elementi: [Elemento]
    @State private var voci: [VoceCompressione] = []
    @State private var lavoro: Task<Void, Never>?
    @State private var finito = false
    @State private var messaggio: String?

    var risparmio: Int64 { voci.filter(\.fatto).reduce(0) { $0 + ($1.elemento.byte - $1.nuovo) } }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("I video diventano HEVC, al massimo 1080p: si vedono uguali sul telefono e pesano molto meno. Data, luogo e preferiti restano. Tieni l'app aperta: con tanti video ci vuole un po'.")
                        .font(.footnote).foregroundColor(.secondary)
                    if risparmio > 0 {
                        Text("Risparmio finora: \(formatoByte(risparmio))").font(.headline).foregroundColor(.green)
                    }
                    if let m = messaggio { Text(m).font(.callout) }
                }
                Section("Video") {
                    ForEach(voci) { v in
                        HStack(spacing: 12) {
                            Miniatura(asset: v.elemento.asset).frame(width: 52, height: 52).cornerRadius(6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.fatto ? "\(formatoByte(v.elemento.byte)) → \(formatoByte(v.nuovo))" : formatoByte(v.elemento.byte))
                                    .monospacedDigit()
                                if !v.fatto && v.avanzamento > 0 && v.avanzamento < 1 {
                                    ProgressView(value: v.avanzamento)
                                }
                                Text(v.stato).font(.caption).foregroundColor(v.fatto ? .green : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Comprimi video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(finito ? "Fine" : "Ferma") { lavoro?.cancel(); chiudi() }
                }
            }
        }
        .onAppear {
            guard voci.isEmpty else { return }
            voci = elementi.filter { Compressore.adatto($0.asset) }.map { VoceCompressione(elemento: $0) }
            let saltati = elementi.count - voci.count
            if saltati > 0 { messaggio = "\(saltati) video saltati (rallentatori o Cinematografici)." }
            lavoro = Task { await esegui() }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    func esegui() async {
        UIApplication.shared.isIdleTimerDisabled = true   // lo schermo non si spegne a meta'
        var originali: [Elemento] = []
        for i in voci.indices {
            if Task.isCancelled { break }
            voci[i].stato = "compressione…"
            let el = voci[i].elemento
            do {
                let n = try await Compressore.comprimi(el) { p in
                    Task { @MainActor in voci[i].avanzamento = p }
                }
                voci[i].nuovo = n
                voci[i].fatto = true
                voci[i].stato = "fatto: \(Int((1 - Double(n) / Double(max(el.byte, 1))) * 100))% in meno"
                originali.append(el)
            } catch {
                voci[i].stato = error.localizedDescription
            }
        }
        UIApplication.shared.isIdleTimerDisabled = false
        if !originali.isEmpty {
            do {
                try await lib.elimina(originali)
                messaggio = "Fatto. Gli originali sono in \"Eliminati di recente\": svuotalo per avere lo spazio."
            } catch {
                messaggio = "Le copie compresse sono in Foto; gli originali sono rimasti (cancellazione non confermata)."
            }
            await lib.analizza()
        }
        finito = true
    }
}
