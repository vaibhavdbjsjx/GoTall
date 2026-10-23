import Foundation

/// Short, sourced reads about growth, sleep, food and posture. Each one is a few paragraphs, says what's known
/// and what isn't, and links to the public-health source it's based on. All pass `CopyGuard`.
public struct Article: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var minutes: Int
    public var symbol: String
    public var paragraphs: [String]
    public var sourceName: String
    public var sourceURL: URL?
    public var isFree: Bool

    public init(id: String, title: String, summary: String, minutes: Int, symbol: String, paragraphs: [String], sourceName: String,
                sourceURL: String, isFree: Bool = false) {
        self.id = id
        self.title = title
        self.summary = summary
        self.minutes = minutes
        self.symbol = symbol
        self.paragraphs = paragraphs
        self.sourceName = sourceName
        self.sourceURL = URL(string: sourceURL)
        self.isFree = isFree
    }
}

public enum ArticleLibrary {
    public static let all: [Article] = [
        Article(id: "what-decides-height", title: "What decides how tall you'll be", summary: "Genes set the range. Health and habits help you reach it.",
                minutes: 3, symbol: "person.2", paragraphs: [
                    "Most of the difference in adult height between people comes from genes. That's why parents' heights are the single best clue to a child's likely adult height.",
                    "Genes set a range, not a fixed number. Within that range, good nutrition, enough sleep, regular activity and overall health help a body reach its potential. Long-term illness or poor nutrition can hold growth back.",
                    "No exercise, food, supplement or stretch has been shown to add height beyond that range in healthy children. Be wary of any product that promises it."
                ], sourceName: "NHS: Height and growth in children", sourceURL: "https://www.nhs.uk/conditions/growth-problems/", isFree: true),
        Article(id: "growth-plates", title: "Growth plates, explained", summary: "Why growth slows down and eventually stops.",
                minutes: 3, symbol: "figure.walk", paragraphs: [
                    "Bones get longer at growth plates: areas of cartilage near the ends of long bones like the thigh and shin.",
                    "During puberty, hormones first speed growth up and then cause the growth plates to harden into bone. Once they've closed, bones can't get any longer.",
                    "Growth plates usually close around 14–15 for girls and 16–17 for boys, though it varies a lot. An X-ray of the hand (a bone-age test) is how doctors check how much growth may be left."
                ], sourceName: "OrthoInfo (American Academy of Orthopaedic Surgeons)", sourceURL: "https://orthoinfo.aaos.org/en/diseases--conditions/growth-plate-fractures/", isFree: true),
        Article(id: "measure-right", title: "How to measure height accurately at home", summary: "Small mistakes add up. Here's how to avoid them.",
                minutes: 2, symbol: "ruler", paragraphs: [
                    "Measure in the morning: everyone is slightly shorter by evening as the discs in the spine compress during the day.",
                    "Stand barefoot on a hard floor with heels, bottom and shoulders against a wall, looking straight ahead. Lay a hardback book flat on the head, mark the wall under it and measure from the floor.",
                    "Measure two or three times and use the average. Measuring every three months is often enough to see a trend; more often mostly shows measuring noise."
                ], sourceName: "CDC: Measuring children's height and weight accurately at home", sourceURL: "https://www.cdc.gov/healthyweight/assessing/bmi/childrens_bmi/measuring_children.html", isFree: true),
        Article(id: "sleep", title: "Why sleep matters for growing bodies", summary: "How much sleep you actually need at each age.",
                minutes: 3, symbol: "moon.stars", paragraphs: [
                    "Growth hormone is released in pulses, and the biggest ones come during deep sleep. Sleep also supports mood, learning, recovery and a healthy weight.",
                    "The American Academy of Sleep Medicine recommends 9–12 hours a night for ages 6–12 and 8–10 hours for teenagers 13–18.",
                    "Most teens get less. A regular bedtime, a dark, cool room and putting screens away 30 minutes before bed are the changes most likely to help."
                ], sourceName: "American Academy of Sleep Medicine", sourceURL: "https://aasm.org/resources/pdf/pediatricsleepdurationconsensus.pdf"),
        Article(id: "food", title: "Eating for healthy growth", summary: "Variety beats supplements.",
                minutes: 3, symbol: "fork.knife", paragraphs: [
                    "Growing bodies need enough energy overall, plus protein, calcium, vitamin D, iron and zinc. A varied diet with protein foods, dairy or fortified alternatives, fruit, vegetables and whole grains usually covers it.",
                    "Calcium and vitamin D build strong bones. Good sources are milk, yoghurt, cheese, fortified plant milks, tinned fish with bones and leafy greens. Vitamin D also comes from sunlight.",
                    "Supplements are only useful when there's a real deficiency. Talk to a doctor before giving them, and skip anything marketed to make you taller."
                ], sourceName: "HealthyChildren.org (American Academy of Pediatrics)", sourceURL: "https://www.healthychildren.org/English/healthy-living/nutrition/Pages/default.aspx"),
        Article(id: "posture", title: "Posture: why you measure shorter when you slouch", summary: "Standing tall changes how tall you measure, not your bones.",
                minutes: 2, symbol: "figure.stand", paragraphs: [
                    "Slouching, rounded shoulders and a forward head all lower how tall you stand. Correcting them can add to your measured height, sometimes by a centimetre or more.",
                    "That's not new growth: it's showing the height you already have. It also tends to reduce neck and back aches from long hours at desks and phones.",
                    "Strong core and upper-back muscles make good posture easier to hold. Short daily routines work better than one long session a week."
                ], sourceName: "NHS: Common posture mistakes and fixes", sourceURL: "https://www.nhs.uk/live-well/exercise/strength-and-flexibility-exercises/common-posture-mistakes-and-fixes/"),
        Article(id: "activity", title: "How much activity kids and teens need", summary: "An hour a day, most of it moderate to vigorous.",
                minutes: 2, symbol: "figure.run", paragraphs: [
                    "Children and teens aged 6–17 should get 60 minutes or more of physical activity each day.",
                    "Most of it should be moderate or vigorous, like brisk walking, cycling or sport. On at least three days a week, include bone-strengthening activity such as running or jumping, and muscle-strengthening activity like climbing or push-ups.",
                    "Weight training supervised by a qualified adult is safe for teens and doesn't stunt growth."
                ], sourceName: "CDC: Physical activity guidelines for children", sourceURL: "https://www.cdc.gov/physical-activity-basics/guidelines/children.html"),
        Article(id: "percentiles", title: "What percentiles really mean", summary: "The 50th percentile isn't a target.",
                minutes: 2, symbol: "chart.xyaxis.line", paragraphs: [
                    "A percentile compares a height with others of the same age and sex. The 25th percentile means taller than about 25 out of 100.",
                    "Any percentile between the 3rd and 97th is within the typical range. What matters more is following roughly the same line over time.",
                    "Doctors look more closely if a child is outside that range or crosses two or more major percentile lines over a year or more."
                ], sourceName: "CDC: Growth charts", sourceURL: "https://www.cdc.gov/growthcharts/"),
        Article(id: "spurts", title: "Growth spurts and puberty", summary: "When the fastest growth usually happens.",
                minutes: 3, symbol: "arrow.up.right", paragraphs: [
                    "Before puberty children usually grow about 5–6 cm a year. During the puberty growth spurt that can double for a year or two.",
                    "Girls usually start puberty between 8 and 13 and have their fastest growth early in puberty, often before periods start. Boys usually start between 9 and 14 and peak a little later.",
                    "Starting earlier or later than friends is normal and doesn't usually change final height much: late starters often keep growing for longer."
                ], sourceName: "NHS: Stages of puberty", sourceURL: "https://www.nhs.uk/conditions/early-or-delayed-puberty/"),
        Article(id: "myths", title: "Height myths, checked", summary: "Stretching, hanging, pills and more.",
                minutes: 3, symbol: "questionmark.circle", paragraphs: [
                    "Hanging and stretching: they can improve flexibility and posture, which can help you stand taller, but they don't lengthen bones.",
                    "Supplements and \"height pills\": there's no good evidence that any over-the-counter product increases height in healthy children, and some contain hormones that can be harmful.",
                    "Coffee and lifting weights: neither has been shown to stunt growth. Too little sleep, poor nutrition and long-term illness can affect growth."
                ], sourceName: "HealthyChildren.org (American Academy of Pediatrics)", sourceURL: "https://www.healthychildren.org/English/health-issues/conditions/growth/Pages/default.aspx"),
        Article(id: "when-to-see-doctor", title: "When to talk to a doctor about growth", summary: "Signs worth a check-up.",
                minutes: 2, symbol: "stethoscope", paragraphs: [
                    "Talk to a doctor if height is below the 3rd or above the 97th percentile, if growth seems to have slowed or stopped for six months or more while still young, or if height crosses two major percentile lines.",
                    "Also check in if puberty starts before 8 in girls or 9 in boys, or hasn't started by 13 in girls or 14 in boys.",
                    "Bring your measurements: a record over time is the most useful thing a doctor can have. Gromax's growth report is made for exactly that."
                ], sourceName: "NHS: Growth problems in children", sourceURL: "https://www.nhs.uk/conditions/growth-problems/", isFree: true)
    ]

    public static func article(id: String) -> Article? { all.first { $0.id == id } }
}
