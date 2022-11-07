//
//  Scalar.swift
//  MathLib
//
//  Created by Junhao Wang on 12/16/21.
//

extension Float {
    public var toDegrees: Float {
        self / Float.pi * 180.0
    }
    
    public var toRadians: Float {
        (self / 180.0) * Float.pi
    }
}

