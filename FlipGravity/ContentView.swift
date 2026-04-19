import SwiftUI
import SpriteKit

struct ContentView: View {
    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: makeScene(size: geometry.size))
                .ignoresSafeArea()
                .statusBarHidden(true)
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = TitleScene(size: size)
        scene.scaleMode = .aspectFill
        return scene
    }
}
