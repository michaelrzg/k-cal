//
//  ExerciseMotion.swift
//  k-cal
//
//  Every lift as a jointed figure seen from the side. A motion is two poses given as joint angles, so limbs keep
//  their length as it moves. Figures work on a 100 x 100 canvas, facing right, with y going down.
//

import CoreGraphics
import Foundation

/// Joint directions in degrees: 0 points right, 90 up.
struct Pose: Equatable {
    var torso: Double
    var upperArm: Double
    var forearm: Double
    var thigh: Double
    var shin: Double
    /// The far leg, where the two differ, as in a lunge.
    var farThigh: Double? = nil
    var farShin: Double? = nil
    /// Raises the shoulders along the torso, for shrugs.
    var shrug: Double = 0
    /// Raises the whole figure, for calf raises.
    var rise: Double = 0

    func blended(to other: Pose, by amount: Double) -> Pose {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * amount }
        return Pose(
            torso: mix(torso, other.torso), upperArm: mix(upperArm, other.upperArm), forearm: mix(forearm, other.forearm),
            thigh: mix(thigh, other.thigh), shin: mix(shin, other.shin),
            farThigh: farThigh.map { mix($0, other.farThigh ?? $0) }, farShin: farShin.map { mix($0, other.farShin ?? $0) },
            shrug: mix(shrug, other.shrug), rise: mix(rise, other.rise)
        )
    }
}

/// Where a figure's joints land for a pose.
struct Skeleton: Equatable {
    var head: CGPoint
    var shoulder: CGPoint
    var elbow: CGPoint
    var hand: CGPoint
    var hip: CGPoint
    var knee: CGPoint
    var foot: CGPoint
    var farKnee: CGPoint
    var farFoot: CGPoint

    static let torsoLength = 29.0
    static let upperArmLength = 14.5
    static let forearmLength = 14.0
    static let thighLength = 19.0
    static let shinLength = 18.0
    static let headDistance = 7.0
    static let headRadius = 5.5
    static let footLength = 6.0

    init(pose: Pose, anchor: MotionAnchor) {
        func step(_ from: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
            let radians = degrees * .pi / 180
            return CGPoint(x: from.x + cos(radians) * length, y: from.y - sin(radians) * length)
        }
        let hip = CGPoint.zero
        let shoulder = step(hip, pose.torso, Self.torsoLength + pose.shrug)
        let head = step(shoulder, pose.torso, Self.headDistance)
        let elbow = step(step(hip, pose.torso, Self.torsoLength), pose.upperArm, Self.upperArmLength)
        let hand = step(elbow, pose.forearm, Self.forearmLength)
        let knee = step(hip, pose.thigh, Self.thighLength)
        let foot = step(knee, pose.shin, Self.shinLength)
        let farKnee = step(hip, pose.farThigh ?? pose.thigh, Self.thighLength)
        let farFoot = step(farKnee, pose.farShin ?? pose.shin, Self.shinLength)

        let fixed: CGPoint
        let target: CGPoint
        switch anchor {
        case let .foot(point): (fixed, target) = (foot, point)
        case let .hip(point): (fixed, target) = (hip, point)
        case let .hand(point): (fixed, target) = (hand, point)
        }
        let offset = CGVector(dx: target.x - fixed.x, dy: target.y - fixed.y - pose.rise)
        func moved(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + offset.dx, y: point.y + offset.dy) }
        self.head = moved(head)
        self.shoulder = moved(shoulder)
        self.elbow = moved(elbow)
        self.hand = moved(hand)
        self.hip = moved(hip)
        self.knee = moved(knee)
        self.foot = moved(foot)
        self.farKnee = moved(farKnee)
        self.farFoot = moved(farFoot)
    }

    /// Puts the hand on `target` with the elbow on the given side, so a limb never changes length.
    mutating func reach(to target: CGPoint, bendSide: CGFloat) {
        let upper = Self.upperArmLength
        let lower = Self.forearmLength
        let dx = target.x - shoulder.x
        let dy = target.y - shoulder.y
        let distance = min(max(hypot(dx, dy), abs(upper - lower) + 0.01), upper + lower - 0.01)
        let length = max(hypot(dx, dy), 0.001)
        let along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
        let height = (max(upper * upper - along * along, 0)).squareRoot()
        let unit = CGVector(dx: dx / length, dy: dy / length)
        let middle = CGPoint(x: shoulder.x + unit.dx * along, y: shoulder.y + unit.dy * along)
        elbow = CGPoint(x: middle.x - unit.dy * height * bendSide, y: middle.y + unit.dx * height * bendSide)
        hand = CGPoint(x: shoulder.x + unit.dx * distance, y: shoulder.y + unit.dy * distance)
    }
}

