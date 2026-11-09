//
//  ExerciseCatalog.swift
//  k-cal
//
//  Every exercise the app knows, written for this app. Exercises in a family train the same thing, which is what
//  makes them alternatives for each other.
//

import Foundation

enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case abs = "Abs"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .shoulders: "figure.arms.open"
        case .biceps: "dumbbell"
        case .triceps: "figure.boxing"
        case .quads: "figure.step.training"
        case .hamstrings: "figure.flexibility"
        case .glutes: "figure.cross.training"
        case .calves: "figure.walk"
        case .abs: "figure.core.training"
        }
    }

    /// Where this muscle sits on the figure.
    var regions: [MuscleRegion] {
        switch self {
        case .chest: [MuscleRegion(bone: .torso, from: 0.6, to: 0.97, side: .front, depth: 6.4)]
        case .back: [MuscleRegion(bone: .torso, from: 0.42, to: 1, side: .back, depth: 6.4)]
        case .abs: [MuscleRegion(bone: .torso, from: 0.1, to: 0.6, side: .front, depth: 5.2)]
        case .shoulders: [MuscleRegion(bone: .upperArm, from: -0.06, to: 0.5, side: .front, depth: 4), MuscleRegion(bone: .upperArm, from: -0.06, to: 0.5, side: .back, depth: 4)]
        case .biceps: [MuscleRegion(bone: .upperArm, from: 0.14, to: 0.92, side: .front, depth: 4.2)]
        case .triceps: [MuscleRegion(bone: .upperArm, from: 0.12, to: 0.92, side: .back, depth: 4.2)]
        case .quads: [MuscleRegion(bone: .thigh, from: 0.08, to: 0.94, side: .front, depth: 5.6)]
        case .hamstrings: [MuscleRegion(bone: .thigh, from: 0.12, to: 0.96, side: .back, depth: 5.4)]
        case .glutes: [MuscleRegion(bone: .torso, from: -0.16, to: 0.2, side: .back, depth: 6.2)]
        case .calves: [MuscleRegion(bone: .shin, from: 0.04, to: 0.62, side: .back, depth: 4.6)]
        }
    }
}

/// A muscle's shape on the figure: a stretch of one bone, bulging out of its front or back.
struct MuscleRegion: Equatable {
    enum Bone {
        case torso
        case upperArm
        case thigh
        case shin
    }

    enum Side {
        case front
        case back
    }

    let bone: Bone
    let from: Double
    let to: Double
    let side: Side
    let depth: Double
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbells"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"

    var id: String { rawValue }

    /// The smallest jump in load this kit allows, in pounds.
    var increment: Double {
        switch self {
        case .barbell: 5
        case .dumbbell: 5
        case .cable, .machine: 5
        case .bodyweight: 0
        }
    }
}

enum ExerciseFamily: String, CaseIterable, Codable {
    case flatPress, inclinePress, chestFly
    case overheadPress, lateralRaise, rearDelt
    case verticalPull, row, straightArm, shrug
    case curl, tricepsExtension
    case squat, singleLeg, legExtension
    case hinge, legCurl, hipExtension, calf, core

    var title: String {
        switch self {
        case .flatPress: "Flat Press"
        case .inclinePress: "Incline Press"
        case .chestFly: "Chest Fly"
        case .overheadPress: "Overhead Press"
        case .lateralRaise: "Side Delts"
        case .rearDelt: "Rear Delts"
        case .verticalPull: "Vertical Pull"
        case .row: "Row"
        case .straightArm: "Lat Isolation"
        case .shrug: "Traps"
        case .curl: "Biceps"
        case .tricepsExtension: "Triceps"
        case .squat: "Squat Pattern"
        case .singleLeg: "Single Leg"
        case .legExtension: "Quad Isolation"
        case .hinge: "Hip Hinge"
        case .legCurl: "Hamstring Curl"
        case .hipExtension: "Glutes"
        case .calf: "Calves"
        case .core: "Core"
        }
    }
}

/// The barbell lifts everything else is scaled from.
enum AnchorLift: String, CaseIterable, Identifiable, Codable {
    case bench, squat, deadlift, press, row

