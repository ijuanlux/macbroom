import SwiftUI

/// Indices used in character sprites.
/// 0  = transparent
/// 1  = green stripe
/// 2  = yellow stripe
/// 3  = orange stripe
/// 4  = red stripe
/// 5  = purple stripe
/// 6  = blue stripe
/// 7  = leaf
/// 8  = outline (dark)
/// 9  = stem (brown)
/// 10 = legs / arms (skin/brown)
/// 11 = mouth + glasses (black)
/// 12 = white highlight
/// 13 = shoes (dark brown)
/// 14 = leaf shadow
enum CharacterPalette {
    static let colors: [Color] = [
        .clear,                                       // 0
        Color(red: 0.42, green: 0.74, blue: 0.36),    // 1 green
        Color(red: 0.98, green: 0.78, blue: 0.20),    // 2 yellow
        Color(red: 0.96, green: 0.55, blue: 0.18),    // 3 orange
        Color(red: 0.91, green: 0.30, blue: 0.27),    // 4 red
        Color(red: 0.61, green: 0.34, blue: 0.71),    // 5 purple
        Color(red: 0.18, green: 0.56, blue: 0.86),    // 6 blue
        Color(red: 0.38, green: 0.70, blue: 0.32),    // 7 leaf
        Color(red: 0.18, green: 0.10, blue: 0.05),    // 8 outline
        Color(red: 0.45, green: 0.30, blue: 0.14),    // 9 stem
        Color(red: 0.95, green: 0.78, blue: 0.42),    // 10 legs
        Color.black,                                   // 11 mouth/glasses
        Color.white.opacity(0.90),                    // 12 highlight
        Color(red: 0.22, green: 0.14, blue: 0.05),    // 13 shoes
        Color(red: 0.22, green: 0.50, blue: 0.20),    // 14 leaf shadow
        Color(red: 0.92, green: 0.30, blue: 0.26),    // 15 headphone accent (red)
        Color(red: 0.55, green: 0.55, blue: 0.60),    // 16 ipod silver
    ]

    /// Goku Super Saiyan palette: yellow/gold body, energy vibes.
    static let goku: [Color] = {
        var c = colors
        let gold   = Color(red: 0.99, green: 0.84, blue: 0.18)
        let orange = Color(red: 0.98, green: 0.55, blue: 0.10)
        c[1] = gold; c[2] = orange; c[3] = gold; c[4] = orange
        c[5] = gold; c[6] = orange
        return c
    }()

    /// Hulk palette: huge green stripes, angry colors.
    static let hulk: [Color] = {
        var c = colors
        let green = Color(red: 0.30, green: 0.72, blue: 0.28)
        let dark  = Color(red: 0.18, green: 0.42, blue: 0.16)
        c[1] = green; c[2] = green; c[3] = dark; c[4] = green
        c[5] = dark;  c[6] = green
        return c
    }()

    /// Pikachu palette: yellow body, red mouth row stays for the cheeks.
    static let pikachu: [Color] = {
        var c = colors
        let yellow = Color(red: 0.99, green: 0.85, blue: 0.10)
        let dark   = Color(red: 0.78, green: 0.62, blue: 0.05)
        c[1] = yellow; c[2] = yellow; c[3] = yellow
        c[4] = Color(red: 0.91, green: 0.30, blue: 0.27)   // keep red mouth area
        c[5] = yellow; c[6] = dark
        return c
    }()

    /// Mario palette: red body + blue stripes (overalls).
    static let mario: [Color] = {
        var c = colors
        let red  = Color(red: 0.91, green: 0.18, blue: 0.18)
        let blue = Color(red: 0.16, green: 0.36, blue: 0.78)
        c[1] = red; c[2] = red; c[3] = red
        c[4] = blue; c[5] = blue; c[6] = blue
        return c
    }()

    /// Ryu (Street Fighter) palette: rainbow stripes become white gi with a
    /// thick black belt running through the mouth row.
    static let ryu: [Color] = {
        var c = colors
        let white = Color(red: 0.96, green: 0.94, blue: 0.90)
        let belt  = Color(red: 0.12, green: 0.10, blue: 0.06)
        c[1] = white   // green → white
        c[2] = white   // yellow → white
        c[3] = white   // orange → white
        c[4] = belt    // red row at the waist → black belt
        c[5] = white   // purple → white
        c[6] = white   // blue → white
        return c
    }()

    /// Spider-Man palette: rainbow stripes swapped for alternating red/blue.
    /// Leaf, stem, glasses, legs and shoes stay intact so the apple is still
    /// recognisable through the costume.
    static let spiderman: [Color] = {
        var c = colors
        let red  = Color(red: 0.85, green: 0.14, blue: 0.18)
        let blue = Color(red: 0.10, green: 0.22, blue: 0.62)
        c[1] = red    // was green stripe
        c[2] = blue   // was yellow stripe
        c[3] = red    // was orange stripe
        c[4] = blue   // was red mouth row (becomes a chunky blue accent)
        c[5] = red    // was purple stripe
        c[6] = blue   // was blue stripe (kept blue)
        return c
    }()
}

