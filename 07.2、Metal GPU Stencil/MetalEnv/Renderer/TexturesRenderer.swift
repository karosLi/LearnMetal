//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

class TexturesRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var viewPortSize: vector_uint2
    
    private var pipelineState: MTLRenderPipelineState?
    private var protectPipelineState: MTLRenderPipelineState?
    private var protectPipelineState1: MTLRenderPipelineState?
    
    private var maskDepthPipelineState: MTLDepthStencilState?
    private var applyMaskDepthPipelineState: MTLDepthStencilState?
    
    private var depthDescriptor: MTLRenderPassDescriptor?
    private var depthTexture: MTLTexture?
    
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!

    private var samplerState: MTLSamplerState?
    private var textures = [MTLTexture]()
    private var instances = [InstanceUniform]()
    
    private var uniform = Uniform()
    
    /// 单位正方形顶点数据
    private let vertices: [Vertex] = [
        Vertex(position: vector2(-0.5,  0.5),
               textureCoords: vector2(0, 1)), // V0 左上
        Vertex(position: vector2(-0.5, -0.5),
               textureCoords: vector2(0, 0)), // V1 左下
        Vertex(position: vector2(0.5, -0.5),
               textureCoords: vector2(1, 0)), // V2 右下
        Vertex(position: vector2(0.5,  0.5),
               textureCoords: vector2(1, 1)),  // V3 右上
    ]
    
    private let primitiveType: MTLPrimitiveType = .triangleStrip
    
    /// 单位正方形顶点索引
    private var indices: [UInt16] {
        switch primitiveType {
        case .triangleStrip:
            return [
                1, 2, 0,
                2, 3, 0
            ]
        case .triangle:
            return [
                0, 1, 2,
                2, 3, 0
            ]
        default:
            return [
                0, 1, 2,
                2, 3, 0
            ]
        }
    }
    
    init(device: MTLDevice, size: CGSize) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        viewPortSize = vector_uint2(1, 1)
        super.init()
        updateSize(size: size)
        buildVertexBuffers(device: device)
        buildPipelineState(device: device)
        buildSamplerState()
    }
}

