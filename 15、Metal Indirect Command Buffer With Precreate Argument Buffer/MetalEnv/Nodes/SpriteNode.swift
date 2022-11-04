//
//  SpriteNode.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/3.
//

import MetalKit

struct Material {
    var textureId: Int? {
        didSet {
            texture = TextureController.getTexture(textureId)
        }
    }
    private(set) var texture: MTLTexture?
    var color: Float3 = [1, 0, 0]
    
    init(textureId: Int?, color: Float3 = [1, 0, 0]) {
        self.textureId = textureId
        self.texture = TextureController.getTexture(textureId)
        self.color = color
    }
}

extension Material: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.textureId == rhs.textureId && lhs.color == rhs.color
    }
}

class SpriteNode: NSObject {
    var uniform: InstanceUniform
    var material: Material = Material(textureId: nil, color: [1, 0, 0])
    
    init(_ material: Material) {
        uniform = InstanceUniform(position: [0, 0, 0], scale: [100, 100, 1], rotation: [0, 0, 0], textureFrame: [0, 0, 1, 1], alpha: 1, materialIndex: 0, modelMatrix: .identity)
        self.material = material
        super.init()
    }
}
