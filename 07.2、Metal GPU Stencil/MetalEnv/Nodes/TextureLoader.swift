//
//  Texturable.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

struct TextureLoader {
    static func loadTexture(device: MTLDevice, imageName: String) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        
        let textureLoaderOptions: [MTKTextureLoader.Option: Any]
        if #available(iOS 10.0, *) {
            textureLoaderOptions = [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft,
                                    .SRGB: false]
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
