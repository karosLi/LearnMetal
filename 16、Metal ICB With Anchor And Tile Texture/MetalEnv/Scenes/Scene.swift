//
//  Scene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Scene {
    var nodes: [Node] = []
    
    func add(childNode: Node?) {
        if let node = childNode {
            nodes.append(node)
        }
    }
}
