import UIKit

// MARK: - AppTheme

enum AppTheme: String, CaseIterable {
    case space = "space"
    case minimal = "minimal"
    case cyberpunk = "cyberpunk"

    var displayName: String {
        switch self {
        case .space:     return "SPACE"
        case .minimal:   return "MINIMAL"
        case .cyberpunk: return "CYBERPUNK"
        }
    }
}

// MARK: - ThemeManager

class ThemeManager {
    static let shared = ThemeManager()
    private init() {}

    private let key = "selectedTheme"

    var current: AppTheme {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? AppTheme.cyberpunk.rawValue
            return AppTheme(rawValue: raw) ?? .cyberpunk
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    // MARK: - Background

    var backgroundColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "050510")
        case .minimal:   return UIColor(hex: "F5F5F7")
        case .cyberpunk: return UIColor(hex: "000000")
        }
    }

    // MARK: - Player

    var playerFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "FFFFFF")
        case .minimal:   return UIColor(hex: "0071E3")
        case .cyberpunk: return UIColor(hex: "00F0FF")
        }
    }

    var playerStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00BFFF")
        case .minimal:   return UIColor(hex: "0055B3")
        case .cyberpunk: return UIColor(hex: "00F0FF")
        }
    }

    // MARK: - Platform (Terrain)

    var terrainFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "1A1A2E")
        case .minimal:   return UIColor(hex: "E5E5EA")
        case .cyberpunk: return UIColor(hex: "0D0D2B")
        }
    }

    var terrainStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00BFFF")
        case .minimal:   return UIColor(hex: "E5E5EA") // 縁なし（同色）
        case .cyberpunk: return UIColor(hex: "00F0FF")
        }
    }

    // MARK: - Platform (Regular)

    var platformFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "1A1A2E")
        case .minimal:   return UIColor(hex: "E5E5EA")
        case .cyberpunk: return UIColor(hex: "0D0D2B")
        }
    }

    var platformStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00BFFF")
        case .minimal:   return UIColor(hex: "E5E5EA") // 縁なし（同色）
        case .cyberpunk: return UIColor(hex: "00F0FF")
        }
    }

    // MARK: - Spike

    var spikeFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00FFFF")
        case .minimal:   return UIColor(hex: "8E8E93")
        case .cyberpunk: return UIColor(hex: "FF0040")
        }
    }

    var spikeStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "FFFFFF")
        case .minimal:   return UIColor(hex: "6E6E73")
        case .cyberpunk: return UIColor(hex: "FF0040")
        }
    }

    // MARK: - Lava

    var lavaFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "FF6B00")
        case .minimal:   return UIColor(hex: "FF3B30")
        case .cyberpunk: return UIColor(hex: "FF6600")
        }
    }

    var lavaStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "FFAB40")
        case .minimal:   return UIColor(hex: "FF6060")
        case .cyberpunk: return UIColor(hex: "FF8800")
        }
    }

    // MARK: - Blinking Floor

    var blinkFloorFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "7B2FBE")
        case .minimal:   return UIColor(hex: "34AADC")
        case .cyberpunk: return UIColor(hex: "BF00FF")
        }
    }

    var blinkFloorStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "B388FF")
        case .minimal:   return UIColor(hex: "50C0F0")
        case .cyberpunk: return UIColor(hex: "D040FF")
        }
    }

    // MARK: - Goal

    var goalFillColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00FFFF")
        case .minimal:   return UIColor(hex: "30D158")
        case .cyberpunk: return UIColor(hex: "00FF41")
        }
    }

    var goalStrokeColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "FFFFFF")
        case .minimal:   return UIColor(hex: "28B84A")
        case .cyberpunk: return UIColor(hex: "00FF41")
        }
    }

    // MARK: - HUD

    var hudColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "00BFFF")
        case .minimal:   return UIColor(hex: "1C1C1E")
        case .cyberpunk: return UIColor(hex: "FFFF00")
        }
    }

    // MARK: - Background Effects

    var hasGrid: Bool {
        switch current {
        case .space:     return false
        case .minimal:   return false
        case .cyberpunk: return true
        }
    }

    var hasStars: Bool {
        switch current {
        case .space:     return true
        case .minimal:   return false
        case .cyberpunk: return false
        }
    }

    // MARK: - Transition Color

    var transitionColor: UIColor {
        switch current {
        case .space:     return UIColor(hex: "050510")
        case .minimal:   return UIColor(hex: "F5F5F7")
        case .cyberpunk: return UIColor(hex: "000000")
        }
    }
}
