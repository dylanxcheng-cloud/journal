//  MainViewController.swift — registers local Capacitor plugins. Main.storyboard points here.
import UIKit
import Capacitor

class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(SharedStorePlugin())
    }
}