/// Big, recognizable apple character with bigger glasses that stick out of the head
/// and longer legs. 18 columns × 30 rows tall total (22 body + 6 leg + 2 shoes).
enum AppleSprites {
    private static let bodyIdle: [[Int]] = [
        //0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17
        [0, 0, 0, 0, 0, 0, 0, 0, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0], // leaf
        [0, 0, 0, 0, 0, 0, 0, 7, 7,14, 7, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 7, 7,14,14, 7, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 7,14, 9, 7, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0], // stem
        [0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0], // top outline
        [0, 0, 8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 8, 0, 0, 0],
        [0, 8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 8, 0, 0],
        // Thug-life glasses — extra chunky, full row of solid black on top + tabs
        [11,11,11,11,11,11,11,11, 1,11,11,11,11,11,11,11,11,11],
        [11,11,11,11,11,11,11, 1, 1, 1,11,11,11,11,11,11,11,11],
        [11,11,12,12,12,11,11, 1, 1, 1,11,12,12,12,11,11,11,11],
        [11,11,12,12,12,11,11,11, 1,11,11,12,12,12,11,11,11,11],
        [11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11],
        [0, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 8, 0], // yellow
        [0, 8, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 8, 0], // orange
        [0, 8, 3, 3,12,12, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0], // highlight + bite
        [0, 8, 4, 4, 4, 4,11,11,11,11, 4, 4, 4, 0, 0, 0, 0, 0], // mouth + bite
        [0, 8, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0],
        [0, 8, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 8, 0, 0, 0],
        [0, 8, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 8, 0, 0, 0],
        [0, 8, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 8, 0, 0, 0],
        [0, 0, 8, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 8, 0, 0, 0, 0],
        [0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0],
    ]

    /// Idle pose: legs together, long.
    static let idle: [[Int]] = bodyIdle + [
        [0, 0, 0, 0,10,10, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,10,10, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,10,10, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,10,10, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,10,10, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0,13,13,13, 0, 0, 0, 0,13,13,13, 0, 0, 0, 0, 0],
        [0, 0, 0,13,13,13, 0, 0, 0, 0,13,13,13, 0, 0, 0, 0, 0],
    ]

    /// Walk frame A — left leg forward (shorter), right leg back (longer).
    static let walkA: [[Int]] = bodyIdle + [
        [0, 0, 0,10,10, 0, 0, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0],
        [0, 0, 0,10,10, 0, 0, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0],
        [0, 0, 0,10,10, 0, 0, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0],
        [0, 0, 0,10,10, 0, 0, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0],
        [0, 0, 0,10,10, 0, 0, 0, 0, 0, 0, 0,10,10, 0, 0, 0, 0],
        [0, 0,13,13,13, 0, 0, 0, 0, 0, 0,13,13,13, 0, 0, 0, 0],
        [0, 0,13,13,13, 0, 0, 0, 0, 0, 0,13,13,13, 0, 0, 0, 0],
    ]

    /// Walk frame B — right leg forward.
    static let walkB: [[Int]] = bodyIdle + [
        [0, 0, 0, 0, 0,10,10, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0,10,10, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0,10,10, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0,10,10, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0,10,10, 0, 0, 0, 0,10,10, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,13,13,13, 0, 0, 0,13,13,13, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,13,13,13, 0, 0, 0,13,13,13, 0, 0, 0, 0, 0],
    ]

    static let sweeping: [[Int]] = idle
}

/// Chunky DJ-style headphones — 22 cols × 9 rows. Drawn over the apple head.
/// Uses palette colors 11 (black), 15 (red accent), 12 (white).
enum HeadphoneSprites {
    static let dj: [[Int]] = [
        //0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21
        [0, 0, 0, 0, 0,11,11,11,11,11,11,11,11,11,11,11, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0, 0, 0],
        [0, 0, 0,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0, 0],
        [0,11,11,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,11,11, 0, 0],
        [11,15,15,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,15,15,11, 0],
        [11,15,12,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,12,15,11, 0],
        [11,15,15,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,15,15,11, 0],
        [11,11,11,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,11,11,11, 0],
        [0,11,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11,11, 0, 0],
    ]
}

/// Thin red karate headband worn high on the apple's forehead in Ryu mode.
/// Two frames so the back-tail flutters while the apple moves. Uses palette
/// index 15 (red) and 11 (black knot dots).
enum RyuSprites {
    /// Calm tail — points roughly straight back.
    static let headbandA: [[Int]] = [
        //0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17
        [0, 0, 0,15,15,15,15,15,15,15,15,15,15,15, 0, 0, 0, 0],
        [0,15,15,15,11,15,15,15,15,15,15,11,15,15,15,15, 0, 0],
        [15,15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ]
    /// Mid-flutter — tail kicks down a row.
    static let headbandB: [[Int]] = [
        [0, 0, 0,15,15,15,15,15,15,15,15,15,15,15, 0, 0, 0, 0],
        [0,15,15,15,11,15,15,15,15,15,15,11,15,15,15,15, 0, 0],
        [0,15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [15,15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ]
}

/// Tiny classic-iPod sprite the apple pulls out during music breaks.
/// 5 cols × 8 rows. Held in the front hand.
enum MusicSprites {
    static let ipod: [[Int]] = [
        [11,11,11,11,11],
        [11,12,12,12,11],
        [11,12,12,12,11],
        [11,12,12,12,11],
        [11,16,16,16,11],
        [11,16,11,16,11],
        [11,16,16,16,11],
        [11,11,11,11,11],
    ]
}

/// 5 columns wide × 12 rows tall broom — visibly bigger than before.
enum BroomSprites {
    static let still: [[Int]] = [
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0,13,13,13, 0],
        [2, 2, 2, 2, 2],
        [2, 2, 2, 2, 2],
        [3, 2, 2, 2, 3],
        [3, 3, 2, 3, 3],
    ]
    static let swingA: [[Int]] = [
        [9, 0, 0, 0, 0],
        [9, 0, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 9, 0, 0, 0],
        [0, 0, 9, 0, 0],
        [0, 0, 9, 0, 0],
        [0, 0, 0, 9, 0],
        [0,13,13,13, 0],
        [2, 2, 2, 2, 2],
        [2, 2, 2, 2, 2],
        [3, 2, 2, 2, 3],
        [3, 3, 2, 3, 3],
    ]
}
