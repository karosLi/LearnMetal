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
        MetalContext.library = MetalContext.device.makeDefaultLibrary()
        MetalContext.commandQueue = MetalContext.device.makeCommandQueue()!
        metalView.device = MetalContext.device
        
        renderer = TexturesRenderer(size: metalView.drawableSize)
        renderer.delegate = self
        
        metalView.clearColor = Colors.wenderlichGreen
        metalView.delegate = renderer
        
        let textureId1 = TextureController.textureId(filename: "container")
        let textureId2 = TextureController.textureId(filename: "awesomeface")
        TextureController.heap = TextureController.buildHeap()
        
        let node1 = SpriteNode(textureId: textureId1);
        node1.uniform.position = [0, 300, 0]
        node1.uniform.scale = [500, 500, 1]
        
        let node2 = SpriteNode(textureId: textureId2);
        node2.uniform.position = [0, -300, 0]
        node2.uniform.scale = [500, 500, 1]
        
        renderer.spriteNodes.append(node1)
        renderer.spriteNodes.append(node2)
        
        for _ in 0..<5000 {
            let node1 = SpriteNode(textureId: textureId1);
            node1.uniform.position = [0, 300, 0]
            node1.uniform.scale = [500, 500, 1]
            renderer.spriteNodes.append(node1)
        }
    }
}

extension ViewController: TexturesRendererProtocol {
    func update() {
//        renderer.reset()
            
        
    }
}
