//
//  ViewController.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import UIKit
import MetalKit

enum Colors {
    static let wenderlichGreen = MTLClearColor(red: 0.0, green: 0.4, blue: 0.21, alpha: 1.0)
}

class ViewController: UIViewController {
    
    var metalView: MTKView {
        return view as! MTKView
    }
    
    var device: MTLDevice!
    var renderer: TexturesRenderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView.device = MTLCreateSystemDefaultDevice()
        device = metalView.device
        renderer = TexturesRenderer(device: device, size: metalView.drawableSize)
        
        metalView.clearColor = Colors.wenderlichGreen
        metalView.delegate = renderer
        
        var textures = [MTLTexture]()
        let textureNames = ["container.jpeg", "awesomeface.png"]
        for imageName in textureNames {
            if let texture = TextureLoader.loadTexture(device: device, imageName: imageName) {
                textures.append(texture)
            }
        }
        renderer.prepare(textures: textures)
    }
}
