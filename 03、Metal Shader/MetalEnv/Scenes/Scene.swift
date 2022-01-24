//
//  Scene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

protocol Scene {
    func sceneVertexBuffer() -> MTLBuffer?
    func sceneIndexBuffer() -> MTLBuffer
    func sceneIndexCount() -> Int
}
