//
//  SpriteNode.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/3.
//

import MetalKit

class SpriteNode: NSObject {
    var uniform: InstanceUniform
    var texture: MTLTexture? {
        didSet {
            updateMaterialBuffer()
        }
    }
    var color: Float3 = [1, 0, 0] {
        didSet {
            if texture == nil {// 如果纹理是空的，才更新材质缓冲，因为纹理和颜色只能显示一个
                updateMaterialBuffer()
            }
        }
    }
    
    private(set) var materialBuffer: MTLBuffer!// Shader buffer, 包含纹理和材质等参数
    
    init(texture: MTLTexture?, color: Float3 = [1, 0, 0]) {
        uniform = InstanceUniform(position: [0, 0, 0], scale: [100, 100, 1], rotation: [0, 0, 0], textureFrame: [0, 0, 1, 1], modelMatrix: .identity)
        self.texture = texture
        super.init()
        updateMaterialBuffer()
    }
    
    func updateMaterialBuffer() {
        let fragment = MetalContext.library.makeFunction(name: "instance_fragment_shader")
        let materialEncoder = fragment!.makeArgumentEncoder(
            bufferIndex: FragmentBufferIndexMaterials.index)
        materialBuffer = MetalContext.device.makeBuffer(
          length: materialEncoder.encodedLength,
          options: [])
        materialEncoder.setArgumentBuffer(materialBuffer, offset: 0)
        if let texture = texture {
            materialEncoder.setTexture(texture, index: 0)
        }
        
        let address = materialEncoder.constantData(at: 1)
        address.copyMemory(from: &color, byteCount: MemoryLayout<Float3>.stride)
    }
}
