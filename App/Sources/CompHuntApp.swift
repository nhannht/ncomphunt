import SwiftUI

/// Entry point for the free build.
///
/// This file must contain NOTHING but the entry point. The paid build compiles
/// the same `App/Sources` directory with exactly this one file excluded by
/// name, so anything parked here would silently vanish from that build.
@main
struct CompHuntApp: App {
    var body: some Scene {
        CompHuntRoot()
    }
}
