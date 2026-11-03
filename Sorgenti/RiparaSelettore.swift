// Dentro LiveContainer il selettore dell'app File si blocca dopo "Apri" (rotella che gira all'infinito).
// Il motivo: il selettore consegna la cartella all'app che ha l'identificativo scritto nell'app
// (com.fmlab.puliziafoto), ma il processo che gira davvero e' LiveContainer, firmato con un altro
// identificativo. iOS non trova l'app a cui darla e resta ad aspettare.
// LiveContainer lo ripara solo se l'utente accende "Ripara Selettore File" nelle impostazioni dell'app
// (TweakLoader/DocumentPicker.m: -[DOCConfiguration setHostIdentifier:]). Qui facciamo la stessa cosa da
// soli, cosi' il selettore funziona subito anche con l'opzione spenta. Fuori da LiveContainer non fa niente.
import Foundation
import ObjectiveC
import UIKit

enum RiparaSelettore {
    /// true se la riparazione e' attiva (solo dentro LiveContainer)
    private(set) static var attiva = false
    private static var provato = false

    static var dentroLiveContainer: Bool { getenv("LC_HOME_PATH") != nil }

    static func applica() {
        guard !provato else { return }
        provato = true
        guard dentroLiveContainer, let vero = identificativoVero() else { return }
        if NSClassFromString("DOCConfiguration") == nil {
            for p in ["/System/Library/PrivateFrameworks/DocumentManager.framework/DocumentManager",
                      "/System/Library/Frameworks/DocumentManager.framework/DocumentManager"] {
                _ = dlopen(p, RTLD_NOW)
            }
        }
        guard let classe = NSClassFromString("DOCConfiguration") else { return }
        let sel = NSSelectorFromString("setHostIdentifier:")
        guard let metodo = class_getInstanceMethod(classe, sel) else { return }
        typealias Imp = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let originale = unsafeBitCast(method_getImplementation(metodo), to: Imp.self)
        let nuovo: @convention(block) (AnyObject, AnyObject?) -> Void = { oggetto, _ in
            originale(oggetto, sel, vero as NSString)
        }
        method_setImplementation(metodo, imp_implementationWithBlock(nuovo))
        attiva = true
    }

    /// Identificativo vero del processo (quello di LiveContainer), letto dalla firma: "TEAMID.com.xxx" → "com.xxx"
    static func identificativoVero() -> String? {
        let tutti = UnsafeMutableRawPointer(bitPattern: -2)   // RTLD_DEFAULT
        guard let pCrea = dlsym(tutti, "SecTaskCreateFromSelf"),
              let pLeggi = dlsym(tutti, "SecTaskCopyValueForEntitlement") else { return nil }
        typealias Crea = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias Leggi = @convention(c) (AnyObject, CFString, UnsafeMutableRawPointer?) -> Unmanaged<AnyObject>?
        guard let compito = unsafeBitCast(pCrea, to: Crea.self)(nil)?.takeRetainedValue(),
              let valore = unsafeBitCast(pLeggi, to: Leggi.self)(compito, "application-identifier" as CFString, nil)?
                .takeRetainedValue() as? String, !valore.isEmpty else { return nil }
        if let punto = valore.firstIndex(of: ".") { return String(valore[valore.index(after: punto)...]) }
        return valore
    }

    /// Con "Sistema Selettore File (Legacy)" acceso, LiveContainer fa arrivare una COPIA nella cartella
    /// Inbox dell'app invece della cartella vera: pulire la copia non servirebbe a niente.
    static func eUnaCopia(_ u: URL) -> Bool {
        let p = u.resolvingSymlinksInPath().path
        let casa = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
        let tmp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        return p.contains("-Inbox/") || p.contains("/Inbox/") || p.hasPrefix(tmp) || p.hasPrefix(casa + "/")
    }
}
