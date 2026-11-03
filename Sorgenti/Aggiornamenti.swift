// Controlla su GitHub se c'e' una versione nuova di FMLAB Cleaner (pubblicata solo se compilata
// senza errori). Per installarla non serve scaricare file (la cartella Download su iCloud puo' dare
// errore): si copia il link e LiveContainer lo installa da solo con "+ -> Installa dall'URL".
import Foundation
import SwiftUI
import UIKit

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
            if manuale { esito = L("Nessuna connessione con GitHub: riprova più tardi.") }
            return
        }
        if Self.piuNuova(v, di: attuale) {
            nuova = v
            esito = nil
        } else {
            nuova = nil
            if manuale { esito = L("Sei già all'ultima versione (%@).", attuale) }
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
    @State private var copiato = false

    var body: some View {
        if let v = agg.nuova {
            VStack(alignment: .leading, spacing: 10) {
                Label("Versione \(v) disponibile", systemImage: "arrow.down.circle.fill").font(.headline)
                if copiato {
                    Text("Link copiato. Ora: chiudi FMLAB Cleaner, in LiveContainer tocca + → Installa dall'URL → Incolla → OK. Si installa sopra questa, i dati restano.")
                        .font(.callout)
                } else {
                    Text("Senza scaricare file: copia il link e installalo da LiveContainer (+ → Installa dall'URL).")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Button {
                    UIPasteboard.general.string = Aggiornamenti.urlIpa.absoluteString
                    Vibrazione.fatto()
                    copiato = true
                } label: {
                    Label(copiato ? L("Link copiato") : L("Copia link di installazione"),
                          systemImage: copiato ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Oppure scarica il file .ipa") { apri(Aggiornamenti.urlIpa) }
                    .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }
}
