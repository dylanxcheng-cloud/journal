//  DaybookWidgetBundle.swift — entry point of the Widget Extension target.
//  Create the target in Xcode (File → New → Target → Widget Extension, name "DaybookWidget",
//  untick "Include Configuration App Intent"), delete the generated Swift files, and add the
//  files in ios/DaybookWidget/ plus ios/Shared/ to the target.
import SwiftUI
import WidgetKit

@main
struct DaybookWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaybookWidget()
        DaybookLockScreenWidget()
    }
}