enum MotionAnchor: Equatable {
    case foot(CGPoint)
    case hip(CGPoint)
    case hand(CGPoint)
}

/// Equipment drawn around the figure. It follows the hands or the shoulders, or stays put.
enum MotionProp: Equatable {
    case barAtHands
    case barOnShoulders
    case dumbbellAtHands
    case handleAtHands
    /// A cable from a fixed point to the hands.
    case cable(from: CGPoint)
    /// A flat pad from one point to another.
    case pad(from: CGPoint, to: CGPoint)
    /// A fixed bar seen end on, to hang from.
    case fixedBar(at: CGPoint)
    /// A plate following the feet, for a leg press.
    case sledAtFeet
    /// A roller on the shin, for leg extensions and curls.
    case rollerAtFeet
}

struct ExerciseMotion: Equatable {
    var start: Pose
    var end: Pose
    var anchor: MotionAnchor
    var props: [MotionProp]
    /// Seconds for one rep, there and back.
    var duration: Double = 3.4
    var showsFloor = true
    /// The hands travel in a straight line, as a bar does, with the elbows following.
    var straightHandPath = false
    /// The figure's front faces the other way: lying on your back with your head to the right.
    var isFlipped = false

    func skeleton(at progress: Double) -> Skeleton {
        var body = Skeleton(pose: start.blended(to: end, by: progress), anchor: anchor)
        guard straightHandPath else { return body }
        let from = Skeleton(pose: start, anchor: anchor).hand
        let to = Skeleton(pose: end, anchor: anchor).hand
        let target = CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
        body.reach(to: target, bendSide: bendSide)
        return body
    }

    /// Which way the elbow bends, taken from the pose where it bends most and kept for the whole rep. Choosing
    /// again each frame lets a nearly straight arm flip the elbow across.
    private var bendSide: CGFloat {
        let bends = [Skeleton(pose: start, anchor: anchor), Skeleton(pose: end, anchor: anchor)].map { body -> CGFloat in
            let reach = CGVector(dx: body.hand.x - body.shoulder.x, dy: body.hand.y - body.shoulder.y)
            let arm = CGVector(dx: body.elbow.x - body.shoulder.x, dy: body.elbow.y - body.shoulder.y)
            return reach.dx * arm.dy - reach.dy * arm.dx
        }
        return (abs(bends[0]) > abs(bends[1]) ? bends[0] : bends[1]) >= 0 ? 1 : -1
    }

    /// Where the toes are for a foot. They stick out from the shin on the body's front, so a figure lying on its back
    /// with its feet to the left has them pointing left, and one lying on its front has them pointing down.
    func toe(foot: CGPoint, knee: CGPoint) -> CGPoint {
        let shin = atan2(foot.y - knee.y, foot.x - knee.x)
        let toe = shin + (isFlipped ? .pi / 2 : -.pi / 2)
        return CGPoint(x: foot.x + cos(toe) * Skeleton.footLength, y: foot.y + sin(toe) * Skeleton.footLength)
    }

