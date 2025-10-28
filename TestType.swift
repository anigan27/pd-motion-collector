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
        case .Tap: return "Extend the arm with the watch straight out in front of you. Tap your index finger and and thumb together in a pinching motion. Repeat this motion as fast as you can for 10 seconds."
        case .Fist: return "Extend the arm with the watch straight out in front of you. Close your hand tightly, making a fist. Open your hand and spread your fingers out as wide as you can. Repeat this opening and closing motion as fast as you can for 10 seconds."
        case .Pronate: return "Extend the arm with the watch straight out in front of you with your palm facing down. Rotate your forearm so that your palm is now facing the ceiling. Rotate your forearm in the opposite direction so that your palm is facing down again. Repeat the twisting motion as fast as you can for 10 seconds."
        case .Walk: return "Find a long, clear, straight path such as corridor. Walk in a straight line with natural arm swings for 10 seconds."
        case .Knees: return "Sit with your feet flat on the floor, and place your hands on knees for 10 seconds."
        case .Toe: return "With hands on knees, keep your feet flat on the floor. Using the foot on the same side as the hand with the watch, tap your toes on the ground as fast as you can for 10 seconds without lifting your heel off the ground. Repeat this motion for 10 seconds."
        case .Nose: return "Extend the arm with the watch straight out in front of you. Keep your index finger extended, like you are pointing at something. With your eyes closed, bring your index finger to your nose and then back out extended in front of you. Repeat this motion for 10 seconds."
        case .StartStop: return "Ensure your phone is in your non-watch hand for this test. Find a long, straight path. Walk 5 steps in a straight line, then pause in place for 5 seconds. Continue walking for another 5 steps. Press the stop button with your non-watch hand when you are done."
        case .Bottle: return "Grab your empty plastic bottle. Ensure your phone is within reach for this test. With the non-watch hand holding the bottle in place, use your watch hand to twist open the cap of the bottle and close it again. This is 1 set. Repeat this opening and closing motion for 5 sets. Press stop with your non-watch hand when you are done."
        case .Button: return "Grab your button-down shirt. Ensure your phone is within reach for this test. With the non-watch hand holding a button, use your watch hand to close the button into its corresponding buttonhole, then open it from the hole. This is 1 set. Repeat this closing and opening for 5 sets. Press stop with your non-watch hand when you are done."
        case .Paper: return "Grab your piece of printer paper, and lay it in landscape orientation on a table in front of you. Ensure your phone is within reach for this test. Using your non-watch hand to hold the paper in place, fold the top long edge of the paper down to the bottom edge to fold the paper in half length-wise. Crease the fold, and do not unfold the paper. Then, fold the paper in half again by bringing the right edge across to the left edge. Crease the fold. Press stop with your non-watch hand when you are done."
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
