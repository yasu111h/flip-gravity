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

// MARK: - Spike Direction

enum SpikeDirection {
    case up, down, left, right
}

// MARK: - GameScene

class GameScene: SKScene, SKPhysicsContactDelegate {

    private var stageIndex: Int = 0

    // ── グリッド座標系 ──────────────────────────────────────
    // 1セル = 30pt。シーンサイズ固定: 390×840
    // 列: 0=左壁左端 〜 13=右壁右端、行: 0=床下端 〜 26=天井ライン
    private let C: CGFloat = 30
    private let ballSizeCells: CGFloat = 1       // ボールサイズ（セル単位）1=1マス分
    private let ballBodyRatio: CGFloat = 0.9    // ボール当たり判定の割合（1.0=視覚と同サイズ）
    private let goalSizeCells: CGFloat = 1.5        // ゴールサイズ（セル単位）1=1マス分
    private let platformThickCells: CGFloat = 0.5  // 床・溶岩・消える床のデフォルト厚み（セル単位）1=1マス分
    private var gravityDirection: GravityDirection = .down
    private var playerNode: SKShapeNode!
    private var deathCount = 0
    private var deathLabel: SKLabelNode!
    private var gravityLabel: SKLabelNode!
    private var isGameCleared = false
    private var canRotate = true
    private var spawnPoint = CGPoint.zero
    private var blinkingFloors: [SKShapeNode: Bool] = [:]
    private var blinkingFloorRects: [CGRect] = []   // リスポーン時に再生成するための初期rect

    convenience init(size: CGSize, stageIndex: Int) {
        self.init(size: CGSize(width: 390, height: 840))
        self.stageIndex = stageIndex
    }

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared
        backgroundColor = .black

        physicsWorld.gravity = gravityDirection.vector
        physicsWorld.contactDelegate = self