    /// Everything the motion touches, for fitting the whole rep on screen.
    var extent: CGRect {
        var points: [CGPoint] = []
        for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
            let body = skeleton(at: progress)
            let radius = Skeleton.headRadius
            points += [body.shoulder, body.elbow, body.hip, body.knee, body.foot, body.farKnee, body.farFoot,
                       toe(foot: body.foot, knee: body.knee), toe(foot: body.farFoot, knee: body.farKnee),
                       CGPoint(x: body.head.x - radius, y: body.head.y - radius), CGPoint(x: body.head.x + radius, y: body.head.y + radius),
                       CGPoint(x: body.hand.x - 8, y: body.hand.y - 8), CGPoint(x: body.hand.x + 8, y: body.hand.y + 8)]
        }
        for prop in props {
            switch prop {
            case let .pad(from, to): points += [from, to]
            case let .cable(from): points.append(from)
            case let .fixedBar(at): points.append(at)
            default: break
            }
        }
        if showsFloor { points += [CGPoint(x: 6, y: 92), CGPoint(x: 94, y: 92)] }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    /// How far through the rep a moment is, from 0 to 1 and back: a controlled move, a short pause, the return.
    static func progress(atPhase phase: Double) -> Double {
        func smooth(_ value: Double) -> Double {
            let t = min(max(value, 0), 1)
            return t * t * t * (t * (t * 6 - 15) + 10)
        }
        switch phase {
        case ..<0.43: return smooth(phase / 0.43)
        case ..<0.5: return 1
        case ..<0.94: return 1 - smooth((phase - 0.5) / 0.44)
        default: return 0
        }
    }
}

extension ExerciseMotion {
    private static let floor = 90.0
    private static let standing = CGPoint(x: 46, y: floor)
    /// The ankle on a body held up on its toes, which reach down to the floor.
    private static let onToes = CGPoint(x: 14, y: floor - 4.5)
    private static let cableHigh = CGPoint(x: 78, y: 6)
    private static let cableFront = CGPoint(x: 94, y: 40)
    private static let cableLow = CGPoint(x: 94, y: 86)
    private static let benchPad = MotionProp.pad(from: CGPoint(x: 18, y: 66), to: CGPoint(x: 74, y: 66))
    private static let seatPad = MotionProp.pad(from: CGPoint(x: 26, y: 66), to: CGPoint(x: 52, y: 66))

    private static let upright = Pose(torso: 90, upperArm: -90, forearm: -90, thigh: -90, shin: -90)
    private static let seated = Pose(torso: 90, upperArm: -90, forearm: -90, thigh: 0, shin: -90)
    private static let lying = Pose(torso: 0, upperArm: 90, forearm: 90, thigh: 188, shin: -96)

