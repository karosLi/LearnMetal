//
//  Scene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Scene: Renderable {
    var nodes: [Node] = []
    
    func add(childNode: Node?) {
        if let node = childNode {
            nodes.append(node)
        }
    }
    
    func render(commandEncoder: MTLRenderCommandEncoder, deltaTime: Float, viewPortSize: vector_uint2) {
        for node in nodes {
            node.render(commandEncoder: commandEncoder, deltaTime: deltaTime, viewPortSize: viewPortSize)
        }
    }
}
