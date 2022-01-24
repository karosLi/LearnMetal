//
//  Texturable.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

protocol Texturable {
    var texture: MTLTexture? { get set }
}

extension Texturable {
    func setTexture(device: MTLDevice, imageName: String) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        
        let textureLoaderOptions: [MTKTextureLoader.Option: Any]
        if #available(iOS 10.0, *) {
            textureLoaderOptions = [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]
        } else {
            textureLoaderOptions = [:]
        }
        
        if let textureURL = Bundle.main.url(forResource: imageName, withExtension: nil) {
            do {
                texture = try textureLoader.newTexture(URL: textureURL, options: textureLoaderOptions)
            } catch {
                print("texture not created")
            }
        }
        
        return texture
    }
}
