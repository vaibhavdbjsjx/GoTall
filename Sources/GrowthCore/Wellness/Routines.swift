import Foundation

/// One guided move: what to do, for how long, and what to feel. Wording is plain and never links a move to height
/// gain. Moves are standard posture, mobility and strength exercises from public physiotherapy guidance.
public struct RoutineMove: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var instruction: String
    /// What the person should notice, or a safety cue.
    public var cue: String
    public var seconds: Int
    /// Hold each side separately (the player splits the time and says "switch sides").
    public var perSide: Bool
    public var symbol: String

    public init(id: String, name: String, instruction: String, cue: String, seconds: Int, perSide: Bool = false, symbol: String) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.cue = cue
        self.seconds = seconds
        self.perSide = perSide
        self.symbol = symbol
    }
}

public enum RoutineFocus: String, Sendable, CaseIterable {
    case posture, mobility, core, morning, evening, desk

    public var title: String {
        switch self {
        case .posture: return "Posture"
        case .mobility: return "Mobility"
        case .core: return "Core strength"
        case .morning: return "Morning"
        case .evening: return "Wind-down"
        case .desk: return "Desk break"
        }
    }
}

public struct Routine: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var focus: RoutineFocus
    public var moves: [RoutineMove]
    /// Free routines are available to everyone; the rest are part of Stature Pro.
    public var isFree: Bool
    /// Rest between moves, in seconds.
    public var restSeconds: Int

    public init(id: String, title: String, subtitle: String, focus: RoutineFocus, moves: [RoutineMove], isFree: Bool = false, restSeconds: Int = 8) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.focus = focus
        self.moves = moves
        self.isFree = isFree
        self.restSeconds = restSeconds
    }

    public var totalSeconds: Int {
        moves.reduce(0) { $0 + $1.seconds } + max(0, moves.count - 1) * restSeconds
    }

    public var minutes: Int { max(1, Int((Double(totalSeconds) / 60).rounded())) }
}

/// The built-in library. Static data, so it works offline and needs no review cycle to read.
public enum RoutineLibrary {
    // MARK: Moves

