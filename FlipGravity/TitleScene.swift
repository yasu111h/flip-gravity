import SpriteKit

class TitleScene: SKScene {

    // MARK: - Properties

    private var tapLabel: SKLabelNode!
    private var debugButtonBg: SKShapeNode!
    private var debugButtonLabel: SKLabelNode!

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared
        backgroundColor = theme.backgroundColor

        setupBackground()
        setupTitleLogo()
        setupTapLabel()
        setupSettingsButton()
        setupDebugButton()
        setupDemoBalls()
    }

    // MARK: - Background

    private func setupBackground() {
        let theme = ThemeManager.shared

        if theme.hasGrid {
            addBackgroundGrid()
        }
        if theme.hasStars {
            addBackgroundStars()
        }
    }

    private func addBackgroundGrid() {
        let gridSpacing: CGFloat = 60
        let gridColor = UIColor(white: 1.0, alpha: 0.05)
        var x: CGFloat = 0
        while x <= size.width {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 1
            line.zPosition = -10
            addChild(line)
            x += gridSpacing
        }
        var y: CGFloat = 0
        while y <= size.height {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 1
            line.zPosition = -10
            addChild(line)
            y += gridSpacing
        }
    }

    private func addBackgroundStars() {
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
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.3), duration: CGFloat.random(in: 0.5...2.0)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.9), duration: CGFloat.random(in: 0.5...2.0))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
    }

    // MARK: - Title Logo

    private func setupTitleLogo() {
        let theme = ThemeManager.shared
        let hudColor = theme.hudColor

        // 上段「FLIP」
        let flipLabel = SKLabelNode(text: "FLIP")
        flipLabel.fontName = "AvenirNext-Heavy"
        flipLabel.fontSize = 72
        flipLabel.fontColor = hudColor
        flipLabel.horizontalAlignmentMode = .center
        flipLabel.verticalAlignmentMode = .center
        flipLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        flipLabel.zPosition = 10
        addChild(flipLabel)

        // 下段「GRAVITY」
        let gravityLabel = SKLabelNode(text: "GRAVITY")
        gravityLabel.fontName = "AvenirNext-Heavy"
        gravityLabel.fontSize = 58
        gravityLabel.fontColor = theme.goalFillColor
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
        subLabel.fontColor = hudColor.withAlphaComponent(0.5)
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        subLabel.zPosition = 10
        addChild(subLabel)
    }

    // MARK: - TAP TO PLAY Label

    private func setupTapLabel() {
        let theme = ThemeManager.shared
        let hudColor = theme.hudColor

        tapLabel = SKLabelNode(text: "TAP TO PLAY")
        tapLabel.fontName = "AvenirNext-Bold"
        tapLabel.fontSize = 22
        tapLabel.fontColor = hudColor
        tapLabel.horizontalAlignmentMode = .center
        tapLabel.verticalAlignmentMode = .center
        tapLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        tapLabel.zPosition = 10
        addChild(tapLabel)

        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.7),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7)
        ])
        tapLabel.run(SKAction.repeatForever(blink))

        let arrowLabel = SKLabelNode(text: "↓")
        arrowLabel.fontName = "AvenirNext-Bold"
        arrowLabel.fontSize = 20
        arrowLabel.fontColor = hudColor.withAlphaComponent(0.6)
        arrowLabel.horizontalAlignmentMode = .center
        arrowLabel.verticalAlignmentMode = .center
        arrowLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.19)
        arrowLabel.zPosition = 10
        addChild(arrowLabel)

        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -5, duration: 0.5),
            SKAction.moveBy(x: 0, y: 5, duration: 0.5)
        ])
        arrowLabel.run(SKAction.repeatForever(bounce))
    }

    // MARK: - Settings Button

    private func setupSettingsButton() {
        let theme = ThemeManager.shared

        let settingsBg = SKShapeNode(rectOf: CGSize(width: 120, height: 40), cornerRadius: 10)
        settingsBg.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        settingsBg.fillColor = theme.hudColor.withAlphaComponent(0.1)
        settingsBg.strokeColor = theme.hudColor.withAlphaComponent(0.4)
        settingsBg.lineWidth = 1.5
        settingsBg.zPosition = 10
        settingsBg.name = "settingsButton"
        addChild(settingsBg)

        let settingsLabel = SKLabelNode(text: "⚙ SETTINGS")
        settingsLabel.fontName = "AvenirNext-Bold"
        settingsLabel.fontSize = 14
        settingsLabel.fontColor = theme.hudColor.withAlphaComponent(0.8)
        settingsLabel.horizontalAlignmentMode = .center
        settingsLabel.verticalAlignmentMode = .center
        settingsLabel.zPosition = 11
        settingsLabel.name = "settingsButton"
        settingsBg.addChild(settingsLabel)
    }

    // MARK: - Debug Button

    private func setupDebugButton() {
        let isOn = UserDefaults.standard.bool(forKey: "debugMode")

        debugButtonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 32), cornerRadius: 8)
        debugButtonBg.position = CGPoint(x: 65, y: 36)
        debugButtonBg.fillColor = isOn
            ? UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.3)
            : UIColor(white: 1.0, alpha: 0.05)
        debugButtonBg.strokeColor = isOn
            ? UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.9)
            : UIColor(white: 1.0, alpha: 0.25)
        debugButtonBg.lineWidth = 1.5
        debugButtonBg.zPosition = 10
        debugButtonBg.name = "debugButton"
        addChild(debugButtonBg)

        debugButtonLabel = SKLabelNode(text: isOn ? "🔓 DEBUG ON" : "🔒 DEBUG")
        debugButtonLabel.fontName = "AvenirNext-Bold"
        debugButtonLabel.fontSize = 11
        debugButtonLabel.fontColor = isOn
            ? UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.45)
        debugButtonLabel.horizontalAlignmentMode = .center
        debugButtonLabel.verticalAlignmentMode = .center
        debugButtonLabel.zPosition = 11
        debugButtonLabel.name = "debugButton"
        debugButtonBg.addChild(debugButtonLabel)
    }

    private func toggleDebugMode() {
        let isOn = !UserDefaults.standard.bool(forKey: "debugMode")
        UserDefaults.standard.set(isOn, forKey: "debugMode")

        debugButtonBg.fillColor = isOn
            ? UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.3)
            : UIColor(white: 1.0, alpha: 0.05)
        debugButtonBg.strokeColor = isOn
            ? UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.9)
            : UIColor(white: 1.0, alpha: 0.25)
        debugButtonLabel.text = isOn ? "🔓 DEBUG ON" : "🔒 DEBUG"
        debugButtonLabel.fontColor = isOn
            ? UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.45)

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        debugButtonBg.run(pop)
    }

    // MARK: - Demo Balls

    private func setupDemoBalls() {
        let theme = ThemeManager.shared
        let c1 = theme.playerFillColor.withAlphaComponent(0.3)
        let c2 = theme.goalFillColor.withAlphaComponent(0.25)
        let c3 = theme.lavaFillColor.withAlphaComponent(0.2)
        let c4 = theme.blinkFloorFillColor.withAlphaComponent(0.2)

        let ballConfigs: [(CGPoint, CGVector, UIColor)] = [
            (CGPoint(x: size.width * 0.1, y: size.height * 0.8),  CGVector(dx: 0.8, dy: -0.6), c1),
            (CGPoint(x: size.width * 0.85, y: size.height * 0.3), CGVector(dx: -0.5, dy: 0.9),  c2),
            (CGPoint(x: size.width * 0.5, y: size.height * 0.9),  CGVector(dx: 0.3, dy: -1.0),  c3),
            (CGPoint(x: size.width * 0.2, y: size.height * 0.1),  CGVector(dx: 0.7, dy: 0.7),   c4),
        ]

        for (position, velocity, color) in ballConfigs {
            let ball = SKShapeNode(circleOfRadius: 10)
            ball.position = position
            ball.fillColor = color
            ball.strokeColor = color.withAlphaComponent(0.6)
            ball.lineWidth = 1
            ball.zPosition = 1
            addChild(ball)
            animateBall(ball, velocity: velocity)
        }
    }

    private func animateBall(_ ball: SKShapeNode, velocity: CGVector) {
        let speed: CGFloat = 120.0
        let normalizedLength = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let vx = velocity.dx / normalizedLength * speed
        let vy = velocity.dy / normalizedLength * speed
        let duration = size.width / speed * 3.0

        let moveAction = SKAction.customAction(withDuration: duration) { [weak self] node, _ in
            guard let self = self else { return }
            var pos = node.position
            pos.x += vx / 60.0
            pos.y += vy / 60.0
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
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)

        for node in nodes {
            if node.name == "settingsButton" {
                goToSettings()
                return
            }
            if node.name == "debugButton" {
                toggleDebugMode()
                return
            }
        }

        transitionToStageSelect()
    }

    private func transitionToStageSelect() {
        let stageSelectScene = StageSelectScene(size: size)
        stageSelectScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.4
        )
        view?.presentScene(stageSelectScene, transition: transition)
    }

    private func goToSettings() {
        let settingsScene = SettingsScene(size: size)
        settingsScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.4
        )
        view?.presentScene(settingsScene, transition: transition)
    }
}
