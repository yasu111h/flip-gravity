import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = view as? SKView else {
            // SKViewでない場合はSKViewを作成してセット
            let skView = SKView(frame: view.bounds)
            skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(skView)
            setupScene(in: skView)
            return
        }
        setupScene(in: skView)
    }

    private func setupScene(in skView: SKView) {
        let screenSize = UIScreen.main.bounds.size
        let scene = TitleScene(size: screenSize)
        scene.scaleMode = .aspectFill

        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true

        skView.presentScene(scene)
    }

    override func loadView() {
        self.view = SKView(frame: UIScreen.main.bounds)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
