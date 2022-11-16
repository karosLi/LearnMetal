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
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.backgroundColor = .clear
        metalView.layer.isOpaque = false
        metalView.delegate = renderer
        
        let textureId1 = TextureController.textureId(filename: "awesomeface")
        let textureId2 = TextureController.textureId(filename: "head1")
        let textureId3 = TextureController.textureId(filename: "body1")
        
        TextureController.heap = TextureController.buildHeap()
        
        let node1 = SpriteNode(Material(textureId: textureId1));
        node1.uniform.position = [0, 0, 0.4]
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
        node2.uniform.scale = [300, 300, 1]
        scene.foodRenderContainer.addRenderable(node2)
        
        let node3 = SpriteNode(Material(textureId: textureId3));
        node3.uniform.position = [0, -400, 0.5]
        node3.uniform.scale = [300, 300, 1]
        scene.foodRenderContainer.addRenderable(node3)
        
        let node4 = SpriteNode(Material(textureId: textureId3));
        node4.uniform.position = [0, -500, 0.5]
        node4.uniform.scale = [300, 300, 1]
        scene.foodRenderContainer.addRenderable(node4)
        
        let node5 = SpriteNode(Material(textureId: textureId3));
        node5.uniform.position = [0, -600, 0.5]
        node5.uniform.scale = [300, 300, 1]
        scene.foodRenderContainer.addRenderable(node5)
        
        
//        let node3 = SpriteNode(Material(textureId: textureId1));
//        node3.uniform.position = [-100, 300, 1]
//        node3.uniform.scale = [500, 500, 1]
////        node1.uniform.alpha = 0.1
//        node3.uniform.anchor = [0.5, 0.5]
//        node3.uniform.textureFrame = Rect(x: 0, y: 0, width: 1, height: 1)
//        scene.foodRenderContainer.addRenderable(node3)
        
        /// iPhoneX 5000 可以保持 60帧
//        for _ in 0..<5000 {
//            let node1 = SpriteNode(Material(textureId: textureId1));
//            node1.uniform.position = [0, 300, 0]
//            node1.uniform.scale = [500, 500, 1]
//            scene.snakeRenderContainer.addRenderable(node3)
//        }
    }
}

extension ViewController: TexturesRendererProtocol {
    func update() {
//        renderer.reset()
            
        
    }
}
