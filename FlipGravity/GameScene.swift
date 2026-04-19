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

    /// 重力方向ごとのネオンカラー
    var neonColor: UIColor {
        switch self {
        case .down:  return UIColor(hex: "4FC3F7") // ブルー
        case .right: return UIColor(hex: "FFD740") // イエロー
        case .up:    return UIColor(hex: "FF5252") // レッド
        case .left:  return UIColor(hex: "69F0AE") // グリーン
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

    private var stageIndex: Int = 0
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

    // MARK: - Initializer

    convenience init(size: CGSize, stageIndex: Int) {
        self.init(size: size)
        self.stageIndex = stageIndex
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        // ダーク背景 (#0D0D1A)
        backgroundColor = UIColor(hex: "0D0D1A")

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

        addBackgroundGrid()
        buildStage()
        setupHUD()
    }

    // MARK: - Background Grid

    private func addBackgroundGrid() {
        let gridSpacing: CGFloat = 60
        let gridColor = UIColor(white: 1.0, alpha: 0.03)

        // 縦線
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

        // 横線
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

    // MARK: - Stage Building

    private func buildStage() {
        switch stageIndex {
        case 0: buildStage0()
        case 1: buildStage1()
        case 2: buildStage2()
        case 3: buildStage3()
        case 4: buildStage4()
        default: buildStage0()
        }
    }

    /// 共通の外壁（全ステージで呼び出す）
    private func addOuterWalls() {
        let w = size.width
        let h = size.height
        addFloor(rect: CGRect(x: 0, y: 0, width: w, height: 30), isTerrain: true)
        addFloor(rect: CGRect(x: 0, y: 0, width: 20, height: h), isTerrain: true)
        addFloor(rect: CGRect(x: w - 20, y: 0, width: 20, height: h), isTerrain: true)
        addFloor(rect: CGRect(x: 0, y: h - 20, width: w, height: 20), isTerrain: true)
    }

    /// Stage 0: チュートリアル（既存レイアウト）
    private func buildStage0() {
        let w = size.width
        let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.2)
        addOuterWalls()

        // 足場
        addFloor(rect: CGRect(x: 20, y: 100, width: w * 0.3, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.35, width: w * 0.25, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.65, width: w * 0.2, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.7, width: w * 0.25, height: 18), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.3, y: h * 0.82, width: w * 0.25, height: 18), isTerrain: false)

        // スパイク
        addSpike(at: CGPoint(x: w * 0.35, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.50, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.65, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.68, y: h * 0.35 + 18), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.8, y: h - 20), pointingUp: false)

        // 溶岩
        addLava(rect: CGRect(x: w * 0.3, y: 30, width: w * 0.13, height: 18))
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: 22))

        // 消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.45, y: h * 0.55, width: w * 0.2, height: 14))

        // ゴール
        addGoal(at: CGPoint(x: w * 0.42, y: h * 0.82 + 18 + 20))

        spawnPlayer()
    }

    /// Stage 1: 縦走路 — 縦に細長い通路を重力切り替えで進む
    private func buildStage1() {
        let w = size.width
        let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.12)
        addOuterWalls()

        // 左通路の縦仕切り（右壁よりの内壁）
        addFloor(rect: CGRect(x: w * 0.4, y: 30, width: 18, height: h * 0.5), isTerrain: true)
        // 右通路の縦仕切り（左壁より）
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.45, width: 18, height: h * 0.55 - 20), isTerrain: true)

        // 左通路内の足場
        addFloor(rect: CGRect(x: 20, y: h * 0.3, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.55, width: w * 0.25, height: 16), isTerrain: false)

        // 右側通路の足場
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.25, width: w * 0.2, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.6, width: w * 0.2, height: 16), isTerrain: false)

        // スパイク（上下に配置）
        addSpike(at: CGPoint(x: w * 0.2, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.2, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.7, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.7, y: h * 0.45), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.85, y: 30), pointingUp: true)

        // 溶岩（通路をふさぐ形）
        addLava(rect: CGRect(x: 20, y: h * 0.42, width: w * 0.35, height: 16))

        // ゴール（右上）
        addGoal(at: CGPoint(x: w * 0.8, y: h * 0.6 + 16 + 22))

        spawnPlayer()
    }

    /// Stage 2: 溶岩地獄 — 画面下半分に溶岩、重力上向き必須
    private func buildStage2() {
        let w = size.width
        let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.7)
        addOuterWalls()

        // 下半分を覆う溶岩（床の上）
        addLava(rect: CGRect(x: 20, y: 30, width: w * 0.3, height: h * 0.38))
        addLava(rect: CGRect(x: w * 0.45, y: 30, width: w * 0.2, height: h * 0.38))
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: h * 0.38))

        // 上側の足場群
        addFloor(rect: CGRect(x: 20, y: h * 0.6, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.35, y: h * 0.72, width: w * 0.3, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.55, width: w * 0.2, height: 16), isTerrain: false)

        // 天井近くの足場（重力上向き時の着地点）
        addFloor(rect: CGRect(x: w * 0.3, y: h * 0.85, width: w * 0.35, height: 16), isTerrain: false)

        // 溶岩の橋を渡るための細足場
        addFloor(rect: CGRect(x: w * 0.32, y: h * 0.4, width: w * 0.1, height: 14), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.67, y: h * 0.4, width: w * 0.06, height: 14), isTerrain: false)

        // スパイク（天井）
        addSpike(at: CGPoint(x: w * 0.5, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.25, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20), pointingUp: false)

        // ゴール（右上の足場上）
        addGoal(at: CGPoint(x: w * 0.7, y: h * 0.55 + 16 + 22))

        spawnPlayer()
    }

    /// Stage 3: 消える床パズル — 踏む順番が重要
    private func buildStage3() {
        let w = size.width
        let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.15)
        addOuterWalls()

        // スタート台（固定足場）
        addFloor(rect: CGRect(x: 20, y: 80, width: w * 0.2, height: 16), isTerrain: false)

        // 消える床1（低段）
        addBlinkingFloor(rect: CGRect(x: w * 0.28, y: h * 0.18, width: w * 0.18, height: 14))
        // 消える床2（中段）
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.35, width: w * 0.18, height: 14))
        // 消える床3（高段）
        addBlinkingFloor(rect: CGRect(x: w * 0.25, y: h * 0.55, width: w * 0.18, height: 14))
        // 消える床4（最高段）
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.18, height: 14))

        // 固定足場（消える床の補助）
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.5, width: w * 0.08, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.82, width: w * 0.08, height: 16), isTerrain: false)

        // スパイク（落下罠）
        addSpike(at: CGPoint(x: w * 0.45, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.6, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.75, y: 30), pointingUp: true)

        // 溶岩（迂回不可能にする）
        addLava(rect: CGRect(x: w * 0.2, y: 30, width: w * 0.22, height: 16))

        // ゴール（右上固定足場の上）
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.82 + 16 + 22))

        spawnPlayer()
    }

    /// Stage 4: 全方向攻略 — 4方向の重力全てを使う難関
    private func buildStage4() {
        let w = size.width
        let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12)
        addOuterWalls()

        // 中央に仕切り壁（上下）
        addFloor(rect: CGRect(x: w * 0.45, y: 30, width: 18, height: h * 0.35), isTerrain: true)
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.6, width: 18, height: h * 0.4 - 20), isTerrain: true)

        // 左下エリアの足場
        addFloor(rect: CGRect(x: 20, y: h * 0.2, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: 20, y: h * 0.4, width: w * 0.18, height: 16), isTerrain: false)

        // 右下エリアの足場
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.25, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.65, y: h * 0.38, width: w * 0.15, height: 16), isTerrain: false)

        // 上エリアの足場
        addFloor(rect: CGRect(x: w * 0.1, y: h * 0.65, width: w * 0.2, height: 16), isTerrain: false)
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.25, height: 16), isTerrain: false)

        // 消える床（中央通路に配置）
        addBlinkingFloor(rect: CGRect(x: w * 0.22, y: h * 0.55, width: w * 0.18, height: 14))
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.55, width: w * 0.18, height: 14))

        // スパイク（全方向）
        addSpike(at: CGPoint(x: w * 0.3, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.7, y: 30), pointingUp: true)
        addSpike(at: CGPoint(x: w * 0.3, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: w * 0.7, y: h - 20), pointingUp: false)
        addSpike(at: CGPoint(x: 20, y: h * 0.5), pointingUp: true)   // 左壁向き（右向きスパイク）
        addSpike(at: CGPoint(x: w - 20, y: h * 0.5), pointingUp: false) // 右壁向き（左向きスパイク）

        // 溶岩（左右の落下エリア）
        addLava(rect: CGRect(x: 20, y: 30, width: w * 0.22, height: 14))
        addLava(rect: CGRect(x: w * 0.58, y: 30, width: w * 0.22, height: 14))

        // ゴール（右上エリア、最も到達困難な位置）
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.72 + 16 + 22))

        spawnPlayer()
    }

    // MARK: - Node Factories

    /// isTerrain: true = 床/壁/天井、false = 足場ブロック
    private func addFloor(rect: CGRect, isTerrain: Bool) {
        let node = SKShapeNode(rect: rect)
        if isTerrain {
            // 床・壁・天井: ダークネイビー + ネオンブルーエッジ
            node.fillColor = UIColor(hex: "1A2035")
            node.strokeColor = UIColor(hex: "00BFFF")
            node.lineWidth = 2.0
        } else {
            // 足場ブロック: 深いブルー + スカイブルー縁
            node.fillColor = UIColor(hex: "0F3460")
            node.strokeColor = UIColor(hex: "4FC3F7")
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
        // シアン #00FFFF（ネオン水色）+ 白縁
        node.fillColor = UIColor(hex: "00FFFF")
        node.strokeColor = UIColor(hex: "FFFFFF")
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
        // #FF3D00（鮮やかなオレンジレッド）+ #FFAB40（アンバー）縁
        node.fillColor = UIColor(hex: "FF3D00")
        node.strokeColor = UIColor(hex: "FFAB40")
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
        // #7C4DFF（ネオンパープル）+ #B388FF（薄紫）縁
        node.fillColor = UIColor(hex: "7C4DFF")
        node.strokeColor = UIColor(hex: "B388FF")
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
        // #00E676（ネオングリーン）+ 白縁
        node.fillColor = UIColor(hex: "00E676").withAlphaComponent(0.9)
        node.strokeColor = .white
        node.lineWidth = 2
        node.name = "goal"

        // キラキラアニメ
        let scale = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5)
        ])
        node.run(SKAction.repeatForever(scale))

        // GOALラベル（fontSize: 14 に拡大）
        let label = SKLabelNode(text: "GOAL")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 14
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
        // 白 + 青グロー
        playerNode.fillColor = UIColor(hex: "FFFFFF")
        playerNode.strokeColor = UIColor(hex: "00BFFF")
        playerNode.lineWidth = 2
        playerNode.name = "player"

        // 転がりを示す十字線（自転感の演出）
        let crossSize: CGFloat = radius * 0.7
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: -crossSize, y: 0))
        crossPath.addLine(to: CGPoint(x: crossSize, y: 0))
        crossPath.move(to: CGPoint(x: 0, y: -crossSize))
        crossPath.addLine(to: CGPoint(x: 0, y: crossSize))
        let crossNode = SKShapeNode(path: crossPath)
        crossNode.strokeColor = UIColor(hex: "00BFFF").withAlphaComponent(0.6)
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
        // 死亡回数（左上）— フォントサイズ20、コーラルレッド
        deathLabel = SKLabelNode(text: "💀 ×0")
        deathLabel.fontName = "AvenirNext-Bold"
        deathLabel.fontSize = 20
        deathLabel.fontColor = UIColor(hex: "FF5252")
        deathLabel.horizontalAlignmentMode = .left
        deathLabel.verticalAlignmentMode = .top
        deathLabel.position = CGPoint(x: 30, y: size.height - 30)
        deathLabel.zPosition = 100
        addChild(deathLabel)

        // 重力インジケーター（下部中央）— フォントサイズ40、方向別ネオンカラー
        gravityLabel = SKLabelNode(text: gravityDirection.arrowText)
        gravityLabel.fontName = "AvenirNext-Heavy"
        gravityLabel.fontSize = 40
        gravityLabel.fontColor = gravityDirection.neonColor
        gravityLabel.horizontalAlignmentMode = .center
        gravityLabel.verticalAlignmentMode = .bottom
        gravityLabel.position = CGPoint(x: size.width / 2, y: 40)
        gravityLabel.zPosition = 100
        addChild(gravityLabel)

        // ヒントラベル — 半透明白、サイズ12
        let hintLabel = SKLabelNode(text: "TAP to rotate gravity")
        hintLabel.fontName = "AvenirNext-Medium"
        hintLabel.fontSize = 12
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
        gravityLabel.fontColor = gravityDirection.neonColor
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

        // 画面全体フラッシュ（0.05秒だけ白くする）
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

        // 重力変換エフェクト強化（colorize + スケール1.2倍）
        let flash = SKAction.sequence([
            SKAction.group([
                SKAction.colorize(with: UIColor(hex: "00BFFF"), colorBlendFactor: 0.9, duration: 0.08),
                SKAction.scale(to: 1.2, duration: 0.08)
            ]),
            SKAction.group([
                SKAction.colorize(with: UIColor(hex: "FFFFFF"), colorBlendFactor: 0.0, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ])
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

        // クリア状態をUserDefaultsに保存
        saveClearedStage(stageIndex)

        // CLEAR! テキスト
        let clearLabel = SKLabelNode(text: "CLEAR!")
        clearLabel.fontName = "AvenirNext-Heavy"
        clearLabel.fontSize = 60
        clearLabel.fontColor = UIColor(hex: "00E676")
        clearLabel.horizontalAlignmentMode = .center
        clearLabel.verticalAlignmentMode = .center
        clearLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
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
        subLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        subLabel.zPosition = 200
        subLabel.alpha = 0
        addChild(subLabel)

        // NEXT STAGE ボタン（次のステージが存在する場合）
        let nextStageIndex = stageIndex + 1
        if nextStageIndex < 20 {
            let nextBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
            nextBg.position = CGPoint(x: size.width / 2, y: size.height / 2 - 75)
            nextBg.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.4, alpha: 0.9)
            nextBg.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.8)
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

            nextBg.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.7),
                SKAction.fadeIn(withDuration: 0.3)
            ]))
        }

        // SELECT STAGE ボタン
        let selectBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
        let selectY = nextStageIndex < 20
            ? size.height / 2 - 130
            : size.height / 2 - 75
        selectBg.position = CGPoint(x: size.width / 2, y: selectY)
        selectBg.fillColor = UIColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 0.9)
        selectBg.strokeColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.7)
        selectBg.lineWidth = 1.5
        selectBg.zPosition = 200
        selectBg.alpha = 0
        selectBg.name = "selectStageButton"
        addChild(selectBg)

        let selectLabel = SKLabelNode(text: "SELECT STAGE")
        selectLabel.fontName = "AvenirNext-Bold"
        selectLabel.fontSize = 18
        selectLabel.fontColor = UIColor(white: 0.9, alpha: 1.0)
        selectLabel.horizontalAlignmentMode = .center
        selectLabel.verticalAlignmentMode = .center
        selectLabel.zPosition = 201
        selectLabel.name = "selectStageButton"
        selectBg.addChild(selectLabel)

        selectBg.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        // Retry ボタン
        let retryBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 10)
        let retryY = nextStageIndex < 20
            ? size.height / 2 - 185
            : size.height / 2 - 130
        retryBg.position = CGPoint(x: size.width / 2, y: retryY)
        retryBg.fillColor = UIColor(red: 0.25, green: 0.15, blue: 0.15, alpha: 0.9)
        retryBg.strokeColor = UIColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 0.7)
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

        retryBg.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.1),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

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

        // 背景を暗く
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

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard let body = playerNode?.physicsBody else { return }

        let speed = sqrt(body.velocity.dx * body.velocity.dx + body.velocity.dy * body.velocity.dy)
        let angularSpeed = abs(body.angularVelocity)

        // 速度が非常に小さい場合は完全停止させる
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
            case "retryButton":
                restartGame()
                return
            case "nextStageButton":
                goToNextStage()
                return
            case "selectStageButton":
                goToStageSelect()
                return
            default:
                break
            }
        }
    }

    private func restartGame() {
        let newScene = GameScene(size: size, stageIndex: stageIndex)
        newScene.scaleMode = scaleMode
        let transition = SKTransition.fade(with: UIColor(hex: "0D0D1A"), duration: 0.4)
        view?.presentScene(newScene, transition: transition)
    }

    private func goToNextStage() {
        let nextIndex = stageIndex + 1
        guard nextIndex < 20 else { return }
        let nextScene = GameScene(size: size, stageIndex: nextIndex)
        nextScene.scaleMode = scaleMode
        let transition = SKTransition.fade(with: UIColor(hex: "0D0D1A"), duration: 0.4)
        view?.presentScene(nextScene, transition: transition)
    }

    private func goToStageSelect() {
        let stageSelectScene = StageSelectScene(size: size)
        stageSelectScene.scaleMode = scaleMode
        let transition = SKTransition.fade(with: UIColor(hex: "0D0D1A"), duration: 0.4)
        view?.presentScene(stageSelectScene, transition: transition)
    }
}
