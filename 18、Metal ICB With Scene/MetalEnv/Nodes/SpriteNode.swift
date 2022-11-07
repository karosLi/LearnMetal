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

extension InstanceUniform {
    var textureFrame: Rect {
        set {
            bottomLeftUV = [newValue.x, newValue.y]
            bottomRightUV = [newValue.x + newValue.width, newValue.y]
            topLeftUV = [newValue.x, newValue.y + newValue.height]
            topRightUV = [newValue.x + newValue.width, newValue.y + newValue.height]
        }
        get {
            return Rect(x: bottomLeftUV.x, y: bottomLeftUV.y, width: topRightUV.x - bottomLeftUV.x, height: topRightUV.y - bottomLeftUV.y)
        }
    }
}

class SpriteNode: Node, Renderable {
    var uniform: InstanceUniform
    var material: Material = Material(textureId: nil, color: [1, 0, 0])
    
    init(_ material: Material) {
        uniform = InstanceUniform(position: [0, 0, 0], scale: [100, 100, 1], rotation: [0, 0, 0], anchor: [0.5, 0.5], alpha: 1, bottomLeftUV: [0, 0], bottomRightUV: [1, 0], topLeftUV: [0, 1], topRightUV: [1, 1], tiling: [1, 1], stripRadians: [0, 0], materialIndex: 0, modelMatrix: .identity, vertices: (
            Vertex(position: [-0.5, -0.5, 0.0],
                   uv: [0, 0], color: [0, 1, 0]), // V0 左下
            Vertex(position: [0.5, -0.5, 0.0],
                   uv: [1, 0], color: [0, 0, 1]), // V1 右下
            Vertex(position: [-0.5, 0.5, 0.0],
                   uv: [0, 1], color: [1, 0, 0]), // V2 左上
            Vertex(position: [0.5, 0.5, 0.0],
                   uv: [1, 1], color: [1, 1, 0]) // V3 右上
        ))
        self.material = material
        super.init(name: "SpriteNode")
    }
}
