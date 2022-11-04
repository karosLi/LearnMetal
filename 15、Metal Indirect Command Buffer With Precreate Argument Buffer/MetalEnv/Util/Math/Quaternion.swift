//
//  Quaternion.swift
//  MathLib
//
//  Created by Junhao Wang on 1/6/22.
//

import simd

public typealias Quaternion = simd_quatf

extension Quaternion {
    public static let identity = simd_quatf(angle: 0, axis: [1, 0, 0])
    
    public init(rotaionXYZ angles: Float3) {
        self.init(Float4x4(rotationXYZ: angles))
    }
    
    public init(rotationZXY angles: Float3) {
        self.init(Float4x4(rotationZXY: angles))
    }
    
    public init(rotationYXZ angles: Float3) {
        self.init(Float4x4(rotationYXZ: angles))
    }
    
    public func toMat() -> Float4x4 {
      var m = Float4x4(self)
      m[3][3] = 1
      return m
    }
}
