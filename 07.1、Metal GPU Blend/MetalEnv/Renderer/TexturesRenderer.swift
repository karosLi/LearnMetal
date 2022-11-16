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
    public var viewPortSize: vector_uint2
    
    private var pipelineState: MTLRenderPipelineState?
    private var protectPipelineState: MTLRenderPipelineState?
    private var protectPipelineState1: MTLRenderPipelineState?
    
    private var offlineAlphaRenderPassDescriptor: MTLRenderPassDescriptor?
    private var alphaTexture: MTLTexture?
    private var offlineAlphaPipelineState: MTLRenderPipelineState?
    
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!

    private var samplerState: MTLSamplerState?
    private var textures = [MTLTexture]()
    private var instances = [InstanceUniform]()
    private var protectInstance: InstanceUniform!
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
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        
        alphaTexture = makeTexture(size: CGSize(width: CGFloat(viewPortSize.x), height: CGFloat(viewPortSize.y)), pixelFormat: .bgra8Unorm, label: "alphaTexture")
        offlineAlphaRenderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = offlineAlphaRenderPassDescriptor?.colorAttachments[0]
        attachment?.texture = alphaTexture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store
        attachment?.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        let offlinePipelineDescriptor = buildPipelineDescriptor(vertext: library?.makeFunction(name: "offline_protect_instance_vertex_shader"), fragment: library?.makeFunction(name: "offline_protect_instance_fragment_shader"))
        offlinePipelineDescriptor.colorAttachments[0].pixelFormat = alphaTexture!.pixelFormat
//        offlinePipelineDescriptor.colorAttachments[0].writeMask = .red
//        offlinePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .max
        offlinePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .oneMinusSourceColor;
        offlinePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .oneMinusSourceColor;
        offlinePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceColor;
        offlinePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceColor;
        do {
            offlineAlphaPipelineState = try device.makeRenderPipelineState(descriptor: offlinePipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        let protectPipelineDescriptor = buildPipelineDescriptor(vertext: library?.makeFunction(name: "protect_instance_vertex_shader"), fragment: library?.makeFunction(name: "protect_instance_fragment_shader"))
        protectPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;
        protectPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha;
        protectPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
        protectPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
//        protectPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
//        protectPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
//        protectPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
//        protectPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
//        protectPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
//        protectPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .zero
        
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
        
        do {
            protectPipelineState1 = try device.makeRenderPipelineState(descriptor: protectPipelineDescriptor1)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
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
        uniform.viewPort = [Float(size.width), Float(size.height)]
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let offlineAlphaRenderPassDescriptor = offlineAlphaRenderPassDescriptor,
              let offlineAlphaPipelineState = offlineAlphaPipelineState,
              let protectPipelineState = protectPipelineState,
              let protectPipelineState1 = protectPipelineState1 else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        /// 离屏渲染，获取蛇的 alhpa 值，把 红色通道当做 alpha 值
        /// 把 护盾纹理盖在蛇节点上，就可以取到 连续的护盾连起来的轮廓，再把这些轮廓取 红色的最大值，并输出到 透明纹理里
        let alphaSnakeRenderEncoder = makeRenderEncoder(commandBuffer, descriptor: offlineAlphaRenderPassDescriptor)
        alphaSnakeRenderEncoder?.setFragmentTexture(textures.last, index: 0)
        alphaSnakeRenderEncoder?.setRenderPipelineState(offlineAlphaPipelineState)
        /// 最后一个是护盾，要减去1
        alphaSnakeRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count - 1, baseVertex: 0, baseInstance: 0)
        alphaSnakeRenderEncoder?.endEncoding()
        
        /// 渲染蛇
        let snakeRenderEncoder = makeRenderEncoder(commandBuffer, descriptor: descriptor)
        snakeRenderEncoder?.setFragmentTextures(textures, range: 0..<textures.count)
        snakeRenderEncoder?.setRenderPipelineState(pipelineState)
        snakeRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count - 1, baseVertex: 0, baseInstance: 0)
        
        /// 渲染护盾
        /// 根据 透明纹理里的透明度值（透明纹理包含的是所有蛇的透明度） 和 护盾纹理(全屏的护盾纹理)的颜色，进行混合
        snakeRenderEncoder?.setRenderPipelineState(protectPipelineState)
        snakeRenderEncoder?.setFragmentTexture(textures.last, index: 0)
        snakeRenderEncoder?.setFragmentTexture(alphaTexture, index: 1)
        snakeRenderEncoder?.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: 1, baseVertex: 0, baseInstance: instances.count - 1)
        snakeRenderEncoder?.endEncoding()
        
        
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