        let border = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: -390,
            y: -840,
            width: 390 * 3,
            height: 840 * 3
        ))
        border.categoryBitMask = PhysicsCategory.ground
        border.collisionBitMask = PhysicsCategory.player
        physicsBody = border

        if theme.hasGrid { addBackgroundGrid() }
        if theme.hasStars { addBackgroundStars() }
        buildStage()
        addPlayAreaBorder()
        setupHUD()
        if UserDefaults.standard.bool(forKey: "debugMode") { addDebugGrid() }
    }

    private func addBackgroundGrid() {
        let gridSpacing: CGFloat = 60
        let gridColor = UIColor(white: 1.0, alpha: 0.05)
        var x: CGFloat = C
        while x <= 12 * C {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: C))
            path.addLine(to: CGPoint(x: x, y: 25 * C))
            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 1
            line.zPosition = -10
            addChild(line)
            x += gridSpacing
        }
        var y: CGFloat = C
        while y <= 25 * C {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: C, y: y))
            path.addLine(to: CGPoint(x: 12 * C, y: y))
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

    // MARK: - 座標系の説明
    //
    //  SpriteKit の座標原点は【画面左下】。
    //  x → 右方向が正、y → 上方向が正。
    //
    //  画面サイズ例（iPhone 14 Pro): w = 393pt, h = 852pt（論理ポイント）
    //  実際の値は size.width / size.height を使用。
    //
    //  ┌──────────────────── (w, h) ── HUDバー(上部60pt) ─
    //  │                                  ↑ y = h - 60 が天井の物理ライン
    //  │
    //  │      ゲームプレイエリア
    //  │      y=0(床) 〜 y=(h-60)(天井)
    //  │
    //  └──── (0, 0) ────────────────── (w, 0)
    //
    //  ── オブジェクト配置の基準点ルール ──
    //
    //  addFloor(at:size:)    → at は【矩形の左下隅】の座標
    //  addLava(at:size:)     → at は【矩形の左下隅】の座標
    //  addSpike(at:direction:) → at は【スパイクの底辺中心】の座標
    //                            .up   → 底辺が下、先端が上
    //                            .down → 底辺が上（y=at.y）、先端が下
    //                            .left → 底辺が右（x=at.x）、先端が左
    //                            .right→ 底辺が左（x=at.x）、先端が右
    //  addGoal(at:)          → at は【ゴール円の中心】
    //  spawnPoint            → プレイヤー出現位置の【中心】
    //
    //  壁・天井（物理ボディ）:
    //    左壁: x=0 の左端に厚さ20pt
    //    右壁: x=w の右端に厚さ20pt
    //    床:   y=0 の下端に厚さ20pt
    //    天井: y=(h-60) に厚さ60pt → HUDバー(60pt)と一致

    // ステージ番号に応じてビルド関数を切り替える
    private func buildStage() {
        switch stageIndex {
        case 0:  buildStage1()
        case 1:  buildStage2()
        case 2:  buildStage3()
        case 3:  buildStage4()
        case 4:  buildStage5()
        case 5:  buildStage6()
        case 6:  buildStage7()
        case 7:  buildStage8()
        case 8:  buildStage9()
        case 9:  buildStage10()
        case 10: buildStage11()
        case 11: buildStage12()
        case 12: buildStage13()
        case 13: buildStage14()
        case 14: buildStage15()
        default: buildStage1()
        }
    }

    // ─────────────────────────────────────────────
    // 【外壁】全ステージ共通の4辺（床・天井・左右の壁）
    // ─────────────────────────────────────────────
    private func addOuterWalls() {
        // ── 外壁・境界（すべて黒で塗りつぶし）──
        // 左壁: x=0〜30（1セル幅、プレイエリア左端）
        addBoundaryWall(rect: CGRect(x: 0, y: 0, width: C, height: 26 * C))
        // 右壁: x=360〜390
        addBoundaryWall(rect: CGRect(x: 12 * C, y: 0, width: C, height: 26 * C))
        // 床: y=0〜30（1セル高さ）
        addBoundaryWall(rect: CGRect(x: 0, y: 0, width: 13 * C, height: C))
        // 天井+上部: y=750〜840（HUDバーとセーフティ領域を含む）
        addBoundaryWall(rect: CGRect(x: 0, y: 25 * C, width: 13 * C, height: 3 * C))
    }

    /// 外壁用: 黒塗りで物理ボディあり
    private func addBoundaryWall(rect: CGRect) {
        let node = SKShapeNode(rect: rect)
        node.fillColor = .black
        node.strokeColor = .clear
        node.zPosition = 5
        let body = SKPhysicsBody(rectangleOf: rect.size,
                                 center: CGPoint(x: rect.midX, y: rect.midY))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.none
        node.physicsBody = body
        addChild(node)
    }

    /// プレイエリアの枠線（x=30〜360, y=30〜750）
    private func addPlayAreaBorder() {
        let playRect = CGRect(x: C, y: C, width: 11 * C, height: 24 * C)
        let border = SKShapeNode(rect: playRect)
        border.fillColor = .clear
        border.strokeColor = UIColor(white: 1.0, alpha: 0.25)
        border.lineWidth = 1.5
        border.zPosition = 6
        addChild(border)
    }

    // ─────────────────────────────────────────────
    // 【グリッド座標系の読み方】
    //
    //  シーン固定サイズ: 390 × 840 pt
    //  1セル(C) = 30pt
    //  グリッド: 13列 × 28行
    //
    //  ┌─ col 0                    col 13 ─┐
    //  │  ├─ 左壁 ─┤              ├─ 右壁 ─┤│
    //  │                                   │ ← row 28
    //  │  [セーフティ余白 row 27-28]          │
    //  │  [HUDバー         row 25-27]       │
    //  │  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ row 25 ← 天井ライン
    //  │                                   │
    //  │  プレイエリア内側                    │
    //  │  col 1〜12, row 1〜24              │
    //  │                                   │
    //  │  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ row 1 ← 床ライン
    //  └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ row 0 ─┘
    //
    //  ── 各ヘルパー関数の引数 ──
    //
    //  addFloor(x: col, y: row, w: 幅[セル], h: 高さ[セル]=0.5)
    //    → プラットフォーム・地形ブロック。x,y は左下コーナーのセル番号。
    //    → isTerrain: true で地形色（仕切り壁など）
    //    例: addFloor(x: 2, y: 5, w: 4)   // col2から4セル幅、row5の高さ0.5セル
    //
    //  addLava(x: col, y: row, w: 幅[セル], h: 高さ[セル]=0.5)
    //    → 溶岩ブロック。x,y は左下コーナー。
    //
    //  addBlinkingFloor(x: col, y: row, w: 幅[セル], h: 高さ[セル]=0.5)
    //    → 消える床。踏むと2秒後に消滅。
    //
    //  addSpike(col: 列, row: 行, direction: 向き)
    //    → col, row はスパイク底辺の中心セル番号。
    //    → .up = 床の上、.down = 天井の下、.right = 左壁から右、.left = 右壁から左
    //    例: addSpike(col: 3, row: 1, direction: .up)  // 床面スパイク
    //        addSpike(col: 6, row: 25, direction: .down) // 天井スパイク
    //
    //  addGoal(col: 列, row: 行)
    //    → ゴール円の中心セル番号。
    //    → 足場の上: row = 足場のrow + 足場のh + ゴール半径/C(≈0.73)
    //    例: addGoal(col: 10, row: 22)
    //
    //  spawnPoint = gp(col, row)
    //    → プレイヤー出現位置の中心セル番号。
    // ─────────────────────────────────────────────

    // ─────────────────────────────────────────────
    // STAGE 1: チュートリアル
    // 難易度: ★☆☆☆☆
    // 概要: 基本操作を学ぶ最初のステージ。
    //       スパイク・溶岩・消える床が少量登場する。
    //       左下からスタートし、足場を踏み替えながら左上のゴールを目指す。
    // ─────────────────────────────────────────────
    private func buildStage1() {
        spawnPoint = gp(1.5, 5.5)
        addOuterWalls()
        addFloor(x: 1, y: 3, w: 4)
        addFloor(x: 6, y: 10, w: 3)
        addFloor(x: 8, y: 18, w: 3)
        addFloor(x: 1, y: 13, w: 3)
        addFloor(x: 5, y: 20.5, w: 3)
        addSpike(col: 1, row: 1, direction: .up)
        addSpike(col: 2, row: 1, direction: .up)
        addSpike(col: 8, row: 10.5, direction: .up)
        addSpike(col: 9.5, row: 24, direction: .down)
        addLava(x: 4, y: 1, w: 5)
        addBlinkingFloor(x: 6, y: 15, w: 3)
        addGoal(col: 5, row: 21)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 2: 縦仕切りの迷路
    // 難易度: ★★☆☆☆
    // 概要: 画面を縦断する2本の仕切り壁がある。
    //       左エリア→右エリアへ移動するには重力を切り替えて
    //       仕切りの上か隙間を抜ける必要がある。
    // ─────────────────────────────────────────────
    private func buildStage2() {
        spawnPoint = gp(1.5, 2.5)
        addOuterWalls()
        // 縦仕切り左: x=5, y=1, w=0.5, h=14
        addFloor(x: 5, y: 1, w: 0.5, h: 14, isTerrain: true)
        // 縦仕切り右: x=7.5, y=12, w=0.5, h=14
        addFloor(x: 7.5, y: 12, w: 0.5, h: 12, isTerrain: true)
        // 足場左
        addFloor(x: 1, y: 8, w: 3)
        addFloor(x: 1, y: 11, w: 2.5)
        addFloor(x: 1, y: 15, w: 3)
        // 足場右
        addFloor(x: 8, y: 17, w: 2.5)
        // スパイク
        addSpike(col: 2, row: 24, direction: .down)
        addSpike(col: 8.5, row: 1, direction: .up)
        addSpike(col: 10.5, row: 1, direction: .up)
//        addLava(x: 1, y: 11, w: 2.5)
        addGoal(col: 8, row: 17.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 3: 溶岩地獄
    // 難易度: ★★★☆☆
    // 概要: 下半分に大きな溶岩ゾーンが広がる。
    //       重力を下向きのままだと即溶岩に落ちる。
    //       上向き重力に切り替えて上半分を渡るのが攻略の鍵。
    // ─────────────────────────────────────────────
    private func buildStage3() {
        spawnPoint = gp(1.5, 12)
        addOuterWalls()
        // 溶岩（下半分・h を明示して縦に大きく）
        addLava(x: 1, y: 1, w: 8, h: 10)      // 左下大溶岩
        addLava(x: 10, y: 1, w: 1, h: 10)     // 右端細い溶岩
        // 足場
        addFloor(x: 1, y: 17, w: 3)      // 左上足場（スタート台）
        addFloor(x: 4.5, y: 20, w: 4)    // 中央上の長い足場
        addFloor(x: 8, y: 15, w: 2.5)    // 右中段足場（ゴール台）
        addFloor(x: 4, y: 22.5, w: 4.5)    // 最上段足場
        addFloor(x: 1, y: 11, w: 4)    // 中段左の中継
        addFloor(x: 9, y: 11, w: 1)    // 中段左の中継
        // 天井スパイク
        addSpike(col: 2.5, row: 24, direction: .down)
        addSpike(col: 9.5, row: 24, direction: .down)
        // ゴール
        addGoal(col: 8, row: 15.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 4: 消える床パズル
    // 難易度: ★★★☆☆
    // 概要: 消える床（水色）が4枚並ぶ。
    //       踏んだ瞬間から2秒後に消えるため、
    //       順番を考えて素早く渡らないとゴールに届かない。
    // ─────────────────────────────────────────────
    private func buildStage4() {
        spawnPoint = gp(1, 3.5)
        addOuterWalls()
        // 固定足場
        addFloor(x: 1, y: 2.5, w: 2.5)     // 左下スタート台
        addFloor(x: 9.5, y: 14, w: 1)       // 右中段の固定足場
        // 消える床
        addBlinkingFloor(x: 3.5, y: 5, w: 2.5)   // ①
        addBlinkingFloor(x: 7, y: 10, w: 2.5)     // ②
        addBlinkingFloor(x: 3, y: 15.5, w: 2.5)   // ③
        addBlinkingFloor(x: 7, y: 20, w: 2.5)     // ④
        // 溶岩
        addLava(x: 1, y: 1, w: 11)
        // ゴール
        addGoal(col: 7.5, row: 21.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 5: 全方向攻略（上級）
    // 難易度: ★★★★☆
    // 概要: 画面を縦断する仕切り壁が中央にあり、
    //       4方向すべての重力を使わないとゴールに届かない。
    //       スパイク・溶岩・消える床の全種類が登場する。
    // ─────────────────────────────────────────────
    private func buildStage5() {
        spawnPoint = gp(1, 2.5)
        addOuterWalls()
        // 縦の仕切り壁
        addFloor(x: 6, y: 1, w: 0.5, h: 10, isTerrain: true)    // 中央仕切り下部
        addFloor(x: 6, y: 17, w: 0.5, h: 9, isTerrain: true)    // 中央仕切り上部
        // 足場（左エリア）
        addFloor(x: 1, y: 5.5, w: 3)   // 左上段
        addFloor(x: 1, y: 11, w: 2.5)  // 左中段
        // 足場（右エリア）
        addFloor(x: 7, y: 5, w: 3.5)   // 右上段
        addFloor(x: 8.5, y: 10.5, w: 2) // 右中段
        addFloor(x: 1, y: 18, w: 2.5)  // 左下段
        addFloor(x: 7, y: 20, w: 3.5)  // 右下段（ゴール台）
        // 消える床
        addBlinkingFloor(x: 3, y: 15, w: 2.5)  // 左側の消える床
        addBlinkingFloor(x: 7, y: 15, w: 2.5)  // 右側の消える床
        // スパイク
        addSpike(col: 3.5, row: 1, direction: .up)
        addSpike(col: 3.5, row: 24, direction: .down)
        addSpike(col: 8.5, row: 24, direction: .down)
        addSpike(col: 1, row: 13, direction: .right)
        addSpike(col: 11, row: 13, direction: .left)
        // 溶岩
        addLava(x: 7.5, y: 1, w: 3)
        // ゴール
        addGoal(col: 9.5, row: 20.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 6: S字ルート
    // 難易度: ★★☆☆☆
    // 概要: 左側を下から上へ登り、中央の橋を渡って右側のゴールへ。
    //       S字を描くような進行ルート。消える床が中継地点に1枚。
    // ─────────────────────────────────────────────
    private func buildStage6() {
        spawnPoint = gp(1.5, 3.5)
        addOuterWalls()
        // 左側の足場
        addFloor(x: 1, y: 2.5, w: 3.5)   // L1: 左下スタート台
        addFloor(x: 1, y: 7, w: 3)        // L2: 左中下段
        addFloor(x: 1, y: 12, w: 3.5)    // L3: 左中上段
        // 中央の橋
        addFloor(x: 3, y: 16, w: 6)    // 橋（長い）
        // 右側の足場
        addFloor(x: 8, y: 12, w: 2.5)    // R1: 右中段
        addFloor(x: 6, y: 20, w: 4.5)    // R2: 右上段
//        addFloor(x: 10, y: 17.5, w: 1, h: 1.5)    // スパイクブロック
        addFloor(x: 10, y: 17.5, w: 1)    // スパイクブロック
        // 壁
        addFloor(x: 4, y: 16.5, w: platformThickCells, h: 7)    // 縦長の壁
        // 消える床
        addBlinkingFloor(x: 5, y: 9, w: 2.5)
        // スパイク
        addSpike(col: 6, row: 20.5, direction: .up)
        addSpike(col: 6, row: 1, direction: .up)
        addSpike(col: 8, row: 1, direction: .up)
        addSpike(col: 10, row: 16.5, direction: .down)
        addSpike(col: 1, row: 24, direction: .down)
        addSpike(col: 22, row: 5, direction: .right)
        addSpike(col: 4.5, row: 16.5, direction: .up)
        addSpike(col: 4.5, row: 22.5, direction: .right)
        // 溶岩
        addLava(x: 9.5, y: 1, w: 1, h: 4)
        // ゴール
        addGoal(col: 7, row: 17.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 7: 交互の足場
    // 難易度: ★★★☆☆
    // 概要: 左右交互に配置された足場をジグザグに登る。
    //       重力を切り替えて対岸の足場へ飛び移るのが攻略の鍵。
    // ─────────────────────────────────────────────
    private func buildStage7() {
        spawnPoint = gp(1.5, 1.5)
        addOuterWalls()
        // ジグザグ足場
        addFloor(x: 1, y: 4, w: 4.5)     // Z1: 左下
        addFloor(x: 6.5, y: 7.5, w: 4)   // Z2: 右中下
        addFloor(x: 1, y: 11.5, w: 4.5)  // Z3: 左中
        addFloor(x: 6.5, y: 15.5, w: 4)  // Z4: 右中上
        addFloor(x: 1, y: 19, w: 4.5)    // Z5: 左上
        addFloor(x: 6.5, y: 23, w: 4)    // Z6: 右上（ゴール台）
        // スパイク
        addSpike(col: 8, row: 1, direction: .up)
        addSpike(col: 5, row: 4.5, direction: .up)
        addSpike(col: 9.5, row: 8, direction: .up)
        addSpike(col: 5, row: 12, direction: .up)
        addSpike(col: 1, row: 24, direction: .down)
        // 溶岩
        addLava(x: 4.5, y: 1, w: 2)
        // ゴール
        addGoal(col: 9, row: 23.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 8: 逆さ溶岩
    // 難易度: ★★★☆☆
    // 概要: 画面下半分がほぼ溶岩。上向き重力に素早く切り替えて
    //       上部の足場を渡り、左上のゴールを目指す。
    //       天井にはスパイクが並んでいるので注意。
    // ─────────────────────────────────────────────
    private func buildStage8() {
        spawnPoint = gp(1, 14.5)
        addOuterWalls()
        // スタート台（左中段）
        addFloor(x: 1, y: 14, w: 2.5)
        // 上部の足場
        addFloor(x: 4, y: 21, w: 3)    // 天井近く左
        addFloor(x: 8, y: 22.5, w: 2.5) // 天井近く右
        addFloor(x: 2, y: 23, w: 4.5)  // 最上段（ゴール台）
        // 中段の中継足場
        addFloor(x: 5.5, y: 15.5, w: 2.5)
        // 溶岩（下半分）
        addLava(x: 1, y: 1, w: 3)      // 左下大溶岩
        addLava(x: 4, y: 1, w: 5)      // 中央下大溶岩
        addLava(x: 10, y: 1, w: 1)     // 右端溶岩
        // 溶岩の中の柱
        addFloor(x: 3.5, y: 1, w: 0.5, h: 3, isTerrain: true)  // 柱①
        addFloor(x: 9, y: 1, w: 0.5, h: 4, isTerrain: true)    // 柱②
        // 天井スパイク
        addSpike(col: 6, row: 24, direction: .down)
        addSpike(col: 9.5, row: 24, direction: .down)
        addSpike(col: 11, row: 24, direction: .down)
        // ゴール
        addGoal(col: 3.5, row: 23.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 9: 消える床の嵐
    // 難易度: ★★★★☆
    // 概要: 消える床が6枚のジグザグ配置。下は溶岩。
    //       踏んだ瞬間から時計が始まるので、素早く次の床へ移動せよ。
    // ─────────────────────────────────────────────
    private func buildStage9() {
        spawnPoint = gp(1, 2.5)
        addOuterWalls()
        // スタート台（固定・左下）
        addFloor(x: 1, y: 2.5, w: 3)
        // 消える床6枚
        addBlinkingFloor(x: 3.5, y: 5.5, w: 2.5)  // ①
        addBlinkingFloor(x: 7, y: 8.5, w: 2.5)     // ②
        addBlinkingFloor(x: 3, y: 11.5, w: 2.5)    // ③
        addBlinkingFloor(x: 7, y: 15.5, w: 2.5)    // ④
        addBlinkingFloor(x: 2.5, y: 19, w: 2.5)    // ⑤
        addBlinkingFloor(x: 7, y: 22.5, w: 2.5)    // ⑥
        // ゴール台（固定・右上）
        addFloor(x: 8, y: 23.5, w: 2.5)
        // 溶岩
        addLava(x: 1, y: 1, w: 6.5)
        addLava(x: 7, y: 1, w: 3.5)
        // スパイク
        addSpike(col: 10.5, row: 1, direction: .up)
        addSpike(col: 1.5, row: 24, direction: .down)
        addSpike(col: 6, row: 24, direction: .down)
        // ゴール
        addGoal(col: 9, row: 24)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 10: 四方スパイク回廊
    // 難易度: ★★★★☆
    // 概要: 中央に縦仕切りで作られた回廊にスパイクが密集。
    //       左右重力を駆使して狭い隙間を通り抜け、右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage10() {
        spawnPoint = gp(1.5, 2)
        addOuterWalls()
        // 縦の仕切り壁（回廊を形成）
        addFloor(x: 5, y: 1, w: 0.5, h: 10, isTerrain: true)    // 仕切り左下
        addFloor(x: 7, y: 1, w: 0.5, h: 7, isTerrain: true)     // 仕切り右下
        addFloor(x: 5, y: 15.5, w: 0.5, h: 10, isTerrain: true) // 仕切り左上
        addFloor(x: 7, y: 12.5, w: 0.5, h: 12, isTerrain: true) // 仕切り右上
        // 足場（左エリア）
        addFloor(x: 1, y: 5.5, w: 2.5)    // 左中下段
        addFloor(x: 1, y: 12.5, w: 2.5)   // 左中段
        addFloor(x: 1, y: 19, w: 2.5)     // 左上段
        // 足場（右エリア）
        addFloor(x: 8, y: 8.5, w: 2.5)    // 右中段
        addFloor(x: 8, y: 17, w: 2.5)     // 右上段（ゴール台）
        // 回廊内の中継
        addFloor(x: 5.5, y: 11.5, w: 2)
        // スパイク
        addSpike(col: 5, row: 10, direction: .up)
        addSpike(col: 5, row: 14.5, direction: .down)
        addSpike(col: 7.5, row: 7, direction: .up)
        addSpike(col: 7.5, row: 11.5, direction: .down)
        addSpike(col: 2.5, row: 1, direction: .up)
        addSpike(col: 8.5, row: 1, direction: .up)
        addSpike(col: 10.5, row: 1, direction: .up)
        addSpike(col: 4.5, row: 24, direction: .down)
        addSpike(col: 7.5, row: 24, direction: .down)
        // 溶岩
        addLava(x: 7, y: 1, w: 1.5)
        // ゴール
        addGoal(col: 9, row: 17.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 11: 孤島巡り
    // 難易度: ★★★☆☆
    // 概要: 溶岩の海に浮かぶ6つの小島。
    //       重力を切り替えながら島から島へホップして右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage11() {
        spawnPoint = gp(1, 3.5)
        addOuterWalls()
        // 島①〜⑥
        addFloor(x: 1, y: 3, w: 2.5)      // 島① 左下（スタート）
        addFloor(x: 5, y: 6, w: 2.5)      // 島② 中央下
        addFloor(x: 8, y: 11, w: 2.5)     // 島③ 右中
        addFloor(x: 4.5, y: 17, w: 2.5)   // 島④ 中央上
        addFloor(x: 1, y: 22, w: 2.5)     // 島⑤ 左上
        addFloor(x: 8, y: 20, w: 2.5)     // 島⑥ 右上（ゴール台）
        // 溶岩
        addLava(x: 1, y: 1, w: 4.5)       // 左底溶岩
        addLava(x: 3, y: 1, w: 4.5)       // 中央底溶岩
        addLava(x: 8, y: 1, w: 2.5)       // 右底溶岩
        addLava(x: 1, y: 9, w: 7.5)       // 中央大溶岩
        // 消える床
        addBlinkingFloor(x: 3, y: 14, w: 1.5)
        // スパイク
        addSpike(col: 3.5, row: 3.5, direction: .up)   // 島①右端
        addSpike(col: 7, row: 6.5, direction: .up)     // 島②右端
        addSpike(col: 6.5, row: 24, direction: .down)
        addSpike(col: 10, row: 24, direction: .down)
        // ゴール
        addGoal(col: 9, row: 20.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 12: 上から下へ
    // 難易度: ★★★★☆
    // 概要: 左上スタートで、徐々に下に降りながらゴールを目指す。
    //       天井にスパイクが密集しており上向き重力は極めて危険。
    //       下向きに下りながら消える床も活用する。
    // ─────────────────────────────────────────────
    private func buildStage12() {
        spawnPoint = gp(1, 21.5)
        addOuterWalls()
        // 天井スパイク（密集）
        addSpike(col: 2.5, row: 24, direction: .down)
        addSpike(col: 4, row: 24, direction: .down)
        addSpike(col: 5.5, row: 24, direction: .down)
        addSpike(col: 6.5, row: 24, direction: .down)
        addSpike(col: 8, row: 24, direction: .down)
        addSpike(col: 9.5, row: 24, direction: .down)
        addSpike(col: 10.5, row: 24, direction: .down)
        // 上段の足場（スタート台）
        addFloor(x: 1, y: 22.5, w: 3)     // 左上スタート台
        addFloor(x: 7, y: 21, w: 3.5)     // 右上足場
        // 中段の足場
        addFloor(x: 3, y: 17, w: 3.5)     // 中央左
        addFloor(x: 7.5, y: 14, w: 3)     // 中央右
        // 下段の足場
        addFloor(x: 1, y: 10.5, w: 3)     // 左下
        addFloor(x: 4.5, y: 7.5, w: 3.5)  // 中央下
        addFloor(x: 8.5, y: 5, w: 2)      // 右下（ゴール台）
        // 消える床
        addBlinkingFloor(x: 4, y: 12.5, w: 3)
        // 床スパイク
        addSpike(col: 3.5, row: 1, direction: .up)
        addSpike(col: 6, row: 1, direction: .up)
        addSpike(col: 8.5, row: 1, direction: .up)
        // 溶岩
        addLava(x: 5, y: 1, w: 2.5)
        // ゴール
        addGoal(col: 9, row: 5.5)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 13: 格子迷路
    // 難易度: ★★★★☆
    // 概要: 縦横の仕切り壁が格子状に配置されたステージ。
    //       各区画の隙間（仕切りの端の開口部）を見つけて右上のゴールへ。
    // ─────────────────────────────────────────────
    private func buildStage13() {
        spawnPoint = gp(1, 2.5)
        addOuterWalls()
        // 縦仕切り（2本）
        addFloor(x: 4, y: 1, w: 0.5, h: 8, isTerrain: true)     // 縦①下半
        addFloor(x: 4, y: 12.5, w: 0.5, h: 12, isTerrain: true) // 縦①上半
        addFloor(x: 7.5, y: 6, w: 0.5, h: 10, isTerrain: true)  // 縦②中
        addFloor(x: 7.5, y: 21, w: 0.5, h: 4, isTerrain: true)  // 縦②上
        // 横仕切り（2本）
        addFloor(x: 4, y: 10.5, w: 3.5, h: 0.5, isTerrain: true)  // 横①
        addFloor(x: 4, y: 18, w: 3.5, h: 0.5, isTerrain: true)    // 横②
        // 足場
        addFloor(x: 1, y: 6, w: 1.5)       // 左下段
        addFloor(x: 1, y: 15.5, w: 1.5)    // 左中段
        addFloor(x: 4.5, y: 14.5, w: 2.5)  // 中央足場
        addFloor(x: 8, y: 10.5, w: 2.5)    // 右中下段
        addFloor(x: 8, y: 17.5, w: 2.5)    // 右中上段（ゴール台）
        // スパイク
        addSpike(col: 5.5, row: 1, direction: .up)
        addSpike(col: 9.5, row: 1, direction: .up)
        addSpike(col: 5.5, row: 24, direction: .down)
        addSpike(col: 9.5, row: 24, direction: .down)
        addSpike(col: 5.5, row: 11, direction: .up)
        // 溶岩
        addLava(x: 1, y: 1, w: 1.5)
        // ゴール
        addGoal(col: 9, row: 18)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 14: 全ギミック総動員
    // 難易度: ★★★★★
    // 概要: 全種類のギミックが高密度で出現する最終試練（前半）。
    //       左上からスタートし、ジグザグに下りながら右下のゴールへ。
    //       消える床を踏んだら即座に次の行動を判断すること。
    // ─────────────────────────────────────────────
    private func buildStage14() {
        spawnPoint = gp(1, 22.5)
        addOuterWalls()
        // スタート台（左上）
        addFloor(x: 1, y: 23, w: 2.5)
        // 通常足場
        addFloor(x: 3.5, y: 20, w: 2.5)   // 足場②
        addFloor(x: 7, y: 17.5, w: 2.5)   // 足場③
        addFloor(x: 3.5, y: 14, w: 2.5)   // 足場④
        // 消える床ゾーン
        addBlinkingFloor(x: 7, y: 11, w: 2.5)   // 消①
        addBlinkingFloor(x: 3, y: 8.5, w: 2.5)  // 消②
        addBlinkingFloor(x: 7, y: 5.5, w: 2.5)  // 消③
        // ゴール台（右下）
        addFloor(x: 8, y: 2.5, w: 2.5)
        // 天井スパイク
        addSpike(col: 4, row: 24, direction: .down)
        addSpike(col: 6, row: 24, direction: .down)
        addSpike(col: 8, row: 24, direction: .down)
        addSpike(col: 10, row: 24, direction: .down)
        // 床スパイク
        addSpike(col: 2, row: 1, direction: .up)
        addSpike(col: 4.5, row: 1, direction: .up)
        addSpike(col: 7.5, row: 1, direction: .up)
        addSpike(col: 10, row: 1, direction: .up)
        // 溶岩
        addLava(x: 1, y: 1, w: 2)
        addLava(x: 5.5, y: 1, w: 2)
        addLava(x: 8.5, y: 1, w: 2)
        // 追加スパイク
        addSpike(col: 6, row: 20.5, direction: .up)   // 足場②右端
        addSpike(col: 9, row: 18, direction: .up)      // 足場③右端
        // ゴール
        addGoal(col: 9, row: 3)
        spawnPlayer()
    }

    // ─────────────────────────────────────────────
    // STAGE 15: 禁断のステージ
    // 難易度: ★★★★★
    // 概要: 全ギミック最高密度の最終面。
    //       中央仕切りで左右に分断され、消える床・溶岩・密集スパイクが全方位から襲う。
    //       4方向の重力を完全に使いこなして突破せよ。
    // ─────────────────────────────────────────────
    private func buildStage15() {
        spawnPoint = gp(1, 2.5)
        addOuterWalls()
        // 中央仕切り（上下に隙間あり）
        addFloor(x: 5.5, y: 1, w: 0.5, h: 8.5, isTerrain: true)     // 仕切り下部
        addFloor(x: 5.5, y: 14.5, w: 0.5, h: 10, isTerrain: true)   // 仕切り上部
        // 左エリアの足場
        addFloor(x: 1, y: 6, w: 2.5)      // 左中下
        addFloor(x: 3, y: 9.5, w: 2.5)    // 左中
        addFloor(x: 1, y: 14.5, w: 2)     // 左中上
        addFloor(x: 3, y: 18, w: 2.5)     // 左上
        // 右エリアの足場
        addFloor(x: 7, y: 5, w: 2)        // 右下
        addFloor(x: 9, y: 9, w: 1.5)      // 右中下
        addFloor(x: 7, y: 13.5, w: 2)     // 右中
        addFloor(x: 9, y: 18, w: 1.5)     // 右上（ゴール台）
        // 消える床
        addBlinkingFloor(x: 2.5, y: 12.5, w: 2.5)   // 左の消える床
        addBlinkingFloor(x: 6, y: 10.5, w: 1)        // 仕切り隙間の消える床
        addBlinkingFloor(x: 7, y: 22.5, w: 3.5)      // 右上の消える床
        // 天井スパイク（6本）
        addSpike(col: 2, row: 24, direction: .down)
        addSpike(col: 3.5, row: 24, direction: .down)
        addSpike(col: 5, row: 24, direction: .down)
        addSpike(col: 6.5, row: 24, direction: .down)
        addSpike(col: 8, row: 24, direction: .down)
        addSpike(col: 10, row: 24, direction: .down)
        // 床スパイク
        addSpike(col: 2.5, row: 1, direction: .up)
        addSpike(col: 6, row: 1, direction: .up)
        addSpike(col: 9, row: 1, direction: .up)
        addSpike(col: 10.5, row: 1, direction: .up)
        // 溶岩
        addLava(x: 1, y: 1, w: 2.5)
        addLava(x: 5.5, y: 1, w: 3)
        addLava(x: 3, y: 22, w: 2.5)
        // 追加スパイク
        addSpike(col: 5, row: 10, direction: .up)
        addSpike(col: 10, row: 9.5, direction: .up)
        // ゴール
        addGoal(col: 9.5, row: 18.5)
        spawnPlayer()
    }

    // MARK: - Debug Grid
    // デバッグモードON時のみ表示される座標グリッド。
    // 1セル(C=30pt)ごとに線を引き、col/row番号をラベル表示する。
    // プレイエリア: col 1〜12, row 1〜24

    private func addDebugGrid() {
        let lineColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.18)
        let labelMain = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.85)
        let labelSub  = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.40)

        func makeLbl(_ text: String, fontSize: CGFloat, color: UIColor,
                     hAlign: SKLabelHorizontalAlignmentMode,
                     vAlign: SKLabelVerticalAlignmentMode,
                     pos: CGPoint) {
            let lbl = SKLabelNode(text: text)
            lbl.fontName = "AvenirNext-Medium"
            lbl.fontSize = fontSize
            lbl.fontColor = color
            lbl.horizontalAlignmentMode = hAlign
            lbl.verticalAlignmentMode = vAlign
            lbl.position = pos
            lbl.zPosition = 56
            addChild(lbl)
        }

        // ── 縦線 + col ラベル（上下2辺）──
        for col in 0...13 {
            let x = CGFloat(col) * C
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            let line = SKShapeNode(path: path)
            line.strokeColor = lineColor
            line.lineWidth = (col % 2 == 0) ? 0.8 : 0.4
            line.zPosition = 55
            addChild(line)

            guard col >= 1 && col <= 12 else { continue }
            let fs: CGFloat = col % 2 == 0 ? 8 : 6
            let fc = col % 2 == 0 ? labelMain : labelSub
            let txt = "c\(col)"
            // 下辺：ライン(x)のすぐ右→左端を示す
            makeLbl(txt, fontSize: fs, color: fc, hAlign: .left, vAlign: .top,
                    pos: CGPoint(x: x + 2, y: C - 2))
            // 上辺
            makeLbl(txt, fontSize: fs, color: fc, hAlign: .left, vAlign: .bottom,
                    pos: CGPoint(x: x + 2, y: 25 * C + 2))
        }

        // ── 横線 + row ラベル（左右2辺）──
        for row in 0...28 {
            let y = CGFloat(row) * C
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let line = SKShapeNode(path: path)
            line.strokeColor = lineColor
            line.lineWidth = (row % 2 == 0) ? 0.8 : 0.4
            line.zPosition = 55
            addChild(line)

            guard row >= 1 && row <= 24 else { continue }
            let fs: CGFloat = row % 2 == 0 ? 8 : 6
            let fc = row % 2 == 0 ? labelMain : labelSub
            let txt = "r\(row)"
            // 左辺：ライン(y)のすぐ上→下端を示す（少し下にずらして下側を指す）
            makeLbl(txt, fontSize: fs, color: fc, hAlign: .left, vAlign: .top,
                    pos: CGPoint(x: C + 2, y: y - 1))
            // 右辺
            makeLbl(txt, fontSize: fs, color: fc, hAlign: .right, vAlign: .top,
                    pos: CGPoint(x: 12 * C - 2, y: y - 1))
        }
    }

        // MARK: - Node Factories

    // MARK: - グリッド座標ヘルパー
    /// セル座標 → CGPoint（左下基準）
    private func gp(_ col: CGFloat, _ row: CGFloat) -> CGPoint {
        CGPoint(x: col * C, y: row * C)
    }
    /// セル数 → CGSize
    private func gs(_ cols: CGFloat, _ rows: CGFloat) -> CGSize {
        CGSize(width: cols * C, height: rows * C)
    }
    /// グリッド座標版 addFloor（h省略時は platformThickCells を使用）
    private func addFloor(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat? = nil, isTerrain: Bool = false) {
        let height = h ?? platformThickCells
        addFloor(rect: CGRect(x: x * C, y: y * C, width: w * C, height: height * C), isTerrain: isTerrain)
    }
    /// グリッド座標版 addLava（h省略時は platformThickCells を使用）
    private func addLava(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat? = nil) {
        let height = h ?? platformThickCells
        addLava(rect: CGRect(x: x * C, y: y * C, width: w * C, height: height * C))
    }
    /// グリッド座標版 addBlinkingFloor（h省略時は platformThickCells を使用）
    private func addBlinkingFloor(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat? = nil) {
        let height = h ?? platformThickCells
        addBlinkingFloor(rect: CGRect(x: x * C, y: y * C, width: w * C, height: height * C))
    }
    /// グリッド座標版 addSpike（(col,row) = スパイクが占める1セルの左下コーナー）
    private func addSpike(col: CGFloat, row: CGFloat, direction: SpikeDirection) {
        let base: CGPoint
        switch direction {
        case .up:    base = CGPoint(x: (col + 0.5) * C, y: row * C)
        case .down:  base = CGPoint(x: (col + 0.5) * C, y: (row + 1) * C)
        case .right: base = CGPoint(x: col * C, y: (row + 0.5) * C)
        case .left:  base = CGPoint(x: (col + 1) * C, y: (row + 0.5) * C)
        }
        addSpike(at: base, direction: direction)
    }
    /// グリッド座標版 addGoal（(col,row) = バウンディング正方形の左下コーナー）
    private func addGoal(col: CGFloat, row: CGFloat) {
        let r = goalSizeCells * C / 2
        addGoal(at: CGPoint(x: col * C + r, y: row * C + r))
    }

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

    private func addSpike(at base: CGPoint, direction: SpikeDirection) {
        let tipLen: CGFloat = C      // = 30pt（1セル分）
        let halfW: CGFloat = C / 2   // = 15pt

        // ── ビジュアル（三角形パス）──
        // base: スパイクの平らな底辺の中心座標
        // 先端はdirectionの方向へ tipLen だけ伸びる
        let path = CGMutablePath()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: base.x, y: base.y + tipLen))       // 上向き先端
            path.addLine(to: CGPoint(x: base.x - halfW, y: base.y))     // 底辺左
            path.addLine(to: CGPoint(x: base.x + halfW, y: base.y))     // 底辺右
        case .down:
            path.move(to: CGPoint(x: base.x, y: base.y - tipLen))       // 下向き先端
            path.addLine(to: CGPoint(x: base.x - halfW, y: base.y))     // 底辺左
            path.addLine(to: CGPoint(x: base.x + halfW, y: base.y))     // 底辺右
        case .right:
            path.move(to: CGPoint(x: base.x + tipLen, y: base.y))       // 右向き先端
            path.addLine(to: CGPoint(x: base.x, y: base.y - halfW))     // 底辺下
            path.addLine(to: CGPoint(x: base.x, y: base.y + halfW))     // 底辺上
        case .left:
            path.move(to: CGPoint(x: base.x - tipLen, y: base.y))       // 左向き先端
            path.addLine(to: CGPoint(x: base.x, y: base.y - halfW))     // 底辺下
            path.addLine(to: CGPoint(x: base.x, y: base.y + halfW))     // 底辺上
        }
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        let theme = ThemeManager.shared
        node.fillColor = theme.spikeFillColor
        node.strokeColor = theme.spikeStrokeColor
        node.lineWidth = 1.5

        // ── 当たり判定（矩形・先端側の半分をカバー）──
        let bodyCenter: CGPoint
        let bodySize: CGSize
        switch direction {
        case .up:
            bodySize = CGSize(width: tipLen, height: tipLen / 2)
            bodyCenter = CGPoint(x: base.x, y: base.y + tipLen / 4)
        case .down:
            bodySize = CGSize(width: tipLen, height: tipLen / 2)
            bodyCenter = CGPoint(x: base.x, y: base.y - tipLen / 4)
        case .right:
            bodySize = CGSize(width: tipLen / 2, height: tipLen)
            bodyCenter = CGPoint(x: base.x + tipLen / 4, y: base.y)
        case .left:
            bodySize = CGSize(width: tipLen / 2, height: tipLen)
            bodyCenter = CGPoint(x: base.x - tipLen / 4, y: base.y)
        }
        let body = SKPhysicsBody(rectangleOf: bodySize, center: bodyCenter)
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
        blinkingFloorRects.append(rect)
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
        let radius = goalSizeCells * C / 2
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = position
        let theme = ThemeManager.shared
        node.fillColor = theme.goalFillColor.withAlphaComponent(0.9)
        node.strokeColor = theme.goalStrokeColor
        node.lineWidth = 2
        node.name = "goal"
        let label = SKLabelNode(text: "GOAL")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 8
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        let body = SKPhysicsBody(circleOfRadius: radius * 0.8)
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
        let radius = ballSizeCells * C / 2
        playerNode = SKShapeNode(circleOfRadius: radius)
        playerNode.position = CGPoint(x: spawnPoint.x + radius, y: spawnPoint.y + radius)
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
        let body = SKPhysicsBody(circleOfRadius: radius * ballBodyRatio)
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

        // ── HUD ヘッダーバー ──────────────────────────────────────
        // 画面最上部に高さ60ptの帯を設け、その中に全HUD要素を配置する。
        // プレイエリアはy=0〜(height-60)、HUDバーはy=(height-60)〜height。
        let hudH: CGFloat = 60
        let midY = size.height - 30 - hudH / 2   // ヘッダーバーの垂直中心 (= 840 - 30 - 30 = 780)

        // 背景バー（完全不透明の黒帯）
        let hudBg = SKShapeNode(rect: CGRect(x: 0, y: size.height - 30 - hudH,
                                             width: size.width, height: hudH))
        hudBg.fillColor = UIColor(white: 0.05, alpha: 1.0)
        hudBg.strokeColor = .clear
        hudBg.zPosition = 88
        addChild(hudBg)

        // バー下端の仕切り線
        let separator = SKShapeNode()
        let sepPath = CGMutablePath()
        sepPath.move(to: CGPoint(x: 0, y: size.height - 30 - hudH))
        sepPath.addLine(to: CGPoint(x: size.width, y: size.height - 30 - hudH))
        separator.path = sepPath
        separator.strokeColor = hudColor.withAlphaComponent(0.25)
        separator.lineWidth = 1
        separator.zPosition = 89
        addChild(separator)

        // ── 💀 死亡カウント（左寄り）──
        deathLabel = SKLabelNode(text: "💀 ×0")
        deathLabel.fontName = "AvenirNext-Bold"
        deathLabel.fontSize = 18
        deathLabel.fontColor = UIColor(hex: "FF5252")
        deathLabel.horizontalAlignmentMode = .left
        deathLabel.verticalAlignmentMode = .center
        deathLabel.position = CGPoint(x: 18, y: midY)
        deathLabel.zPosition = 100
        addChild(deathLabel)

        // ── 重力方向矢印（中央）──
        gravityLabel = SKLabelNode(text: gravityDirection.arrowText)
        gravityLabel.fontName = "AvenirNext-Heavy"
        gravityLabel.fontSize = 30
        gravityLabel.fontColor = gravityDirection.neonColor
        gravityLabel.horizontalAlignmentMode = .center
        gravityLabel.verticalAlignmentMode = .center
        gravityLabel.position = CGPoint(x: size.width / 2, y: midY + 4)
        gravityLabel.zPosition = 100
        addChild(gravityLabel)

        // ヒントテキスト（矢印の真下・小さめ）
        let hintLabel = SKLabelNode(text: "TAP to rotate")
        hintLabel.fontName = "AvenirNext-Medium"
        hintLabel.fontSize = 9
        hintLabel.fontColor = hudColor.withAlphaComponent(0.4)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width / 2, y: midY - 13)
        hintLabel.zPosition = 100
        addChild(hintLabel)

        // ── ✕ バックボタン（右寄り）──
        let backButton = SKLabelNode(text: "✕")
        backButton.fontName = "AvenirNext-Bold"
        backButton.fontSize = 22
        backButton.fontColor = hudColor.withAlphaComponent(0.7)
        backButton.horizontalAlignmentMode = .right
        backButton.verticalAlignmentMode = .center
        backButton.position = CGPoint(x: size.width - 18, y: midY)
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
            // HUDバー内（上部60pt）のタップは重力回転に使わない
            if location.y > size.height - 60 { return }
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
            self.restoreBlinkingFloors()
            self.spawnPlayer()
        }
    }

    private func restoreBlinkingFloors() {
        for node in blinkingFloors.keys { node.removeFromParent() }
        blinkingFloors.removeAll()
        let rects = blinkingFloorRects
        blinkingFloorRects.removeAll()
        for rect in rects { addBlinkingFloor(rect: rect) }
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
        let vx = body.velocity.dx
        let vy = body.velocity.dy
        let speed = sqrt(vx * vx + vy * vy)

        if speed < 15.0 {
            // ほぼ静止：速度と回転を強制的にゼロにして無駄な微動を止める
            body.velocity = .zero
            body.angularVelocity = 0
        } else {
            // 移動中は速度に比例して回転させる（地面上・空中どちらでも）
            // 重力方向に垂直な速度成分でロールさせることで自然な回転に見える
            let radius: CGFloat = 15.0
            switch gravityDirection {
            case .down, .up:
                body.angularVelocity = -vx / radius
            case .left, .right:
                body.angularVelocity = vy / radius
            }
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
