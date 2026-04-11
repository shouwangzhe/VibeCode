import SwiftUI

// MARK: - Color Palette

/// Pixel art color palette for mascot animations
enum MascotPalette {
    static let black = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let darkGray = Color(red: 0.3, green: 0.3, blue: 0.3)
    static let gray = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let white = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let darkOrange = Color(red: 0.8, green: 0.4, blue: 0.1)
    static let pink = Color(red: 1.0, green: 0.5, blue: 0.5)
    static let green = Color(red: 0.3, green: 0.8, blue: 0.4)
    static let darkGreen = Color(red: 0.2, green: 0.5, blue: 0.3)
    static let brown = Color(red: 0.5, green: 0.3, blue: 0.15)
    static let darkBrown = Color(red: 0.35, green: 0.2, blue: 0.1)
    static let teal = Color(red: 0.2, green: 0.7, blue: 0.7)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.2)
}

/// Typealias for a 12x12 pixel frame
typealias PixelFrame = [[Color?]]

// MARK: - Shorthand aliases for readability
private let __ : Color? = nil
private let BK = MascotPalette.black
private let DG = MascotPalette.darkGray
private let GY = MascotPalette.gray
private let WH = MascotPalette.white
private let OR = MascotPalette.orange
private let DO = MascotPalette.darkOrange
private let PK = MascotPalette.pink
private let GR = MascotPalette.green
private let DGR = MascotPalette.darkGreen
private let BR = MascotPalette.brown
private let DB = MascotPalette.darkBrown
private let TL = MascotPalette.teal
private let YL = MascotPalette.yellow

// MARK: - Cat Idle (lying down sideways, stretching)

