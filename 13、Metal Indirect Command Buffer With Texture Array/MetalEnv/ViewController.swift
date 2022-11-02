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
    
    var renderer: TexturesRenderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        MetalContext.device = MTLCreateSystemDefaultDevice()
        MetalContext.commandQueue = MetalContext.device.makeCommandQueue()!
        metalView.device = MetalContext.device
        
        renderer = TexturesRenderer(size: metalView.drawableSize)
        renderer.delegate = self
        
        metalView.clearColor = Colors.wenderlichGreen
        metalView.delegate = renderer
    }
}

extension ViewController: TexturesRendererProtocol {
    func update() {
        renderer.reset()
            
        let instance = InstanceUniform(center: vector_float2(0.0, 300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureId: Int32(TextureController.textureId(filename: "container") ?? 0), textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, textureIndex: 0, modelMatrix: matrix4x4_indentify())
        renderer.configDrawableInstance(instance)
        
        let instance1 = InstanceUniform(center: vector_float2(0.0, -300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureId: Int32(TextureController.textureId(filename: "awesomeface") ?? 0), textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, textureIndex: 1, modelMatrix: matrix4x4_indentify())
        renderer.configDrawableInstance(instance1)
    }
}
