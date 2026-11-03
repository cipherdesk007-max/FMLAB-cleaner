// Colori FMLAB: il rosso del logo su nero.
import SwiftUI
import UIKit

enum Tema {
    static let uiRosso = UIColor(red: 191 / 255, green: 109 / 255, blue: 111 / 255, alpha: 1)   // #BF6D6F, dal logo
    static let uiFondo = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
    static let uiRiga = UIColor(red: 0.12, green: 0.11, blue: 0.11, alpha: 1)
    static let rosso = Color(uiRosso)
    static let fondo = Color(uiFondo)
    static let riga = Color(uiRiga)

    /// Aspetto delle parti UIKit che SwiftUI usa sotto (liste, barre) anche su iOS 15.
    static func applica() {
        UITableView.appearance().backgroundColor = uiFondo
        UICollectionView.appearance().backgroundColor = uiFondo
        UITableViewCell.appearance().backgroundColor = uiRiga
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = uiFondo
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = uiFondo
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UIView.appearance().tintColor = uiRosso
    }
}

/// Il logo FMLAB (Resources/logo.png nel pacchetto dell'app).
struct Logo: View {
    var lato: CGFloat = 44
    var body: some View {
        if let img = UIImage(named: "logo") {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(width: lato, height: lato)
                .clipShape(RoundedRectangle(cornerRadius: lato * 0.22, style: .continuous))
        }
    }
}

enum Vibrazione {
    static func tocco() { UISelectionFeedbackGenerator().selectionChanged() }
    static func fatto() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// Testo tradotto (italiano di base, inglese in en.lproj/Localizable.strings).
func L(_ s: String) -> String { NSLocalizedString(s, comment: "") }
/// Testo tradotto con valori: L("%lld video saltati", n)
func L(_ s: String, _ v: CVarArg...) -> String { String(format: NSLocalizedString(s, comment: ""), arguments: v) }

/// "1 elemento" / "5 elementi"
func contaElementi(_ n: Int) -> String { n == 1 ? L("1 elemento") : L("%lld elementi", n) }
/// "1 file" / "5 file" (in inglese "1 file" / "5 files")
func contaFile(_ n: Int) -> String { n == 1 ? L("1 file") : L("%lld file", n) }

/// Testo con **grassetto**: Text(String) mostrerebbe gli asterischi cosi' come sono.
func TestoMd(_ s: String) -> Text {
    if let a = try? AttributedString(markdown: s) { return Text(a) }
    return Text(s)
}
