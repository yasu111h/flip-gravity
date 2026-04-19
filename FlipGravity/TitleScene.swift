import SpriteKit

class TitleScene: SKScene {

    // MARK: - Properties

    private var tapLabel: SKLabelNode!

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1.0)

        setupBackground()
        setupTitleLogo()
        setupTapLabel()
        setupDemoBalls()
    }

    // MARK: - Background Stars

    private func setupBackground() {
        // 背景の星（小さい点）
        for _ in 0..<60 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.fillColor = UIColor(white: 1.0, alpha: CGFloat.random(in: 0.2...0.8))
            star.strokeColor = .clear
            star.zPosition = 0
            addChild(star)

            // 点滅アニメ
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.3), duration: CGFloat.random(in: 0.5...2.0)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.9), duration: CGFloat.random(in: 0.5...2.0))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
    }

    // MARK: - Title Logo

    private func setupTitleLogo() {
        // 上段「FLIP」
        let flipLabel = SKLabelNode(text: "FLIP")
        flipLabel.fontName = "AvenirNext-Heavy"
        flipLabel.fontSize = 72
        flipLabel.fontColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        flipLabel.horizontalAlignmentMode = .center
        flipLabel.verticalAlignmentMode = .center
        flipLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        flipLabel.zPosition = 10

        // グロウ効果
        let glowEffect = SKEffectNode()
        glowEffect.shouldRasterize = true
        glowEffect.shouldEnableEffects = true
        addChild(flipLabel)

        // 下段「GRAVITY」
        let gravityLabel = SKLabelNode(text: "GRAVITY")
        gravityLabel.fontName = "AvenirNext-Heavy"
        gravityLabel.fontSize = 58
        gravityLabel.fontColor = UIColor(red: 0.2, green: 1.0, blue: 0.6, alpha: 1.0)
        gravityLabel.horizontalAlignmentMode = .center
        gravityLabel.verticalAlignmentMode = .center
        gravityLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        gravityLabel.zPosition = 10
        addChild(gravityLabel)

        // タイトルのパルスアニメ
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.03, duration: 1.2),
            SKAction.scale(to: 0.97, duration: 1.2)
        ])
        flipLabel.run(SKAction.repeatForever(pulse))
        gravityLabel.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 0.97, duration: 1.2),
            SKAction.scale(to: 1.03, duration: 1.2)
        ])))

        // サブタイトル
        let subLabel = SKLabelNode(text: "- gravity action game -")
        subLabel.fontName = "AvenirNext-Medium"
        subLabel.fontSize = 16
        subLabel.fontColor = UIColor(white: 1.0, alpha: 0.5)
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        subLabel.zPosition = 10
        addChild(subLabel)
    }

    // MARK: - TAP TO PLAY Label

    private func setupTapLabel() {
        tapLabel = SKLabelNode(text: "TAP TO PLAY")
        tapLabel.fontName = "AvenirNext-Bold"
        tapLabel.fontSize = 22
        tapLabel.fontColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        tapLabel.horizontalAlignmentMode = .center
        tapLabel.verticalAlignmentMode = .center
        tapLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        tapLabel.zPosition = 10
        addChild(tapLabel)

        // 点滅アニメ
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.7),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7)
        ])
        tapLabel.run(SKAction.repeatForever(blink))

        // 下向き矢印
        let arrowLabel = SKLabelNode(text: "↓")
        arrowLabel.fontName = "AvenirNext-Bold"
        arrowLabel.fontSize = 20
        arrowLabel.fontColor = UIColor(white: 1.0, alpha: 0.6)
        arrowLabel.horizontalAlignmentMode = .center
        arrowLabel.verticalAlignmentMode = .center
        arrowLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.13)
        arrowLabel.zPosition = 10
        addChild(arrowLabel)

        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -5, duration: 0.5),
            SKAction.moveBy(x: 0, y: 5, duration: 0.5)
        ])
        arrowLabel.run(SKAction.repeatForever(bounce))
    }

    // MARK: - Demo Balls

    private func setupDemoBalls() {
        // 異なる方向・速さで動く背景デモボール
        let ballConfigs: [(CGPoint, CGVector, UIColor)] = [
            (CGPoint(x: size.width * 0.1, y: size.height * 0.8),
             CGVector(dx: 0.8, dy: -0.6),
             UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.3)),
            (CGPoint(x: size.width * 0.85, y: size.height * 0.3),
             CGVector(dx: -0.5, dy: 0.9),
             UIColor(red: 0.2, green: 1.0, blue: 0.6, alpha: 0.25)),
            (CGPoint(x: size.width * 0.5, y: size.height * 0.9),
             CGVector(dx: 0.3, dy: -1.0),
             UIColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 0.2)),
            (CGPoint(x: size.width * 0.2, y: size.height * 0.1),
             CGVector(dx: 0.7, dy: 0.7),
             UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 0.2)),
        ]

        for (position, velocity, color) in ballConfigs {
            let ball = SKShapeNode(circleOfRadius: 10)
            ball.position = position
            ball.fillColor = color
            ball.strokeColor = color.withAlphaComponent(0.6)
            ball.lineWidth = 1
            ball.zPosition = 1

            addChild(ball)

            // 画面を跳ね回るアニメ（折り返し）
            animateBall(ball, velocity: velocity)
        }
    }

    private func animateBall(_ ball: SKShapeNode, velocity: CGVector) {
        let speed: CGFloat = 120.0
        let normalizedLength = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let vx = velocity.dx / normalizedLength * speed
        let vy = velocity.dy / normalizedLength * speed

        let duration = size.width / speed * 3.0

        let moveAction = SKAction.customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self = self else { return }
            var pos = node.position
            pos.x += vx / 60.0
            pos.y += vy / 60.0

            // 画面端で折り返し（実装簡略化：単純に端まで行ったら反対側から出現）
            if pos.x < -20 { pos.x = self.size.width + 20 }
            if pos.x > self.size.width + 20 { pos.x = -20 }
            if pos.y < -20 { pos.y = self.size.height + 20 }
            if pos.y > self.size.height + 20 { pos.y = -20 }

            node.position = pos
        }

        ball.run(SKAction.repeatForever(moveAction))
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        transitionToStageSelect()
    }

    private func transitionToStageSelect() {
        let stageSelectScene = StageSelectScene(size: size)
        stageSelectScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1.0),
            duration: 0.4
        )
        view?.presentScene(stageSelectScene, transition: transition)
    }
}
