//
//  Functions.swift
//  MathLib
//
//  Created by Junhao Wang on 1/8/22.
//

import simd
import Foundation

// MARK: - Quaternion Functions
@inlinable public func mul(_ q1: Quaternion, _ q2: Quaternion) -> Quaternion {
    return q1 * q2
}

@inlinable public func add(_ q1: Quaternion, _ q2: Quaternion) -> Quaternion {
    return q1 + q2
}

@inlinable public func sub(_ q1: Quaternion, _ q2: Quaternion) -> Quaternion {
    return q1 - q2
}

// MARK: - Matrix Functions

// Multiply
@inlinable public func mul(_ m1: Float2x2, _ m2: Float2x2) -> Float2x2 {
    return simd_mul(m1, m2)
}

@inlinable public func mul(_ m1: Float3x3, _ m2: Float3x3) -> Float3x3 {
    return simd_mul(m1, m2)
}

@inlinable public func mul(_ m1: Float4x4, _ m2: Float4x4) -> Float4x4 {
    return simd_mul(m1, m2)
}

// Add
@inlinable public func add(_ m1: Float2x2, _ m2: Float2x2) -> Float2x2 {
    return simd_add(m1, m2)
}

@inlinable public func add(_ m1: Float3x3, _ m2: Float3x3) -> Float3x3 {
    return simd_add(m1, m2)
}

@inlinable public func add(_ m1: Float4x4, _ m2: Float4x4) -> Float4x4 {
    return simd_add(m1, m2)
}

// Subtract
@inlinable public func sub(_ m1: Float2x2, _ m2: Float2x2) -> Float2x2 {
    return simd_sub(m1, m2)
}

@inlinable public func sub(_ m1: Float3x3, _ m2: Float3x3) -> Float3x3 {
    return simd_sub(m1, m2)
}

@inlinable public func sub(_ m1: Float4x4, _ m2: Float4x4) -> Float4x4 {
    return simd_sub(m1, m2)
}


// MARK: - Scalar/Vector Functions

// Normalize
@inlinable public func normalize(_ v: Float2) -> Float2 {
    return simd_normalize(v)
}

@inlinable public func normalize(_ v: Float3) -> Float3 {
    return simd_normalize(v)
}

@inlinable public func normalize(_ v: Float4) -> Float4 {
    return simd_normalize(v)
}

// Dot
@inlinable public func dot(_ v1: Float2, _ v2: Float2) -> Float {
    return simd_dot(v1, v2)
}

@inlinable public func dot(_ v1: Float3, _ v2: Float3) -> Float {
    return simd_dot(v1, v2)
}

@inlinable public func dot(_ v1: Float4, _ v2: Float4) -> Float {
    return simd_dot(v1, v2)
}

// Cross
@inlinable public func cross(_ v1: Float2, _ v2: Float2) -> Float3 {
    return simd_cross(v1, v2)
}

@inlinable public func cross(_ v1: Float3, _ v2: Float3) -> Float3 {
    return simd_cross(v1, v2)
}

// Length
@inlinable public func length(_ v: Float2) -> Float {
    return simd_length(v)
}

@inlinable public func length(_ v: Float3) -> Float {
    return simd_length(v)
}

@inlinable public func length(_ v: Float4) -> Float {
    return simd_length(v)
}

// Lerp
@inlinable public func lerp(_ v1: Float2, _ v2: Float2, _ t: Float2) -> Float2 {
    return simd_mix(v1, v2, t)
}

@inlinable public func lerp(_ v1: Float3, _ v2: Float3, _ t: Float3) -> Float3 {
    return simd_mix(v1, v2, t)
}

@inlinable public func lerp(_ v1: Float4, _ v2: Float4, _ t: Float4) -> Float4 {
    return simd_mix(v1, v2, t)
}

@inlinable public func lerp(_ v1: Float2, _ v2: Float2, _ t: Float) -> Float2 {
    return simd_mix(v1, v2, Float2(repeating: t))
}

@inlinable public func lerp(_ v1: Float3, _ v2: Float3, _ t: Float) -> Float3 {
    return simd_mix(v1, v2, Float3(repeating: t))
}

@inlinable public func lerp(_ v1: Float4, _ v2: Float4, _ t: Float) -> Float4 {
    return simd_mix(v1, v2, Float4(repeating: t))
}

// Smoothstep
@inlinable public func smoothstep(_ v1: Float2, _ v2: Float2, _ t: Float2) -> Float2 {
    return simd_smoothstep(v1, v2, t)
}

