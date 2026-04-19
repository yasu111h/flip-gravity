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

    // ステージ番号に応じてビルド関数を切り替える
    private func buildStage() {
        switch stageIndex {
        case 0:  buildStage0()
        case 1:  buildStage1()
        case 2:  buildStage2()
        case 3:  buildStage3()
        case 4:  buildStage4()
        case 5:  buildStage5()
        case 6:  buildStage6()
        case 7:  buildStage7()
        case 8:  buildStage8()
        case 9:  buildStage9()
        case 10: buildStage10()
        case 11: buildStage11()
        case 12: buildStage12()
        case 13: buildStage13()
        case 14: buildStage14()
        default: buildStage0()
        }
    }

    // ─────────────────────────────────────────────
    // 【外壁】全ステージ共通の4辺（床・天井・左右の壁）
    // ─────────────────────────────────────────────
    private func addOuterWalls() {
        let w = size.width
        let h = size.height
        addFloor(rect: CGRect(x: 0,      y: 0,      width: w,  height: 30), isTerrain: true) // 床
        addFloor(rect: CGRect(x: 0,      y: 0,      width: 20, height: h),  isTerrain: true) // 左壁
        addFloor(rect: CGRect(x: w - 20, y: 0,      width: 20, height: h),  isTerrain: true) // 右壁
        addFloor(rect: CGRect(x: 0,      y: h - 20, width: w,  height: 20), isTerrain: true) // 天井
    }

    // ─────────────────────────────────────────────
    // 【座標の読み方】
    //
    //  原点(0,0)は画面の左下。
    //  w = 画面幅（iPhone 16で約390pt）
    //  h = 画面高さ（iPhone 16で約844pt）
    //
    //  例: CGPoint(x: w * 0.5, y: h * 0.5) → 画面中央
    //      CGPoint(x: w * 0.1, y: h * 0.9) → 左上付近
    //      CGPoint(x: w * 0.9, y: h * 0.1) → 右下付近
    //
    //  addFloor の rect:
    //    CGRect(x: 左端X, y: 下端Y, width: 横幅, height: 縦幅)
    //    ブロックの左下コーナーからの大きさで指定する
    //
    //  addSpike の at: / pointingUp:
    //    at: スパイクの「根本」の位置
    //    pointingUp: true  → 上向き三角（床の上に置く。下から来た球に刺さる）
    //    pointingUp: false → 下向き三角（天井に付ける。上から来た球に刺さる）
    //
    //  addGoal の at:
    //    ゴール円の中心座標
    //    足場の上に置く場合: y = 足場のY + 足場の高さ + ゴール半径(22)
    // ─────────────────────────────────────────────

    // ─────────────────────────────────────────────
    // STAGE 0: チュートリアル
    // 難易度: ★☆☆☆☆
    // 概要: 基本操作を学ぶ最初のステージ。
    //       スパイク・溶岩・消える床が少量登場する。
    //       左下からスタートし、足場を踏み替えながら左上のゴールを目指す。
    // ─────────────────────────────────────────────
    private func buildStage0() {
        let w = size.width; let h = size.height

        // プレイヤーの初期出現位置（左下付近）
        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.2)
        addOuterWalls()

        // ── 足場 ──
        addFloor(rect: CGRect(x: 20,       y: 100,       width: w * 0.3,  height: 18), isTerrain: false) // 左下の足場
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.35,  width: w * 0.25, height: 18), isTerrain: false) // 中段右の足場
        addFloor(rect: CGRect(x: w * 0.6,  y: h * 0.65,  width: w * 0.2,  height: 18), isTerrain: false) // 右上の足場
        addFloor(rect: CGRect(x: 20,       y: h * 0.7,   width: w * 0.25, height: 18), isTerrain: false) // 左上の足場
        addFloor(rect: CGRect(x: w * 0.3,  y: h * 0.82,  width: w * 0.25, height: 18), isTerrain: false) // ゴール手前の足場

        // ── スパイク（床の上向き）──
        addSpike(at: CGPoint(x: w * 0.1, y: 30), pointingUp: true)  // 床左のスパイク①
        addSpike(at: CGPoint(x: w * 0.15, y: 30), pointingUp: true)  // 床左のスパイク②
        addSpike(at: CGPoint(x: w * 0.68, y: h * 0.35 + 18), pointingUp: true)  // 中段足場の右端スパイク
        addSpike(at: CGPoint(x: w * 0.8,  y: h - 20), pointingUp: false)         // 天井の下向きスパイク

        // ── 溶岩 ──
        addLava(rect: CGRect(x: w * 0.35,  y: 30, width: w * 0.4, height: 18)) // 床中央の溶岩プール

        // ── 消える床 ──
        addBlinkingFloor(rect: CGRect(x: w * 0.45, y: h * 0.55, width: w * 0.2, height: 14)) // 中段の消える床

        // ── ゴール（ゴール手前足場の上）──
        // y = 足場のY(h*0.82) + 足場高さ(18) + ゴール半径(22) ≈ 足場の上にちょうど乗る位置
        addGoal(at: CGPoint(x: w * 0.42, y: h * 0.82 + 18 + 20))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 1: 縦仕切りの迷路
    // 難易度: ★★☆☆☆
    // 概要: 画面を縦断する2本の仕切り壁がある。
    //       左エリア→右エリアへ移動するには重力を切り替えて
    //       仕切りの上か隙間を抜ける必要がある。
    // ─────────────────────────────────────────────
    private func buildStage1() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.12) // 左上付近からスタート
        addOuterWalls()

        // ── 縦仕切り壁（isTerrain: true で地形色に） ──
        addFloor(rect: CGRect(x: w * 0.4,  y: 30,       width: 18, height: h * 0.5),       isTerrain: true) // 中央仕切り（下半分）
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.45, width: 18, height: h * 0.55 - 20), isTerrain: true) // 右寄り仕切り（上半分）

        // ── 足場（左エリア）──
        addFloor(rect: CGRect(x: 20, y: h * 0.3,  width: w * 0.25, height: 16), isTerrain: false) // 左中段
        addFloor(rect: CGRect(x: 20, y: h * 0.55, width: w * 0.25, height: 16), isTerrain: false) // 左上段

        // ── 足場（右エリア）──
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.25, width: w * 0.2, height: 16), isTerrain: false) // 右中段
        addFloor(rect: CGRect(x: w * 0.6, y: h * 0.6,  width: w * 0.2, height: 16), isTerrain: false) // 右上段（ゴール台）

        // ── スパイク ──
        addSpike(at: CGPoint(x: w * 0.2,  y: 30),       pointingUp: true)  // 左エリア床スパイク
        addSpike(at: CGPoint(x: w * 0.2,  y: h - 20),   pointingUp: false) // 左エリア天井スパイク
        addSpike(at: CGPoint(x: w * 0.7,  y: 30),       pointingUp: true)  // 右エリア床スパイク
        addSpike(at: CGPoint(x: w * 0.7,  y: h * 0.45), pointingUp: false) // 右中段足場の上スパイク
        addSpike(at: CGPoint(x: w * 0.85, y: 30),       pointingUp: true)  // 右壁際スパイク

        // ── 溶岩（左エリア中段に横長の溶岩）──
        addLava(rect: CGRect(x: 20, y: h * 0.42, width: w * 0.2, height: 16))

        // ── ゴール（右上段の足場の上）──
        addGoal(at: CGPoint(x: w * 0.8, y: h * 0.6 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 2: 溶岩地獄
    // 難易度: ★★★☆☆
    // 概要: 下半分に大きな溶岩ゾーンが広がる。
    //       重力を下向きのままだと即溶岩に落ちる。
    //       上向き重力に切り替えて上半分を渡るのが攻略の鍵。
    // ─────────────────────────────────────────────
    private func buildStage2() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.7) // 左上付近スタート（溶岩の上方）
        addOuterWalls()

        // ── 溶岩（下半分を埋め尽くす）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.3,  height: h * 0.38)) // 左下の大きな溶岩
        addLava(rect: CGRect(x: w * 0.45, y: 30, width: w * 0.2,  height: h * 0.38)) // 中央下の溶岩
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: h * 0.38)) // 右端の細い溶岩

        // ── 足場（上半分に配置）──
        addFloor(rect: CGRect(x: 20,       y: h * 0.6,  width: w * 0.25, height: 16), isTerrain: false) // 左上足場（スタート台）
        addFloor(rect: CGRect(x: w * 0.35, y: h * 0.72, width: w * 0.3,  height: 16), isTerrain: false) // 中央上の長い足場
        addFloor(rect: CGRect(x: w * 0.6,  y: h * 0.55, width: w * 0.2,  height: 16), isTerrain: false) // 右中段足場（ゴール台）
        addFloor(rect: CGRect(x: w * 0.3,  y: h * 0.85, width: w * 0.35, height: 16), isTerrain: false) // 最上段足場

        // ── 溶岩と足場の隙間にある小さな中継足場 ──
        addFloor(rect: CGRect(x: w * 0.32, y: h * 0.4,  width: w * 0.1,  height: 14), isTerrain: false) // 中段左の中継
        addFloor(rect: CGRect(x: w * 0.67, y: h * 0.4,  width: w * 0.06, height: 14), isTerrain: false) // 中段右の中継

        // ── 天井スパイク（上向き重力時の脅威）──
        addSpike(at: CGPoint(x: w * 0.5,  y: h - 20), pointingUp: false) // 天井中央スパイク
        addSpike(at: CGPoint(x: w * 0.25, y: h - 20), pointingUp: false) // 天井左スパイク
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20), pointingUp: false) // 天井右スパイク

        // ── ゴール（右中段足場の上）──
        addGoal(at: CGPoint(x: w * 0.7, y: h * 0.55 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 3: 消える床パズル
    // 難易度: ★★★☆☆
    // 概要: 消える床（水色）が4枚並ぶ。
    //       踏んだ瞬間から2秒後に消えるため、
    //       順番を考えて素早く渡らないとゴールに届かない。
    // ─────────────────────────────────────────────
    private func buildStage3() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.15) // 左下付近スタート
        addOuterWalls()

        // ── 通常足場（固定）──
        addFloor(rect: CGRect(x: 20,       y: 80,       width: w * 0.2,  height: 16), isTerrain: false) // 左下のスタート台
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.5,  width: w * 0.08, height: 16), isTerrain: false) // 右中段の固定足場
        addFloor(rect: CGRect(x: w * 0.72, y: h * 0.82, width: w * 0.08, height: 16), isTerrain: false) // 右上の固定足場（ゴール台）

        // ── 消える床（踏むと2秒後に消滅）──
        // ※ 踏む順番: ①→②→③→④→ゴール が推奨ルート
        addBlinkingFloor(rect: CGRect(x: w * 0.28, y: h * 0.18, width: w * 0.18, height: 14)) // ① 左下の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.35, width: w * 0.18, height: 14)) // ② 中央の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.25, y: h * 0.55, width: w * 0.18, height: 14)) // ③ 左上の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.18, height: 14)) // ④ 右上の消える床

        // ── スパイク（床と右エリアへの罰）──
        addSpike(at: CGPoint(x: w * 0.45, y: 30), pointingUp: true) // 床中央スパイク①
        addSpike(at: CGPoint(x: w * 0.6,  y: 30), pointingUp: true) // 床中央スパイク②
        addSpike(at: CGPoint(x: w * 0.75, y: 30), pointingUp: true) // 床右スパイク③

        // ── 溶岩（床の一部）──
        addLava(rect: CGRect(x: w * 0.2, y: 30, width: w * 0.22, height: 16))

        // ── ゴール（右上固定足場の上）──
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.82 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 4: 全方向攻略（上級）
    // 難易度: ★★★★☆
    // 概要: 画面を縦断する仕切り壁が中央にあり、
    //       4方向すべての重力を使わないとゴールに届かない。
    //       スパイク・溶岩・消える床の全種類が登場する。
    // ─────────────────────────────────────────────
    private func buildStage4() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12) // 左上スタート
        addOuterWalls()

        // ── 縦の仕切り壁（中央で左右を分断）──
        addFloor(rect: CGRect(x: w * 0.45, y: 30,       width: 18, height: h * 0.35),       isTerrain: true) // 中央仕切り下部
        addFloor(rect: CGRect(x: w * 0.45, y: h * 0.6,  width: 18, height: h * 0.4 - 20),   isTerrain: true) // 中央仕切り上部

        // ── 足場（左エリア）──
        addFloor(rect: CGRect(x: 20,       y: h * 0.2,  width: w * 0.25, height: 16), isTerrain: false) // 左上段
        addFloor(rect: CGRect(x: 20,       y: h * 0.4,  width: w * 0.18, height: 16), isTerrain: false) // 左中段（短い）

        // ── 足場（右エリア）──
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.25, height: 16), isTerrain: false) // 右上段
        addFloor(rect: CGRect(x: w * 0.65, y: h * 0.38, width: w * 0.15, height: 16), isTerrain: false) // 右中段
        addFloor(rect: CGRect(x: w * 0.1,  y: h * 0.65, width: w * 0.2,  height: 16), isTerrain: false) // 左下段
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.72, width: w * 0.25, height: 16), isTerrain: false) // 右下段（ゴール台）

        // ── 消える床（仕切りの隙間に配置）──
        addBlinkingFloor(rect: CGRect(x: w * 0.22, y: h * 0.55, width: w * 0.18, height: 14)) // 左側の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.55, width: w * 0.18, height: 14)) // 右側の消える床

        // ── スパイク（四隅と中央）──
        addSpike(at: CGPoint(x: w * 0.3,  y: 30),       pointingUp: true)  // 床左スパイク
        addSpike(at: CGPoint(x: w * 0.7,  y: 30),       pointingUp: true)  // 床右スパイク
        addSpike(at: CGPoint(x: w * 0.3,  y: h - 20),   pointingUp: false) // 天井左スパイク
        addSpike(at: CGPoint(x: w * 0.7,  y: h - 20),   pointingUp: false) // 天井右スパイク
        addSpike(at: CGPoint(x: 20,       y: h * 0.5),  pointingUp: true)  // 左壁中段スパイク（横向き危険ゾーン）
        addSpike(at: CGPoint(x: w - 20,   y: h * 0.5),  pointingUp: false) // 右壁中段スパイク

        // ── 溶岩（床の両端）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.22, height: 14)) // 左端の溶岩
        addLava(rect: CGRect(x: w * 0.58, y: 30, width: w * 0.22, height: 14)) // 右端の溶岩

        // ── ゴール（右下段足場の上）──
        addGoal(at: CGPoint(x: w * 0.76, y: h * 0.72 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 5: S字ルート
    // 難易度: ★★☆☆☆
    // 概要: 左側を下から上へ登り、中央の橋を渡って右側のゴールへ。
    //       S字を描くような進行ルート。消える床が中継地点に1枚。
    // ─────────────────────────────────────────────
    private func buildStage5() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.12)
        addOuterWalls()

        // ── 左側の足場（下から順に登る）──
        addFloor(rect: CGRect(x: 20,       y: 80,       width: w * 0.28, height: 16), isTerrain: false) // L1: 左下スタート台
        addFloor(rect: CGRect(x: 20,       y: h * 0.25, width: w * 0.22, height: 16), isTerrain: false) // L2: 左中下段
        addFloor(rect: CGRect(x: 20,       y: h * 0.42, width: w * 0.28, height: 16), isTerrain: false) // L3: 左中上段

        // ── 中央の橋（左から右へ渡る）──
        addFloor(rect: CGRect(x: w * 0.25, y: h * 0.58, width: w * 0.5, height: 16), isTerrain: false) // 橋（長い）

        // ── 右側の足場（橋を渡った先）──
        addFloor(rect: CGRect(x: w * 0.6,  y: h * 0.42, width: w * 0.2,  height: 16), isTerrain: false) // R1: 右中段
        addFloor(rect: CGRect(x: w * 0.6,  y: h * 0.72, width: w * 0.2,  height: 16), isTerrain: false) // R2: 右上段（ゴール台）

        // ── 消える床（橋の下の中継地点）──
        addBlinkingFloor(rect: CGRect(x: w * 0.38, y: h * 0.33, width: w * 0.2, height: 14))

        // ── スパイク ──
        addSpike(at: CGPoint(x: w * 0.35, y: 30),             pointingUp: true)  // 床中央スパイク①
        addSpike(at: CGPoint(x: w * 0.5,  y: 30),             pointingUp: true)  // 床中央スパイク②
        addSpike(at: CGPoint(x: w * 0.65, y: 30),             pointingUp: true)  // 床右スパイク
        addSpike(at: CGPoint(x: w * 0.85, y: h * 0.58 + 16), pointingUp: true)  // 橋の右端スパイク
        addSpike(at: CGPoint(x: w * 0.15, y: h - 20),         pointingUp: false) // 天井左スパイク

        // ── 溶岩 ──
        addLava(rect: CGRect(x: w * 0.3,  y: 30, width: w * 0.08, height: 18)) // 左スパイク間の溶岩
        addLava(rect: CGRect(x: w * 0.72, y: 30, width: w * 0.06, height: 18)) // 右端の溶岩

        // ── ゴール（右上段の上）──
        addGoal(at: CGPoint(x: w * 0.75, y: h * 0.72 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 6: 交互の足場
    // 難易度: ★★★☆☆
    // 概要: 左右交互に配置された足場をジグザグに登る。
    //       重力を切り替えて対岸の足場へ飛び移るのが攻略の鍵。
    // ─────────────────────────────────────────────
    private func buildStage6() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.08)
        addOuterWalls()

        // ── ジグザグ足場（左右交互に配置）──
        addFloor(rect: CGRect(x: 20,      y: h * 0.15, width: w * 0.35, height: 16), isTerrain: false) // Z1: 左下
        addFloor(rect: CGRect(x: w * 0.5, y: h * 0.28, width: w * 0.3,  height: 16), isTerrain: false) // Z2: 右中下
        addFloor(rect: CGRect(x: 20,      y: h * 0.42, width: w * 0.35, height: 16), isTerrain: false) // Z3: 左中
        addFloor(rect: CGRect(x: w * 0.5, y: h * 0.55, width: w * 0.3,  height: 16), isTerrain: false) // Z4: 右中上
        addFloor(rect: CGRect(x: 20,      y: h * 0.68, width: w * 0.35, height: 16), isTerrain: false) // Z5: 左上
        addFloor(rect: CGRect(x: w * 0.5, y: h * 0.82, width: w * 0.3,  height: 16), isTerrain: false) // Z6: 右上（ゴール台）

        // ── スパイク（ジグザグの隙間に配置）──
        addSpike(at: CGPoint(x: w * 0.2,  y: 30),             pointingUp: true)  // 床スパイク①
        addSpike(at: CGPoint(x: w * 0.7,  y: 30),             pointingUp: true)  // 床スパイク②
        addSpike(at: CGPoint(x: w * 0.4,  y: h * 0.15 + 16), pointingUp: true)  // Z1右端スパイク
        addSpike(at: CGPoint(x: w * 0.85, y: h * 0.28 + 16), pointingUp: true)  // Z2右端スパイク
        addSpike(at: CGPoint(x: w * 0.4,  y: h * 0.42 + 16), pointingUp: true)  // Z3右端スパイク
        addSpike(at: CGPoint(x: w * 0.15, y: h - 20),         pointingUp: false) // 天井スパイク

        // ── 溶岩（床の中央部）──
        addLava(rect: CGRect(x: w * 0.35, y: 30, width: w * 0.14, height: 16))

        // ── ゴール（Z6の上）──
        addGoal(at: CGPoint(x: w * 0.72, y: h * 0.82 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 7: 逆さ溶岩
    // 難易度: ★★★☆☆
    // 概要: 画面下半分がほぼ溶岩。上向き重力に素早く切り替えて
    //       上部の足場を渡り、左上のゴールを目指す。
    //       天井にはスパイクが並んでいるので注意。
    // ─────────────────────────────────────────────
    private func buildStage7() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.55) // 左中段の足場の上からスタート
        addOuterWalls()

        // ── スタート台（左中段の安全地帯）──
        addFloor(rect: CGRect(x: 20, y: h * 0.5, width: w * 0.18, height: 16), isTerrain: false)

        // ── 上部の足場（上向き重力時に使用）──
        addFloor(rect: CGRect(x: w * 0.3,  y: h * 0.75, width: w * 0.25, height: 16), isTerrain: false) // 天井近く左
        addFloor(rect: CGRect(x: w * 0.6,  y: h * 0.8,  width: w * 0.2,  height: 16), isTerrain: false) // 天井近く右
        addFloor(rect: CGRect(x: w * 0.15, y: h * 0.88, width: w * 0.35, height: 16), isTerrain: false) // 最上段（ゴール台）

        // ── 中段の中継足場 ──
        addFloor(rect: CGRect(x: w * 0.42, y: h * 0.55, width: w * 0.18, height: 14), isTerrain: false)

        // ── 溶岩（下半分をほぼ覆う）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.25, height: h * 0.32)) // 左下大溶岩
        addLava(rect: CGRect(x: w * 0.32, y: 30, width: w * 0.36, height: h * 0.38)) // 中央下大溶岩
        addLava(rect: CGRect(x: w * 0.75, y: 30, width: w * 0.05, height: h * 0.28)) // 右端溶岩

        // ── 溶岩の中の柱（通過地点）──
        addFloor(rect: CGRect(x: w * 0.27, y: 30, width: w * 0.05, height: h * 0.1),  isTerrain: true) // 柱①
        addFloor(rect: CGRect(x: w * 0.7,  y: 30, width: w * 0.05, height: h * 0.15), isTerrain: true) // 柱②

        // ── 天井スパイク（上向き重力時の脅威）──
        addSpike(at: CGPoint(x: w * 0.5,  y: h - 20), pointingUp: false) // 天井中央
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20), pointingUp: false) // 天井右
        addSpike(at: CGPoint(x: w * 0.88, y: h - 20), pointingUp: false) // 天井右端

        // ── ゴール（最上段の上）──
        addGoal(at: CGPoint(x: w * 0.3, y: h * 0.88 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 8: 消える床の嵐
    // 難易度: ★★★★☆
    // 概要: 消える床が6枚のジグザグ配置。下は溶岩。
    //       踏んだ瞬間から時計が始まるので、素早く次の床へ移動せよ。
    // ─────────────────────────────────────────────
    private func buildStage8() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12)
        addOuterWalls()

        // ── スタート台（固定・左下）──
        addFloor(rect: CGRect(x: 20, y: 80, width: w * 0.22, height: 16), isTerrain: false)

        // ── 消える床6枚（①→②→…→⑥の順に渡るルートが推奨）──
        addBlinkingFloor(rect: CGRect(x: w * 0.28, y: h * 0.2,  width: w * 0.2, height: 14)) // ①
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.3,  width: w * 0.2, height: 14)) // ②
        addBlinkingFloor(rect: CGRect(x: w * 0.25, y: h * 0.42, width: w * 0.2, height: 14)) // ③
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.55, width: w * 0.2, height: 14)) // ④
        addBlinkingFloor(rect: CGRect(x: w * 0.2,  y: h * 0.68, width: w * 0.2, height: 14)) // ⑤
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.8,  width: w * 0.2, height: 14)) // ⑥

        // ── ゴール台（固定・右上）──
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.88, width: w * 0.18, height: 16), isTerrain: false)

        // ── 溶岩（床をほぼ全部覆う）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.5,  height: 20)) // 左底溶岩
        addLava(rect: CGRect(x: w * 0.55, y: 30, width: w * 0.25, height: 20)) // 右底溶岩

        // ── スパイク ──
        addSpike(at: CGPoint(x: w * 0.85, y: 30),     pointingUp: true)  // 床右スパイク
        addSpike(at: CGPoint(x: w * 0.15, y: h - 20), pointingUp: false) // 天井左スパイク
        addSpike(at: CGPoint(x: w * 0.5,  y: h - 20), pointingUp: false) // 天井中央スパイク

        // ── ゴール（ゴール台の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.88 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 9: 四方スパイク回廊
    // 難易度: ★★★★☆
    // 概要: 中央に縦仕切りで作られた回廊にスパイクが密集。
    //       左右重力を駆使して狭い隙間を通り抜け、右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage9() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.15, y: h * 0.1)
        addOuterWalls()

        // ── 縦の仕切り壁（中央の回廊を形成）──
        addFloor(rect: CGRect(x: w * 0.38, y: 30,       width: 18, height: h * 0.35),       isTerrain: true) // 仕切り左下
        addFloor(rect: CGRect(x: w * 0.55, y: 30,       width: 18, height: h * 0.25),       isTerrain: true) // 仕切り右下
        addFloor(rect: CGRect(x: w * 0.38, y: h * 0.55, width: 18, height: h * 0.35 - 20), isTerrain: true) // 仕切り左上
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.45, width: 18, height: h * 0.45 - 20), isTerrain: true) // 仕切り右上

        // ── 足場（左エリア）──
        addFloor(rect: CGRect(x: 20, y: h * 0.2,  width: w * 0.2,  height: 16), isTerrain: false) // 左中下段
        addFloor(rect: CGRect(x: 20, y: h * 0.45, width: w * 0.2,  height: 16), isTerrain: false) // 左中段
        addFloor(rect: CGRect(x: 20, y: h * 0.68, width: w * 0.2,  height: 16), isTerrain: false) // 左上段

        // ── 足場（右エリア）──
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.3,  width: w * 0.18, height: 16), isTerrain: false) // 右中段
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.6,  width: w * 0.18, height: 16), isTerrain: false) // 右上段（ゴール台）

        // ── 足場（回廊内の中継地点）──
        addFloor(rect: CGRect(x: w * 0.42, y: h * 0.42, width: w * 0.13, height: 16), isTerrain: false)

        // ── スパイク（仕切り端と床・天井に密集）──
        addSpike(at: CGPoint(x: w * 0.45, y: h * 0.35 + 2),  pointingUp: true)  // 仕切り左上端スパイク
        addSpike(at: CGPoint(x: w * 0.45, y: h * 0.55 - 2),  pointingUp: false) // 仕切り左下端スパイク（上段）
        addSpike(at: CGPoint(x: w * 0.62, y: h * 0.25 + 2),  pointingUp: true)  // 仕切り右上端スパイク
        addSpike(at: CGPoint(x: w * 0.62, y: h * 0.45 - 2),  pointingUp: false) // 仕切り右下端スパイク（上段）
        addSpike(at: CGPoint(x: w * 0.25, y: 30),             pointingUp: true)  // 床スパイク①
        addSpike(at: CGPoint(x: w * 0.7,  y: 30),             pointingUp: true)  // 床スパイク②
        addSpike(at: CGPoint(x: w * 0.85, y: 30),             pointingUp: true)  // 床スパイク③
        addSpike(at: CGPoint(x: w * 0.4,  y: h - 20),         pointingUp: false) // 天井スパイク①
        addSpike(at: CGPoint(x: w * 0.6,  y: h - 20),         pointingUp: false) // 天井スパイク②

        // ── 溶岩（仕切り間の床）──
        addLava(rect: CGRect(x: w * 0.55, y: 30, width: w * 0.12, height: 16))

        // ── ゴール（右上段の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.6 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 10: 孤島巡り
    // 難易度: ★★★☆☆
    // 概要: 溶岩の海に浮かぶ6つの小島。
    //       重力を切り替えながら島から島へホップして右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage10() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.18)
        addOuterWalls()

        // ── 島①〜⑥（小さな足場が点在）──
        addFloor(rect: CGRect(x: 20,       y: h * 0.12, width: w * 0.2,  height: 20), isTerrain: false) // 島① 左下（スタート）
        addFloor(rect: CGRect(x: w * 0.38, y: h * 0.22, width: w * 0.2,  height: 20), isTerrain: false) // 島② 中央下
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.4,  width: w * 0.18, height: 20), isTerrain: false) // 島③ 右中
        addFloor(rect: CGRect(x: w * 0.35, y: h * 0.6,  width: w * 0.2,  height: 20), isTerrain: false) // 島④ 中央上
        addFloor(rect: CGRect(x: 20,       y: h * 0.78, width: w * 0.2,  height: 20), isTerrain: false) // 島⑤ 左上
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.72, width: w * 0.18, height: 20), isTerrain: false) // 島⑥ 右上（ゴール台）

        // ── 溶岩（島以外をほぼ全部覆う）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.35, height: h * 0.1))        // 左底溶岩
        addLava(rect: CGRect(x: w * 0.22, y: 30, width: w * 0.35, height: h * 0.18))       // 中央底溶岩
        addLava(rect: CGRect(x: w * 0.62, y: 30, width: w * 0.18, height: h * 0.36))       // 右底溶岩
        addLava(rect: CGRect(x: 20,       y: h * 0.34, width: w * 0.58, height: h * 0.22)) // 中央大溶岩

        // ── 消える床（島②と島④の橋渡し）──
        addBlinkingFloor(rect: CGRect(x: w * 0.22, y: h * 0.5, width: w * 0.12, height: 14))

        // ── スパイク ──
        addSpike(at: CGPoint(x: w * 0.3,  y: h * 0.12 + 20), pointingUp: true)  // 島①右端スパイク
        addSpike(at: CGPoint(x: w * 0.6,  y: h * 0.22 + 20), pointingUp: true)  // 島②右端スパイク
        addSpike(at: CGPoint(x: w * 0.55, y: h - 20),         pointingUp: false) // 天井スパイク①
        addSpike(at: CGPoint(x: w * 0.8,  y: h - 20),         pointingUp: false) // 天井スパイク②

        // ── ゴール（島⑥の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.72 + 20 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 11: 上から下へ
    // 難易度: ★★★★☆
    // 概要: 左上スタートで、徐々に下に降りながらゴールを目指す。
    //       天井にスパイクが密集しており上向き重力は極めて危険。
    //       下向きに下りながら消える床も活用する。
    // ─────────────────────────────────────────────
    private func buildStage11() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.88)
        addOuterWalls()

        // ── 天井スパイク（上向き重力への強い抑止）──
        addSpike(at: CGPoint(x: w * 0.25, y: h - 20), pointingUp: false) // 天井①
        addSpike(at: CGPoint(x: w * 0.35, y: h - 20), pointingUp: false) // 天井②
        addSpike(at: CGPoint(x: w * 0.45, y: h - 20), pointingUp: false) // 天井③
        addSpike(at: CGPoint(x: w * 0.55, y: h - 20), pointingUp: false) // 天井④
        addSpike(at: CGPoint(x: w * 0.65, y: h - 20), pointingUp: false) // 天井⑤
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20), pointingUp: false) // 天井⑥
        addSpike(at: CGPoint(x: w * 0.85, y: h - 20), pointingUp: false) // 天井⑦

        // ── 上段の足場（スタート台）──
        addFloor(rect: CGRect(x: 20,       y: h * 0.8,  width: w * 0.22, height: 16), isTerrain: false) // 左上スタート台
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.75, width: w * 0.25, height: 16), isTerrain: false) // 右上足場

        // ── 中段の足場 ──
        addFloor(rect: CGRect(x: w * 0.25, y: h * 0.6,  width: w * 0.25, height: 16), isTerrain: false) // 中央左
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.5,  width: w * 0.22, height: 16), isTerrain: false) // 中央右

        // ── 下段の足場 ──
        addFloor(rect: CGRect(x: 20,       y: h * 0.38, width: w * 0.25, height: 16), isTerrain: false) // 左下
        addFloor(rect: CGRect(x: w * 0.35, y: h * 0.28, width: w * 0.25, height: 16), isTerrain: false) // 中央下
        addFloor(rect: CGRect(x: w * 0.64, y: h * 0.18, width: w * 0.16, height: 16), isTerrain: false) // 右下（ゴール台）

        // ── 消える床（中段の通過地点）──
        addBlinkingFloor(rect: CGRect(x: w * 0.3, y: h * 0.45, width: w * 0.22, height: 14))

        // ── 床スパイク ──
        addSpike(at: CGPoint(x: w * 0.3,  y: 30), pointingUp: true) // 床スパイク①
        addSpike(at: CGPoint(x: w * 0.5,  y: 30), pointingUp: true) // 床スパイク②
        addSpike(at: CGPoint(x: w * 0.7,  y: 30), pointingUp: true) // 床スパイク③

        // ── 溶岩 ──
        addLava(rect: CGRect(x: w * 0.4, y: 30, width: w * 0.2, height: 18))

        // ── ゴール（右下段の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.18 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 12: 格子迷路
    // 難易度: ★★★★☆
    // 概要: 縦横の仕切り壁が格子状に配置されたステージ。
    //       各区画の隙間（仕切りの端の開口部）を見つけて右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage12() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12)
        addOuterWalls()

        // ── 縦仕切り（2本・各々に隙間あり）──
        addFloor(rect: CGRect(x: w * 0.3,  y: 30,       width: 16, height: h * 0.28),       isTerrain: true) // 縦①下半
        addFloor(rect: CGRect(x: w * 0.3,  y: h * 0.45, width: 16, height: h * 0.42 - 20), isTerrain: true) // 縦①上半
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.22, width: 16, height: h * 0.35),       isTerrain: true) // 縦②中
        addFloor(rect: CGRect(x: w * 0.58, y: h * 0.75, width: 16, height: h * 0.13),       isTerrain: true) // 縦②上

        // ── 横仕切り（2本）──
        addFloor(rect: CGRect(x: w * 0.3,  y: h * 0.38, width: w * 0.28, height: 16), isTerrain: true) // 横①
        addFloor(rect: CGRect(x: w * 0.32, y: h * 0.65, width: w * 0.26, height: 16), isTerrain: true) // 横②

        // ── 足場（各エリアに配置）──
        addFloor(rect: CGRect(x: 20,       y: h * 0.22, width: w * 0.12, height: 14), isTerrain: false) // 左下段
        addFloor(rect: CGRect(x: 20,       y: h * 0.55, width: w * 0.12, height: 14), isTerrain: false) // 左中段
        addFloor(rect: CGRect(x: w * 0.36, y: h * 0.52, width: w * 0.18, height: 14), isTerrain: false) // 中央足場
        addFloor(rect: CGRect(x: w * 0.63, y: h * 0.38, width: w * 0.17, height: 14), isTerrain: false) // 右中下段
        addFloor(rect: CGRect(x: w * 0.63, y: h * 0.62, width: w * 0.17, height: 14), isTerrain: false) // 右中上段（ゴール台）

        // ── スパイク ──
        addSpike(at: CGPoint(x: w * 0.45, y: 30),             pointingUp: true)  // 床中央スパイク
        addSpike(at: CGPoint(x: w * 0.75, y: 30),             pointingUp: true)  // 床右スパイク
        addSpike(at: CGPoint(x: w * 0.45, y: h - 20),         pointingUp: false) // 天井スパイク①
        addSpike(at: CGPoint(x: w * 0.75, y: h - 20),         pointingUp: false) // 天井スパイク②
        addSpike(at: CGPoint(x: w * 0.45, y: h * 0.38 + 16), pointingUp: true)  // 横仕切り①の上端スパイク

        // ── 溶岩（左端の小さな溶岩）──
        addLava(rect: CGRect(x: 20, y: 30, width: w * 0.1, height: 18))

        // ── ゴール（右中上段の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.62 + 14 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 13: 全ギミック総動員
    // 難易度: ★★★★★
    // 概要: 全種類のギミックが高密度で出現する最終試練（前半）。
    //       左上からスタートし、ジグザグに下りながら右下のゴールへ。
    //       消える床を踏んだら即座に次の行動を判断すること。
    // ─────────────────────────────────────────────
    private func buildStage13() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.88)
        addOuterWalls()

        // ── スタート台（左上・固定）──
        addFloor(rect: CGRect(x: 20, y: h * 0.82, width: w * 0.2, height: 16), isTerrain: false)

        // ── 通常足場（下りながら進む）──
        addFloor(rect: CGRect(x: w * 0.28, y: h * 0.72, width: w * 0.18, height: 14), isTerrain: false) // 足場②
        addFloor(rect: CGRect(x: w * 0.52, y: h * 0.62, width: w * 0.18, height: 14), isTerrain: false) // 足場③
        addFloor(rect: CGRect(x: w * 0.28, y: h * 0.5,  width: w * 0.18, height: 14), isTerrain: false) // 足場④

        // ── 消える床ゾーン（足場④から先）──
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.4,  width: w * 0.18, height: 14)) // 消①
        addBlinkingFloor(rect: CGRect(x: w * 0.25, y: h * 0.3,  width: w * 0.18, height: 14)) // 消②
        addBlinkingFloor(rect: CGRect(x: w * 0.52, y: h * 0.2,  width: w * 0.18, height: 14)) // 消③

        // ── ゴール台（右下・固定）──
        addFloor(rect: CGRect(x: w * 0.62, y: h * 0.1, width: w * 0.18, height: 16), isTerrain: false)

        // ── 天井スパイク（密集）──
        addSpike(at: CGPoint(x: w * 0.35, y: h - 20), pointingUp: false) // 天井①
        addSpike(at: CGPoint(x: w * 0.5,  y: h - 20), pointingUp: false) // 天井②
        addSpike(at: CGPoint(x: w * 0.65, y: h - 20), pointingUp: false) // 天井③
        addSpike(at: CGPoint(x: w * 0.8,  y: h - 20), pointingUp: false) // 天井④

        // ── 床スパイク ──
        addSpike(at: CGPoint(x: w * 0.2,  y: 30), pointingUp: true) // 床スパイク①
        addSpike(at: CGPoint(x: w * 0.4,  y: 30), pointingUp: true) // 床スパイク②
        addSpike(at: CGPoint(x: w * 0.6,  y: 30), pointingUp: true) // 床スパイク③
        addSpike(at: CGPoint(x: w * 0.8,  y: 30), pointingUp: true) // 床スパイク④

        // ── 溶岩（大面積）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.15, height: h * 0.12)) // 左底溶岩
        addLava(rect: CGRect(x: w * 0.42, y: 30, width: w * 0.15, height: h * 0.16)) // 中央底溶岩
        addLava(rect: CGRect(x: w * 0.65, y: 30, width: w * 0.15, height: h * 0.07)) // 右底溶岩

        // ── 追加スパイク（足場の縁）──
        addSpike(at: CGPoint(x: w * 0.5,  y: h * 0.72 + 14), pointingUp: true) // 足場②右端スパイク
        addSpike(at: CGPoint(x: w * 0.73, y: h * 0.62 + 14), pointingUp: true) // 足場③右端スパイク

        // ── ゴール（ゴール台の上）──
        addGoal(at: CGPoint(x: w * 0.73, y: h * 0.1 + 16 + 22))

        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 14: 禁断のステージ
    // 難易度: ★★★★★
    // 概要: 全ギミック最高密度の最終面。
    //       中央仕切りで左右に分断され、消える床・溶岩・密集スパイクが全方位から襲う。
    //       4方向の重力を完全に使いこなして突破せよ。
    // ─────────────────────────────────────────────
    private func buildStage14() {
        let w = size.width; let h = size.height

        spawnPoint = CGPoint(x: w * 0.12, y: h * 0.12)
        addOuterWalls()

        // ── 中央仕切り（上下に隙間あり）──
        addFloor(rect: CGRect(x: w * 0.42, y: 30,       width: 18, height: h * 0.3),        isTerrain: true) // 仕切り下部
        addFloor(rect: CGRect(x: w * 0.42, y: h * 0.52, width: 18, height: h * 0.35 - 20), isTerrain: true) // 仕切り上部

        // ── 左エリアの足場 ──
        addFloor(rect: CGRect(x: 20,       y: h * 0.22, width: w * 0.2,  height: 14), isTerrain: false) // 左中下
        addFloor(rect: CGRect(x: w * 0.22, y: h * 0.35, width: w * 0.18, height: 14), isTerrain: false) // 左中
        addFloor(rect: CGRect(x: 20,       y: h * 0.52, width: w * 0.15, height: 14), isTerrain: false) // 左中上
        addFloor(rect: CGRect(x: w * 0.22, y: h * 0.65, width: w * 0.18, height: 14), isTerrain: false) // 左上

        // ── 右エリアの足場 ──
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.15, height: 14), isTerrain: false) // 右下
        addFloor(rect: CGRect(x: w * 0.7,  y: h * 0.32, width: w * 0.1,  height: 14), isTerrain: false) // 右中下
        addFloor(rect: CGRect(x: w * 0.55, y: h * 0.48, width: w * 0.15, height: 14), isTerrain: false) // 右中
        addFloor(rect: CGRect(x: w * 0.7,  y: h * 0.65, width: w * 0.1,  height: 14), isTerrain: false) // 右上（ゴール台）

        // ── 消える床（仕切りの隙間と上部）──
        addBlinkingFloor(rect: CGRect(x: w * 0.2,  y: h * 0.45, width: w * 0.2,  height: 12)) // 左の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.46, y: h * 0.38, width: w * 0.08, height: 12)) // 仕切り隙間の消える床
        addBlinkingFloor(rect: CGRect(x: w * 0.55, y: h * 0.8,  width: w * 0.25, height: 12)) // 右上の消える床

        // ── 天井スパイク（6本・密集）──
        addSpike(at: CGPoint(x: w * 0.2,  y: h - 20), pointingUp: false) // 天井①
        addSpike(at: CGPoint(x: w * 0.32, y: h - 20), pointingUp: false) // 天井②
        addSpike(at: CGPoint(x: w * 0.44, y: h - 20), pointingUp: false) // 天井③
        addSpike(at: CGPoint(x: w * 0.56, y: h - 20), pointingUp: false) // 天井④
        addSpike(at: CGPoint(x: w * 0.68, y: h - 20), pointingUp: false) // 天井⑤
        addSpike(at: CGPoint(x: w * 0.8,  y: h - 20), pointingUp: false) // 天井⑥

        // ── 床スパイク ──
        addSpike(at: CGPoint(x: w * 0.25, y: 30), pointingUp: true) // 床スパイク①
        addSpike(at: CGPoint(x: w * 0.5,  y: 30), pointingUp: true) // 床スパイク②
        addSpike(at: CGPoint(x: w * 0.72, y: 30), pointingUp: true) // 床スパイク③
        addSpike(at: CGPoint(x: w * 0.85, y: 30), pointingUp: true) // 床スパイク④

        // ── 溶岩（大面積・複数箇所）──
        addLava(rect: CGRect(x: 20,       y: 30, width: w * 0.2,  height: h * 0.18))       // 左底大溶岩
        addLava(rect: CGRect(x: w * 0.45, y: 30, width: w * 0.22, height: h * 0.14))       // 仕切り右底溶岩
        addLava(rect: CGRect(x: w * 0.22, y: h * 0.78, width: w * 0.18, height: h * 0.1)) // 左上溶岩

        // ── 追加スパイク（足場の縁）──
        addSpike(at: CGPoint(x: w * 0.45, y: h * 0.35 + 14), pointingUp: true) // 左中足場の右端スパイク
        addSpike(at: CGPoint(x: w * 0.82, y: h * 0.32 + 14), pointingUp: true) // 右中下足場の右端スパイク

        // ── ゴール（右上の上）──
        addGoal(at: CGPoint(x: w * 0.77, y: h * 0.65 + 14 + 22))

        spawnPlayer()
    }

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
