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
            textureLoaderOptions = [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]
        } else {
            textureLoaderOptions = [:]
        }
        
        let image = UIImage(named: imageName)
        if let image = image {
            do {
                texture = try textureLoader.newTexture(cgImage: image.cgImage!, options: textureLoaderOptions)
            } catch {
                print("texture not created")
            }
        } else if let textureURL = Bundle.main.url(forResource: imageName, withExtension: nil) {
            do {
                texture = try textureLoader.newTexture(URL: textureURL, options: textureLoaderOptions)
            } catch {
                print("texture not created")
            }
        }
        
//        textureLoader.new
        
        return texture
    }
}
