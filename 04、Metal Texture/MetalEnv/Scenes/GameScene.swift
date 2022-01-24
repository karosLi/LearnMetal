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
        plane = Plane(device: device, imageName: "container.jpeg");
        super.init()
        add(childNode: plane)
    }
}