@inlinable public func smoothstep(_ v1: Float3, _ v2: Float3, _ t: Float3) -> Float3 {
    return simd_smoothstep(v1, v2, t)
}

@inlinable public func smoothstep(_ v1: Float4, _ v2: Float4, _ t: Float4) -> Float4 {
    return simd_smoothstep(v1, v2, t)
}

@inlinable public func smoothstep(_ v1: Float2, _ v2: Float2, _ t: Float) -> Float2 {
    return simd_smoothstep(v1, v2, Float2(repeating: t))
}

@inlinable public func smoothstep(_ v1: Float3, _ v2: Float3, _ t: Float) -> Float3 {
    return simd_smoothstep(v1, v2, Float3(repeating: t))
}

@inlinable public func smoothstep(_ v1: Float4, _ v2: Float4, _ t: Float) -> Float4 {
    return simd_smoothstep(v1, v2, Float4(repeating: t))
}

// Sqrt
@inlinable public func sqrt(_ v: Float) -> Float {
    return Foundation.sqrtf(v)
}

// Abs
@inlinable public func abs(_ v: Float) -> Float {
    return fabsf(v)
}

@inlinable public func abs(_ v: Int) -> Int {
    return Int(Foundation.abs(Int32(v)))
}

// Min & Max
@inlinable public func min(_ v1: Float, _ v2: Float) -> Float {
    return simd_min(v1, v2)
}

@inlinable public func min(_ v1: Float2, _ v2: Float2) -> Float2 {
    return simd_min(v1, v2)
}

@inlinable public func min(_ v1: Float3, _ v2: Float3) -> Float3 {
    return simd_min(v1, v2)
}

@inlinable public func min(_ v1: Float4, _ v2: Float4) -> Float4 {
    return simd_min(v1, v2)
}

@inlinable public func max(_ v1: Float, _ v2: Float) -> Float {
    return simd_max(v1, v2)
}

@inlinable public func max(_ v1: Float2, _ v2: Float2) -> Float2 {
    return simd_max(v1, v2)
}

@inlinable public func max(_ v1: Float3, _ v2: Float3) -> Float3 {
    return simd_max(v1, v2)
}

@inlinable public func max(_ v1: Float4, _ v2: Float4) -> Float4 {
    return simd_max(v1, v2)
}

// MinComponent & MaxComponent
@inlinable public func minComponent(_ v: Float2) -> Float {
    return simd_min(v.x, v.y)
}

@inlinable public func minComponent(_ v: Float3) -> Float {
    return simd_min(v.x, simd_min(v.y, v.z))
}

@inlinable public func minComponent(_ v: Float4) -> Float {
    return simd_min(simd_min(v.x, v.y), simd_min(v.z, v.w))
}

@inlinable public func maxComponent(_ v: Float2) -> Float {
    return simd_max(v.x, v.y)
}

@inlinable public func maxComponent(_ v: Float3) -> Float {
    return simd_max(v.x, simd_max(v.y, v.z))
}

@inlinable public func maxComponent(_ v: Float4) -> Float {
    return simd_max(simd_max(v.x, v.y), simd_max(v.z, v.w))
}

// IsInfinite/HasInfinite
public func isInfinite(_ v: Float) -> Bool {
    return v.isInfinite
}

public func hasInfinite(_ v: Float2) -> Bool {
    return v.x.isInfinite || v.y.isInfinite
}

public func hasInfinite(_ v: Float3) -> Bool {
    return v.x.isInfinite || v.y.isInfinite || v.z.isInfinite
}

public func hasInfinite(_ v: Float4) -> Bool {
    return v.x.isInfinite || v.y.isInfinite || v.z.isInfinite || v.w.isInfinite
}

// IsNaN/HasNaN
public func isNaN(_ v: Float) -> Bool {
    return v.isNaN
}

public func hasNaN(_ v: Float2) -> Bool {
    return v.x.isNaN || v.y.isNaN
}

public func hasNaN(_ v: Float3) -> Bool {
    return v.x.isNaN || v.y.isNaN || v.z.isNaN
}

public func hasNaN(_ v: Float4) -> Bool {
    return v.x.isNaN || v.y.isNaN || v.z.isNaN || v.w.isNaN
}

// IsZero
public func isZero(_ v: Float) -> Bool {
    return v.isZero
}

public func isZero(_ v: Float2) -> Bool {
    return v.x.isZero && v.y.isZero
}

public func isZero(_ v: Float3) -> Bool {
    return v.x.isZero && v.y.isZero && v.z.isZero
}

public func isZero(_ v: Float4) -> Bool {
    return v.x.isZero && v.y.isZero && v.z.isZero && v.w.isZero
}
