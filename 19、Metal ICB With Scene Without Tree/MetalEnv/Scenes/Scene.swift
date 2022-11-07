//
//  Scene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class BgRenderContainer: NSObject, RenderContainer {
    lazy var renderables: [Renderable] = []
    
    func addRenderable(_ renderable: Renderable) {
        renderables.append(renderable)
    }
}

class FoodRenderContainer: NSObject, RenderContainer {
    lazy var renderables: [Renderable] = []
    
    func addRenderable(_ renderable: Renderable) {
        renderables.append(renderable)
    }
}

class SnakeRenderContainer: NSObject, RenderContainer {
    lazy var renderables: [Renderable] = []
    
    func addRenderable(_ renderable: Renderable) {
        renderables.append(renderable)
    }
}

class Scene: NSObject, SceneContainer {
    lazy var bgRenderContainer = BgRenderContainer()
    lazy var foodRenderContainer = FoodRenderContainer()
    lazy var snakeRenderContainer = SnakeRenderContainer()
    
    lazy var renderContainers: [RenderContainer] = [bgRenderContainer, foodRenderContainer, snakeRenderContainer]
}
