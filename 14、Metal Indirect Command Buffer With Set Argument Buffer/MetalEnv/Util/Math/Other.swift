//
//  Other.swift
//  MathLib
//
//  Created by Junhao Wang on 12/16/21.
//

// Rect
public struct Rect {
    public var left: Float = 0
    public var right: Float = 0
    public var bottom: Float = 0
    public var top: Float = 0
    
    public init(left: Float, right: Float, bottom: Float, top: Float) {
        self.left = left
        self.right = right
        self.bottom = bottom
        self.top = top
    }
}

extension Rect: Equatable { }
extension Rect: Hashable { }
extension Rect: Codable { }

// Bounds
public struct Bounds2 {
    public var pMin: Float2 = Float2()
    public var pMax: Float2 = Float2()

    public init(pMin: Float2, pMax: Float2) {
        self.pMin = pMin
        self.pMax = pMax
    }
}

extension Bounds2: Equatable { }
extension Bounds2: Hashable { }
extension Bounds2: Codable { }
