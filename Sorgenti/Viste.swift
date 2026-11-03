import Photos
import SwiftUI
import UIKit

@main
struct PuliziaFotoApp: App {
    @StateObject private var libreria = Libreria()
    @StateObject private var aggiornamenti = Aggiornamenti()

    init() { Tema.applica() }

    var body: some Scene {
        WindowGroup {
            TabView {
                Principale()
                    .tabItem { Label("Pulizia", systemImage: "sparkles") }
                if SpazioLC.disponibile {
                    NavigationView { SchedaApp() }
                        .navigationViewStyle(.stack)
                        .tabItem { Label("App", systemImage: "square.grid.2x2") }
                }
                NavigationView { Telefono() }
                    .navigationViewStyle(.stack)
                    .tabItem { Label("Telefono", systemImage: "iphone") }
            }
                .environmentObject(libreria)
                .environmentObject(aggiornamenti)
                .task { await aggiornamenti.controlla() }
                .tint(Tema.rosso)
                .accentColor(Tema.rosso)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - schermata principale

struct Principale: View {
    @EnvironmentObject var lib: Libreria

    var body: some View {
        NavigationView {
            Group {
                if !lib.accesso {
                    Permesso()
                } else if lib.analisiInCorso && !lib.analizzata {
                    Analisi()
                } else {
                    Riepilogo()
                }
            }
            .navigationTitle("FMLAB Cleaner")
        }
        .navigationViewStyle(.stack)
        .task { if lib.accesso && !lib.analizzata { await lib.analizza() } }
    }
}

struct Permesso: View {
    @EnvironmentObject var lib: Libreria

    var body: some View {
        VStack(spacing: 18) {
            Logo(lato: 110)
            Text("Trova video grandi, doppioni e screenshot da togliere.")
                .font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            Text("Tutto resta sul telefono: niente internet, niente abbonamenti. Non cancello niente da sola: scegli tu, iOS chiede conferma e le foto finiscono in \"Eliminati di recente\" per 30 giorni.")
                .font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
            if lib.permesso == .denied || lib.permesso == .restricted {
                Text("Accesso alle foto negato. Apri Impostazioni → LiveContainer (o FMLAB Cleaner) → Foto → Tutte le foto.")
                    .font(.callout).foregroundColor(.orange).multilineTextAlignment(.center)
                Button("Apri Impostazioni") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }.buttonStyle(.borderedProminent)
            } else {
                Button("Consenti l'accesso alle foto") { Task { await lib.chiediPermesso() } }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(28)
    }
}

struct Analisi: View {
    @EnvironmentObject var lib: Libreria

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: lib.progresso)
            Text("Analizzo la libreria… \(Int(lib.progresso * 100))%").foregroundColor(.secondary)
            Text("Con migliaia di foto può volerci un minuto.").font(.footnote).foregroundColor(.secondary)
        }
        .padding(32)
    }
}

struct Riepilogo: View {
    @EnvironmentObject var lib: Libreria
    @EnvironmentObject var agg: Aggiornamenti
    @State private var svuota = false
    @Environment(\.openURL) var apri
    @State private var erroreCestino: String?

    var recuperabile: Int64 { Categoria.allCases.reduce(0) { $0 + lib.peso($1) } }

