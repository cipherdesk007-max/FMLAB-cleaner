// Controlla su GitHub se c'e' una versione nuova di FMLAB Cleaner (pubblicata solo se compilata
// senza errori). Se c'e', un tocco apre il download del file .ipa: in LiveContainer si
// installa sopra la vecchia (+ in alto a destra -> il file scaricato) e i dati restano.
import Foundation
import SwiftUI

@MainActor
final class Aggiornamenti: ObservableObject {
    // Il numero di versione e il file .ipa stanno nella stessa pubblicazione "ultima" del repository
    // FMLAB-cleaner: escono insieme, quindi l'avviso compare solo quando il file nuovo e' davvero pronto.
    static let urlVersione = URL(string: "https://github.com/cipherdesk007-max/FMLAB-cleaner/releases/download/ultima/VERSIONE")!
    static let urlIpa = URL(string: "https://github.com/cipherdesk007-max/FMLAB-cleaner/releases/download/ultima/FMLAB-Cleaner.ipa")!

    @Published var nuova: String?
    @Published var controllo = false
    @Published var esito: String?

    var attuale: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }

    func controlla(manuale: Bool = false) async {
        controllo = true
        defer { controllo = false }
        var r = URLRequest(url: URL(string: Self.urlVersione.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))")!)
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.timeoutInterval = 15
        guard let (dati, risposta) = try? await URLSession.shared.data(for: r),
              (risposta as? HTTPURLResponse)?.statusCode == 200,
              let v = String(data: dati, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              v.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else {
            if manuale { esito = "Nessuna connessione con GitHub: riprova più tardi." }
            return
        }
        if Self.piuNuova(v, di: attuale) {
            nuova = v
            esito = nil
        } else {
            nuova = nil
            if manuale { esito = "Sei già all'ultima versione (\(attuale))." }
        }
    }

    static func piuNuova(_ a: String, di b: String) -> Bool {
        let x = a.split(separator: ".").compactMap { Int($0) }, y = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

struct AvvisoAggiornamento: View {
    @ObservedObject var agg: Aggiornamenti
    @Environment(\.openURL) var apri

    var body: some View {
        if let v = agg.nuova {
            Button {
                apri(Aggiornamenti.urlIpa)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Versione \(v) disponibile", systemImage: "arrow.down.circle.fill").font(.headline)
                    Text("Tocca per scaricarla, poi in LiveContainer: + in alto a destra → il file scaricato.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        }
    }
}
