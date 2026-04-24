/// Records body evaluations of a probed View — how many times body ran and the
/// last state value it observed.
///
/// MainActor-isolated so it can be safely mutated from SwiftUI view body (which
/// itself runs on MainActor). Reference type so captured probe in View struct
/// shares state with the enclosing test.
@MainActor
final class RenderProbe {
    private(set) var bodyCount = 0
    private(set) var lastCount: Int? = nil

    func record(_ count: Int) {
        bodyCount += 1
        lastCount = count
    }
}
