// Stato del telefono con le sole informazioni che iOS da' davvero a un'app: batteria, risparmio
// energetico, stato termico (quanto e' caldo), spazio, memoria, da quanto e' acceso.
// Nessuna app iOS puo' "liberare la RAM", chiudere le altre app o "riparare la batteria":
// chi lo promette mente. Qui si misura e si danno solo consigli che funzionano.
import SwiftUI
import UIKit

@MainActor
final class StatoTelefono: ObservableObject {
    @Published var batteria: Float = -1
    @Published var carica: UIDevice.BatteryState = .unknown
    @Published var risparmio = false
    @Published var termico: ProcessInfo.ThermalState = .nominal
    @Published var libero: Int64 = 0
    @Published var totale: Int64 = 0
    @Published var acceso: TimeInterval = 0
    let ram = ProcessInfo.processInfo.physicalMemory
    private var ciclo: Task<Void, Never>?

    func avvia() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        aggiorna()
        ciclo?.cancel()
        ciclo = Task { [weak self] in   // ogni 5 s, solo mentre la scheda e' aperta
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self = self else { return }
                self.aggiorna()
            }
        }
    }

    func ferma() { ciclo?.cancel(); ciclo = nil }

    func aggiorna() {
        let d = UIDevice.current
        batteria = d.batteryLevel
        carica = d.batteryState
        let p = ProcessInfo.processInfo
        risparmio = p.isLowPowerModeEnabled
        termico = p.thermalState
        acceso = p.systemUptime
        let casa = URL(fileURLWithPath: NSHomeDirectory())
        if let v = try? casa.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            libero = v.volumeAvailableCapacityForImportantUsage ?? 0
            totale = Int64(v.volumeTotalCapacity ?? 0)
        }
    }

    var testoTermico: (String, Color) {
        switch termico {
        case .nominal: return (L("Normale"), .green)
        case .fair: return (L("Tiepido"), .yellow)
        case .serious: return (L("Caldo: iOS sta già rallentando"), .orange)
        case .critical: return (L("Molto caldo: lascialo riposare"), .red)
        @unknown default: return (L("Sconosciuto"), .gray)
        }
    }

    var giorniAcceso: Int { Int(acceso / 86400) }

    /// Consigli in ordine di effetto, calcolati dallo stato vero del telefono.
    var consigli: [(String, String)] {
        var c: [(String, String)] = []
        let percLibero = totale > 0 ? Double(libero) / Double(totale) : 1
        if percLibero < 0.10 {
            c.append(("internaldrive", L("Spazio quasi finito (%@ liberi): un iPhone pieno rallenta tutto e scalda di più. Inizia da \"Video grandi\" qui sopra, poi Impostazioni → Generali → Spazio iPhone.", formatoByte(libero))))
        }
        if termico == .serious || termico == .critical {
            c.append(("thermometer.sun", L("Il telefono è caldo: iOS abbassa da solo la velocità per proteggerlo. Togli la custodia se sta caricando, chiudi giochi e Linux pesanti, evita il sole diretto.")))
        }
        if giorniAcceso >= 7 {
            c.append(("arrow.clockwise", L("Acceso da %lld giorni: un riavvio ogni tanto libera la memoria e chiude i processi rimasti appesi.", giorniAcceso)))
        }
        if batteria >= 0 && batteria < 0.2 && !risparmio {
            c.append(("battery.25", L("Batteria sotto il 20%: attiva Risparmio energetico (Centro di Controllo).")))
        }
        c.append(("battery.100.bolt", L("Batteria: Impostazioni → Batteria → Ricarica → Ricarica ottimizzata (o limite all'80%) fa durare di più la batteria negli anni.")))
        c.append(("sun.max", L("Luminosità automatica e modalità scura consumano meno schermo, la parte che usa più batteria.")))
        c.append(("arrow.triangle.2.circlepath", L("Aggiornamento app in background: spegnilo per le app che non ne hanno bisogno (Impostazioni → Generali).")))
        c.append(("location", L("Localizzazione: \"Mentre usi l'app\" invece di \"Sempre\" per le app che non servono in sottofondo.")))
        return c
    }
}

struct Telefono: View {
    @StateObject private var s = StatoTelefono()

    var body: some View {
        List {
            Section("Adesso") {
                riga("bolt.batteryblock", L("Batteria"),
                     s.batteria < 0 ? "—" : "\(Int(s.batteria * 100))%" + (s.carica == .charging ? L(" · in carica") : s.carica == .full ? L(" · carica") : ""))
                riga("leaf", L("Risparmio energetico"), s.risparmio ? L("acceso") : L("spento"))
                HStack {
                    Label("Temperatura", systemImage: "thermometer")
                    Spacer()
                    Text(s.testoTermico.0).foregroundColor(s.testoTermico.1).bold()
                }
                riga("internaldrive", L("Spazio libero"),
                     L("%@ su %@", formatoByte(s.libero), formatoByte(s.totale)))
                riga("memorychip", L("Memoria (RAM)"), formatoByte(Int64(s.ram)))
                riga("clock.arrow.circlepath", L("Acceso da"),
                     s.giorniAcceso > 1 ? L("%lld giorni", s.giorniAcceso) : s.giorniAcceso == 1 ? L("1 giorno") : s.acceso < 3600 ? L("meno di un'ora") : L("%lld ore", Int(s.acceso / 3600)))
            }
            Section {
                ForEach(Array(s.consigli.enumerated()), id: \.offset) { _, c in
                    Label(c.1, systemImage: c.0).font(.callout)
                }
            } header: { Text("Cosa fare, in ordine di effetto") } footer: {
                Text("La temperatura è quella che iOS comunica alle app (normale, tiepido, caldo, molto caldo): utile mentre usi Linux in LinuxRunner. Nessuna app per iPhone può liberare la RAM, chiudere le altre app o \"riparare\" la batteria: chi lo promette non fa niente di vero.")
            }
        }
        .navigationTitle("Telefono")
        .onAppear { s.avvia() }
        .onDisappear { s.ferma() }
    }

    func riga(_ icona: String, _ nome: String, _ valore: String) -> some View {
        HStack {
            Label(nome, systemImage: icona)
            Spacer()
            Text(valore).foregroundColor(.secondary).monospacedDigit()
        }
    }
}
