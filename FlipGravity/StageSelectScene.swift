import SpriteKit

class StageSelectScene: SKScene {

    // MARK: - Constants

    private let totalStages = 20
    private let initialUnlocked = 5
    private let columns = 4
    private let rows = 5

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared
        backgroundColor = theme.backgroundColor

        setupBackground()
        setupTitle()
        setupBackButton()
        setupStageGrid()
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
        for _ in 0..<40 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.fillColor = UIColor(white: 1.0, alpha: CGFloat.random(in: 0.2...0.6))
            star.strokeColor = .clear
            star.zPosition = 0
            addChild(star)
        }
    }

    // MARK: - Title

    private func setupTitle() {
        let theme = ThemeManager.shared

        let titleLabel = SKLabelNode(text: "SELECT STAGE")
        titleLabel.fontName = "AvenirNext-Heavy"
        titleLabel.fontSize = 32
        titleLabel.fontColor = theme.hudColor
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        titleLabel.zPosition = 10
        addChild(titleLabel)
    }

    // MARK: - Back Button

    private func setupBackButton() {
        let theme = ThemeManager.shared

        let backBg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        backBg.position = CGPoint(x: 55, y: size.height - 60)
        backBg.fillColor = theme.hudColor.withAlphaComponent(0.1)
        backBg.strokeColor = theme.hudColor.withAlphaComponent(0.4)
        backBg.lineWidth = 1.5
        backBg.zPosition = 10
        backBg.name = "backButton"
        addChild(backBg)

        let backLabel = SKLabelNode(text: "< BACK")
        backLabel.fontName = "AvenirNext-Bold"
        backLabel.fontSize = 14
        backLabel.fontColor = theme.hudColor.withAlphaComponent(0.9)
        backLabel.horizontalAlignmentMode = .center
        backLabel.verticalAlignmentMode = .center
        backLabel.zPosition = 11
        backLabel.name = "backButton"
        backBg.addChild(backLabel)
    }

    // MARK: - Stage Grid

    private func setupStageGrid() {
        let clearedStages = getClearedStages()
        let unlockedCount = max(initialUnlocked, clearedStages.count + 1)

        let gridWidth = size.width * 0.9
        let gridHeight = size.height * 0.72
        let cardWidth = gridWidth / CGFloat(columns) - 12
        let cardHeight = gridHeight / CGFloat(rows) - 12

        let startX = (size.width - gridWidth) / 2 + cardWidth / 2
        let startY = size.height - 110 - cardHeight / 2

        for index in 0..<totalStages {
            let col = index % columns
            let row = index / columns
            let stageNumber = index + 1

            let x = startX + CGFloat(col) * (cardWidth + 12)
            let y = startY - CGFloat(row) * (cardHeight + 12)
            let position = CGPoint(x: x, y: y)

            let isCleared = clearedStages.contains(index)
            let isUnlocked = index < unlockedCount

            addStageCard(
                at: position,
                stageNumber: stageNumber,
                stageIndex: index,
                cardSize: CGSize(width: cardWidth, height: cardHeight),
                isCleared: isCleared,
                isUnlocked: isUnlocked
            )
        }
    }

    private func addStageCard(
        at position: CGPoint,
        stageNumber: Int,
        stageIndex: Int,
        cardSize: CGSize,
        isCleared: Bool,
        isUnlocked: Bool
    ) {
        let theme = ThemeManager.shared
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 10)
        card.position = position
        card.zPosition = 10

        if isCleared {
            card.fillColor = theme.goalFillColor.withAlphaComponent(0.25)
            card.strokeColor = theme.goalFillColor.withAlphaComponent(0.8)
            card.lineWidth = 2
        } else if isUnlocked {
            card.fillColor = theme.hudColor.withAlphaComponent(0.1)
            card.strokeColor = theme.hudColor.withAlphaComponent(0.5)
            card.lineWidth = 1.5
        } else {
            card.fillColor = theme.hudColor.withAlphaComponent(0.05)
            card.strokeColor = theme.hudColor.withAlphaComponent(0.2)
            card.lineWidth = 1
        }

        if isUnlocked {
            card.name = "stage_\(stageIndex)"
        }
        addChild(card)

        // ステージ番号
        let numberLabel = SKLabelNode(text: "\(stageNumber)")
        numberLabel.fontName = "AvenirNext-Heavy"
        numberLabel.fontSize = 20
        numberLabel.fontColor = isUnlocked
            ? theme.hudColor
            : theme.hudColor.withAlphaComponent(0.35)
        numberLabel.horizontalAlignmentMode = .center
        numberLabel.verticalAlignmentMode = .center
        numberLabel.position = CGPoint(x: 0, y: isCleared ? 6 : 0)
        numberLabel.zPosition = 11
        if isUnlocked { numberLabel.name = "stage_\(stageIndex)" }
        card.addChild(numberLabel)

        // クリア済みチェックマーク
        if isCleared {
            let checkLabel = SKLabelNode(text: "✓")
            checkLabel.fontName = "AvenirNext-Heavy"
            checkLabel.fontSize = 13
            checkLabel.fontColor = theme.goalFillColor
            checkLabel.horizontalAlignmentMode = .center
            checkLabel.verticalAlignmentMode = .center
            checkLabel.position = CGPoint(x: 0, y: -10)
            checkLabel.zPosition = 11
            card.addChild(checkLabel)
        }

        // ロックアイコン
        if !isUnlocked {
            let lockLabel = SKLabelNode(text: "🔒")
            lockLabel.fontSize = 16
            lockLabel.horizontalAlignmentMode = .center
            lockLabel.verticalAlignmentMode = .center
            lockLabel.position = CGPoint(x: 0, y: -10)
            lockLabel.zPosition = 11
            card.addChild(lockLabel)
        }

        // アンロック済みカードにホバーアニメ
        if isUnlocked {
            let hoverScale = SKAction.sequence([
                SKAction.scale(to: 1.03, duration: 0.8 + Double.random(in: 0...0.4)),
                SKAction.scale(to: 0.97, duration: 0.8 + Double.random(in: 0...0.4))
            ])
            card.run(SKAction.repeatForever(hoverScale))
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)

        for node in nodes {
            if node.name == "backButton" {
                goToTitle()
                return
            }
            if let name = node.name, name.hasPrefix("stage_"),
               let indexStr = name.split(separator: "_").last,
               let stageIndex = Int(indexStr) {
                startStage(index: stageIndex)
                return
            }
        }
    }

    // MARK: - Navigation

    private func goToTitle() {
        let titleScene = TitleScene(size: size)
        titleScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.4
        )
        view?.presentScene(titleScene, transition: transition)
    }

    private func startStage(index: Int) {
        let gameScene = GameScene(size: size, stageIndex: index)
        gameScene.scaleMode = scaleMode
        let transition = SKTransition.fade(
            with: ThemeManager.shared.transitionColor,
            duration: 0.4
        )
        view?.presentScene(gameScene, transition: transition)
    }

    // MARK: - UserDefaults

    private func getClearedStages() -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: "clearedStages") as? [Int] ?? []
        return Set(array)
    }
}
