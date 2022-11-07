//
//  Renderable.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/7.
//

import Foundation

protocol Renderable: NSObject {
    var uniform: InstanceUniform {get set}
    var material: Material {get set}
}
