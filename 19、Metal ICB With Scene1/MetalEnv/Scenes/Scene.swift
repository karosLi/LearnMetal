//
//  Scene.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class BackgroundRenderUpdate: RenderUpdate {
    
}

class FoodRenderUpdate: RenderUpdate {
    
}


class Scene: Renderables {
    private var curRenderableIndex = 0
    var renderables: [Renderable] = []
    
    
    
    
//    func nextRenderable() -> Renderable {
//        if curRenderableIndex < renderables.count {
//            let renderable = renderables[curRenderableIndex]
//            curRenderableIndex += 1
//            return renderable
//        }
//
//        curRenderableIndex += 1
//        return SpriteNode()
//    }
    
    
    
}
