import SpriteKit

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - GravityDirection

enum GravityDirection {
    case down, right, up, left

    var vector: CGVector {
        switch self {
        case .down:  return CGVector(dx: 0, dy: -9.8)
        case .right: return CGVector(dx: 9.8, dy: 0)
        case .up:    return CGVector(dx: 0, dy: 9.8)
        case .left:  return CGVector(dx: -9.8, dy: 0)
        }
    }

    func next() -> GravityDirection {
        switch self {
        case .down:  return .right
        case .right: return .up
        case .up:    return .left
        case .left:  return .down
        }
    }

    var arrowText: String {
        switch self {
        case .down:  return "↓"
        case .right: return "→"
        case .up:    return "↑"
        case .left:  return "←"
        }
    }

    var neonColor: UIColor {
        switch self {
        case .down:  return UIColor(hex: "4FC3F7")
        case .right: return UIColor(hex: "FFD740")
        case .up:    return UIColor(hex: "FF5252")
        case .left:  return UIColor(hex: "69F0AE")
        }
    }
}

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none:   UInt32 = 0x0
    static let player: UInt32 = 0x1
    static let ground: UInt32 = 0x2
    static let hazard: UInt32 = 0x4
    static let goal:   UInt32 = 0x8
}

// MARK: - GameScene

class GameScene: SKScene, SKPhysicsContactDelegate {

    private var stageIndex: Int = 0
    private var gravityDirection: GravityDirection = .down
    private var playerNode: SKShapeNode!
    private var deathCount = 0
    private var deathLabel: SKLabelNode!
    private var gravityLabel: SKLabelNode!
    private var isGameCleared = false
    private var canRotate = true
    private var spawnPoint = CGPoint.zero
    private var blinkingFloors: [SKShapeNode: Bool] = [:]

    convenience init(size: CGSize, stageIndex: Int) {
        self.init(size: size)
        self.stageIndex = stageIndex
    }

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared
        backgroundColor = theme.backgroundColor

        physicsWorld.gravity = gravityDirection.vector
        physicsWorld.contactDelegate = self