    static let wallAngel = RoutineMove(id: "wall-angel", name: "Wall angels",
        instruction: "Stand with your back, head and bottom against a wall. Raise your arms into a W, then slowly slide them up into a Y and back down.",
        cue: "Keep your lower back gently against the wall. Move only as far as feels comfortable.", seconds: 45, symbol: "figure.arms.open")
    static let chinTuck = RoutineMove(id: "chin-tuck", name: "Chin tucks",
        instruction: "Sit or stand tall. Glide your chin straight back, as if making a double chin, hold for two seconds, then relax.",
        cue: "Your head moves backwards, not down. Eyes stay level.", seconds: 40, symbol: "person.crop.circle")
    static let doorwayStretch = RoutineMove(id: "doorway-stretch", name: "Doorway chest stretch",
        instruction: "Place your forearms on either side of a doorway at shoulder height. Step one foot through until you feel a stretch across your chest.",
        cue: "A gentle stretch, never pain. Breathe slowly.", seconds: 40, symbol: "door.left.hand.open")
    static let catCow = RoutineMove(id: "cat-cow", name: "Cat–cow",
        instruction: "On hands and knees, round your back up towards the ceiling, then let your belly drop and lift your chest. Move with your breath.",
        cue: "Slow and smooth. Breathe in as you lift your chest, out as you round.", seconds: 45, symbol: "figure.mind.and.body")
    static let childsPose = RoutineMove(id: "childs-pose", name: "Child's pose",
        instruction: "Kneel, sit back towards your heels and walk your hands forward until your forehead rests on the floor or a cushion.",
        cue: "Let your shoulders soften. Breathe into your back.", seconds: 45, symbol: "figure.cooldown")
    static let thoracicRotation = RoutineMove(id: "open-book", name: "Open book rotation",
        instruction: "Lie on your side with knees bent and arms straight in front. Lift the top arm and open it across to the other side, following it with your eyes.",
        cue: "Keep your knees together so the turn comes from your upper back.", seconds: 60, perSide: true, symbol: "figure.flexibility")
    static let hipFlexor = RoutineMove(id: "hip-flexor", name: "Kneeling hip flexor stretch",
        instruction: "Kneel on one knee with the other foot in front. Tuck your tailbone under and shift forward until you feel a stretch at the front of the back hip.",
        cue: "Stay tall through your chest. Use a cushion under the knee.", seconds: 60, perSide: true, symbol: "figure.strengthtraining.functional")
    static let hamstring = RoutineMove(id: "hamstring", name: "Hamstring stretch",
        instruction: "Lie on your back, loop a towel around one foot and gently raise the straight leg until you feel the back of the thigh.",
        cue: "Keep the other leg relaxed on the floor.", seconds: 60, perSide: true, symbol: "figure.flexibility")
    static let glueBridge = RoutineMove(id: "glute-bridge", name: "Glute bridge",
        instruction: "Lie on your back with knees bent. Squeeze your glutes and lift your hips until your body forms a straight line, then lower slowly.",
        cue: "Push through your heels. Don't arch your lower back.", seconds: 45, symbol: "figure.core.training")
    static let birdDog = RoutineMove(id: "bird-dog", name: "Bird dog",
        instruction: "On hands and knees, reach one arm forward and the opposite leg back. Hold for a breath, return, then switch.",
        cue: "Keep your hips level, as if balancing a cup on your back.", seconds: 50, symbol: "figure.core.training")
    static let deadBug = RoutineMove(id: "dead-bug", name: "Dead bug",
        instruction: "Lie on your back with arms up and knees over hips. Slowly lower the opposite arm and leg towards the floor, then switch.",
        cue: "Press your lower back gently into the floor the whole time.", seconds: 45, symbol: "figure.core.training")
    static let plank = RoutineMove(id: "plank", name: "Forearm plank",
        instruction: "Rest on your forearms and toes, body in one straight line from head to heels.",
        cue: "Drop to your knees whenever you need to. Quality beats time.", seconds: 30, symbol: "figure.core.training")
    static let sidePlank = RoutineMove(id: "side-plank", name: "Side plank",
        instruction: "Lie on your side, prop up on your forearm and lift your hips so your body forms a straight line.",
        cue: "Bend the bottom knee for an easier version.", seconds: 40, perSide: true, symbol: "figure.core.training")
    static let superman = RoutineMove(id: "prone-y", name: "Prone Y raise",
        instruction: "Lie face down with arms overhead in a Y, thumbs up. Lift your arms a few centimetres by squeezing your shoulder blades, then lower.",
        cue: "Keep your neck long and look at the floor.", seconds: 40, symbol: "figure.arms.open")
    static let shoulderRoll = RoutineMove(id: "shoulder-roll", name: "Shoulder rolls",
        instruction: "Lift your shoulders towards your ears, roll them back and down. Repeat slowly.",
        cue: "Big, slow circles. Let your arms hang loose.", seconds: 30, symbol: "figure.walk")
    static let neckSide = RoutineMove(id: "neck-side", name: "Side neck stretch",
        instruction: "Sit tall and let one ear drop towards the shoulder. Rest the hand on top of your head without pulling.",
        cue: "Keep the opposite shoulder relaxed and low.", seconds: 40, perSide: true, symbol: "person.crop.circle")
    static let seatedTwist = RoutineMove(id: "seated-twist", name: "Seated twist",
        instruction: "Sit tall, feet flat. Turn your chest to one side, holding the back of the chair, then switch.",
        cue: "Grow taller as you breathe in, turn a little further as you breathe out.", seconds: 40, perSide: true, symbol: "chair")
    static let standUpReach = RoutineMove(id: "overhead-reach", name: "Overhead reach",
        instruction: "Stand, interlace your fingers and reach up high, then lean gently to each side.",
        cue: "Long through both sides of the waist.", seconds: 30, symbol: "figure.stand")
    static let calfRaise = RoutineMove(id: "calf-raise", name: "Calf raises",
        instruction: "Stand near a wall for balance. Rise onto the balls of your feet, pause, and lower slowly.",
        cue: "Up for one, down for three.", seconds: 40, symbol: "figure.stand")
    static let hang = RoutineMove(id: "dead-hang", name: "Supported hang",
        instruction: "Hold a sturdy pull-up bar with feet still on the floor or a step, and let your shoulders and back lengthen.",
        cue: "Only on equipment made for it. Keep your feet supported and let go if your grip tires.", seconds: 30, symbol: "figure.climbing")
    static let squat = RoutineMove(id: "bodyweight-squat", name: "Bodyweight squat",
        instruction: "Feet shoulder-width apart, sit your hips back and down as if onto a chair, then stand up tall.",
        cue: "Knees follow your toes. Chest stays proud.", seconds: 45, symbol: "figure.strengthtraining.functional")
    static let jumpingJacks = RoutineMove(id: "jumping-jacks", name: "Easy jumping jacks",
        instruction: "Jump your feet out as your arms rise, then back in. Step side to side instead for a quieter version.",
        cue: "Land softly through the balls of your feet.", seconds: 40, symbol: "figure.mixed.cardio")
    static let breathing = RoutineMove(id: "box-breathing", name: "Box breathing",
        instruction: "Breathe in for four, hold for four, out for four, hold for four. Repeat.",
        cue: "Let your shoulders drop with every breath out.", seconds: 60, symbol: "wind")
    static let legsUpWall = RoutineMove(id: "legs-up-wall", name: "Legs up the wall",
        instruction: "Lie on your back with your bottom near a wall and rest your legs up against it.",
        cue: "Arms relaxed by your sides. Just breathe.", seconds: 90, symbol: "bed.double")
    static let figureFour = RoutineMove(id: "figure-four", name: "Figure-four stretch",
        instruction: "Lie on your back, cross one ankle over the opposite knee and gently draw both legs towards you.",
        cue: "Feel it in the outer hip of the crossed leg.", seconds: 60, perSide: true, symbol: "figure.flexibility")
    static let tallStand = RoutineMove(id: "tall-stand", name: "Stand-tall check",
        instruction: "Stand with feet hip-width apart. Imagine a string lifting the crown of your head. Soften your knees, level your hips, relax your shoulders.",
        cue: "This is the posture to measure in: it's how tall you really stand.", seconds: 30, symbol: "figure.stand")

