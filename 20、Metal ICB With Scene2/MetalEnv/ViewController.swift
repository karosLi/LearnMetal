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
    var scene: Scene = Scene()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MetalContext.device = MTLCreateSystemDefaultDevice()
        MetalContext.library = MetalContext.device.makeDefaultLibrary()
        MetalContext.commandQueue = MetalContext.device.makeCommandQueue()!
        metalView.device = MetalContext.device
        
        renderer = TexturesRenderer(size: metalView.drawableSize, scene: scene)
        renderer.delegate = self
        
        metalView.clearColor = Colors.wenderlichGreen
        metalView.delegate = renderer
        
        let textureId1 = TextureController.textureId(filename: "container")
        let textureId2 = TextureController.textureId(filename: "guo")
        TextureController.heap = TextureController.buildHeap()
        
        let node1 = SpriteNode(Material(textureId: textureId1));
        node1.uniform.position = [0, 300, 1]
        node1.uniform.scale = [500, 500, 1]
//        node1.uniform.alpha = 0.1
        node1.uniform.anchor = [0.5, 0.5]
//        node1.uniform.tiling = [2, 2]
        
//        node1.uniform.rotation = [0, 0, 0.45]
//        node1.uniform.stripRadians = [0.45, 0.8]
        node1.uniform.textureFrame = Rect(x: 0, y: 0, width: 1, height: 1)
        scene.bgRenderContainer.addRenderable(node1)
        
        let node2 = SpriteNode(Material(textureId: textureId2));
        node2.uniform.position = [0, -300, 0.5]
        node2.uniform.scale = [500, 500, 1]
//        node2.uniform.alpha = 0.1
//        node2.uniform.tiling = [2, 2]
//        node2.uniform.stripRadians = [0.45, 0.45]
        
        scene.foodRenderContainer.addRenderable(node2)
        
        let node3 = SpriteNode(Material(textureId: textureId1));
        node3.uniform.position = [-100, 300, 1]
        node3.uniform.scale = [500, 500, 1]
//        node1.uniform.alpha = 0.1
        node3.uniform.anchor = [0.5, 0.5]
        node3.uniform.textureFrame = Rect(x: 0, y: 0, width: 1, height: 1)
        scene.foodRenderContainer.addRenderable(node3)
        
        /// iPhoneX 3500 可以保持 60帧
        for _ in 0..<4000 {
            let node1 = SpriteNode(Material(textureId: textureId1));
            node1.uniform.position = [0, 300, 0]
            node1.uniform.scale = [500, 500, 1]
            scene.snakeRenderContainer.addRenderable(node3)
        }
    }
}

extension ViewController: TexturesRendererProtocol {
    func update() {
//        renderer.reset()
            
        
    }
}
