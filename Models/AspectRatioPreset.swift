import Foundation

/// Předvolby poměru stran pro obrazový ořez videa.
enum AspectRatioPreset: String, CaseIterable, Identifiable, Equatable {
    case original = "Originál"
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"
    case ratio1x1 = "1:1"
    case ratio4x5 = "4:5"
    case ratio4x3 = "4:3"
    case custom = "Vlastní"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .original: return tr("Plný obraz")
        case .ratio16x9: return tr("Širokoúhlé")
        case .ratio9x16: return "Reels / Shorts"
        case .ratio1x1: return tr("Čtverec")
        case .ratio4x5: return tr("Portrét IG")
        case .ratio4x3: return tr("Klasické")
        case .custom: return tr("Volný výřez")
        }
    }

    /// Cílový poměr šířka / výška, nebo nil pro volný / původní formát.
    var aspectRatio: CGFloat? {
        switch self {
        case .original, .custom:
            return nil
        case .ratio16x9:
            return 16.0 / 9.0
        case .ratio9x16:
            return 9.0 / 16.0
        case .ratio1x1:
            return 1.0
        case .ratio4x5:
            return 4.0 / 5.0
        case .ratio4x3:
            return 4.0 / 3.0
        }
    }

    var isInteractiveCrop: Bool {
        self != .original
    }

    /// Vrátí vycentrovaný normalizovaný výřez (0...1) pro dané rozlišení videa.
    func centeredNormalizedCrop(for displaySize: CGSize) -> CGRect {
        guard displaySize.width > 0, displaySize.height > 0,
              let targetAspect = aspectRatio else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let sourceAspect = displaySize.width / displaySize.height
        if abs(sourceAspect - targetAspect) < 0.001 {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        if targetAspect < sourceAspect {
            let normalizedWidth = targetAspect / sourceAspect
            let x = (1.0 - normalizedWidth) / 2.0
            return CGRect(x: x, y: 0, width: normalizedWidth, height: 1.0)
        } else {
            let normalizedHeight = sourceAspect / targetAspect
            let y = (1.0 - normalizedHeight) / 2.0
            return CGRect(x: 0, y: y, width: 1.0, height: normalizedHeight)
        }
    }
}
