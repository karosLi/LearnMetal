//
//  Matrix.swift
//  MathLib
//
//  Created by Junhao Wang on 12/16/21.
//

import simd

public typealias Float2x2 = float2x2
public typealias Float3x3 = float3x3
public typealias Float4x4 = float4x4

private let floatPrefixLength = 7

extension Float2x2 {
    public static var identity: Float2x2 {
        get { matrix_identity_float2x2 }
    }
    
    public var str: String {
        let r0 = Float2(columns.0.x, columns.1.x)
        let r1 = Float2(columns.0.y, columns.1.y)
        return """
        
        Float2x2 [\(r0.str.dropFirst(floatPrefixLength)),
                  \(r1.str.dropFirst(floatPrefixLength))]
        """
    }
    
    public var str3f: String {
        let r0 = Float2(columns.0.x, columns.1.x)
        let r1 = Float2(columns.0.y, columns.1.y)
        return """
        
        Float2x2 [\(r0.str3f.dropFirst(floatPrefixLength)),
                  \(r1.str3f.dropFirst(floatPrefixLength))]
        """
    }
}

extension Float3x3 {
    public static var identity: Float3x3 {
        get { matrix_identity_float3x3 }
    }
    
    public var str: String {
        let r0 = Float3(columns.0.x, columns.1.x, columns.2.x)
        let r1 = Float3(columns.0.y, columns.1.y, columns.2.y)
        let r2 = Float3(columns.0.z, columns.1.z, columns.2.z)
        return """
        
        Float3x3 [\(r0.str.dropFirst(floatPrefixLength)),
                  \(r1.str.dropFirst(floatPrefixLength)),
                  \(r2.str.dropFirst(floatPrefixLength))]
        """
    }
    
    public var str3f: String {
        let r0 = Float3(columns.0.x, columns.1.x, columns.2.x)
        let r1 = Float3(columns.0.y, columns.1.y, columns.2.y)
        let r2 = Float3(columns.0.z, columns.1.z, columns.2.z)
        return """
        
        Float3x3 [\(r0.str3f.dropFirst(floatPrefixLength)),
                  \(r1.str3f.dropFirst(floatPrefixLength)),
                  \(r2.str3f.dropFirst(floatPrefixLength))]
        """
    }
}

extension Float4x4 {
    public static var identity: Float4x4 {
        get { matrix_identity_float4x4 }
    }
    
    public var str: String {
        let r0 = Float4(columns.0.x, columns.1.x, columns.2.x, columns.3.x)
        let r1 = Float4(columns.0.y, columns.1.y, columns.2.y, columns.3.y)
        let r2 = Float4(columns.0.z, columns.1.z, columns.2.z, columns.3.z)
        let r3 = Float4(columns.0.w, columns.1.w, columns.2.w, columns.3.w)
        return """
        
        Float4x4 [\(r0.str.dropFirst(floatPrefixLength)),
                  \(r1.str.dropFirst(floatPrefixLength)),
                  \(r2.str.dropFirst(floatPrefixLength)),
                  \(r3.str.dropFirst(floatPrefixLength))]
        """
    }
    
    public var str3f: String {
        let r0 = Float4(columns.0.x, columns.1.x, columns.2.x, columns.3.x)
        let r1 = Float4(columns.0.y, columns.1.y, columns.2.y, columns.3.y)
        let r2 = Float4(columns.0.z, columns.1.z, columns.2.z, columns.3.z)
        let r3 = Float4(columns.0.w, columns.1.w, columns.2.w, columns.3.w)
        return """
        
        Float4x4 [\(r0.str3f.dropFirst(floatPrefixLength)),
                  \(r1.str3f.dropFirst(floatPrefixLength)),
                  \(r2.str3f.dropFirst(floatPrefixLength)),
                  \(r3.str3f.dropFirst(floatPrefixLength))]
        """
    }
    
    // Translate
    public init(translation: Float3) {
        let matrix = Float4x4(
            [            1,             0,             0, 0],  // column
            [            0,             1,             0, 0],
            [            0,             0,             1, 0],
            [translation.x, translation.y, translation.z, 1]
        )
        self = matrix
    }
    
    // Scale
    public init(scale: Float3) {
        let matrix = Float4x4(
            [scale.x,       0,       0, 0],
            [      0, scale.y,       0, 0],
            [      0,       0, scale.z, 0],
            [      0,       0,       0, 1]
        )
        self = matrix
    }
    
