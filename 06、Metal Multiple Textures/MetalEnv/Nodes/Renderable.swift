//
//  Renderable.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

protocol Renderable {
    func render(commandEncoder: MTLRenderCommandEncoder, deltaTime: Float, viewPortSize: vector_uint2)
}
