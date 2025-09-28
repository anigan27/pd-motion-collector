//import Foundation
//
//enum TestType: String, CaseIterable, Identifiable, Codable {
//    case fingerTapping = "Finger Tapping"
//    case fistOpenClose = "Fist Open and Close"
//    case wristPronateSupinate = "Wrist Pronate and Supinate"
//    case walkWithArmSwing = "Walk with Arm Swing"
//    case handsOnKnees = "Hands on Knees"
//    case toeTapping = "Toe Tapping"
//    case fingerToNose = "Finger to Nose"
//    case startStop = "Start and Stop"
//    case bottleCap = "Bottle Cap Opening and Closing"
//    case buttonUnbutton = "Buttoning and Unbuttoning"
//    case paperFold = "Paper Folding"
//
//    var fileName: String {
//        switch self {
//        case .fingerTapping: return "finger_tapping"
//        case .fistOpenClose: return "fist_open_close"
//        case .wristPronateSupinate: return "wrist_pronate_supinate"
//        case .walkWithArmSwing: return "walk_with_arm_swing"
//        case .handsOnKnees: return "hands_on_knees"
//        case .toeTapping: return "toe_tap"
//        case .fingerToNose: return "finger_to_nose"
//        case .startStop: return "start_stop"
//        case .bottleCap: return "bottle_cap"
//        case .buttonUnbutton: return "button_unbutton"
//        case .paperFold: return "paper_fold"
//        }
//    }
//
//    var needsTimer: Bool {
//        switch self {
//        case .fingerTapping, .fistOpenClose, .wristPronateSupinate, .walkWithArmSwing, .handsOnKnees, .toeTapping, .fingerToNose:
//            return true
//        default:
//            return false
//        }
//    }
//
//    var id: String { self.rawValue }
//}
//


import Foundation

enum TestType: String, CaseIterable, Identifiable {
    case Tap = "Finger Tapping"
    case Fist = "Fist Open and Close"
    case Pronate = "Wrist Pronate and Supinate"
    case Walk = "Walk with Arm Swing"
    case Knees = "Hands on Knees"
    case Toe = "Toe Tapping"
    case Nose = "Finger to Nose"
    case StartStop = "Start and Stop"
    case Bottle = "Bottle Cap"
    case Button = "Button and Unbutton"
    case Paper = "Paper Fold"

    var id: String { rawValue }

    static var timed: [TestType] {
        [.Tap, .Fist, .Pronate, .Walk, .Knees, .Toe, .Nose]
    }
    static var untimed: [TestType] {
        [.StartStop, .Bottle, .Button, .Paper]
    }
    var instructions: String {
        switch self {
        case .Tap: return "Tap your index finger to thumb as fast as you can for 10 seconds."
        case .Fist: return "Open and close your fist rapidly for 10 seconds."
        case .Pronate: return "Rotate your wrist back and forth for 10 seconds."
        case .Walk: return "Walk in a straight line with natural arm swings for 10 seconds."
        case .Knees: return "Sit with hands on knees for 10 seconds."
        case .Toe: return "With hands on knees, tap your toe for 10 seconds."
        case .Nose: return "Touch your finger to your nose and out for 10 seconds."
        case .StartStop: return "Walk 5 steps, then pause, then walk 5 steps again. Press Start to begin, Stop when done."
        case .Bottle: return "Twist open and close a bottle cap repeatedly for 5 times. Press Start to begin, Stop when done."
        case .Button: return "Button and unbutton a shirt 5 times. Press Start to begin, Stop when done."
        case .Paper: return "Fold a piece of paper, crease at half, fold again and crease . Press Start to begin, Stop when done."
        }
    }
    var isTimed: Bool {
        switch self {
        case .StartStop, .Button, .Bottle, .Paper: return false
        default: return true
        }
    }
    var icon: String { "doc.text.fill" }
    var fileName: String {
        rawValue.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
    }
}
