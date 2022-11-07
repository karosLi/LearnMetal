//
//  Renderable.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/7.
//

import Foundation

protocol Renderables {
    var renderables: [Renderable] {get set}
}

protocol Renderable {
    var isHidden: Bool {get set}
    var uniform: InstanceUniform {get set}
    var material: Material {get set}
}


protocol RenderUpdate {
    
}
