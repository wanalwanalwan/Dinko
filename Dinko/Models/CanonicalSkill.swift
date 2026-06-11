import Foundation

/// Static definition of a canonical skill tracked by Brine.
/// These are the ~22 skills every user has; user-created skills are separate.
struct CanonicalSkill: Identifiable, Hashable {
    let id: String // e.g. "third_shot_drop"
    let name: String
    let pillar: SkillPillar
    let description: String
    let whyItMatters: String
    let iconName: String
    let displayOrder: Int

    /// All canonical skills in display order.
    static let all: [CanonicalSkill] = [
        // Consistency
        CanonicalSkill(
            id: "serve_consistency", name: "Serve Consistency", pillar: .consistency,
            description: "Landing deep, consistent serves reliably",
            whyItMatters: "A consistent serve keeps you out of trouble and sets up your third shot.",
            iconName: "arrow.up.forward", displayOrder: 0
        ),
        CanonicalSkill(
            id: "return_consistency", name: "Return Consistency", pillar: .consistency,
            description: "Returning serves deep and in play consistently",
            whyItMatters: "A deep return neutralizes the serving team's third shot advantage.",
            iconName: "arrow.turn.down.right", displayOrder: 1
        ),
        CanonicalSkill(
            id: "dink_rallies", name: "Dink Rallies", pillar: .consistency,
            description: "Sustaining patient dink exchanges at the kitchen line",
            whyItMatters: "Winning the dink rally is the foundation of competitive pickleball.",
            iconName: "hand.raised.fill", displayOrder: 2
        ),
        CanonicalSkill(
            id: "volley_consistency", name: "Volley Consistency", pillar: .consistency,
            description: "Keeping volleys controlled and in play",
            whyItMatters: "Consistent volleys prevent unforced errors during fast exchanges.",
            iconName: "tennis.racket", displayOrder: 3
        ),

        // Transition
        CanonicalSkill(
            id: "third_shot_drop", name: "3rd Shot Drop", pillar: .transition,
            description: "Executing a soft drop shot on the third shot to approach the net",
            whyItMatters: "The third shot drop is your key to getting from baseline to kitchen safely.",
            iconName: "arrow.down.to.line", displayOrder: 4
        ),
        CanonicalSkill(
            id: "resets", name: "Resets", pillar: .transition,
            description: "Absorbing pace and resetting the ball low over the net",
            whyItMatters: "Resets neutralize attacks and give you time to recover court position.",
            iconName: "arrow.counterclockwise", displayOrder: 5
        ),
        CanonicalSkill(
            id: "approach_shots", name: "Approach Shots", pillar: .transition,
            description: "Transitioning from baseline to net with controlled shots",
            whyItMatters: "Good approach shots let you move up without giving away easy put-aways.",
            iconName: "arrow.up.right", displayOrder: 6
        ),
        CanonicalSkill(
            id: "shot_selection", name: "Shot Selection", pillar: .transition,
            description: "Choosing the right shot for each situation during transitions",
            whyItMatters: "Smart shot selection during transitions reduces errors and creates advantages.",
            iconName: "list.bullet", displayOrder: 7
        ),

        // Attack
        CanonicalSkill(
            id: "drives", name: "Drives", pillar: .attack,
            description: "Executing powerful groundstrokes to pressure opponents",
            whyItMatters: "Well-placed drives can force weak returns and create finishing opportunities.",
            iconName: "bolt.horizontal.fill", displayOrder: 8
        ),
        CanonicalSkill(
            id: "speed_ups", name: "Speed-Ups", pillar: .attack,
            description: "Accelerating the ball from a dink rally to catch opponents off guard",
            whyItMatters: "A well-timed speed-up can end points and keep opponents guessing.",
            iconName: "hare.fill", displayOrder: 9
        ),
        CanonicalSkill(
            id: "counters", name: "Counters", pillar: .attack,
            description: "Redirecting fast-paced attacks back with precision",
            whyItMatters: "Strong counters turn defense into offense instantly.",
            iconName: "arrow.uturn.right", displayOrder: 10
        ),
        CanonicalSkill(
            id: "roll_volleys", name: "Roll Volleys", pillar: .attack,
            description: "Hitting topspin volleys at the kitchen line for aggressive play",
            whyItMatters: "Roll volleys add an offensive weapon from the kitchen line.",
            iconName: "arrow.up.right.circle", displayOrder: 11
        ),
        CanonicalSkill(
            id: "atp", name: "ATP (Around the Post)", pillar: .attack,
            description: "Hitting the ball around the net post for a winner",
            whyItMatters: "ATPs are high-percentage winners that demoralize opponents.",
            iconName: "arrow.right.circle", displayOrder: 12
        ),
        CanonicalSkill(
            id: "erne", name: "Erne", pillar: .attack,
            description: "Jumping or running around the kitchen to volley for a winner",
            whyItMatters: "Ernes are surprise attacks that can end points decisively.",
            iconName: "figure.run.circle", displayOrder: 13
        ),

        // Movement
        CanonicalSkill(
            id: "split_step", name: "Split Step", pillar: .movement,
            description: "Performing a balanced ready hop before each shot",
            whyItMatters: "The split step is the foundation of quick reactions on court.",
            iconName: "figure.stand", displayOrder: 14
        ),
        CanonicalSkill(
            id: "court_positioning", name: "Court Positioning", pillar: .movement,
            description: "Being in the right spot on the court at the right time",
            whyItMatters: "Good positioning reduces the distance you need to move and opens up shot options.",
            iconName: "square.grid.2x2", displayOrder: 15
        ),
        CanonicalSkill(
            id: "recovery", name: "Recovery", pillar: .movement,
            description: "Getting back into position after hitting a shot",
            whyItMatters: "Fast recovery prevents opponents from exploiting open court.",
            iconName: "arrow.counterclockwise.circle", displayOrder: 16
        ),
        CanonicalSkill(
            id: "lateral_movement", name: "Lateral Movement", pillar: .movement,
            description: "Moving side-to-side efficiently to cover the court",
            whyItMatters: "Lateral movement lets you reach wide shots without losing balance.",
            iconName: "arrow.left.and.right", displayOrder: 17
        ),

        // Strategy
        CanonicalSkill(
            id: "target_selection", name: "Target Selection", pillar: .strategy,
            description: "Choosing where to place shots for maximum effectiveness",
            whyItMatters: "Smart targeting exploits weaknesses and creates openings.",
            iconName: "scope", displayOrder: 18
        ),
        CanonicalSkill(
            id: "pattern_play", name: "Pattern Play", pillar: .strategy,
            description: "Using sequences of shots to set up winners",
            whyItMatters: "Patterns let you control rallies and dictate the pace of play.",
            iconName: "chart.bar.doc.horizontal", displayOrder: 19
        ),
        CanonicalSkill(
            id: "stacking", name: "Stacking", pillar: .strategy,
            description: "Positioning with your partner to maximize strengths",
            whyItMatters: "Stacking keeps your best shots in play more often.",
            iconName: "rectangle.stack", displayOrder: 20
        ),
        CanonicalSkill(
            id: "point_construction", name: "Point Construction", pillar: .strategy,
            description: "Building points methodically from serve to finish",
            whyItMatters: "Constructed points win more consistently than hoping for winners.",
            iconName: "building.2", displayOrder: 21
        ),
    ]

    /// Look up a canonical skill by its ID.
    static func find(_ id: String) -> CanonicalSkill? {
        all.first { $0.id == id }
    }

    /// All canonical skills for a given pillar.
    static func skills(for pillar: SkillPillar) -> [CanonicalSkill] {
        all.filter { $0.pillar == pillar }
    }
}