    static let squat = ExerciseMotion(
        start: Pose(torso: 86, upperArm: -142, forearm: 62, thigh: -90, shin: -90),
        end: Pose(torso: 54, upperArm: -168, forearm: 34, thigh: -8, shin: -112),
        anchor: .foot(standing), props: [.barOnShoulders], duration: 3.6
    )
    static let frontSquat = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -20, forearm: 120, thigh: -90, shin: -90),
        end: Pose(torso: 72, upperArm: -38, forearm: 102, thigh: -6, shin: -116),
        anchor: .foot(standing), props: [.barAtHands], duration: 3.6
    )
    static let hackSquat = ExerciseMotion(
        start: Pose(torso: 102, upperArm: -80, forearm: -80, thigh: -78, shin: -96),
        end: Pose(torso: 96, upperArm: -80, forearm: -80, thigh: -4, shin: -108),
        anchor: .foot(CGPoint(x: 56, y: floor)), props: [.pad(from: CGPoint(x: 24, y: 10), to: CGPoint(x: 42, y: 62))], duration: 3.6
    )
    static let gobletSquat = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -60, forearm: 72, thigh: -90, shin: -90),
        end: Pose(torso: 70, upperArm: -82, forearm: 56, thigh: -8, shin: -114),
        anchor: .foot(standing), props: [.dumbbellAtHands], duration: 3.6
    )
    static let legPress = ExerciseMotion(
        start: Pose(torso: 138, upperArm: -52, forearm: 0, thigh: 72, shin: -44),
        end: Pose(torso: 138, upperArm: -52, forearm: 0, thigh: 22, shin: 12),
        anchor: .hip(CGPoint(x: 30, y: 74)),
        props: [.pad(from: CGPoint(x: 10, y: 54), to: CGPoint(x: 30, y: 78)), .sledAtFeet], duration: 3.4, showsFloor: true
    )
    static let lunge = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -90, forearm: -90, thigh: -76, shin: -96, farThigh: -104, farShin: -118),
        end: Pose(torso: 86, upperArm: -90, forearm: -90, thigh: -6, shin: -100, farThigh: -112, farShin: -176),
        anchor: .foot(CGPoint(x: 58, y: floor)), props: [.dumbbellAtHands], duration: 3.6
    )
    static let legExtension = ExerciseMotion(
        start: Pose(torso: 96, upperArm: -80, forearm: -40, thigh: 0, shin: -100),
        end: Pose(torso: 96, upperArm: -80, forearm: -40, thigh: 0, shin: 2),
        anchor: .hip(CGPoint(x: 34, y: 60)), props: [.pad(from: CGPoint(x: 22, y: 66), to: CGPoint(x: 52, y: 66)), .rollerAtFeet]
    )
    static let legCurl = ExerciseMotion(
        start: Pose(torso: 180, upperArm: -60, forearm: -30, thigh: 2, shin: -2),
        end: Pose(torso: 180, upperArm: -60, forearm: -30, thigh: 2, shin: 96),
        anchor: .hip(CGPoint(x: 52, y: 62)), props: [.pad(from: CGPoint(x: 16, y: 68), to: CGPoint(x: 72, y: 68)), .rollerAtFeet], isFlipped: true
    )
    static let deadlift = ExerciseMotion(
        start: Pose(torso: 34, upperArm: -92, forearm: -92, thigh: -14, shin: -104),
        end: Pose(torso: 92, upperArm: -92, forearm: -92, thigh: -90, shin: -90),
        anchor: .foot(standing), props: [.barAtHands], duration: 3.8, straightHandPath: true
    )
    static let romanianDeadlift = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -92, forearm: -92, thigh: -86, shin: -92),
        end: Pose(torso: 22, upperArm: -90, forearm: -90, thigh: -72, shin: -96),
        anchor: .foot(standing), props: [.barAtHands], duration: 3.8, straightHandPath: true
    )
    static let goodMorning = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -142, forearm: 62, thigh: -86, shin: -92),
        end: Pose(torso: 18, upperArm: -214, forearm: 8, thigh: -74, shin: -96),
        anchor: .foot(standing), props: [.barOnShoulders], duration: 3.8
    )
    static let hipThrust = ExerciseMotion(
        start: Pose(torso: 160, upperArm: -40, forearm: 60, thigh: 4, shin: -94),
        end: Pose(torso: 180, upperArm: -56, forearm: 44, thigh: 2, shin: -92),
        anchor: .foot(CGPoint(x: 72, y: floor)), props: [.pad(from: CGPoint(x: 4, y: 58), to: CGPoint(x: 26, y: 58)), .barAtHands]
    )
    static let calfRaise = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -142, forearm: 62, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: -142, forearm: 62, thigh: -90, shin: -90, rise: 8),
        anchor: .foot(standing), props: [.barOnShoulders], duration: 2.6
    )
    static let seatedCalfRaise = ExerciseMotion(
        start: Pose(torso: 92, upperArm: -60, forearm: -30, thigh: 0, shin: -90),
        end: Pose(torso: 92, upperArm: -60, forearm: -30, thigh: 6, shin: -82),
        anchor: .hip(CGPoint(x: 34, y: 58)), props: [seatPad], duration: 2.6
    )
    static let benchPress = ExerciseMotion(
        start: lying,
        end: Pose(torso: 0, upperArm: 196, forearm: 82, thigh: 188, shin: -96),
        anchor: .hip(CGPoint(x: 26, y: 60)), props: [benchPad, .barAtHands], straightHandPath: true, isFlipped: true
    )
    static let dumbbellPress = ExerciseMotion(
        start: lying,
        end: Pose(torso: 0, upperArm: 196, forearm: 82, thigh: 188, shin: -96),
        anchor: .hip(CGPoint(x: 26, y: 60)), props: [benchPad, .dumbbellAtHands], straightHandPath: true, isFlipped: true
    )
    static let inclinePress = ExerciseMotion(
        start: Pose(torso: 40, upperArm: 90, forearm: 90, thigh: 196, shin: -92),
        end: Pose(torso: 40, upperArm: 208, forearm: 84, thigh: 196, shin: -92),
        anchor: .hip(CGPoint(x: 30, y: 66)), props: [.pad(from: CGPoint(x: 26, y: 72), to: CGPoint(x: 64, y: 38)), .barAtHands], straightHandPath: true, isFlipped: true
    )
    static let machinePress = ExerciseMotion(
        start: Pose(torso: 88, upperArm: -172, forearm: 0, thigh: 0, shin: -90),
        end: Pose(torso: 88, upperArm: 2, forearm: 2, thigh: 0, shin: -90),
        anchor: .hip(CGPoint(x: 30, y: 60)), props: [seatPad, .handleAtHands], straightHandPath: true
    )
    static let pushUp = ExerciseMotion(
        start: Pose(torso: 20.6, upperArm: -90, forearm: -90, thigh: 200.6, shin: 200.6),
        end: Pose(torso: 9, upperArm: -158, forearm: -44, thigh: 189, shin: 189),
        anchor: .foot(onToes), props: [], straightHandPath: true
    )
    static let chestFly = ExerciseMotion(
        start: Pose(torso: 0, upperArm: 82, forearm: 98, thigh: 188, shin: -96),
        end: Pose(torso: 0, upperArm: 182, forearm: 150, thigh: 188, shin: -96),
        anchor: .hip(CGPoint(x: 26, y: 60)), props: [benchPad, .dumbbellAtHands], isFlipped: true
    )
    static let cableFly = ExerciseMotion(
        start: Pose(torso: 78, upperArm: -190, forearm: -210, thigh: -84, shin: -92),
        end: Pose(torso: 74, upperArm: -28, forearm: -12, thigh: -84, shin: -92),
        anchor: .foot(CGPoint(x: 40, y: floor)), props: [.cable(from: CGPoint(x: 6, y: 18)), .handleAtHands]
    )
    static let overheadPress = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -150, forearm: 84, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: 88, forearm: 90, thigh: -90, shin: -90),
        anchor: .foot(standing), props: [.barAtHands], straightHandPath: true
    )
    static let seatedPress = ExerciseMotion(
        start: Pose(torso: 92, upperArm: -160, forearm: 88, thigh: 0, shin: -90),
        end: Pose(torso: 92, upperArm: 88, forearm: 92, thigh: 0, shin: -90),
        anchor: .hip(CGPoint(x: 38, y: 60)), props: [seatPad, .dumbbellAtHands], straightHandPath: true
    )
    static let lateralRaise = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -86, forearm: -80, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: 2, forearm: 8, thigh: -90, shin: -90),
        anchor: .foot(standing), props: [.dumbbellAtHands], duration: 3
    )
    static let cableLateralRaise = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -86, forearm: -80, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: 2, forearm: 8, thigh: -90, shin: -90),
        anchor: .foot(CGPoint(x: 40, y: floor)), props: [.cable(from: CGPoint(x: 8, y: 86)), .handleAtHands], duration: 3
    )
    static let reverseFly = ExerciseMotion(
        start: Pose(torso: 24, upperArm: -86, forearm: -80, thigh: -76, shin: -94),
        end: Pose(torso: 24, upperArm: -184, forearm: -188, thigh: -76, shin: -94),
        anchor: .foot(CGPoint(x: 38, y: floor)), props: [.dumbbellAtHands], duration: 3
    )
    static let facePull = ExerciseMotion(
        start: Pose(torso: 86, upperArm: 2, forearm: 4, thigh: -84, shin: -94),
        end: Pose(torso: 92, upperArm: 186, forearm: 12, thigh: -84, shin: -94),
        anchor: .foot(CGPoint(x: 36, y: floor)), props: [.cable(from: CGPoint(x: 94, y: 22)), .handleAtHands], duration: 3, straightHandPath: true
    )
    static let barbellRow = ExerciseMotion(
        start: Pose(torso: 26, upperArm: -90, forearm: -90, thigh: -70, shin: -96),
        end: Pose(torso: 28, upperArm: -162, forearm: -48, thigh: -70, shin: -96),
        anchor: .foot(CGPoint(x: 40, y: floor)), props: [.barAtHands], straightHandPath: true
    )
    static let dumbbellRow = ExerciseMotion(
        start: Pose(torso: 18, upperArm: -90, forearm: -90, thigh: -66, shin: -98),
        end: Pose(torso: 18, upperArm: -170, forearm: -56, thigh: -66, shin: -98),
        anchor: .foot(CGPoint(x: 36, y: floor)), props: [.dumbbellAtHands], straightHandPath: true
    )
    static let cableRow = ExerciseMotion(
        start: Pose(torso: 76, upperArm: 4, forearm: 2, thigh: 6, shin: -8),
        end: Pose(torso: 100, upperArm: -168, forearm: -2, thigh: 6, shin: -8),
        anchor: .hip(CGPoint(x: 26, y: 72)), props: [.pad(from: CGPoint(x: 14, y: 78), to: CGPoint(x: 48, y: 78)), .cable(from: cableLow), .handleAtHands], straightHandPath: true
    )
    static let latPulldown = ExerciseMotion(
        start: Pose(torso: 80, upperArm: 84, forearm: 88, thigh: 0, shin: -90),
        end: Pose(torso: 72, upperArm: -148, forearm: 74, thigh: 0, shin: -90),
        anchor: .hip(CGPoint(x: 38, y: 60)), props: [seatPad, .cable(from: CGPoint(x: 52, y: 2)), .barAtHands], straightHandPath: true
    )
    static let pullUp = ExerciseMotion(
        start: Pose(torso: 92, upperArm: 88, forearm: 90, thigh: -96, shin: -112),
        end: Pose(torso: 84, upperArm: -146, forearm: 72, thigh: -84, shin: -118),
        anchor: .hand(CGPoint(x: 52, y: 8)), props: [.fixedBar(at: CGPoint(x: 52, y: 8))], showsFloor: false
    )
    static let straightArmPulldown = ExerciseMotion(
        start: Pose(torso: 66, upperArm: 62, forearm: 58, thigh: -80, shin: -96),
        end: Pose(torso: 66, upperArm: -74, forearm: -70, thigh: -80, shin: -96),
        anchor: .foot(CGPoint(x: 36, y: floor)), props: [.cable(from: cableHigh), .barAtHands]
    )
    static let shrug = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -92, forearm: -92, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: -92, forearm: -92, thigh: -90, shin: -90, shrug: 6),
        anchor: .foot(standing), props: [.dumbbellAtHands], duration: 2.6
    )
    static let curl = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -94, forearm: -84, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: -88, forearm: 112, thigh: -90, shin: -90),
        anchor: .foot(standing), props: [.barAtHands], duration: 3
    )
    static let dumbbellCurl = ExerciseMotion(
        start: Pose(torso: 90, upperArm: -94, forearm: -84, thigh: -90, shin: -90),
        end: Pose(torso: 90, upperArm: -88, forearm: 112, thigh: -90, shin: -90),
        anchor: .foot(standing), props: [.dumbbellAtHands], duration: 3
    )
    static let inclineCurl = ExerciseMotion(
        start: Pose(torso: 118, upperArm: -100, forearm: -92, thigh: 4, shin: -90),
        end: Pose(torso: 118, upperArm: -92, forearm: 96, thigh: 4, shin: -90),
        anchor: .hip(CGPoint(x: 42, y: 62)), props: [.pad(from: CGPoint(x: 18, y: 28), to: CGPoint(x: 40, y: 68)), .dumbbellAtHands], duration: 3
    )
    static let preacherCurl = ExerciseMotion(
        start: Pose(torso: 80, upperArm: -40, forearm: -32, thigh: 0, shin: -90),
        end: Pose(torso: 80, upperArm: -40, forearm: 96, thigh: 0, shin: -90),
        anchor: .hip(CGPoint(x: 32, y: 62)), props: [seatPad, .pad(from: CGPoint(x: 48, y: 42), to: CGPoint(x: 64, y: 56)), .barAtHands], duration: 3
    )
    static let cableCurl = ExerciseMotion(
        start: Pose(torso: 88, upperArm: -92, forearm: -60, thigh: -86, shin: -92),
        end: Pose(torso: 88, upperArm: -86, forearm: 112, thigh: -86, shin: -92),
        anchor: .foot(CGPoint(x: 42, y: floor)), props: [.cable(from: cableLow), .handleAtHands], duration: 3
    )
    static let pushdown = ExerciseMotion(
        start: Pose(torso: 84, upperArm: -92, forearm: 18, thigh: -86, shin: -92),
        end: Pose(torso: 84, upperArm: -92, forearm: -84, thigh: -86, shin: -92),
        anchor: .foot(CGPoint(x: 40, y: floor)), props: [.cable(from: CGPoint(x: 66, y: 4)), .handleAtHands], duration: 3
    )
    static let overheadExtension = ExerciseMotion(
        start: Pose(torso: 92, upperArm: 98, forearm: 196, thigh: 0, shin: -90),
        end: Pose(torso: 92, upperArm: 98, forearm: 90, thigh: 0, shin: -90),
        anchor: .hip(CGPoint(x: 40, y: 60)), props: [seatPad, .dumbbellAtHands], duration: 3
    )
    static let skullCrusher = ExerciseMotion(
        start: Pose(torso: 0, upperArm: 96, forearm: 96, thigh: 188, shin: -96),
        end: Pose(torso: 0, upperArm: 106, forearm: 12, thigh: 188, shin: -96),
        anchor: .hip(CGPoint(x: 26, y: 60)), props: [benchPad, .barAtHands], duration: 3, isFlipped: true
    )
    static let dip = ExerciseMotion(
        start: Pose(torso: 84, upperArm: -92, forearm: -88, thigh: -106, shin: -128),
        end: Pose(torso: 72, upperArm: -160, forearm: -82, thigh: -98, shin: -126),
        anchor: .hand(CGPoint(x: 52, y: 58)), props: [.fixedBar(at: CGPoint(x: 52, y: 58))], showsFloor: false
    )
    static let crunch = ExerciseMotion(
        start: Pose(torso: 168, upperArm: 96, forearm: 110, thigh: 42, shin: -64),
        end: Pose(torso: 128, upperArm: 62, forearm: 30, thigh: 42, shin: -64),
        anchor: .hip(CGPoint(x: 46, y: 84)), props: [], duration: 2.8
    )
    static let hangingLegRaise = ExerciseMotion(
        start: Pose(torso: 92, upperArm: 90, forearm: 90, thigh: -92, shin: -96),
        end: Pose(torso: 96, upperArm: 90, forearm: 90, thigh: 6, shin: -6),
        anchor: .hand(CGPoint(x: 44, y: 8)), props: [.fixedBar(at: CGPoint(x: 44, y: 8))], showsFloor: false
    )
    static let cableCrunch = ExerciseMotion(
        start: Pose(torso: 84, upperArm: 70, forearm: 150, thigh: 14, shin: -86),
        end: Pose(torso: 26, upperArm: 30, forearm: 130, thigh: 14, shin: -86),
        anchor: .foot(CGPoint(x: 62, y: floor)), props: [.cable(from: CGPoint(x: 28, y: 6))], duration: 3
    )
    static let plank = ExerciseMotion(
        start: Pose(torso: 9, upperArm: -92, forearm: 2, thigh: 190, shin: 190),
        end: Pose(torso: 10, upperArm: -92, forearm: 2, thigh: 190, shin: 190),
        anchor: .foot(CGPoint(x: 16, y: onToes.y)), props: [], duration: 3.6
    )
}
