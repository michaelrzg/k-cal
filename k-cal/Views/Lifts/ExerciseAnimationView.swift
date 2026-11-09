//
//  ExerciseAnimationView.swift
//  k-cal
//
//  Draws an exercise's figure and plays it on a loop: a neutral body with the muscles being trained picked out in
//  their real places, brightening as the rep gets hard.
//

import SwiftUI

struct ExerciseAnimationView: View {
    let exercise: Exercise
    var isPlaying = true
    /// Worked out once, because the figure redraws on every frame.
    private let extent: CGRect

    init(exercise: Exercise, isPlaying: Bool = true) {
        self.exercise = exercise
        self.isPlaying = isPlaying
        extent = exercise.motion.extent
    }

    var body: some View {
        Group {
            if isPlaying {
                TimelineView(.animation) { timeline in
                    FigureCanvas(exercise: exercise, extent: extent, progress: Self.progress(at: timeline.date, duration: exercise.motion.duration))
                }
            } else {
                FigureCanvas(exercise: exercise, extent: extent, progress: 0.6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Animation of \(exercise.name), working the \(exercise.muscle.rawValue.lowercased())")
    }

    static func progress(at date: Date, duration: Double) -> Double {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        return ExerciseMotion.progress(atPhase: phase)
    }
}

struct FigureCanvas: View {
    let exercise: Exercise
    let extent: CGRect
    let progress: Double

    @Environment(\.colorScheme) private var colorScheme

    init(exercise: Exercise, extent: CGRect? = nil, progress: Double) {
        self.exercise = exercise
        self.extent = extent ?? exercise.motion.extent
        self.progress = progress
    }

    var body: some View {
        let motion = exercise.motion
        let skeleton = motion.skeleton(at: progress)
        let dark = colorScheme == .dark
        let skin = dark ? Color(white: 0.56) : Color(white: 0.66)
        let farSkin = dark ? Color(white: 0.33) : Color(white: 0.82)
        // The near arm crosses the torso, so it needs its own tone to read against the body.
        let arm = dark ? Color(white: 0.82) : Color(white: 0.42)
        let gear = dark ? Color(white: 0.45) : Color(white: 0.66)
        let plate = dark ? Color(white: 0.28) : Color(white: 0.3)

        Canvas { context, size in
            // Fits the whole rep with a little margin, so the figure never leaves the frame.
            let side = max(max(extent.width, extent.height) + 8, 60)
            let scale = min(size.width, size.height) / side
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: side / 2 - extent.midX, y: side / 2 - extent.midY)

            if motion.showsFloor {
                var floor = Path()
                floor.move(to: CGPoint(x: 6, y: 92))
                floor.addLine(to: CGPoint(x: 94, y: 92))
                context.stroke(floor, with: .color(gear.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            for prop in motion.props { drawBehind(prop, skeleton, gear, in: context) }

            // Far limbs sit behind and stay plain, so the near side reads clearly.
            Figure.limb(skeleton.hip, skeleton.farKnee, 4.4, 3, farSkin, in: context)
            Figure.limb(skeleton.farKnee, skeleton.farFoot, 2.9, 1.9, farSkin, in: context)
            Figure.foot(from: skeleton.farFoot, to: motion.toe(foot: skeleton.farFoot, knee: skeleton.farKnee), farSkin, in: context)
            Figure.limb(skeleton.shoulder, skeleton.elbow, 3, 2.4, farSkin, in: context, offset: CGVector(dx: -1.4, dy: 0.6))
            Figure.limb(skeleton.elbow, skeleton.hand, 2.4, 1.6, farSkin, in: context, offset: CGVector(dx: -1.4, dy: 0.6))

            Figure.limb(skeleton.hip, skeleton.shoulder, 5.4, 6.2, skin, in: context)
            Figure.neck(skeleton, skin, in: context)
            Figure.limb(skeleton.hip, skeleton.knee, 4.7, 3.2, skin, in: context)
            Figure.limb(skeleton.knee, skeleton.foot, 3.1, 2, skin, in: context)
            Figure.foot(from: skeleton.foot, to: motion.toe(foot: skeleton.foot, knee: skeleton.knee), skin, in: context)

            // Secondary muscles first, so the main one sits on top.
            let effort = 0.72 + 0.28 * progress
            for muscle in exercise.secondary {
                Figure.muscle(muscle, skeleton, flipped: motion.isFlipped, Theme.brand.opacity(0.45), in: context)
            }
            Figure.muscle(exercise.muscle, skeleton, flipped: motion.isFlipped, Theme.brand.opacity(effort), in: context)

            // A thin gap around the arm, so it stays separate even over a highlighted muscle.
            var gap = context
            gap.blendMode = .destinationOut
            Figure.limb(skeleton.shoulder, skeleton.elbow, 3.9, 3.2, .black, in: gap)
            Figure.limb(skeleton.elbow, skeleton.hand, 3.2, 2.4, .black, in: gap)
            Figure.limb(skeleton.shoulder, skeleton.elbow, 3.2, 2.5, arm, in: context)
            Figure.limb(skeleton.elbow, skeleton.hand, 2.5, 1.7, arm, in: context)
            // The arm covers its own muscles, so those go back on over it.
            for region in exercise.muscle.regions where region.bone == .upperArm {
                Figure.draw(region, skeleton, flipped: motion.isFlipped, Theme.brand.opacity(effort), in: context)
            }

            let radius = Skeleton.headRadius
            context.fill(Path(ellipseIn: CGRect(x: skeleton.head.x - radius, y: skeleton.head.y - radius, width: radius * 2, height: radius * 2)), with: .color(skin))

            for prop in motion.props { drawInFront(prop, skeleton, gear, plate, in: context) }
        }
    }

    private func dot(_ point: CGPoint, radius: CGFloat, _ color: Color, in context: GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private func drawBehind(_ prop: MotionProp, _ skeleton: Skeleton, _ gear: Color, in context: GraphicsContext) {
        switch prop {
        case let .pad(from, to):
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path, with: .color(gear), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case let .cable(from):
            var path = Path()
            path.move(to: from)
            path.addLine(to: skeleton.hand)
            context.stroke(path, with: .color(gear), style: StrokeStyle(lineWidth: 1))
            dot(from, radius: 2, gear, in: context)
        case let .fixedBar(at):
            dot(at, radius: 2.4, gear, in: context)
        default:
            break
        }
    }

    private func drawInFront(_ prop: MotionProp, _ skeleton: Skeleton, _ gear: Color, _ plate: Color, in context: GraphicsContext) {
        switch prop {
        case .barAtHands:
            dot(skeleton.hand, radius: 7.5, plate, in: context)
            dot(skeleton.hand, radius: 1.6, gear, in: context)
        case .barOnShoulders:
            dot(skeleton.shoulder, radius: 7.5, plate, in: context)
            dot(skeleton.shoulder, radius: 1.6, gear, in: context)
        case .dumbbellAtHands:
            context.fill(Path(roundedRect: CGRect(x: skeleton.hand.x - 5, y: skeleton.hand.y - 2.6, width: 10, height: 5.2), cornerRadius: 1.6), with: .color(plate))
        case .handleAtHands:
            dot(skeleton.hand, radius: 2.4, plate, in: context)
        case .sledAtFeet:
            var path = Path()
            path.move(to: CGPoint(x: skeleton.foot.x + 3, y: skeleton.foot.y - 10))
            path.addLine(to: CGPoint(x: skeleton.foot.x + 3, y: skeleton.foot.y + 10))
            context.stroke(path, with: .color(plate), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case .rollerAtFeet:
            dot(skeleton.foot, radius: 3.2, plate, in: context)
        default:
            break
        }
    }
}

/// The body's shapes.
private enum Figure {
    /// A tapered limb: two circles and the skin between them.
    static func limb(_ start: CGPoint, _ end: CGPoint, _ startRadius: CGFloat, _ endRadius: CGFloat, _ color: Color, in context: GraphicsContext, offset: CGVector = .zero) {
        let from = CGPoint(x: start.x + offset.dx, y: start.y + offset.dy)
        let to = CGPoint(x: end.x + offset.dx, y: end.y + offset.dy)
        let angle = atan2(to.y - from.y, to.x - from.x) + .pi / 2
        let normal = CGVector(dx: cos(angle), dy: sin(angle))
        var path = Path()
        path.move(to: CGPoint(x: from.x + normal.dx * startRadius, y: from.y + normal.dy * startRadius))
        path.addLine(to: CGPoint(x: to.x + normal.dx * endRadius, y: to.y + normal.dy * endRadius))
        path.addLine(to: CGPoint(x: to.x - normal.dx * endRadius, y: to.y - normal.dy * endRadius))
        path.addLine(to: CGPoint(x: from.x - normal.dx * startRadius, y: from.y - normal.dy * startRadius))
        path.closeSubpath()
        context.fill(path, with: .color(color))
        // Filled apart from the body: in one path, overlapping shapes can cancel out and leave holes at the joints.
        context.fill(Path(ellipseIn: CGRect(x: from.x - startRadius, y: from.y - startRadius, width: startRadius * 2, height: startRadius * 2)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: to.x - endRadius, y: to.y - endRadius, width: endRadius * 2, height: endRadius * 2)), with: .color(color))
    }

    static func neck(_ skeleton: Skeleton, _ color: Color, in context: GraphicsContext) {
        limb(skeleton.shoulder, skeleton.head, 2.2, 2.2, color, in: context)
    }

    static func foot(from heel: CGPoint, to toe: CGPoint, _ color: Color, in context: GraphicsContext) {
        limb(heel, toe, 2, 1.3, color, in: context)
    }

    static func muscle(_ muscle: Muscle, _ skeleton: Skeleton, flipped: Bool, _ color: Color, in context: GraphicsContext) {
        for region in muscle.regions where region.bone != .upperArm {
            draw(region, skeleton, flipped: flipped, color, in: context)
        }
    }

    /// A lens along the bone, swelling out on the muscle's side.
    static func draw(_ region: MuscleRegion, _ skeleton: Skeleton, flipped: Bool, _ color: Color, in context: GraphicsContext) {
        let (start, end): (CGPoint, CGPoint) = switch region.bone {
        case .torso: (skeleton.hip, skeleton.shoulder)
        case .upperArm: (skeleton.shoulder, skeleton.elbow)
        case .thigh: (skeleton.hip, skeleton.knee)
        case .shin: (skeleton.knee, skeleton.foot)
        }
        let delta = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let length = max(hypot(delta.dx, delta.dy), 0.001)
        // Facing right and standing, a limb hangs down and the torso points up, so their fronts turn opposite ways.
        var front = region.bone == .torso ? CGVector(dx: -delta.dy / length, dy: delta.dx / length) : CGVector(dx: delta.dy / length, dy: -delta.dx / length)
        if flipped { front = CGVector(dx: -front.dx, dy: -front.dy) }
        let sign: CGFloat = region.side == .front ? 1 : -1
        let normal = CGVector(dx: front.dx * sign, dy: front.dy * sign)

        let from = CGPoint(x: start.x + delta.dx * region.from, y: start.y + delta.dy * region.from)
        let to = CGPoint(x: start.x + delta.dx * region.to, y: start.y + delta.dy * region.to)
        let reach = CGVector(dx: (to.x - from.x) * 0.2, dy: (to.y - from.y) * 0.2)
        // The outer edge pushes just past the skin, and the inner edge crosses the bone, so it reads as a full muscle.
        let outer = region.depth * 1.15
        let inner = region.depth * -0.3
        var path = Path()
        path.move(to: from)
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + reach.dx + normal.dx * outer, y: from.y + reach.dy + normal.dy * outer),
            control2: CGPoint(x: to.x - reach.dx + normal.dx * outer, y: to.y - reach.dy + normal.dy * outer)
        )
        path.addCurve(
            to: from,
            control1: CGPoint(x: to.x - reach.dx + normal.dx * inner, y: to.y - reach.dy + normal.dy * inner),
            control2: CGPoint(x: from.x + reach.dx + normal.dx * inner, y: from.y + reach.dy + normal.dy * inner)
        )
        context.fill(path, with: .color(color))
    }
}