    var id: String { rawValue }

    var exerciseID: String {
        switch self {
        case .bench: "bench-press"
        case .squat: "back-squat"
        case .deadlift: "deadlift"
        case .press: "overhead-press"
        case .row: "barbell-row"
        }
    }

    var title: String {
        switch self {
        case .bench: "Bench Press"
        case .squat: "Back Squat"
        case .deadlift: "Deadlift"
        case .press: "Overhead Press"
        case .row: "Barbell Row"
        }
    }

    /// A reasonable one-rep max for each experience level, as a multiple of bodyweight.
    func bodyweightRatio(for experience: LiftExperience) -> Double {
        switch (self, experience) {
        case (.bench, .beginner): 0.7
        case (.bench, .intermediate): 1.0
        case (.bench, .advanced): 1.35
        case (.squat, .beginner): 0.9
        case (.squat, .intermediate): 1.35
        case (.squat, .advanced): 1.8
        case (.deadlift, .beginner): 1.1
        case (.deadlift, .intermediate): 1.6
        case (.deadlift, .advanced): 2.1
        case (.press, .beginner): 0.45
        case (.press, .intermediate): 0.65
        case (.press, .advanced): 0.9
        case (.row, .beginner): 0.55
        case (.row, .intermediate): 0.85
        case (.row, .advanced): 1.1
        }
    }
}

struct Exercise: Identifiable, Equatable {
    let id: String
    let name: String
    let family: ExerciseFamily
    let muscle: Muscle
    let secondary: [Muscle]
    let equipment: Equipment
    let motion: ExerciseMotion
    /// The anchor lift this is scaled from and its one-rep max as a share of that lift's. Nil for bodyweight work.
    let anchor: AnchorLift?
    let ratio: Double
    let cues: [String]

    var isBodyweight: Bool {
        equipment == .bodyweight
    }
}