    public init(scale: Float) {
        self = matrix_identity_float4x4
        //        columns.3.w = 1 / scale
        columns.0.x = scale
        columns.1.y = scale
        columns.2.z = scale
    }
    
    // Rotate
    public init(rotationX angle: Float) {  // radians
        let matrix = Float4x4(
            [1,           0,          0, 0],
            [0,  cos(angle), sin(angle), 0],
            [0, -sin(angle), cos(angle), 0],  // left-handed
            [0,           0,          0, 1]
        )
        self = matrix
    }
    
    public init(rotationY angle: Float) {
        let matrix = Float4x4(
            [cos(angle), 0, -sin(angle), 0],
            [         0, 1,           0, 0],
            [sin(angle), 0,  cos(angle), 0],
            [         0, 0,           0, 1]
        )
        self = matrix
    }
    
    public init(rotationZ angle: Float) {
        let matrix = Float4x4(
            [ cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [          0,          0, 1, 0],
            [          0,          0, 0, 1]
        )
        self = matrix
    }
    
    public init(rotationXYZ angle: Float3) {
        let X = Float4x4(rotationX: angle.x)
        let Y = Float4x4(rotationY: angle.y)
        let Z = Float4x4(rotationZ: angle.z)
        self = Z * Y * X
    }
    
    public init(rotationZXY angle: Float3) {
        let X = Float4x4(rotationX: angle.x)
        let Y = Float4x4(rotationY: angle.y)
        let Z = Float4x4(rotationZ: angle.z)
        self = Y * X * Z
    }
    
    public init(rotationYXZ angle: Float3) {
        let X = Float4x4(rotationX: angle.x)
        let Y = Float4x4(rotationY: angle.y)
        let Z = Float4x4(rotationZ: angle.z)
        self = Z * X * Y
    }
    
    public var upperLeft: Float3x3 {
        let c0 = columns.0.xyz
        let c1 = columns.1.xyz
        let c2 = columns.2.xyz
        return Float3x3(columns: (c0, c1, c2))
    }
    
    /// 法线矩阵，用于把本地空间的法线转换到世界空间
    public var normalMatrix: Float3x3 {
        return self.inverse.transpose.upperLeft
    }
    
    /// Left-handed LookAt Matrix，用于构建一个以相机为原点的坐标系，这样就可以世界空间中的点，可以转换到相机空间
    /// eye 相机的位置，target 是要相机看向的点，up 是 相机在世界空间中的向上的朝向
    public init(eye: Float3, target: Float3, up: Float3) {
        let z = normalize(target - eye)  // forward
        let x = normalize(cross(up, z))  // right
        let y = cross(z, x)
        
        let c0 = Float4(x.x, y.x, z.x, 0)
        let c1 = Float4(x.y, y.y, z.y, 0)
        let c2 = Float4(x.z, y.z, z.z, 0)
        let c3 = Float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        self.init(c0, c1, c2, c3)
    }
    
    /// 正交投影矩阵
    public init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let rect = Rect(left: left, right: right, bottom: bottom, top: top)
        self.init(orthographic: rect, near: near, far: far)
    }
    
    /// 正交投影矩阵
    public init(orthographic rect: Rect, near: Float, far: Float) {
        let c0 = Float4(2 / (rect.right - rect.left), 0, 0, 0)
        let c1 = Float4(0, 2 / (rect.top - rect.bottom), 0, 0)
        let c2 = Float4(0, 0, 1 / (far - near), 0)
        let c3 = Float4((rect.left + rect.right) / (rect.left - rect.right),
                        (rect.top + rect.bottom) / (rect.bottom - rect.top),
                        near / (near - far),
                        1)
        self.init(c0, c1, c2, c3)
    }
    
    /// 透视投影矩阵
    public init(projectionFov fov: Float, aspectRatio: Float, near: Float, far: Float, lhs: Bool = true) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspectRatio
        let z = lhs ? far / (far - near) : far / (near - far)
        let c0 = Float4(x, 0, 0, 0)
        let c1 = Float4(0, y, 0, 0)
        let c2 = lhs ? Float4(0, 0, z, 1) : Float4(0, 0, z, -1)
        let c3 = lhs ? Float4(0, 0, z * -near, 0) : Float4(0, 0, z * near, 0)
        self.init(c0, c1, c2, c3)
    }
}
