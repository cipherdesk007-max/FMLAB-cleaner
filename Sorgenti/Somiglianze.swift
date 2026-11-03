// Analisi approfondita delle foto, tutta sul telefono (Vision di Apple, niente internet):
//  - foto simili: scatti quasi uguali fatti a pochi secondi di distanza; in ogni gruppo resta la piu' nitida
//  - foto sfocate e foto buie (da controllare: non sono mai preselezionate)
// Si lancia a richiesta, perche' guarda ogni foto: su migliaia di foto servono alcuni minuti.
import CoreGraphics
import Foundation
import Photos
import UIKit
import Vision

struct EsitoImmagini {
    var simili: [Elemento] = []
    var sfocate: [Elemento] = []
    var buie: [Elemento] = []
    var analizzate = 0
}

enum AnalisiImmagini {
    /// Due scatti sono "simili" se sono a meno di 2 minuti di distanza e la distanza Vision e' sotto soglia.
    static let finestra: TimeInterval = 120
    static let sogliaSimili: Float = 9          // Vision feature print, revisione 1
    static let sogliaSfocata: Double = 18       // varianza del Laplaciano su 128x128 in scala di grigi
    static let sogliaBuia: Double = 28          // luminosita' media 0-255

    /// Miniatura locale (niente download da iCloud: si usano le anteprime gia' sul telefono).
    static func miniatura(_ a: PHAsset) -> CGImage? {
        let o = PHImageRequestOptions()
        o.isSynchronous = true
        o.deliveryMode = .highQualityFormat
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = false
        var img: CGImage?
        PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: 256, height: 256),
                                              contentMode: .aspectFit, options: o) { ui, _ in img = ui?.cgImage }
        return img
    }

    /// Nitidezza (varianza del Laplaciano) e luminosita' media su una copia 128x128 in grigio.
    static func nitidezzaELuce(_ cg: CGImage) -> (Double, Double) {
        let w = 128, h = 128
        var px = [UInt8](repeating: 0, count: w * h)
        let ok: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return (1000, 128) }
        var somma = 0.0, somma2 = 0.0, luce = 0.0, n = 0.0
        for v in px { luce += Double(v) }
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let l = 4 * Double(px[i]) - Double(px[i - 1]) - Double(px[i + 1]) - Double(px[i - w]) - Double(px[i + w])
                somma += l; somma2 += l * l; n += 1
            }
        }
        let media = somma / n
        return (somma2 / n - media * media, luce / Double(w * h))
    }

    static func impronta(_ cg: CGImage) -> VNFeaturePrintObservation? {
        let r = VNGenerateImageFeaturePrintRequest()
        r.revision = VNGenerateImageFeaturePrintRequestRevision1   // distanze stabili tra versioni di iOS
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r])
        return r.results?.first as? VNFeaturePrintObservation
    }

    static func esegui(pesi: [String: Int64], annullata: () -> Bool, progresso: @escaping (Double) -> Void) -> EsitoImmagini {
        var esito = EsitoImmagini()
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        o.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let foto = PHAsset.fetchAssets(with: o)
        let n = foto.count

        var gruppo: [(PHAsset, Double)] = []      // (foto, nitidezza) del gruppo in corso
        var precedente: (PHAsset, VNFeaturePrintObservation)?
        var g = 1_000_000                          // numeri dei gruppi separati da quelli dei doppioni

        func chiudiGruppo() {
            defer { gruppo = [] }
            guard gruppo.count > 1 else { return }
            g += 1
            // resta la piu' nitida (a parita': preferita)
            let migliore = gruppo.max { a, b in
                (a.0.isFavorite ? 1e9 : 0) + a.1 < (b.0.isFavorite ? 1e9 : 0) + b.1
            }!.0.localIdentifier
            for (a, _) in gruppo {
                esito.simili.append(Elemento(asset: a, byte: pesi[a.localIdentifier] ?? 0, gruppo: g,
                                             daTenere: a.localIdentifier == migliore || a.isFavorite))
            }
        }

        for i in 0..<n {
            if annullata() { break }
            let a = foto.object(at: i)
            if i % 25 == 0 { progresso(Double(i) / Double(max(n, 1))) }
            if a.mediaSubtypes.contains(.photoScreenshot) { chiudiGruppo(); precedente = nil; continue }
            autoreleasepool {
                guard let cg = miniatura(a) else { return }
                esito.analizzate += 1
                let (nitidezza, luce) = nitidezzaELuce(cg)
                let e = Elemento(asset: a, byte: pesi[a.localIdentifier] ?? 0, gruppo: 0, daTenere: false)
                if luce < sogliaBuia { esito.buie.append(e) } else if nitidezza < sogliaSfocata { esito.sfocate.append(e) }

                guard let fp = impronta(cg) else { chiudiGruppo(); precedente = nil; return }
                var simile = false
                if let p = precedente,
                   let d1 = p.0.creationDate, let d2 = a.creationDate, d2.timeIntervalSince(d1) <= finestra {
                    var dist: Float = .greatestFiniteMagnitude
                    try? fp.computeDistance(&dist, to: p.1)
                    simile = dist < sogliaSimili
                }
                if simile {
                    if gruppo.isEmpty, let pa = precedente?.0 {
                        // la foto precedente apre il gruppo (la sua nitidezza si ricalcola qui)
                        let np = miniatura(pa).map { nitidezzaELuce($0).0 } ?? 0
                        gruppo.append((pa, np))
                    }
                    gruppo.append((a, nitidezza))
                } else {
                    chiudiGruppo()
                }
                precedente = (a, fp)
            }
        }
        chiudiGruppo()
        esito.sfocate.sort { $0.byte > $1.byte }
        esito.buie.sort { $0.byte > $1.byte }
        progresso(1)
        return esito
    }
}