    // MARK: Routines

    public static let all: [Routine] = [
        Routine(id: "posture-reset", title: "Posture reset", subtitle: "Undo a day of slouching in seven minutes.", focus: .posture,
                moves: [shoulderRoll, chinTuck, wallAngel, doorwayStretch, superman, tallStand], isFree: true),
        Routine(id: "morning-wake", title: "Morning wake-up", subtitle: "Loosen up and stand tall before the day starts.", focus: .morning,
                moves: [standUpReach, catCow, hipFlexor, squat, calfRaise, tallStand]),
        Routine(id: "spine-flow", title: "Spine mobility flow", subtitle: "Gentle movement for a stiff back.", focus: .mobility,
                moves: [catCow, thoracicRotation, childsPose, figureFour, hamstring]),
        Routine(id: "core-foundation", title: "Core foundation", subtitle: "The muscles that hold you upright.", focus: .core,
                moves: [deadBug, birdDog, glueBridge, plank, sidePlank]),
        Routine(id: "tech-neck", title: "Tech-neck relief", subtitle: "For phones, laptops and long study sessions.", focus: .desk,
                moves: [chinTuck, neckSide, shoulderRoll, doorwayStretch, superman]),
        Routine(id: "desk-break", title: "Two-minute desk break", subtitle: "Do it between classes or homework.", focus: .desk,
                moves: [shoulderRoll, seatedTwist, chinTuck, standUpReach], restSeconds: 5),
        Routine(id: "active-energy", title: "Active energy", subtitle: "Get your heart rate up, no equipment.", focus: .core,
                moves: [jumpingJacks, squat, glueBridge, calfRaise, plank, jumpingJacks]),
        Routine(id: "full-stretch", title: "Full-body stretch", subtitle: "Head-to-toe stretches for flexibility.", focus: .mobility,
                moves: [standUpReach, hang, hipFlexor, hamstring, figureFour, childsPose]),
        Routine(id: "wind-down", title: "Bedtime wind-down", subtitle: "Calm your body before sleep.", focus: .evening,
                moves: [breathing, childsPose, figureFour, legsUpWall, breathing], isFree: true, restSeconds: 5),
    ]

    public static func routine(id: String) -> Routine? { all.first { $0.id == id } }

    public static var moveCount: Int { Set(all.flatMap { $0.moves.map(\.id) }).count }

    /// Routines that address what a posture check found, most relevant first.
    public static func suggestions(for check: PostureCheckRecord) -> [Routine] {
        var ids: [String] = []
        if let forward = check.forwardHeadDegrees, forward > PostureScoring.forwardHeadComfortDegrees { ids += ["tech-neck", "posture-reset"] }
        if let shoulders = check.shoulderTiltDegrees, abs(shoulders) > PostureScoring.tiltComfortDegrees { ids += ["posture-reset", "spine-flow"] }
        if let hips = check.hipTiltDegrees, abs(hips) > PostureScoring.tiltComfortDegrees { ids += ["core-foundation", "full-stretch"] }
        if ids.isEmpty { ids = ["core-foundation", "posture-reset"] }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }.compactMap(routine(id:))
    }
}
