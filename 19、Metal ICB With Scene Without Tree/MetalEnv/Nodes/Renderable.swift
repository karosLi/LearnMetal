//
//  Renderable.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/7.
//

import Foundation

protocol SceneContainer: NSObject {
    var renderContainers: [RenderContainer] {get set}
}

protocol RenderContainer: NSObject {
    var renderables: [Renderable] {get set}
    func addRenderable(_ renderable: Renderable)
}

protocol Renderable: NSObject {
    var isHidden: Bool {get set}
    var uniform: InstanceUniform {get set}
    var material: Material {get set}
}
