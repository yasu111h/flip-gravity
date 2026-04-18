import SpriteKit

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

    // MARK: Properties

    private var gravityDirection: GravityDirection = .down
    private var playerNode: SKShapeNode!
    private var deathCount = 0
    private var deathLabel: SKLabelNode!
    private var gravityLabel: SKLabelNode!
    private var isGameCleared = false
    private var canRotate = true
    private var spawnPoint = CGPoint.zero

    // 消える床管理
    private var blinkingFloors: [SKShapeNode: Bool] = [:]

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1.0)

        physicsWorld.gravity = gravityDirection.vector
        physicsWorld.contactDelegate = self

        // 世界の境界（画面外に落ちないよう少し広めに）
        let border = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: -size.width,
            y: -size.height * 2,
            width: size.width * 3,
            height: size.height * 4
        ))
        border.categoryBitMask = PhysicsCategory.ground
        border.collisionBitMask = PhysicsCategory.player
        physicsBody = border

        buildStage()
        setupHUD()
    }

    // MARK: - Stage Building

    private func buildStage() {
        let w = size.width
        let h = size.height

        // スポーン地点
        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.2)

        // ---- 床・壁 ----
        // 下の床（全幅）
        addFloor(rect: CGRect(x: 0, y: 0, width: w, height: 30), color: .darkGray)

        // 左の壁
        addFloor(rect: CGRect(x: 0, y: 0, width: 20, height: h), color: .darkGray)

        // 右の壁
        addFloor(rect: CGRect(x: w - 20, y: 0, width: 20, height: h), color: .darkGray)

        // 上の天井
        addFloor(rect: CGRect(x: 0, y: h - 20, width: w, height: 20), color: .darkGray)

        // ---- 足場 ----
        // 左下足場
        addFloor(rect: CGRect(x: 20, y: 100, width: w * 0.3, height: 18), color: UIColor(white: 0.45, alpha: 1))

        // 中央右の中段足場
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.35, width: w * 0.25, height: 18), color: UIColor(white: 0.45, alpha: 1))

        // 右上足場
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.65, width: w * 0.2, height: 18), color: UIColor(white: 0.45, alpha: 1))

        // 左上足場
        addFloor(rect: CGRect(x: 20, y: h * 0.7, width: w * 0.25, height: 18), color: UIColor(white: 0.45, alpha: 1))

        // 中央高足場（ゴール手前）
        addFloor(rect: CGRect(x: w * 0.3, y: h * 0.82, width: w * 0.25, height: 18), color: UIColor(white: 0.45, alpha: 1))

        // ---- ハザード: スパイク（三角形） ----
        // 下の床の上のスパイク群
        addSpike(at: CGPoint(x: w * 0.35, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.50, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.65, y: 30), pointingUp: true)

        // 中段足場の右端スパイク
        addSpike(at: CGPoint(x: w * 0.68, y: h * 0.35 + 18), pointingUp: true)

        // 右壁寄りスパイク（天井向き）
        addSpike(at: CGPoint(x: w * 0.8, y: h - 20), pointingUp: false)

        // ---- ハザード: 溶岩 ----
        addLava(rect: CGRect(x: w * 0.3, y: 30, width: w * 0.13, height: 18))

        // 右側溶岩プール
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: 22))

        // ---- 消える床 ----
        addBlinkingFloor(rect: CGRect(x: w * 0.45, y: h * 0.55, width: w * 0.2, height: 14))

        // ---- ゴール ----
        addGoal(at: CGPoint(x: w * 0.42, y: h * 0.82 + 18 + 20))

        // ---- プレイヤー生成 ----
        spawnPlayer()
    }

    // MARK: - Node Factories

    private func addFloor(rect: CGRect, color: UIColor) {
        let node = SKShapeNode(rect: rect)
        node.fillColor = color
        node.strokeColor = color.withAlphaComponent(0.5)
        node.lineWidth = 1

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
        node.fillColor = UIColor(red: 0.9, green: 0.85, blue: 0.2, alpha: 1)
        node.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1)
        node.lineWidth = 1.5

        // 当たり判定は長方形で近似
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
        node.fillColor = UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1.0)
        node.strokeColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        node.lineWidth = 2

        // ぐつぐつエフェクト（簡易パーティクル代わりにアニメ）
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
        node.fillColor = UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        node.strokeColor = UIColor(red: 0.5, green: 1.0, blue: 1.0, alpha: 1.0)
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
        node.fillColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.9)
        node.strokeColor = .white
        node.lineWidth = 2
        node.name = "goal"

        // キラキラアニメ
        let scale = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5)
        ])
        node.run(SKAction.repeatForever(scale))

        // GOALラベル
        let label = SKLabelNode(text: "GOAL")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        let body = SKPhysicsBody(circleOfRadius: 22)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.goal
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
        addChild(node)
    }

    // MARK: - Player

    private func spawnPlayer() {
        if playerNode != nil {
            playerNode.removeFromParent()
        }
        let radius: CGFloat = 15
        playerNode = SKShapeNode(circleOfRadius: radius)
        playerNode.position = spawnPoint
        playerNode.fillColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        playerNode.strokeColor = .white
        playerNode.lineWidth = 2
        playerNode.name = "player"

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.restitution = 0.1
        body.friction = 0.5
        body.linearDamping = 0.1
        body.angularDamping = 0.5
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.hazard | PhysicsCategory.goal | PhysicsCategory.ground
        playerNode.physicsBody = body
        addChild(playerNode)
    }

    // MARK: - HUD

    private func setupHUD() {
        // 死亡回数（左上）
        deathLabel = SKLabelNode(text: "💀 ×0")
        deathLabel.fontName = "AvenirNext-Bold"
        deathLabel.fontSize = 22
        deathLabel.fontColor = .white
        deathLabel.horizontalAlignmentMode = .left
        deathLabel.verticalAlignmentMode = .top
        deathLabel.position = CGPoint(x: 30, y: size.height - 30)
        deathLabel.zPosition = 100
        addChild(deathLabel)

        // 重力インジケーター（下部中央）
        gravityLabel = SKLabelNode(text: gravityDirection.arrowText)
        gravityLabel.fontName = "AvenirNext-Bold"
        gravityLabel.fontSize = 36
        gravityLabel.fontColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        gravityLabel.horizontalAlignmentMode = .center
        gravityLabel.verticalAlignmentMode = .bottom
        gravityLabel.position = CGPoint(x: size.width / 2, y: 40)
        gravityLabel.zPosition = 100
        addChild(gravityLabel)

        // ヒントラベル
        let hintLabel = SKLabelNode(text: "TAP to rotate gravity")
        hintLabel.fontName = "AvenirNext-Medium"
        hintLabel.fontSize = 13
        hintLabel.fontColor = UIColor(white: 1.0, alpha: 0.5)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .bottom
        hintLabel.position = CGPoint(x: size.width / 2, y: 15)
        hintLabel.zPosition = 100
        addChild(hintLabel)
    }

    private func updateHUD() {
        deathLabel.text = "💀 ×\(deathCount)"
        gravityLabel.text = gravityDirection.arrowText
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameCleared, canRotate else { return }

        // 連打防止
        canRotate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.canRotate = true
        }

        gravityDirection = gravityDirection.next()
        physicsWorld.gravity = gravityDirection.vector
        updateHUD()

        // 重力変換エフェクト
        let flash = SKAction.sequence([
            SKAction.colorize(with: UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 1), colorBlendFactor: 0.8, duration: 0.1),
            SKAction.colorize(with: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1), colorBlendFactor: 0.0, duration: 0.15)
        ])
        playerNode?.run(flash)

        // 矢印ラベルポップアニメ
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
            // 消える床のチェック
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

        // プレイヤーを止める
        playerNode.physicsBody?.velocity = .zero
        playerNode.physicsBody?.angularVelocity = 0

        // 死亡エフェクト
        let shrink = SKAction.sequence([
            SKAction.scale(to: 0.1, duration: 0.2),
            SKAction.removeFromParent()
        ])
        playerNode.run(shrink)

        // リスポーン
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            // 重力をリセット
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

        // CLEAR! テキスト
        let clearLabel = SKLabelNode(text: "CLEAR!")
        clearLabel.fontName = "AvenirNext-Heavy"
        clearLabel.fontSize = 60
        clearLabel.fontColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
        clearLabel.horizontalAlignmentMode = .center
        clearLabel.verticalAlignmentMode = .center
        clearLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        clearLabel.zPosition = 200
        clearLabel.setScale(0.1)
        addChild(clearLabel)

        // サブテキスト
        let subLabel = SKLabelNode(text: "Deaths: \(deathCount)")
        subLabel.fontName = "AvenirNext-Medium"
        subLabel.fontSize = 24
        subLabel.fontColor = .white
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        subLabel.zPosition = 200
        subLabel.alpha = 0
        addChild(subLabel)

        // タップでリトライボタン
        let retryLabel = SKLabelNode(text: "Tap to Retry")
        retryLabel.fontName = "AvenirNext-Medium"
        retryLabel.fontSize = 20
        retryLabel.fontColor = UIColor(white: 1.0, alpha: 0.8)
        retryLabel.horizontalAlignmentMode = .center
        retryLabel.verticalAlignmentMode = .center
        retryLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 95)
        retryLabel.zPosition = 200
        retryLabel.alpha = 0
        retryLabel.name = "retryButton"
        addChild(retryLabel)

        // アニメーション
        let popIn = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        clearLabel.run(popIn)

        let fadeIn = SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeIn(withDuration: 0.3)
        ])
        subLabel.run(fadeIn)
        retryLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            ]))
        ]))

        // 背景を暗く
        let overlay = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        overlay.fillColor = UIColor(white: 0, alpha: 0.5)
        overlay.strokeColor = .clear
        overlay.zPosition = 190
        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 0.5, duration: 0.3))
    }

    // MARK: - Blinking Floor

    private func triggerBlinkFloor(_ node: SKShapeNode) {
        guard blinkingFloors[node] == false else { return }
        blinkingFloors[node] = true

        // 点滅して2秒後に消える
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
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            self?.blinkingFloors.removeValue(forKey: node)
        }
    }

    // MARK: - Touch for Retry

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameCleared else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        if nodes.contains(where: { $0.name == "retryButton" }) {
            restartGame()
        }
    }

    private func restartGame() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        let transition = SKTransition.fade(with: UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1.0), duration: 0.4)
        view?.presentScene(newScene, transition: transition)
    }
}
