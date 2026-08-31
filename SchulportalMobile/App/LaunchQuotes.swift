import Foundation

/// The launch screen's little trick: a sentence worth reading takes about as
/// long as the session check, so the wait stops feeling like one.
///
/// Curated by hand, not fetched: short, school-appropriate, and only quotes
/// with a solid attribution — a launch screen that misquotes Einstein daily
/// would teach exactly the wrong lesson.
struct LaunchQuote {
    let text: String
    let author: String

    static func random() -> LaunchQuote {
        all.randomElement() ?? all[0]
    }

    static let all: [LaunchQuote] = [
        .init(text: "Phantasie ist wichtiger als Wissen.",
              author: "Albert Einstein"),
        .init(text: "Ich habe keine besondere Begabung — ich bin nur leidenschaftlich neugierig.",
              author: "Albert Einstein"),
        .init(text: "Was wir wissen, ist ein Tropfen; was wir nicht wissen, ein Ozean.",
              author: "Isaac Newton"),
        .init(text: "Ich weiß, dass ich nichts weiß.",
              author: "Sokrates"),
        .init(text: "Der Anfang ist die Hälfte des Ganzen.",
              author: "Aristoteles"),
        .init(text: "Habe Mut, dich deines eigenen Verstandes zu bedienen.",
              author: "Immanuel Kant"),
        .init(text: "Es ist nicht genug zu wissen — man muss auch anwenden.",
              author: "Johann Wolfgang von Goethe"),
        .init(text: "Nicht für die Schule, sondern für das Leben lernen wir.",
              author: "nach Seneca"),
        .init(text: "Man merkt nie, was schon getan wurde — man sieht immer nur, was noch zu tun bleibt.",
              author: "Marie Curie"),
        .init(text: "Ich wurde gelehrt, dass der Weg des Fortschritts weder schnell noch leicht ist.",
              author: "Marie Curie"),
        .init(text: "Gebt mir einen festen Punkt, und ich hebe die Welt aus den Angeln.",
              author: "Archimedes"),
        .init(text: "Im Grunde sind es die Verbindungen mit Menschen, die dem Leben seinen Wert geben.",
              author: "Wilhelm von Humboldt"),
        .init(text: "Ein Mensch, der eine Stunde zu verschwenden wagt, hat den Wert des Lebens noch nicht erkannt.",
              author: "Charles Darwin"),
        .init(text: "Wie das Eisen ohne Gebrauch rostet, so verdirbt der Geist ohne Übung.",
              author: "Leonardo da Vinci")
    ]
}
