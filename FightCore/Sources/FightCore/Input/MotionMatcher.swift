/// Subsequence motion matching with tick-span leniency.
public enum MotionMatcher: Sendable {
    public static let specialLeniency = 11
    public static let superLeniency = 20

    private struct Candidate: Sendable {
        var pattern: MotionPattern
        var sequence: [UInt8]
        var priority: InputPriority
        var leniency: Int
    }

    private static let candidates: [Candidate] = [
        Candidate(
            pattern: .super236236,
            sequence: [2, 3, 6, 2, 3, 6],
            priority: .superMove,
            leniency: superLeniency
        ),
        Candidate(pattern: .dp623, sequence: [6, 2, 3], priority: .special, leniency: specialLeniency),
        Candidate(pattern: .dp623, sequence: [6, 3, 2, 3], priority: .special, leniency: specialLeniency),
        Candidate(pattern: .qcf236, sequence: [2, 3, 6], priority: .special, leniency: specialLeniency),
        Candidate(pattern: .qcb214, sequence: [2, 1, 4], priority: .special, leniency: specialLeniency),
    ]

    /// Returns the highest-priority motion whose pattern fits within its leniency window.
    public static func matchMotion(in buffer: InputRingBuffer) -> MotionPattern? {
        var best: (MotionPattern, InputPriority)?
        for c in candidates {
            guard spanMatches(pattern: c.sequence, maxSpan: c.leniency, buffer: buffer) else {
                continue
            }
            if let current = best {
                if c.priority > current.1 {
                    best = (c.pattern, c.priority)
                }
            } else {
                best = (c.pattern, c.priority)
            }
        }
        return best?.0
    }

  public static func spanMatches(pattern: [UInt8], maxSpan: Int, buffer: InputRingBuffer) -> Bool {
        guard let span = matchingSpan(pattern: pattern, buffer: buffer) else { return false }
        return span <= maxSpan
    }

    /// Tick span from oldest matched direction through the newest frame (ago 0).
    /// Walks newest→oldest so the terminal direction must be recent (motion ends on button frame).
    public static func matchingSpan(pattern: [UInt8], buffer: InputRingBuffer) -> Int? {
        guard !pattern.isEmpty, buffer.frameCount > 0 else { return nil }
        var step = pattern.count - 1
        let limit = buffer.frameCount
        for ago in 0 ..< limit {
            let pad = buffer.entry(ago: ago)?.numpad ?? 0
            if pad == 0 { continue }
            if pad == pattern[step] {
                if step == 0 {
                    return ago + 1
                }
                step -= 1
            }
        }
        return nil
    }
}