enum ExerciseCatalog {
    static let all: [Exercise] = [
        // Chest
        Exercise(id: "bench-press", name: "Barbell Bench Press", family: .flatPress, muscle: .chest, secondary: [.triceps, .shoulders], equipment: .barbell, motion: .benchPress, anchor: .bench, ratio: 1,
                 cues: ["Pin your shoulder blades back and down", "Lower to the lower chest with control", "Drive your feet into the floor and press up and back"]),
        Exercise(id: "db-bench-press", name: "Dumbbell Bench Press", family: .flatPress, muscle: .chest, secondary: [.triceps, .shoulders], equipment: .dumbbell, motion: .dumbbellPress, anchor: .bench, ratio: 0.8,
                 cues: ["Lower until you feel a deep chest stretch", "Keep your wrists stacked over your elbows", "Bring the dumbbells together at the top without clanging"]),
        Exercise(id: "machine-chest-press", name: "Machine Chest Press", family: .flatPress, muscle: .chest, secondary: [.triceps], equipment: .machine, motion: .machinePress, anchor: .bench, ratio: 0.95,
                 cues: ["Set the handles level with mid chest", "Keep your chest up and shoulders back on the pad", "Stop just short of locking out"]),
        Exercise(id: "push-up", name: "Push-Up", family: .flatPress, muscle: .chest, secondary: [.triceps, .abs], equipment: .bodyweight, motion: .pushUp, anchor: nil, ratio: 0,
                 cues: ["Keep a straight line from head to heels", "Lower until your chest nearly touches", "Tuck your elbows to about 45 degrees"]),
        Exercise(id: "incline-bench", name: "Incline Barbell Press", family: .inclinePress, muscle: .chest, secondary: [.shoulders, .triceps], equipment: .barbell, motion: .inclinePress, anchor: .bench, ratio: 0.8,
                 cues: ["Set the bench around 30 degrees", "Lower to the upper chest, just under your collarbone", "Keep your shoulder blades pinned"]),
        Exercise(id: "incline-db-press", name: "Incline Dumbbell Press", family: .inclinePress, muscle: .chest, secondary: [.shoulders, .triceps], equipment: .dumbbell, motion: .inclinePress, anchor: .bench, ratio: 0.7,
                 cues: ["Press up and slightly in", "Get a full stretch at the bottom", "Don't let your lower back arch off the pad"]),
        Exercise(id: "cable-fly", name: "Cable Fly", family: .chestFly, muscle: .chest, secondary: [], equipment: .cable, motion: .cableFly, anchor: .bench, ratio: 0.3,
                 cues: ["Keep a soft bend in the elbows throughout", "Hug your arms together in a wide arc", "Squeeze your chest for a beat at the end"]),
        Exercise(id: "db-fly", name: "Dumbbell Fly", family: .chestFly, muscle: .chest, secondary: [], equipment: .dumbbell, motion: .chestFly, anchor: .bench, ratio: 0.3,
                 cues: ["Lower until you feel a stretch, not a strain", "Keep your elbow angle fixed", "Lead with your elbows on the way up"]),
        Exercise(id: "pec-deck", name: "Pec Deck", family: .chestFly, muscle: .chest, secondary: [], equipment: .machine, motion: .cableFly, anchor: .bench, ratio: 0.45,
                 cues: ["Set the handles level with mid chest", "Bring your hands together, not just your elbows", "Control the stretch on the way back"]),

        // Shoulders
        Exercise(id: "overhead-press", name: "Barbell Overhead Press", family: .overheadPress, muscle: .shoulders, secondary: [.triceps], equipment: .barbell, motion: .overheadPress, anchor: .press, ratio: 1,
                 cues: ["Squeeze your glutes and brace hard", "Move your head back, then through once the bar passes", "Finish with the bar over your mid foot"]),
        Exercise(id: "seated-db-press", name: "Seated Dumbbell Press", family: .overheadPress, muscle: .shoulders, secondary: [.triceps], equipment: .dumbbell, motion: .seatedPress, anchor: .press, ratio: 0.8,
                 cues: ["Set the bench just short of upright", "Lower to ear level", "Press without shrugging your shoulders up"]),
        Exercise(id: "machine-shoulder-press", name: "Machine Shoulder Press", family: .overheadPress, muscle: .shoulders, secondary: [.triceps], equipment: .machine, motion: .seatedPress, anchor: .press, ratio: 0.95,
                 cues: ["Set the seat so the handles start at shoulder height", "Keep your back flat on the pad", "Stop just short of lockout"]),
        Exercise(id: "lateral-raise", name: "Dumbbell Lateral Raise", family: .lateralRaise, muscle: .shoulders, secondary: [], equipment: .dumbbell, motion: .lateralRaise, anchor: .press, ratio: 0.22,
                 cues: ["Raise out to the sides, leading with your elbows", "Stop at shoulder height", "Lower slowly: this is where most lifters cheat"]),
        Exercise(id: "cable-lateral-raise", name: "Cable Lateral Raise", family: .lateralRaise, muscle: .shoulders, secondary: [], equipment: .cable, motion: .cableLateralRaise, anchor: .press, ratio: 0.18,
                 cues: ["Stand side on with the cable low", "Keep tension at the bottom", "Lean away slightly for a longer range"]),
        Exercise(id: "machine-lateral-raise", name: "Machine Lateral Raise", family: .lateralRaise, muscle: .shoulders, secondary: [], equipment: .machine, motion: .lateralRaise, anchor: .press, ratio: 0.35,
                 cues: ["Line your shoulders up with the machine's pivot", "Drive with your elbows", "Pause briefly at the top"]),
        Exercise(id: "face-pull", name: "Face Pull", family: .rearDelt, muscle: .shoulders, secondary: [.back], equipment: .cable, motion: .facePull, anchor: .press, ratio: 0.4,
                 cues: ["Set the rope at upper chest height", "Pull toward your forehead with elbows high", "Rotate your hands back at the end"]),
        Exercise(id: "reverse-fly", name: "Reverse Dumbbell Fly", family: .rearDelt, muscle: .shoulders, secondary: [.back], equipment: .dumbbell, motion: .reverseFly, anchor: .press, ratio: 0.2,
                 cues: ["Hinge until your chest faces the floor", "Sweep your arms out, not back", "Keep the weight light and the reps clean"]),
        Exercise(id: "reverse-pec-deck", name: "Reverse Pec Deck", family: .rearDelt, muscle: .shoulders, secondary: [.back], equipment: .machine, motion: .reverseFly, anchor: .press, ratio: 0.4,
                 cues: ["Face the pad with your chest up", "Lead with your elbows", "Don't let your shoulders roll forward"]),

        // Back
        Exercise(id: "pull-up", name: "Pull-Up", family: .verticalPull, muscle: .back, secondary: [.biceps], equipment: .bodyweight, motion: .pullUp, anchor: nil, ratio: 0,
                 cues: ["Start from a dead hang", "Drive your elbows down to your ribs", "Get your chin over the bar without kipping"]),
        Exercise(id: "lat-pulldown", name: "Lat Pulldown", family: .verticalPull, muscle: .back, secondary: [.biceps], equipment: .cable, motion: .latPulldown, anchor: .row, ratio: 0.95,
                 cues: ["Lock your thighs under the pad", "Lean back a touch and pull to your upper chest", "Let your lats stretch fully at the top"]),
        Exercise(id: "neutral-pulldown", name: "Neutral-Grip Pulldown", family: .verticalPull, muscle: .back, secondary: [.biceps], equipment: .cable, motion: .latPulldown, anchor: .row, ratio: 0.95,
                 cues: ["Use the close parallel handle", "Think of pulling your elbows into your back pockets", "Pause with the handle at your chest"]),
        Exercise(id: "barbell-row", name: "Barbell Row", family: .row, muscle: .back, secondary: [.biceps], equipment: .barbell, motion: .barbellRow, anchor: .row, ratio: 1,
                 cues: ["Hinge until your torso is near 30 degrees", "Pull the bar to your lower ribs", "Don't let your torso rise to finish the rep"]),
        Exercise(id: "db-row", name: "One-Arm Dumbbell Row", family: .row, muscle: .back, secondary: [.biceps], equipment: .dumbbell, motion: .dumbbellRow, anchor: .row, ratio: 0.45,
                 cues: ["Brace one hand on the bench", "Pull your elbow to your hip", "Stretch the lat fully at the bottom"]),
        Exercise(id: "cable-row", name: "Seated Cable Row", family: .row, muscle: .back, secondary: [.biceps], equipment: .cable, motion: .cableRow, anchor: .row, ratio: 0.9,
                 cues: ["Sit tall with a slight bend in your knees", "Pull to your stomach and squeeze your shoulder blades", "Reach forward for the stretch without rounding"]),
        Exercise(id: "chest-supported-row", name: "Chest-Supported Row", family: .row, muscle: .back, secondary: [.biceps], equipment: .machine, motion: .dumbbellRow, anchor: .row, ratio: 0.9,
                 cues: ["Keep your chest on the pad", "Pull your elbows past your ribs", "Let the pad remove all the swing"]),
        Exercise(id: "straight-arm-pulldown", name: "Straight-Arm Pulldown", family: .straightArm, muscle: .back, secondary: [], equipment: .cable, motion: .straightArmPulldown, anchor: .row, ratio: 0.4,
                 cues: ["Hinge forward with a long spine", "Sweep the bar down in an arc to your thighs", "Keep a slight, fixed bend in your elbows"]),
        Exercise(id: "db-pullover", name: "Dumbbell Pullover", family: .straightArm, muscle: .back, secondary: [.chest], equipment: .dumbbell, motion: .straightArmPulldown, anchor: .row, ratio: 0.35,
                 cues: ["Lie across a bench holding one dumbbell", "Lower it behind your head until your lats stretch", "Pull back over your chest with your arms nearly straight"]),
        Exercise(id: "barbell-shrug", name: "Barbell Shrug", family: .shrug, muscle: .back, secondary: [], equipment: .barbell, motion: .shrug, anchor: .deadlift, ratio: 0.6,
                 cues: ["Hold the bar at your thighs", "Lift straight up, with no rolling", "Pause at the top of every rep"]),
        Exercise(id: "db-shrug", name: "Dumbbell Shrug", family: .shrug, muscle: .back, secondary: [], equipment: .dumbbell, motion: .shrug, anchor: .deadlift, ratio: 0.3,
                 cues: ["Lift straight up toward your ears", "Hold the top for a full second", "Don't roll your shoulders"]),

        // Biceps
        Exercise(id: "barbell-curl", name: "Barbell Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .barbell, motion: .curl, anchor: .press, ratio: 0.65,
                 cues: ["Pin your elbows at your sides", "Curl without leaning back", "Lower for a slow two count"]),
        Exercise(id: "db-curl", name: "Dumbbell Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .dumbbell, motion: .dumbbellCurl, anchor: .press, ratio: 0.3,
                 cues: ["Turn your palms up as you lift", "Squeeze at the top", "Fully straighten your arm at the bottom"]),
        Exercise(id: "hammer-curl", name: "Hammer Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .dumbbell, motion: .dumbbellCurl, anchor: .press, ratio: 0.33,
                 cues: ["Keep your palms facing each other", "Curl toward the same shoulder", "Don't swing your elbows forward"]),
        Exercise(id: "incline-curl", name: "Incline Dumbbell Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .dumbbell, motion: .inclineCurl, anchor: .press, ratio: 0.25,
                 cues: ["Let your arms hang behind your body", "Curl without letting your elbows drift forward", "Feel the long stretch at the bottom"]),
        Exercise(id: "preacher-curl", name: "Preacher Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .barbell, motion: .preacherCurl, anchor: .press, ratio: 0.55,
                 cues: ["Press your upper arms into the pad", "Stop just short of a full lockout", "Lower slowly under control"]),
        Exercise(id: "cable-curl", name: "Cable Curl", family: .curl, muscle: .biceps, secondary: [], equipment: .cable, motion: .cableCurl, anchor: .press, ratio: 0.55,
                 cues: ["Step back to keep tension at the bottom", "Keep your elbows still", "Squeeze hard at the top"]),

        // Triceps
        Exercise(id: "rope-pushdown", name: "Rope Pushdown", family: .tricepsExtension, muscle: .triceps, secondary: [], equipment: .cable, motion: .pushdown, anchor: .bench, ratio: 0.4,
                 cues: ["Pin your elbows to your sides", "Spread the rope at the bottom", "Let your forearms rise to chest height"]),
        Exercise(id: "skull-crusher", name: "Skull Crusher", family: .tricepsExtension, muscle: .triceps, secondary: [], equipment: .barbell, motion: .skullCrusher, anchor: .bench, ratio: 0.4,
                 cues: ["Keep your upper arms still", "Lower to just behind your forehead", "Use an EZ bar if your wrists complain"]),
        Exercise(id: "overhead-extension", name: "Overhead Dumbbell Extension", family: .tricepsExtension, muscle: .triceps, secondary: [], equipment: .dumbbell, motion: .overheadExtension, anchor: .bench, ratio: 0.3,
                 cues: ["Keep your elbows pointing forward", "Lower for a deep triceps stretch", "Press straight up without flaring"]),
        Exercise(id: "dip", name: "Dip", family: .tricepsExtension, muscle: .triceps, secondary: [.chest], equipment: .bodyweight, motion: .dip, anchor: nil, ratio: 0,
                 cues: ["Keep your torso upright for triceps", "Lower until your upper arm is parallel to the floor", "Press to a full lockout"]),
        Exercise(id: "close-grip-bench", name: "Close-Grip Bench Press", family: .tricepsExtension, muscle: .triceps, secondary: [.chest], equipment: .barbell, motion: .benchPress, anchor: .bench, ratio: 0.85,
                 cues: ["Grip just inside shoulder width", "Tuck your elbows close", "Touch the lower chest and press"]),

        // Quads
        Exercise(id: "back-squat", name: "Barbell Back Squat", family: .squat, muscle: .quads, secondary: [.glutes, .hamstrings], equipment: .barbell, motion: .squat, anchor: .squat, ratio: 1,
                 cues: ["Brace before you unrack and before each rep", "Sit between your hips with knees tracking your toes", "Drive the floor away and keep your chest up"]),
        Exercise(id: "front-squat", name: "Front Squat", family: .squat, muscle: .quads, secondary: [.glutes], equipment: .barbell, motion: .frontSquat, anchor: .squat, ratio: 0.8,
                 cues: ["Keep your elbows high", "Stay as upright as you can", "Drop straight down between your feet"]),
        Exercise(id: "hack-squat", name: "Hack Squat", family: .squat, muscle: .quads, secondary: [.glutes], equipment: .machine, motion: .hackSquat, anchor: .squat, ratio: 1.1,
                 cues: ["Set your feet shoulder width on the plate", "Lower until your thighs pass parallel", "Keep your back flat on the pad"]),
        Exercise(id: "leg-press", name: "Leg Press", family: .squat, muscle: .quads, secondary: [.glutes], equipment: .machine, motion: .legPress, anchor: .squat, ratio: 1.8,
                 cues: ["Lower until your hips are about to tuck", "Press through your whole foot", "Don't lock your knees hard at the top"]),
        Exercise(id: "goblet-squat", name: "Goblet Squat", family: .squat, muscle: .quads, secondary: [.glutes], equipment: .dumbbell, motion: .gobletSquat, anchor: .squat, ratio: 0.45,
                 cues: ["Hold the dumbbell against your chest", "Let your elbows track inside your knees", "Stay tall through the whole rep"]),
        Exercise(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", family: .singleLeg, muscle: .quads, secondary: [.glutes], equipment: .dumbbell, motion: .lunge, anchor: .squat, ratio: 0.3,
                 cues: ["Rest your back foot on a bench", "Lower straight down over your front foot", "Push through your whole front foot"]),
        Exercise(id: "walking-lunge", name: "Walking Lunge", family: .singleLeg, muscle: .quads, secondary: [.glutes], equipment: .dumbbell, motion: .lunge, anchor: .squat, ratio: 0.3,
                 cues: ["Take a long, controlled stride", "Lightly touch your back knee down", "Drive up through your front heel"]),
        Exercise(id: "leg-extension", name: "Leg Extension", family: .legExtension, muscle: .quads, secondary: [], equipment: .machine, motion: .legExtension, anchor: .squat, ratio: 0.5,
                 cues: ["Line your knees up with the machine's pivot", "Pause with your quads squeezed at the top", "Lower slowly, don't drop it"]),
        Exercise(id: "single-leg-extension", name: "Single-Leg Extension", family: .legExtension, muscle: .quads, secondary: [], equipment: .machine, motion: .legExtension, anchor: .squat, ratio: 0.25,
                 cues: ["Work one leg at a time to even out both sides", "Lock the rep out and squeeze", "Lower for a slow count of three"]),

        // Hamstrings and glutes
        Exercise(id: "deadlift", name: "Barbell Deadlift", family: .hinge, muscle: .hamstrings, secondary: [.back, .glutes], equipment: .barbell, motion: .deadlift, anchor: .deadlift, ratio: 1,
                 cues: ["Start with the bar over your mid foot", "Pull the slack out and brace", "Push the floor away and keep the bar against you"]),
        Exercise(id: "romanian-deadlift", name: "Romanian Deadlift", family: .hinge, muscle: .hamstrings, secondary: [.glutes, .back], equipment: .barbell, motion: .romanianDeadlift, anchor: .deadlift, ratio: 0.65,
                 cues: ["Push your hips straight back", "Slide the bar down your thighs", "Stop when your hamstrings run out, not your back"]),
        Exercise(id: "db-romanian-deadlift", name: "Dumbbell Romanian Deadlift", family: .hinge, muscle: .hamstrings, secondary: [.glutes], equipment: .dumbbell, motion: .romanianDeadlift, anchor: .deadlift, ratio: 0.5,
                 cues: ["Keep a soft bend in your knees", "Keep the dumbbells close to your legs", "Stand tall by squeezing your glutes"]),
        Exercise(id: "good-morning", name: "Good Morning", family: .hinge, muscle: .hamstrings, secondary: [.back, .glutes], equipment: .barbell, motion: .goodMorning, anchor: .squat, ratio: 0.4,
                 cues: ["Start light: this one bites", "Push your hips back with a flat back", "Stop around parallel to the floor"]),
        Exercise(id: "lying-leg-curl", name: "Lying Leg Curl", family: .legCurl, muscle: .hamstrings, secondary: [], equipment: .machine, motion: .legCurl, anchor: .deadlift, ratio: 0.3,
                 cues: ["Keep your hips pressed into the pad", "Curl until your heels near your glutes", "Lower for a slow count of three"]),
        Exercise(id: "seated-leg-curl", name: "Seated Leg Curl", family: .legCurl, muscle: .hamstrings, secondary: [], equipment: .machine, motion: .legExtension, anchor: .deadlift, ratio: 0.33,
                 cues: ["Lean forward slightly to stretch the hamstrings", "Pull your heels under the seat", "Control the way back up"]),
        Exercise(id: "hip-thrust", name: "Barbell Hip Thrust", family: .hipExtension, muscle: .glutes, secondary: [.hamstrings], equipment: .barbell, motion: .hipThrust, anchor: .deadlift, ratio: 0.9,
                 cues: ["Rest your upper back on a bench", "Tuck your chin and ribs down", "Squeeze your glutes hard at the top"]),

        Exercise(id: "glute-bridge", name: "Glute Bridge", family: .hipExtension, muscle: .glutes, secondary: [.hamstrings], equipment: .bodyweight, motion: .hipThrust, anchor: nil, ratio: 0,
                 cues: ["Plant your feet close to your hips", "Press through your heels", "Hold the top and squeeze for a full second"]),
        Exercise(id: "cable-pull-through", name: "Cable Pull-Through", family: .hipExtension, muscle: .glutes, secondary: [.hamstrings], equipment: .cable, motion: .romanianDeadlift, anchor: .deadlift, ratio: 0.35,
                 cues: ["Face away from a low cable with the rope between your legs", "Hinge back until you feel your hamstrings stretch", "Drive your hips through and squeeze your glutes"]),

        // Calves and core
        Exercise(id: "standing-calf-raise", name: "Standing Calf Raise", family: .calf, muscle: .calves, secondary: [], equipment: .machine, motion: .calfRaise, anchor: .squat, ratio: 0.9,
                 cues: ["Pause at the bottom to kill the bounce", "Rise as high as you can", "Hold the top for a beat"]),
        Exercise(id: "seated-calf-raise", name: "Seated Calf Raise", family: .calf, muscle: .calves, secondary: [], equipment: .machine, motion: .seatedCalfRaise, anchor: .squat, ratio: 0.5,
                 cues: ["Set the pad just above your knees", "Stretch fully at the bottom", "Use a slow, even tempo"]),
        Exercise(id: "cable-crunch", name: "Cable Crunch", family: .core, muscle: .abs, secondary: [], equipment: .cable, motion: .cableCrunch, anchor: .row, ratio: 0.5,
                 cues: ["Curl your ribs toward your hips", "Keep your hips still", "Exhale hard at the bottom"]),
        Exercise(id: "hanging-leg-raise", name: "Hanging Leg Raise", family: .core, muscle: .abs, secondary: [], equipment: .bodyweight, motion: .hangingLegRaise, anchor: nil, ratio: 0,
                 cues: ["Start from a still hang", "Curl your pelvis up, not just your legs", "Lower without swinging"]),
        Exercise(id: "crunch", name: "Crunch", family: .core, muscle: .abs, secondary: [], equipment: .bodyweight, motion: .crunch, anchor: nil, ratio: 0,
                 cues: ["Curl your shoulders off the floor", "Keep your lower back down", "Pause and squeeze at the top"]),
        Exercise(id: "plank", name: "Plank", family: .core, muscle: .abs, secondary: [], equipment: .bodyweight, motion: .plank, anchor: nil, ratio: 0,
                 cues: ["Stack your shoulders over your elbows", "Squeeze your glutes and abs", "Keep a straight line and breathe"]),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func exercise(_ id: String) -> Exercise? {
        byID[id]
    }

    static func alternatives(to exercise: Exercise) -> [Exercise] {
        all.filter { $0.family == exercise.family && $0.id != exercise.id }
    }
}