    var body: some View {
        List {
            if agg.nuova != nil { Section { AvvisoAggiornamento(agg: agg) } }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatoByte(lib.risultato.totale)).font(.system(size: 34, weight: .bold))
                    Text("\(lib.risultato.foto) foto · \(lib.risultato.video) video")
                        .foregroundColor(.secondary)
                    if recuperabile > 0 {
                        Text("Puoi liberare fino a \(formatoByte(recuperabile))")
                            .font(.headline).foregroundColor(Tema.rosso)
                    }
                    if lib.liberato > 0 {
                        Text("Già tolti: \(formatoByte(lib.liberato)) — svuota \"Eliminati di recente\" in Foto per avere lo spazio subito.")
                            .font(.footnote).foregroundColor(.green)
                    }
                    if lib.permesso == .limited {
                        Text("Accesso limitato: vedo solo le foto che hai scelto.")
                            .font(.footnote).foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 6)
            }
            Section {
                if let c = lib.cestino {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Eliminati di recente: \(c.numero) elementi · \(formatoByte(c.byte))", systemImage: "trash")
                            .font(.headline)
                        Text("Occupano ancora spazio finché non svuoti il cestino (iOS li tiene 30 giorni).")
                            .font(.footnote).foregroundColor(.secondary)
                        Button(role: .destructive) { svuota = true } label: {
                            Text("Svuota tutto in una volta").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                    }
                    .padding(.vertical, 4)
                } else if lib.cestinoInLettura {
                    HStack { ProgressView(); Text("Controllo Eliminati di recente…").font(.footnote).foregroundColor(.secondary) }
                } else {
                    // iOS non lascia leggere l'album alle app: si spiega il modo piu' veloce a mano
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Eliminati di recente", systemImage: "trash").font(.headline)
                        Text("Le foto tolte occupano spazio per 30 giorni. Per svuotarle tutte insieme: Foto → Raccolte → Eliminati di recente → Seleziona → **Elimina tutto** (in basso a sinistra): toglie anche quelle non ancora caricate sullo schermo.")
                            .font(.footnote)
                        Button { if let u = URL(string: "photos-redirect://") { apri(u) } } label: {
                            Label("Apri Foto", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                AltreApp()
            } header: { Text("WhatsApp e Telegram") } footer: {
                Text("iOS chiude ogni app nella sua cartella: nessuna app può cancellare i file di WhatsApp o Telegram al posto loro. Da qui li apri sulla pagina giusta in due tocchi.")
            }
            Section("Cosa togliere") {
                ForEach(Categoria.allCases) { c in
                    NavigationLink(destination: Elenco(categoria: c)) {
                        HStack {
                            Image(systemName: c.icona).frame(width: 28).foregroundColor(Tema.rosso)
                            VStack(alignment: .leading) {
                                Text(c.titolo)
                                Text(contaElementi(lib.elementi(c).filter { !$0.daTenere }.count))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(lib.peso(c) > 0 ? formatoByte(lib.peso(c)) : "—").foregroundColor(.secondary).monospacedDigit()
                        }
                    }
                    .disabled(lib.elementi(c).isEmpty)
                }
            }
            Section {
                Text("Doppioni anche dall'app Foto: Raccolte → Utility → Duplicati → Unisci.")
                Text("Spazio dell'aggiornamento iOS e delle app: Impostazioni → Generali → Spazio iPhone.")
                Button(agg.controllo ? L("Controllo…") : L("Controlla aggiornamenti di FMLAB Cleaner")) {
                    Task { await agg.controlla(manuale: true) }
                }.disabled(agg.controllo)
                if let e = agg.esito { Text(e).foregroundColor(.secondary) }
            } header: { Text("Altri consigli") } footer: {
                Text("FMLAB Cleaner \(agg.attuale)").frame(maxWidth: .infinity)
            }
            .font(.footnote)
        }
        .refreshable { await lib.analizza() }
        .confirmationDialog("Cancellare per sempre \(lib.cestino?.numero ?? 0) elementi (\(formatoByte(lib.cestino?.byte ?? 0)))?",
                            isPresented: $svuota, titleVisibility: .visible) {
            Button("Svuota Eliminati di recente", role: .destructive) {
                Task {
                    do { try await lib.svuotaCestino() } catch {
                        let e = error as NSError
                        if !(e.domain == "PHPhotosErrorDomain" && e.code == 3072) { erroreCestino = error.localizedDescription }
                    }
                }
            }
        } message: { Text("Non si potranno più recuperare. iOS chiederà ancora conferma.") }
        .alert("Non riuscito", isPresented: Binding(get: { erroreCestino != nil }, set: { if !$0 { erroreCestino = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text((erroreCestino ?? "") + "\n\n" + L("In alternativa: Foto → Eliminati di recente → Seleziona → Elimina tutto.")) }
        .overlay(alignment: .top) {
            if lib.analisiInCorso { ProgressView(value: lib.progresso).padding(.horizontal) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Logo(lato: 30) }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await lib.analizza() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(lib.analisiInCorso)
            }
        }
    }
}

// MARK: - elenco di una categoria

struct Elenco: View {
    @EnvironmentObject var lib: Libreria
    let categoria: Categoria
    @State private var scelti: Set<String> = []
    @State private var preparato = false
    @State private var conferma = false
    @State private var errore: String?
    @State private var anteprima: Elemento?
    @State private var comprimi = false
    @State private var lavoro: Lavoro = .comprimi

    var elementi: [Elemento] { lib.elementi(categoria) }
    var sceltiElementi: [Elemento] { elementi.filter { scelti.contains($0.id) } }
    var pesoScelti: Int64 { sceltiElementi.reduce(0) { $0 + $1.byte } }
    let colonne = [GridItem(.adaptive(minimum: 104), spacing: 4)]

    var body: some View {
        ScrollView {
            Text(categoria.spiegazione)
                .font(.footnote).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.top, 8)
            if categoria == .doppioni {
                ForEach(gruppi, id: \.self) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gruppo \(g)").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        LazyVGrid(columns: colonne, spacing: 4) {
                            ForEach(elementi.filter { $0.gruppo == g }) { e in cella(e) }
                        }
                    }
                    .padding(.horizontal, 6).padding(.top, 8)
                }
            } else {
                LazyVGrid(columns: colonne, spacing: 4) {
                    ForEach(elementi) { e in cella(e) }
                }
                .padding(6)
            }
            Color.clear.frame(height: 90)
        }
        .navigationTitle(categoria.titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Seleziona tutto") { scelti = Set(elementi.filter { !$0.daTenere }.map(\.id)) }
                Button("Deseleziona tutto") { scelti = [] }
            } label: { Image(systemName: "checkmark.circle") }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if categoria == .videoGrandi && !scelti.isEmpty {
                    Button {
                        lavoro = .comprimi; comprimi = true
                    } label: {
                        Text("Comprimi · ~\(formatoByte(pesoScelti / 2))")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundColor(.black)
                }
                if categoria == .live && !scelti.isEmpty {
                    Button {
                        lavoro = .soloFoto; comprimi = true
                    } label: {
                        Text("Trasforma in foto · \(formatoByte(pesoScelti))")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundColor(.black)
                }
                if categoria != .live { Button {
                    conferma = true
                } label: {
                    Text(scelti.isEmpty ? (categoria == .videoGrandi ? L("Tocca i video da togliere o comprimere") : L("Tocca le foto da togliere"))
                         : L("Togli %lld · %@", scelti.count, formatoByte(pesoScelti)))
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(scelti.isEmpty ? .gray : .red)
                .disabled(scelti.isEmpty) }
                if categoria == .live && scelti.isEmpty {
                    Text("Tocca le Live Photo da trasformare (o ✓ in alto: tutte)")
                        .frame(maxWidth: .infinity).foregroundColor(.secondary).padding(.vertical, 6)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            // (foglio agganciato qui: due .sheet sulla stessa vista non funzionano su iOS 15)
            .sheet(isPresented: $comprimi, onDismiss: { scelti = [] }) {
                Compressione(elementi: sceltiElementi, tipo: lavoro).environmentObject(lib)
            }
        }
        .confirmationDialog("Togliere \(scelti.count) elementi (\(formatoByte(pesoScelti)))?",
                            isPresented: $conferma, titleVisibility: .visible) {
            Button("Sposta in Eliminati di recente", role: .destructive) { Task { await togli() } }
        } message: {
            Text("Potrai recuperarli dall'app Foto per 30 giorni.")
        }
        .alert("Non riuscito", isPresented: Binding(get: { errore != nil }, set: { if !$0 { errore = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errore ?? "") }
        .sheet(item: $anteprima) { e in Anteprima(elemento: e) }
        .onAppear {
            if !preparato {
                preparato = true
                if categoria.preselezione { scelti = Set(elementi.filter { !$0.daTenere }.map(\.id)) }
            }
        }
    }

    var gruppi: [Int] {
        var visti = Set<Int>(), out: [Int] = []
        for e in elementi where !visti.contains(e.gruppo) { visti.insert(e.gruppo); out.append(e.gruppo) }
        return out
    }

    @ViewBuilder func cella(_ e: Elemento) -> some View {
        let scelto = scelti.contains(e.id)
        Miniatura(asset: e.asset)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text(e.asset.mediaType == .video ? "\(durata(e.asset.duration)) · \(formatoByte(e.byte))" : formatoByte(e.byte))
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                    .padding(3).background(Color.black.opacity(0.55)).cornerRadius(4).padding(3)
            }
            .overlay(alignment: .topTrailing) {
                if e.daTenere {
                    Text("TIENI").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(3).background(Color.green).cornerRadius(4).padding(4)
                } else {
                    Image(systemName: scelto ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundColor(scelto ? .red : .white)
                        .shadow(radius: 2).padding(4)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(scelto ? Color.red : Color.clear, lineWidth: 3))
            .contentShape(Rectangle())
            .onTapGesture {
                Vibrazione.tocco()
                if scelto { scelti.remove(e.id) } else { scelti.insert(e.id) }
            }
            .onLongPressGesture { anteprima = e }
    }

    func durata(_ s: TimeInterval) -> String {
        let t = Int(s.rounded())
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    func togli() async {
        do {
            try await lib.elimina(sceltiElementi)
            scelti = []
        } catch {
            // l'utente ha premuto "Non consentire" nella conferma di iOS: nessun errore da mostrare
            let e = error as NSError
            if !(e.domain == "PHPhotosErrorDomain" && e.code == 3072) { errore = error.localizedDescription }
        }
    }
}

// MARK: - miniature e anteprima

final class Immagini {
    static let gestore = PHCachingImageManager()

    static func carica(_ a: PHAsset, lato: CGFloat) async -> UIImage? {
        await withCheckedContinuation { (c: CheckedContinuation<UIImage?, Never>) in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat     // una sola risposta
            o.resizeMode = .fast
            o.isNetworkAccessAllowed = true          // anche le foto rimaste su iCloud
            var fatto = false
            gestore.requestImage(for: a, targetSize: CGSize(width: lato, height: lato),
                                 contentMode: .aspectFill, options: o) { img, _ in
                if !fatto { fatto = true; c.resume(returning: img) }
            }
        }
    }
}

struct Miniatura: View {
    let asset: PHAsset
    @State private var img: UIImage?

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.gray.opacity(0.15)
                if let img { Image(uiImage: img).resizable().scaledToFill() }
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipped()
        }
        .task(id: asset.localIdentifier) {
            img = await Immagini.carica(asset, lato: 240 * UIScreen.main.scale / 2)
        }
    }
}

struct Anteprima: View {
    let elemento: Elemento
    @Environment(\.dismiss) var chiudi
    @State private var img: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                if let img { Image(uiImage: img).resizable().scaledToFit() } else { ProgressView() }
                Text(info).font(.footnote).foregroundColor(.secondary).padding()
            }
            .toolbar { Button("Chiudi") { chiudi() } }
        }
        .task { img = await Immagini.carica(elemento.asset, lato: 1200) }
    }

    var info: String {
        let a = elemento.asset
        let d = a.creationDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "?"
        return "\(d) · \(a.pixelWidth)×\(a.pixelHeight) · \(formatoByte(elemento.byte))"
    }
}


// MARK: - WhatsApp e Telegram: guida diretta alla pagina che libera spazio
struct AltreApp: View {
    @Environment(\.openURL) var apri

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            voce(icona: "message.fill", nome: "WhatsApp", url: "whatsapp://",
                 passi: L("Impostazioni → Spazio e dati → Gestisci spazio: ordina per dimensione, apri le chat più pesanti e togli video e file inoltrati. Poi Impostazioni → Chat → Salva nel rullino: spento, così le foto non si duplicano in Foto."))
            Divider()
            voce(icona: "paperplane.fill", nome: "Telegram", url: "tg://settings",
                 passi: L("Impostazioni → Dati e memoria → Utilizzo memoria → Svuota cache (i messaggi restano sul cloud di Telegram). Imposta \"Conserva media\" a 1 settimana e un limite alla cache."))
        }
        .padding(.vertical, 4)
    }

    func voce(icona: String, nome: String, url: String, passi: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(nome, systemImage: icona).font(.headline)
                Spacer()
                Button(L("Apri")) { if let u = URL(string: url) { apri(u) } }
                    .buttonStyle(.bordered)
            }
            Text(passi).font(.footnote).foregroundColor(.secondary)
        }
    }
}