/// Cat lying sideways with paws stretched out, breathing animation
enum CatIdleFrames {
    // Frame 1 - paws out, eyes open
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,BK,BK,__,__,__,__,__,__,__,__,__],
        [BK,OR,OR,BK,BK,__,__,__,__,__,__,__],
        [BK,OR,GR,OR,BK,BK,BK,BK,__,__,__,__],
        [__,BK,OR,PK,OR,OR,OR,OR,BK,__,__,__],
        [BK,BK,OR,OR,OR,OR,OR,OR,OR,BK,__,__],
        [__,__,BK,BK,BK,BK,BK,__,BK,OR,BK,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Frame 2 - body slightly raised (breathing in)
    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,BK,BK,__,__,__,__,__,__,__,__,__],
        [BK,OR,OR,BK,BK,__,__,__,__,__,__,__],
        [BK,OR,GR,OR,BK,BK,BK,BK,__,__,__,__],
        [__,BK,OR,PK,OR,OR,OR,OR,BK,__,__,__],
        [BK,BK,OR,OR,OR,OR,OR,OR,OR,BK,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,OR,BK,__,__],
        [__,__,__,BK,BK,BK,BK,__,BK,OR,BK,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let frame2: PixelFrame = frame0

    // Frame 4 - eyes closed (dozing)
    static let frame3: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,BK,BK,__,__,__,__,__,__,__,__,__],
        [BK,OR,OR,BK,BK,__,__,__,__,__,__,__],
        [BK,OR,BK,OR,BK,BK,BK,BK,__,__,__,__],
        [__,BK,OR,PK,OR,OR,OR,OR,BK,__,__,__],
        [BK,BK,OR,OR,OR,OR,OR,OR,OR,BK,__,__],
        [__,__,BK,BK,BK,BK,BK,__,BK,OR,BK,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Cat Ready (sitting, tail wagging)

enum CatReadyFrames {
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,__,__,__,BK,__,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,__,__,__],
        [__,__,__,__,__,__,__,__,__,BK,OR,__],
        [__,__,__,__,__,__,__,__,__,__,BK,__],
    ]

    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,__,__,__,BK,__,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,BK,__],
        [__,__,__,__,__,__,__,__,__,__,__,BK],
    ]

    static let frame2: PixelFrame = frame0

    static let frame3: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,__,__,__,BK,__,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,BK,__,__],
        [__,__,__,__,__,__,__,__,__,OR,BK,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Cat Approval (standing, waving hand)

enum CatApprovalFrames {
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,BK,__,__],
        [__,__,BK,__,__,__,__,__,BK,OR,BK,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,OR,OR,OR,BK,BK,__,__,__],
        [__,OR,BK,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,BK,__,__,__,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,BK,OR,BK,__],
        [__,__,BK,__,__,__,__,__,BK,BK,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,OR,OR,OR,BK,BK,__,__,__],
        [__,OR,BK,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,BK,__,__,__,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let frame2: PixelFrame = frame0

    static let frame3: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,BK,OR,__],
        [__,__,BK,__,__,__,__,__,BK,BK,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,OR,OR,OR,BK,BK,__,__,__],
        [__,OR,BK,BK,OR,OR,OR,BK,__,__,__,__],
        [__,BK,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,BK,__,__,__,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Cat Input (sitting, head tilting)

enum CatInputFrames {
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,__,__,__,BK,__,__,__],
        [__,BK,OR,BK,__,__,__,BK,OR,BK,__,__],
        [__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__],
        [__,__,BK,OR,GR,BK,GR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,PK,OR,OR,BK,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Head tilted right
    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,BK,__,__,__,__,__,BK,__,__],
        [__,__,BK,OR,BK,__,__,__,BK,OR,BK,__],
        [__,__,BK,OR,BK,BK,BK,BK,BK,OR,BK,__],
        [__,__,__,BK,OR,GR,BK,GR,OR,BK,__,__],
        [__,__,__,BK,OR,OR,PK,OR,OR,BK,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let frame2: PixelFrame = frame0

    // Head tilted left
    static let frame3: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,BK,__,__,__,__,__,BK,__,__,__,__],
        [BK,OR,BK,__,__,__,BK,OR,BK,__,__,__],
        [BK,OR,BK,BK,BK,BK,BK,OR,BK,__,__,__],
        [__,BK,OR,GR,BK,GR,OR,BK,__,__,__,__],
        [__,BK,OR,OR,PK,OR,OR,BK,__,__,__,__],
        [__,__,__,BK,OR,OR,OR,BK,__,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,OR,OR,OR,OR,OR,BK,__,__,__],
        [__,__,BK,BK,__,__,__,BK,BK,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Hare Think (sitting, ears twitching)

enum HareThinkFrames {
    // Ears up straight
    static let frame0: PixelFrame = [
        [__,__,__,BK,__,__,__,BK,__,__,__,__],
        [__,__,__,BK,PK,__,__,PK,BK,__,__,__],
        [__,__,__,BK,PK,__,__,PK,BK,__,__,__],
        [__,__,BK,WH,BK,BK,BK,WH,BK,__,__,__],
        [__,__,BK,WH,PK,BK,PK,WH,BK,__,__,__],
        [__,__,__,BK,WH,PK,WH,BK,__,__,__,__],
        [__,__,__,__,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Left ear twitched
    static let frame1: PixelFrame = [
        [__,__,BK,__,__,__,__,BK,__,__,__,__],
        [__,BK,PK,BK,__,__,__,PK,BK,__,__,__],
        [__,__,BK,PK,__,__,__,PK,BK,__,__,__],
        [__,__,BK,WH,BK,BK,BK,WH,BK,__,__,__],
        [__,__,BK,WH,PK,BK,PK,WH,BK,__,__,__],
        [__,__,__,BK,WH,PK,WH,BK,__,__,__,__],
        [__,__,__,__,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let frame2: PixelFrame = frame0

    // Right ear twitched
    static let frame3: PixelFrame = [
        [__,__,__,BK,__,__,__,__,BK,__,__,__],
        [__,__,__,BK,PK,__,BK,PK,BK,__,__,__],
        [__,__,__,BK,PK,__,BK,PK,__,__,__,__],
        [__,__,BK,WH,BK,BK,BK,WH,BK,__,__,__],
        [__,__,BK,WH,PK,BK,PK,WH,BK,__,__,__],
        [__,__,__,BK,WH,PK,WH,BK,__,__,__,__],
        [__,__,__,__,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,BK,__,BK,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Hare Run (running with alternating legs)

enum HareRunFrames {
    // Legs extended back
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,BK,__,__,__,__,__,__],
        [__,__,BK,PK,__,PK,BK,__,__,__,__,__],
        [__,__,BK,WH,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,PK,BK,__,__,__,__,__,__],
        [__,__,BK,WH,WH,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,BK,__,BK,BK,__,__,BK,__,__,__],
        [__,BK,__,__,__,__,__,__,__,BK,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Legs together mid-stride
    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,BK,__,__,__,__,__,__],
        [__,__,BK,PK,__,PK,BK,__,__,__,__,__],
        [__,__,BK,WH,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,PK,BK,__,__,__,__,__,__],
        [__,__,BK,WH,WH,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,__,BK,BK,__,__,__,__,__,__],
        [__,__,__,__,BK,BK,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Legs extended forward
    static let frame2: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,BK,__,__,__,__,__,__],
        [__,__,BK,PK,__,PK,BK,__,__,__,__,__],
        [__,__,BK,WH,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,PK,BK,__,__,__,__,__,__],
        [__,__,BK,WH,WH,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,__,__,BK,__,__,BK,__,__,__,__,__],
        [__,__,BK,__,__,__,__,BK,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Airborne
    static let frame3: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,BK,__,__,BK,__,__,__,__,__,__],
        [__,__,BK,PK,__,PK,BK,__,__,__,__,__],
        [__,__,BK,WH,BK,WH,BK,__,__,__,__,__],
        [__,__,__,BK,PK,BK,__,__,__,__,__,__],
        [__,__,BK,WH,WH,WH,BK,__,__,__,__,__],
        [__,__,__,BK,WH,WH,WH,BK,__,__,__,__],
        [__,BK,__,__,BK,BK,__,__,BK,__,__,__],
        [BK,__,__,__,__,__,__,__,__,BK,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Turtle Compact (walking slowly)

enum TurtleCompactFrames {
    // Walk pose 1
    static let frame0: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,DGR,DGR,DGR,__,__,__,__,__],
        [__,__,__,DGR,GR,GR,GR,DGR,__,__,__,__],
        [__,__,DGR,GR,DGR,GR,DGR,GR,DGR,__,__,__],
        [__,BK,DGR,GR,GR,GR,GR,GR,DGR,__,__,__],
        [__,BK,DGR,__,BK,BK,__,DGR,__,__,__,__],
        [__,__,DGR,BK,__,__,BK,__,DGR,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Walk pose 2 - legs shifted
    static let frame1: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,DGR,DGR,DGR,__,__,__,__,__],
        [__,__,__,DGR,GR,GR,GR,DGR,__,__,__,__],
        [__,__,DGR,GR,DGR,GR,DGR,GR,DGR,__,__,__],
        [__,BK,DGR,GR,GR,GR,GR,GR,DGR,__,__,__],
        [__,BK,__,DGR,BK,BK,DGR,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Walk pose 3
    static let frame2: PixelFrame = [
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,DGR,DGR,DGR,__,__,__,__,__],
        [__,__,__,DGR,GR,GR,GR,DGR,__,__,__,__],
        [__,__,DGR,GR,DGR,GR,DGR,GR,DGR,__,__,__],
        [__,BK,DGR,GR,GR,GR,GR,GR,DGR,__,__,__],
        [__,BK,DGR,BK,__,__,BK,DGR,__,__,__,__],
        [__,__,__,__,BK,BK,__,__,DGR,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
        [__,__,__,__,__,__,__,__,__,__,__,__],
    ]

    // Walk pose 4 - legs together
    static let frame3: PixelFrame = frame1

    static let all: [PixelFrame] = [frame0, frame1, frame2, frame3]
}

// MARK: - Cat Ended (lying down sideways, gray)

enum CatEndedFrames {
    static let frame0: PixelFrame = {
        // Same as CatIdleFrames.frame0 but gray — stretched pose, eyes closed
        return [
            [__,__,__,__,__,__,__,__,__,__,__,__],
            [__,__,__,__,__,__,__,__,__,__,__,__],
            [__,__,__,__,__,__,__,__,__,__,__,__],
            [__,__,__,__,__,__,__,__,__,__,__,__],
            [__,DG,DG,__,__,__,__,__,__,__,__,__],
            [DG,GY,GY,DG,DG,__,__,__,__,__,__,__],
            [DG,GY,DG,GY,DG,DG,DG,DG,__,__,__,__],
            [__,DG,GY,DG,GY,GY,GY,GY,DG,__,__,__],
            [DG,DG,GY,GY,GY,GY,GY,GY,GY,DG,__,__],
            [__,__,DG,DG,DG,DG,DG,__,DG,GY,DG,__],
            [__,__,__,__,__,__,__,__,__,__,__,__],
            [__,__,__,__,__,__,__,__,__,__,__,__],
        ]
    }()

    static let all: [PixelFrame] = [frame0]
}

// MARK: - Frame Provider

enum MascotFrameProvider {
    static func frames(for state: MascotState) -> [PixelFrame] {
        switch state {
        case .idle: return CatIdleFrames.all
        case .ready: return CatReadyFrames.all
        case .thinking: return HareThinkFrames.all
        case .running: return HareRunFrames.all
        case .approval: return CatApprovalFrames.all
        case .input: return CatInputFrames.all
        case .compacting: return TurtleCompactFrames.all
        case .ended: return CatEndedFrames.all
        }
    }

    static func frameInterval(for state: MascotState) -> TimeInterval {
        switch state {
        case .idle: return 0.5
        case .ready: return 0.4
        case .thinking: return 0.3
        case .running: return 0.15
        case .approval: return 0.3
        case .input: return 0.5
        case .compacting: return 0.4
        case .ended: return 1.0
        }
    }
}
