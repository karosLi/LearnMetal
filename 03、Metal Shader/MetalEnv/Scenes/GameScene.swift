//
//  GameScene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class GameScene: Scene {
    
    var plane: Plane?
    
    init(device: MTLDevice) {
        plane = Plane(device: device);
    }

    func sceneVertexBuffer() -> MTLBuffer? {
        return plane?.vertexBuffer
    }
    
    func sceneIndexBuffer() -> MTLBuffer {
        return (plane?.indexBuffer)!
    }
    
    func sceneIndexCount() -> Int {
        return plane?.indices.count ?? 0
    }
}
