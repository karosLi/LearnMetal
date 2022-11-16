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
    static let white = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
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
        let textureNames = ["head.png", "body.png", "protection.png"]
        for imageName in textureNames {
            if let texture = TextureLoader.loadTexture(device: device, imageName: imageName) {
                textures.append(texture)
            }
        }
        renderer.prepare(textures: textures)
        
        /// 蛇1
        for index in (0..<5) {
            let instance = InstanceUniform(center: vector_float2(0.0, -1000.0 + Float(index) * 200.0), size: vector_float2(300.0, 300.0), radian: 0.0, textureIndex: index == 4 ? 0 : 1, color: vector_float4(151/255, 224/255, 255/255, 1.0))
            renderer.add(instance: instance)
        }
        
        /// 蛇2，横着的蛇，要顺时针旋转 90 度，调整方向
        for index in (0..<5) {
            let instance = InstanceUniform(center: vector_float2(-400 + Float(index) * 200.0, 300), size: vector_float2(300.0, 300.0), radian: -Float.pi / 2.0, textureIndex: index == 4 ? 0 : 1, color: vector_float4(0.59, 0.87, 1.0, 1.0))
            renderer.add(instance: instance)
        }
        
        /// 护盾
        let instance = InstanceUniform(center: vector_float2(0, 0), size: vector_float2(Float(renderer.viewPortSize.x), Float(renderer.viewPortSize.y)), radian: 0.0, textureIndex: 2, color: vector_float4(151/255, 224/255, 255/255, 1.0))
        renderer.add(instance: instance)
        
    }
}