/// MARK - 构建 buffer 和 属性描述
extension TexturesRenderer {
    private func buildVertexBuffers(device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
    
    private func buildPipelineState(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "instance_vertex_shader")
        let fragmentFunction = library?.makeFunction(name: "instance_fragment_shader")
        
        let pipelineDescriptor = buildPipelineDescriptor(vertext: vertexFunction, fragment: fragmentFunction)
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        
        /// 创建深度和模板纹理，可以被shader读取，也可以作为 render target 写入值
        depthTexture = makeTexture(size: CGSize(width: CGFloat(viewPortSize.x), height: CGFloat(viewPortSize.y)), pixelFormat: .depth32Float_stencil8, label: "depth_stencil", storageMode: .shared, usage: [.shaderRead, .renderTarget])
        depthDescriptor = MTLRenderPassDescriptor()
        
        
        let protectPipelineDescriptor = buildPipelineDescriptor(vertext: library?.makeFunction(name: "protect_instance_vertex_shader"), fragment: library?.makeFunction(name: "protect_instance_fragment_shader"))
        protectPipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        protectPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        protectPipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        do {
            protectPipelineState = try device.makeRenderPipelineState(descriptor: protectPipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        let protectPipelineDescriptor1 = buildPipelineDescriptor(vertext: library?.makeFunction(name: "protect_instance_vertex_shader"), fragment: library?.makeFunction(name: "protect_instance_fragment_shader"))
        protectPipelineDescriptor1.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;
        protectPipelineDescriptor1.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha;
        protectPipelineDescriptor1.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
        protectPipelineDescriptor1.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
        protectPipelineDescriptor1.depthAttachmentPixelFormat = .depth32Float_stencil8
        protectPipelineDescriptor1.stencilAttachmentPixelFormat = .depth32Float_stencil8
        
        do {
            protectPipelineState1 = try device.makeRenderPipelineState(descriptor: protectPipelineDescriptor1)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        let dsDesc = MTLDepthStencilDescriptor()
        dsDesc.depthCompareFunction = .less
        dsDesc.isDepthWriteEnabled = true
        dsDesc.frontFaceStencil.stencilCompareFunction = .always
        dsDesc.frontFaceStencil.stencilFailureOperation = .keep
        dsDesc.frontFaceStencil.depthFailureOperation = .keep
        dsDesc.frontFaceStencil.depthStencilPassOperation = .incrementClamp
        maskDepthPipelineState = device.makeDepthStencilState(descriptor: dsDesc)
        
        let dsDesc1 = MTLDepthStencilDescriptor()
        dsDesc1.isDepthWriteEnabled = false
        dsDesc1.frontFaceStencil.stencilCompareFunction = .equal
        dsDesc1.frontFaceStencil.stencilFailureOperation = .keep
        dsDesc1.frontFaceStencil.depthFailureOperation = .keep
        dsDesc1.frontFaceStencil.depthStencilPassOperation = .keep
        applyMaskDepthPipelineState = device.makeDepthStencilState(descriptor: dsDesc)
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = device.makeSamplerState(descriptor: descriptor)
    }
}

/// MARK - 更新数据
extension TexturesRenderer {
    func prepare(textures: [MTLTexture]) {
        self.textures.removeAll()
        self.textures.append(contentsOf: textures)
    }
    
    func add(instance: InstanceUniform) {
        instances.append(instance)
    }
    
    func removeAllInstances() {
        instances.removeAll()
    }
}

/// MARK - 渲染
extension TexturesRenderer: MTKViewDelegate {
    private func updateSize(size: CGSize) {
        viewPortSize.x = UInt32(size.width);
        viewPortSize.y = UInt32(size.height);
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let depthDescriptor = depthDescriptor,
              let pipelineState = pipelineState,
              let protectPipelineState = protectPipelineState,
              let protectPipelineState1 = protectPipelineState1,
              let maskDepthPipelineState = maskDepthPipelineState,
              let applyMaskDepthPipelineState = applyMaskDepthPipelineState else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        /// 渲染蛇
        let snakeRenderEncoder = makeRenderEncoder(commandBuffer, descriptor: descriptor)
        snakeRenderEncoder?.setRenderPipelineState(pipelineState)
        snakeRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count, baseVertex: 0, baseInstance: 0)
        snakeRenderEncoder?.endEncoding()
        
        /// 只渲染拉伸后的蛇的模板值，不渲染蛇颜色
        depthDescriptor.depthAttachment.texture = depthTexture
        depthDescriptor.depthAttachment.storeAction = .dontCare
        depthDescriptor.stencilAttachment.texture = depthTexture
        depthDescriptor.stencilAttachment.storeAction = .store// 存储模板值
        let snakeStencilRenderEncoder = makeRenderEncoder(commandBuffer, descriptor: depthDescriptor)
        snakeStencilRenderEncoder?.setRenderPipelineState(protectPipelineState)
        snakeStencilRenderEncoder?.setDepthStencilState(maskDepthPipelineState)
        snakeStencilRenderEncoder?.setStencilReferenceValue(0x1)
        snakeStencilRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count, baseVertex: 0, baseInstance: 0)
        snakeStencilRenderEncoder?.endEncoding()
        
        /// 应用模板
//        descriptor.stencilAttachment.texture = depthTexture
//        descriptor.depthAttachment.texture = depthTexture
//        descriptor.stencilAttachment.loadAction = .load // 加载模板值
//        descriptor.depthAttachment.loadAction = .dontCare
//        let applySnakeStencilRenderEncoder = makeRenderEncoder(commandBuffer, descriptor: descriptor)
//        applySnakeStencilRenderEncoder?.setRenderPipelineState(protectPipelineState1)
//        applySnakeStencilRenderEncoder?.setDepthStencilState(applyMaskDepthPipelineState)
//        applySnakeStencilRenderEncoder?.setStencilReferenceValue(0x1)
//        applySnakeStencilRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count, baseVertex: 0, baseInstance: 0)
//        applySnakeStencilRenderEncoder?.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func makeRenderEncoder(_ commandBuffer: MTLCommandBuffer, descriptor: MTLRenderPassDescriptor) -> MTLRenderCommandEncoder? {
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        /// 构建 MVP
        uniform.modeMatrix = matrix4x4_indentify()
        let projectionMatrix = matrix4x4_ortho(left: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, nearZ: -1, farZ: 1)
        uniform.projectionMatrix = projectionMatrix
        
        /// 渲染设置
        commandEncoder.setFrontFacing(.counterClockwise)// 逆时针为正面
        commandEncoder.setCullMode(.back)// 背面剔除
        
        /// 设置采样器
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        /// 顶点缓冲，只有一份单位正方形顶点数据
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        /// 设置 MVP
        commandEncoder.setVertexBytes(&uniform, length: MemoryLayout<Uniform>.stride, index: 1)
        
        /// 多重纹理
        for (index, texture) in textures.enumerated() {
            commandEncoder.setFragmentTexture(texture, index: index)
        }
        
        /// 实例化数据
        commandEncoder.setVertexBytes(&instances, length: MemoryLayout<InstanceUniform>.stride * instances.count, index: 2)
        
        return commandEncoder
    }
}

extension TexturesRenderer {
    
    func buildPipelineDescriptor(vertext: MTLFunction?, fragment: MTLFunction?) -> MTLRenderPipelineDescriptor {
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertext
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true;
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        return pipelineDescriptor
    }
    
    func makeTexture(
      size: CGSize,
      pixelFormat: MTLPixelFormat,
      label: String,
      storageMode: MTLStorageMode = .private,
      usage: MTLTextureUsage = [.shaderRead, .renderTarget]
    ) -> MTLTexture? {
      let width = Int(size.width)
      let height = Int(size.height)
      guard width > 0 && height > 0 else { return nil }
      let textureDesc =
        MTLTextureDescriptor.texture2DDescriptor(
          pixelFormat: pixelFormat,
          width: width,
          height: height,
          mipmapped: false)
      textureDesc.storageMode = storageMode
      textureDesc.usage = usage
      guard let texture =
        device.makeTexture(descriptor: textureDesc) else {
          fatalError("Failed to create texture")
        }
      texture.label = label
      return texture
    }
}
