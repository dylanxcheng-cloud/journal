//  SharedStorePlugin.swift — Capacitor plugin the web app calls (see js/native.js).
//  Add to the App target only. Registered in MainViewController.capacitorDidLoad().
import Foundation
import Capacitor
import WidgetKit

@objc(SharedStorePlugin)
public class SharedStorePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SharedStorePlugin"
    public let jsName = "SharedStore"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "save", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readPending", returnType: CAPPluginReturnPromise),
    ]

    /// save({ json }) — store the snapshot and ask WidgetKit to redraw every widget.
    @objc func save(_ call: CAPPluginCall) {
        guard let json = call.getString("json") else { call.reject("json is required"); return }
        SharedStore.saveSnapshot(json)
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    /// readPending() — taps made inside widgets while the app was closed.
    @objc func readPending(_ call: CAPPluginCall) {
        call.resolve(["toggles": SharedStore.drainPendingToggles()])
    }
}
