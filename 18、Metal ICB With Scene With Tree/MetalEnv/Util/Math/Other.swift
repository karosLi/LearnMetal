//
//  Other.swift
//  MathLib
//
//  Created by Junhao Wang on 12/16/21.
//

// Rect
public struct Rect {
    public var x: Float = 0
    public var y: Float = 0
    public var width: Float = 0
    public var height: Float = 0
    
    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

extension Rect: Equatable { }
extension Rect: Hashable { }
extension Rect: Codable { }

// ORect
public struct ORect {
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

extension ORect: Equatable { }
extension ORect: Hashable { }
extension ORect: Codable { }

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
