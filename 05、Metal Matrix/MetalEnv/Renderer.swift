//
//  Renderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Renderer: NSObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var viewPortSize: vector_uint2
    
    var scene: Scene?
    
    var samplerState: MTLSamplerState?
    
    
    init(device: MTLDevice, size: CGSize) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        viewPortSize = vector_uint2(1, 1)
        super.init()
        updateSize(size: size)
        buildSamplerState()
    }
    
    private func updateSize(size: CGSize) {
        viewPortSize.x = UInt32(size.width);
        viewPortSize.y = UInt32(size.height);
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = device.makeSamplerState(descriptor: descriptor)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        let deltaTime = 1.0 / Float(view.preferredFramesPerSecond)
        
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        let viewPort = MTLViewport(originX: 0.0, originY: 0.0, width: Double(viewPortSize.x), height: Double(viewPortSize.y), znear: 0.0, zfar: 1.0)
        commandEncoder.setViewport(viewPort)
        
        scene?.render(commandEncoder: commandEncoder, deltaTime: deltaTime, viewPortSize: viewPortSize)
        
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
