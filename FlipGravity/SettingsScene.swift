import SpriteKit

class SettingsScene: SKScene {

    // MARK: - Properties

    private var themeButtons: [AppTheme: SKShapeNode] = [:]

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared
        backgroundColor = theme.backgroundColor

        setupBackground()
        setupTitle()
        setupThemeButtons()
        setupBackButton()
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

    // MARK: - Title

    private func setupTitle() {
        let theme = ThemeManager.shared

        let titleLabel = SKLabelNode(text: "SETTINGS")
        titleLabel.fontName = "AvenirNext-Heavy"
        titleLabel.fontSize = 36
        titleLabel.fontColor = theme.hudColor
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 70)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        let subLabel = SKLabelNode(text: "THEME")
        subLabel.fontName = "AvenirNext-Medium"
        subLabel.fontSize = 18
        subLabel.fontColor = theme.hudColor.withAlphaComponent(0.7)
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: size.width / 2, y: size.height - 120)
        subLabel.zPosition = 10
        addChild(subLabel)
    }

    // MARK: - Theme Buttons

    private func setupThemeButtons() {
        let themes = AppTheme.allCases
        let buttonWidth: CGFloat = size.width * 0.75
        let buttonHeight: CGFloat = 64
        let spacing: CGFloat = 20
        let totalHeight = CGFloat(themes.count) * buttonHeight + CGFloat(themes.count - 1) * spacing
        let startY = size.height / 2 + totalHeight / 2

        for (i, appTheme) in themes.enumerated() {
            let y = startY - CGFloat(i) * (buttonHeight + spacing) - buttonHeight / 2
            let position = CGPoint(x: size.width / 2, y: y)
            addThemeButton(for: appTheme, at: position, size: CGSize(width: buttonWidth, height: buttonHeight))
        }
    }

    private func addThemeButton(for appTheme: AppTheme, at position: CGPoint, size buttonSize: CGSize) {
        let isSelected = ThemeManager.shared.current == appTheme
        let theme = ThemeManager.shared

        let bg = SKShapeNode(rectOf: buttonSize, cornerRadius: 14)
        bg.position = position
        bg.zPosition = 10
        bg.name = "theme_\(appTheme.rawValue)"

        if isSelected {
            bg.fillColor = theme.hudColor.withAlphaComponent(0.3)
            bg.strokeColor = theme.hudColor
            bg.lineWidth = 2.5
        } else {
            bg.fillColor = theme.hudColor.withAlphaComponent(0.08)
            bg.strokeColor = theme.hudColor.withAlphaComponent(0.4)
            bg.lineWidth = 1.5
        }

        addChild(bg)
        themeButtons[appTheme] = bg

        // テーマ名ラベル
        let nameLabel = SKLabelNode(text: appTheme.displayName)
        nameLabel.fontName = isSelected ? "AvenirNext-Heavy" : "AvenirNext-Bold"
        nameLabel.fontSize = 22
        nameLabel.fontColor = isSelected
            ? theme.hudColor
            : theme.hudColor.withAlphaComponent(0.6)
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .center
        nameLabel.zPosition = 11
        nameLabel.name = "theme_\(appTheme.rawValue)"
        bg.addChild(nameLabel)

        // 選択中マーク
        if isSelected {
            let checkLabel = SKLabelNode(text: "✓")
            checkLabel.fontName = "AvenirNext-Heavy"
            checkLabel.fontSize = 18
            checkLabel.fontColor = theme.hudColor
            checkLabel.horizontalAlignmentMode = .right
            checkLabel.verticalAlignmentMode = .center
            checkLabel.position = CGPoint(x: buttonSize.width / 2 - 16, y: 0)
            checkLabel.zPosition = 12
            checkLabel.name = "theme_\(appTheme.rawValue)"
            bg.addChild(checkLabel)

            // 選択ボタンのパルスアニメ
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.02, duration: 0.8),
                SKAction.scale(to: 0.98, duration: 0.8)
            ])
            bg.run(SKAction.repeatForever(pulse))
        }
    }

    // MARK: - Back Button

    private func setupBackButton() {
        let theme = ThemeManager.shared

        let backBg = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 10)
        backBg.position = CGPoint(x: size.width / 2, y: 80)
        backBg.fillColor = theme.hudColor.withAlphaComponent(0.1)
        backBg.strokeColor = theme.hudColor.withAlphaComponent(0.5)
        backBg.lineWidth = 1.5
        backBg.zPosition = 10
        backBg.name = "backButton"
        addChild(backBg)

        let backLabel = SKLabelNode(text: "< BACK")
        backLabel.fontName = "AvenirNext-Bold"
        backLabel.fontSize = 16
        backLabel.fontColor = theme.hudColor.withAlphaComponent(0.9)
        backLabel.horizontalAlignmentMode = .center
        backLabel.verticalAlignmentMode = .center
        backLabel.zPosition = 11
        backLabel.name = "backButton"
        backBg.addChild(backLabel)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)

        for node in nodes {
            guard let name = node.name else { continue }

            if name == "backButton" {
                goToTitle()
                return
            }

            if name.hasPrefix("theme_") {
                let rawValue = String(name.dropFirst("theme_".count))
                if let selectedTheme = AppTheme(rawValue: rawValue) {
                    ThemeManager.shared.current = selectedTheme
                    reloadScene()
                    return
                }
            }
        }
    }

    // MARK: - Navigation

    private func reloadScene() {
        let newScene = SettingsScene(size: size)
        newScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.3
        )
        view?.presentScene(newScene, transition: transition)
    }

    private func goToTitle() {
        let titleScene = TitleScene(size: size)
        titleScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.4
        )
        view?.presentScene(titleScene, transition: transition)
    }
}