        let border = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: -size.width,
            y: -size.height * 2,
            width: size.width * 3,
            height: size.height * 4
        ))
        border.categoryBitMask = PhysicsCategory.ground
        border.collisionBitMask = PhysicsCategory.player
        physicsBody = border

        if theme.hasGrid { addBackgroundGrid() }
        if theme.hasStars { addBackgroundStars() }
        buildStage()
        setupHUD()
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
        for _ in 0..<80 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.fillColor = UIColor(white: 1.0, alpha: CGFloat.random(in: 0.2...0.8))
            star.strokeColor = .clear
            star.zPosition = -5
            addChild(star)
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.3), duration: CGFloat.random(in: 0.5...2.0)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.9), duration: CGFloat.random(in: 0.5...2.0))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
    }

    private func buildStage() {
        switch stageIndex {
        case 0: buildStage0()
        case 1: buildStage1()
        case 2: buildStage2()
        case 3: buildStage3()
        case 4: buildStage4()
        case 5: buildStage5()
        case 6: buildStage6()
        case 7: buildStage7()
        case 8: buildStage8()
        case 9: buildStage9()
        case 10: buildStage10()
        case 11: buildStage11()
        case 12: buildStage12()
        case 13: buildStage13()
        case 14: buildStage14()
        default: buildStage0()
        }
    }

    private func addOuterWalls() {
        let w = size.width
        let h = size.height
        addFloor(rect: CGRect(x: 0, y: 0, width: w, height: 30), isTerrain: true)
        addFloor(rect: CGRect(x: 0, y: 0, width: 20, height: h), isTerrain: true)
        addFloor(rect: CGRect(x: w - 20, y: 0, width: 20, height: h), isTerrain: true)
        addFloor(rect: CGRect(x: 0, y: h - 20, width: w, height: 20), isTerrain: true)
    }

    private func buildStage0() {
        let w = size.width; let h = size.height
        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.2)
        addOuterWalls()
        addFloor(rect: CGRect(x: 20, y: 100, width: w * 0.3, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.35, width: w * 0.25, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.65, width: w * 0.2, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.7, width: w * 0.25, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.3, y: h * 0.82, width: w * 0.25, height: 18), isTerrain: false)
        addSpike(at: CGPoint(x: w * 0.35, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.50, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.65, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.68, y: h * 0.35 + 18), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.8, y: h - 20), pointingUp: false)
        addLava(rect: CGRect(x: w * 0.3, y: 30, width: w * 0.13, height: 18))
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: 22))
        addBlinkingFloor(rect: CGRect(x: w * 0.45, y: h * 0.55, width: w * 0.2, height: 14))
        addGoal(at: CGPoint(x: w * 0.42, y: h * 0.82 + 18 + 20))
        spawnPlayer()
    }

    private func buildStage1() {
        let w = size.width; let h = size.height
        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.12)
        addOuterWalls()
        addFloor(rect: CGRect(x: w * 0.4, y: 30, width: 18, height: h * 0.5), isTerrain: true)
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.45, width: 18, height: h * 0.55 - 20), isTerrain: true)
        addFloor(rect: CGRect(x: 20, y: h * 0.3, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.55, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.25, width: w * 0.2, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.6, width: w * 0.2, height: 16), isTerrain: false)
        addSpike(at: CGPoint(x: w * 0.2, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.2, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.7, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.7, y: h * 0.45), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.85, y: 30), pointingUp: true)
        addLava(rect: CGRect(x: 20, y: h * 0.42, width: w * 0.35, height: 16))
        addGoal(at: CGPoint(x: w * 0.8, y: h * 0.6 + 16 + 22))
        spawnPlayer()
    }

    private func buildStage2() {
        let w = size.width; let h = size.height
        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.7)
        addOuterWalls()
        addLava(rect: CGRect(x: 20, y: 30, width: w * 0.3, height: h * 0.38))
        addLava(rect: CGRect(x: w * 0.45, y: 30, width: w * 0.2, height: h * 0.38))
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: h * 0.38))
        addFloor(rect: CGRect(x: 20, y: h * 0.6, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.35, y: h * 0.72, width: w * 0.3, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.55, width: w * 0.2, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.3, y: h * 0.85, width: w * 0.35, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.32, y: h * 0.4, width: w * 0.1, height: 14), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.67, y: h * 0.4, width: w * 0.06, height: 14), isTerrain: false)
        addSpike(at: CGPoint(x: w * 0.5, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.25, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20), pointingUp: false)
        addGoal(at: CGPoint(x: w * 0.7, y: h * 0.55 + 16 + 22))
        spawnPlayer()
    }

    private func buildStage3() {
        let w = size.width; let h = size.height
        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.15)
        addOuterWalls()
        addFloor(rect: CGRect(x: 20, y: 80, width: w * 0.2, height: 16), isTerrain: false)
        addBlinkingFloor(rect: CGRect(x: w * 0.28, y: h * 0.18, width: w * 0.18, height: 14))
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.35, width: w * 0.18, height: 14))
        addBlinkingFloor(rect: CGRect(x: w * 0.25, y: h * 0.55, width: w * 0.18, height: 14))
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.18, height: 14))
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.5, width: w * 0.08, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.82, width: w * 0.08, height: 16), isTerrain: false)
        addSpike(at: CGPoint(x: w * 0.45, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.6, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.75, y: 30), pointingUp: true)
        addLava(rect: CGRect(x: w * 0.2, y: 30, width: w * 0.22, height: 16))
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.82 + 16 + 22))
        spawnPlayer()
    }

    private func buildStage4() {
        let w = size.width; let h = size.height
        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12)
        addOuterWalls()
        addFloor(rect: CGRect(x: w * 0.45, y: 30, width: 18, height: h * 0.35), isTerrain: true)
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.6, width: 18, height: h * 0.4 - 20), isTerrain: true)
        addFloor(rect: CGRect(x: 20, y: h * 0.2, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.4, width: w * 0.18, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.65, y: h * 0.38, width: w * 0.15, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.1, y: h * 0.65, width: w * 0.2, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.25, height: 16), isTerrain: false)
        addBlinkingFloor(rect: CGRect(x: w * 0.22, y: h * 0.55, width: w * 0.18, height: 14))
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.55, width: w * 0.18, height: 14))
        addSpike(at: CGPoint(x: w * 0.3, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.7, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.3, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.7, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: 20, y: h * 0.5), pointingUp: true)
        addSpike(at: CGPoint(x: w - 20, y: h * 0.5), pointingUp: false)
        addLava(rect: CGRect(x: 20, y: 30, width: w * 0.22, height: 14))
        addLava(rect: CGRect(x: w * 0.58, y: 30, width: w * 0.22, height: 14))
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.72 + 16 + 22))
        spawnPlayer()
    }

    private func buildStage5() { buildStage0() }
    private func buildStage6() { buildStage1() }
    private func buildStage7() { buildStage2() }
    private func buildStage8() { buildStage3() }
    private func buildStage9() { buildStage4() }
    private func buildStage10() { buildStage0() }
    private func buildStage11() { buildStage1() }
    private func buildStage12() { buildStage2() }
    private func buildStage13() { buildStage3() }
    private func buildStage14() { buildStage4() }

    // MARK: - Node Factories

    private func addFloor(rect: CGRect, isTerrain: Bool) {
        let node = SKShapeNode(rect: rect)
        let theme = ThemeManager.shared
        if isTerrain {
            node.fillColor = theme.terrainFillColor
            node.strokeColor = theme.terrainStrokeColor
            node.lineWidth = 2.0
        } else {
            node.fillColor = theme.platformFillColor
            node.strokeColor = theme.platformStrokeColor
            node.lineWidth = 2.0
        }
        let body = SKPhysicsBody(rectangleOf: rect.size,
                                 center: CGPoint(x: rect.midX, y: rect.midY))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.none
        node.physicsBody = body
        addChild(node)
    }

    private func addSpike(at tip: CGPoint, pointingUp: Bool) {
        let size: CGFloat = 20
        let path = CGMutablePath()
        if pointingUp {
            path.move(to: CGPoint(x: tip.x, y: tip.y + size))
            path.addLine(to: CGPoint(x: tip.x - size / 2, y: tip.y))
            path.addLine(to: CGPoint(x: tip.x + size / 2, y: tip.y))
        } else {
            path.move(to: CGPoint(x: tip.x, y: tip.y - size))
            path.addLine(to: CGPoint(x: tip.x - size / 2, y: tip.y))
            path.addLine(to: CGPoint(x: tip.x + size / 2, y: tip.y))
        }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        let theme = ThemeManager.shared
        node.fillColor = theme.spikeFillColor
        node.strokeColor = theme.spikeStrokeColor
        node.lineWidth = 1.5
        let body = SKPhysicsBody(rectangleOf: CGSize(width: size, height: size / 2),
                                 center: CGPoint(x: tip.x, y: tip.y + (pointingUp ? size / 4 : -size / 4)))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
        addChild(node)
    }

    private func addLava(rect: CGRect) {
        let node = SKShapeNode(rect: rect, cornerRadius: 3)
        let theme = ThemeManager.shared
        node.fillColor = theme.lavaFillColor
        node.strokeColor = theme.lavaStrokeColor
        node.lineWidth = 2
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.4),
            SKAction.fadeAlpha(to: 1.0, duration: 0.4)
        ])
        node.run(SKAction.repeatForever(pulse))
        let body = SKPhysicsBody(rectangleOf: rect.size,
                                 center: CGPoint(x: rect.midX, y: rect.midY))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
        addChild(node)
    }

    private func addBlinkingFloor(rect: CGRect) {
        let node = SKShapeNode(rect: rect)
        let theme = ThemeManager.shared
        node.fillColor = theme.blinkFloorFillColor
        node.strokeColor = theme.blinkFloorStrokeColor
        node.lineWidth = 1.5
        node.name = "blinkFloor"
        let body = SKPhysicsBody(rectangleOf: rect.size,
                                 center: CGPoint(x: rect.midX, y: rect.midY))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
        blinkingFloors[node] = false
        addChild(node)
    }

    private func addGoal(at position: CGPoint) {
        let node = SKShapeNode(circleOfRadius: 22)
        node.position = position
        let theme = ThemeManager.shared
        node.fillColor = theme.goalFillColor.withAlphaComponent(0.9)
        node.strokeColor = theme.goalStrokeColor
        node.lineWidth = 2
        node.name = "goal"
        let scale = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5)
        ])
        node.run(SKAction.repeatForever(scale))
        let label = SKLabelNode(text: "GOAL")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.goal
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
        addChild(node)
    }

    // MARK: - Player

    private func spawnPlayer() {
        if playerNode != nil { playerNode.removeFromParent() }
        let radius: CGFloat = 15
        playerNode = SKShapeNode(circleOfRadius: radius)
        playerNode.position = spawnPoint
        let theme = ThemeManager.shared
        playerNode.fillColor = theme.playerFillColor
        playerNode.strokeColor = theme.playerStrokeColor
        playerNode.lineWidth = 2
        playerNode.name = "player"
        let crossSize: CGFloat = radius * 0.7
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: -crossSize, y: 0))
        crossPath.addLine(to: CGPoint(x: crossSize, y: 0))
        crossPath.move(to: CGPoint(x: 0, y: -crossSize))
        crossPath.addLine(to: CGPoint(x: 0, y: crossSize))
        let crossNode = SKShapeNode(path: crossPath)
        crossNode.strokeColor = theme.playerStrokeColor.withAlphaComponent(0.6)
        crossNode.lineWidth = 1.5
        crossNode.zPosition = 1
        playerNode.addChild(crossNode)
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.restitution = 0.1
        body.friction = 0.3
        body.linearDamping = 0.8
        body.angularDamping = 0.95
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.hazard | PhysicsCategory.goal | PhysicsCategory.ground
        playerNode.physicsBody = body
        addChild(playerNode)
    }

    // MARK: - HUD

    private func setupHUD() {
        let theme = ThemeManager.shared
        let hudColor = theme.hudColor

        deathLabel = SKLabelNode(text: "💀 ×0")
        deathLabel.fontName = "AvenirNext-Bold"
        deathLabel.fontSize = 20
        deathLabel.fontColor = UIColor(hex: "FF5252")
        deathLabel.horizontalAlignmentMode = .left
        deathLabel.verticalAlignmentMode = .top
        deathLabel.position = CGPoint(x: 30, y: size.height - 30)
        deathLabel.zPosition = 100
        addChild(deathLabel)

        gravityLabel = SKLabelNode(text: gravityDirection.arrowText)
        gravityLabel.fontName = "AvenirNext-Heavy"
        gravityLabel.fontSize = 40
        gravityLabel.fontColor = gravityDirection.neonColor
        gravityLabel.horizontalAlignmentMode = .center
        gravityLabel.verticalAlignmentMode = .bottom
        gravityLabel.position = CGPoint(x: size.width / 2, y: 40)
        gravityLabel.zPosition = 100
        addChild(gravityLabel)

        let hintLabel = SKLabelNode(text: "TAP to rotate gravity")
        hintLabel.fontName = "AvenirNext-Medium"
        hintLabel.fontSize = 12
        hintLabel.fontColor = hudColor.withAlphaComponent(0.5)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .bottom
        hintLabel.position = CGPoint(x: size.width / 2, y: 15)
        hintLabel.zPosition = 100
        addChild(hintLabel)

        let backButton = SKLabelNode(text: "✕")
        backButton.fontName = "AvenirNext-Bold"
        backButton.fontSize = 24
        backButton.fontColor = hudColor.withAlphaComponent(0.7)
        backButton.horizontalAlignmentMode = .right
        backButton.verticalAlignmentMode = .top
        backButton.position = CGPoint(x: size.width - 25, y: size.height - 25)
        backButton.zPosition = 100
        backButton.name = "backButton"
        addChild(backButton)
    }

    private func updateHUD() {
        deathLabel.text = "💀 ×\(deathCount)"
        gravityLabel.text = gravityDirection.arrowText
        gravityLabel.fontColor = gravityDirection.neonColor
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let nodes = self.nodes(at: location)
            if nodes.contains(where: { $0.name == "backButton" }) {
                goToStageSelect()
                return
            }
        }

        guard !isGameCleared, canRotate else { return }

        canRotate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.canRotate = true
        }

        gravityDirection = gravityDirection.next()
        physicsWorld.gravity = gravityDirection.vector
        updateHUD()

        let screenFlash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        screenFlash.fillColor = UIColor(white: 1.0, alpha: 0.15)
        screenFlash.strokeColor = .clear
        screenFlash.zPosition = 150
        addChild(screenFlash)
        screenFlash.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))

        let theme = ThemeManager.shared
        let flash = SKAction.sequence([
            SKAction.group([
                SKAction.colorize(with: theme.playerStrokeColor, colorBlendFactor: 0.9, duration: 0.08),
                SKAction.scale(to: 1.2, duration: 0.08)
            ]),
            SKAction.group([
                SKAction.colorize(with: theme.playerFillColor, colorBlendFactor: 0.0, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ])
        ])
        playerNode?.run(flash)

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        gravityLabel.run(pop)
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let playerBody = (bodyA.categoryBitMask == PhysicsCategory.player) ? bodyA : bodyB
        let otherBody  = (bodyA.categoryBitMask == PhysicsCategory.player) ? bodyB : bodyA
        guard playerBody.categoryBitMask == PhysicsCategory.player else { return }

        if otherBody.categoryBitMask == PhysicsCategory.hazard {
            handleDeath()
        } else if otherBody.categoryBitMask == PhysicsCategory.goal {
            handleClear()
        } else if otherBody.categoryBitMask == PhysicsCategory.ground {
            if let floorNode = otherBody.node as? SKShapeNode,
               blinkingFloors[floorNode] == false {
                triggerBlinkFloor(floorNode)
            }
        }
    }

    // MARK: - Death & Respawn

    private func handleDeath() {
        guard !isGameCleared else { return }
        deathCount += 1
        updateHUD()
        playerNode.physicsBody?.velocity = .zero
        playerNode.physicsBody?.angularVelocity = 0
        let shrink = SKAction.sequence([
            SKAction.scale(to: 0.1, duration: 0.2),
            SKAction.removeFromParent()
        ])
        playerNode.run(shrink)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            self.gravityDirection = .down
            self.physicsWorld.gravity = self.gravityDirection.vector
            self.updateHUD()
            self.spawnPlayer()
        }
    }

    // MARK: - Clear

    private func handleClear() {
        guard !isGameCleared else { return }
        isGameCleared = true
        playerNode.physicsBody?.isDynamic = false
        saveClearedStage(stageIndex)

        let theme = ThemeManager.shared

        let clearLabel = SKLabelNode(text: "CLEAR!")
        clearLabel.fontName = "AvenirNext-Heavy"
        clearLabel.fontSize = 60
        clearLabel.fontColor = theme.goalFillColor
        clearLabel.horizontalAlignmentMode = .center
        clearLabel.verticalAlignmentMode = .center
        clearLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        clearLabel.zPosition = 200
        clearLabel.setScale(0.1)
        addChild(clearLabel)

        let subLabel = SKLabelNode(text: "Deaths: \(deathCount)")
        subLabel.fontName = "AvenirNext-Medium"
        subLabel.fontSize = 24
        subLabel.fontColor = theme.hudColor
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        subLabel.zPosition = 200
        subLabel.alpha = 0
        addChild(subLabel)

        let nextStageIndex = stageIndex + 1
        if nextStageIndex < 20 {
            let nextBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
            nextBg.position = CGPoint(x: size.width / 2, y: size.height / 2 - 75)
            nextBg.fillColor = theme.goalFillColor.withAlphaComponent(0.3)
            nextBg.strokeColor = theme.goalFillColor.withAlphaComponent(0.8)
            nextBg.lineWidth = 2
            nextBg.zPosition = 200
            nextBg.alpha = 0
            nextBg.name = "nextStageButton"
            addChild(nextBg)
            let nextLabel = SKLabelNode(text: "NEXT STAGE →")
            nextLabel.fontName = "AvenirNext-Bold"
            nextLabel.fontSize = 18
            nextLabel.fontColor = .white
            nextLabel.horizontalAlignmentMode = .center
            nextLabel.verticalAlignmentMode = .center
            nextLabel.zPosition = 201
            nextLabel.name = "nextStageButton"
            nextBg.addChild(nextLabel)
            nextBg.run(SKAction.sequence([SKAction.wait(forDuration: 0.7), SKAction.fadeIn(withDuration: 0.3)]))
        }

        let selectBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
        let selectY = nextStageIndex < 20 ? size.height / 2 - 130 : size.height / 2 - 75
        selectBg.position = CGPoint(x: size.width / 2, y: selectY)
        selectBg.fillColor = theme.hudColor.withAlphaComponent(0.15)
        selectBg.strokeColor = theme.hudColor.withAlphaComponent(0.7)
        selectBg.lineWidth = 1.5
        selectBg.zPosition = 200
        selectBg.alpha = 0
        selectBg.name = "selectStageButton"
        addChild(selectBg)
        let selectLabel = SKLabelNode(text: "SELECT STAGE")
        selectLabel.fontName = "AvenirNext-Bold"
        selectLabel.fontSize = 18
        selectLabel.fontColor = theme.hudColor
        selectLabel.horizontalAlignmentMode = .center
        selectLabel.verticalAlignmentMode = .center
        selectLabel.zPosition = 201
        selectLabel.name = "selectStageButton"
        selectBg.addChild(selectLabel)
        selectBg.run(SKAction.sequence([SKAction.wait(forDuration: 0.9), SKAction.fadeIn(withDuration: 0.3)]))

        let retryBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
        let retryY = nextStageIndex < 20 ? size.height / 2 - 185 : size.height / 2 - 130
        retryBg.position = CGPoint(x: size.width / 2, y: retryY)
        retryBg.fillColor = UIColor(hex: "FF5252").withAlphaComponent(0.15)
        retryBg.strokeColor = UIColor(hex: "FF5252").withAlphaComponent(0.7)
        retryBg.lineWidth = 1.5
        retryBg.zPosition = 200
        retryBg.alpha = 0
        retryBg.name = "retryButton"
        addChild(retryBg)
        let retryLabel = SKLabelNode(text: "RETRY")
        retryLabel.fontName = "AvenirNext-Bold"
        retryLabel.fontSize = 18
        retryLabel.fontColor = UIColor(white: 0.85, alpha: 1.0)
        retryLabel.horizontalAlignmentMode = .center
        retryLabel.verticalAlignmentMode = .center
        retryLabel.zPosition = 201
        retryLabel.name = "retryButton"
        retryBg.addChild(retryLabel)
        retryBg.run(SKAction.sequence([SKAction.wait(forDuration: 1.1), SKAction.fadeIn(withDuration: 0.3)]))

        let popIn = SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.3), SKAction.scale(to: 1.0, duration: 0.1)])
        clearLabel.run(popIn)
        let fadeIn = SKAction.sequence([SKAction.wait(forDuration: 0.4), SKAction.fadeIn(withDuration: 0.3)])
        subLabel.run(fadeIn)

        let overlay = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        overlay.fillColor = UIColor(white: 0, alpha: 0.5)
        overlay.strokeColor = .clear
        overlay.zPosition = 190
        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 0.5, duration: 0.3))
    }

    // MARK: - UserDefaults

    private func saveClearedStage(_ index: Int) {
        var cleared = UserDefaults.standard.array(forKey: "clearedStages") as? [Int] ?? []
        if !cleared.contains(index) {
            cleared.append(index)
            UserDefaults.standard.set(cleared, forKey: "clearedStages")
        }
    }

    // MARK: - Blinking Floor

    private func triggerBlinkFloor(_ node: SKShapeNode) {
        guard blinkingFloors[node] == false else { return }
        blinkingFloors[node] = true
        let blink = SKAction.sequence([
            SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ]))
        ])
        node.run(blink, withKey: "blink")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak node] in
            guard let node = node else { return }
            node.removeAction(forKey: "blink")
            node.physicsBody?.categoryBitMask = PhysicsCategory.none
            node.physicsBody?.collisionBitMask = PhysicsCategory.none
            node.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
            self?.blinkingFloors.removeValue(forKey: node)
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard let body = playerNode?.physicsBody else { return }
        let speed = sqrt(body.velocity.dx * body.velocity.dx + body.velocity.dy * body.velocity.dy)
        let angularSpeed = abs(body.angularVelocity)
        if speed < 15.0 && angularSpeed < 0.3 {
            body.velocity = .zero
            body.angularVelocity = 0
        }
    }

    // MARK: - Touch for Retry

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameCleared else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        for node in nodes {
            switch node.name {
            case "retryButton":    restartGame(); return
            case "nextStageButton": goToNextStage(); return
            case "selectStageButton": goToStageSelect(); return
            default: break
            }
        }
    }

    private func restartGame() {
        let newScene = GameScene(size: size, stageIndex: stageIndex)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: SKTransition.fade(with: ThemeManager.shared.transitionColor, duration: 0.4))
    }

    private func goToNextStage() {
        let nextIndex = stageIndex + 1
        guard nextIndex < 20 else { return }
        let nextScene = GameScene(size: size, stageIndex: nextIndex)
        nextScene.scaleMode = scaleMode
        view?.presentScene(nextScene, transition: SKTransition.fade(with: ThemeManager.shared.transitionColor, duration: 0.4))
    }

    private func goToStageSelect() {
        let stageSelectScene = StageSelectScene(size: size)
        stageSelectScene.scaleMode = scaleMode
        view?.presentScene(stageSelectScene, transition: SKTransition.fade(with: ThemeManager.shared.transitionColor, duration: 0.4))
    }
}
