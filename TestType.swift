import Foundation

enum TestType: String, CaseIterable, Identifiable, Codable {
    case fingerTapping = "Finger Tapping"
    case fistOpenClose = "Fist Open and Close"
    case wristPronateSupinate = "Wrist Pronate and Supinate"
    case walkWithArmSwing = "Walk with Arm Swing"
    case handsOnKnees = "Hands on Knees"
    case toeTapping = "Toe Tapping"
    case fingerToNose = "Finger to Nose"
    case startStop = "Start and Stop"
    case bottleCap = "Bottle Cap Opening and Closing"
    case buttonUnbutton = "Buttoning and Unbuttoning"
    case paperFold = "Paper Folding"

    var fileName: String {
        switch self {
        case .fingerTapping: return "finger_tapping"
        case .fistOpenClose: return "fist_open_close"
        case .wristPronateSupinate: return "wrist_pronate_supinate"
        case .walkWithArmSwing: return "walk_with_arm_swing"
        case .handsOnKnees: return "hands_on_knees"
        case .toeTapping: return "toe_tap"
        case .fingerToNose: return "finger_to_nose"
        case .startStop: return "start_stop"
        case .bottleCap: return "bottle_cap"
        case .buttonUnbutton: return "button_unbutton"
        case .paperFold: return "paper_fold"
        }
    }

    var needsTimer: Bool {
        switch self {
        case .fingerTapping, .fistOpenClose, .wristPronateSupinate, .walkWithArmSwing, .handsOnKnees, .toeTapping, .fingerToNose:
            return true
        default:
            return false
        }
    }

    var id: String { self.rawValue }
}

