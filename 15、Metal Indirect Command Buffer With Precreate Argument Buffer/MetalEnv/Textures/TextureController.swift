//
//  TextureController.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/2.
//

import MetalKit

extension MTLTexture {
    var descriptor: MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = textureType
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.depth = depth
        descriptor.mipmapLevelCount = mipmapLevelCount
        descriptor.arrayLength = arrayLength
        descriptor.sampleCount = sampleCount
        descriptor.cpuCacheMode = cpuCacheMode
        descriptor.usage = usage
        descriptor.storageMode = storageMode
        return descriptor
    }
}

class TextureController {
  static var textureNameIdMap: [String: Int] = [:]
  static var textures: [MTLTexture] = []
  static var heap: MTLHeap?

    static func texture(filename: String) -> MTLTexture? {
      return getTexture(textureId(filename: filename))
    }
    
  static func textureId(filename: String) -> Int? {
    if let id = textureNameIdMap[filename] {
      return id
    }
    let texture = try? loadTexture(filename: filename)
    if let texture = texture {
      return store(texture: texture, name: filename)
    }
    return nil
  }

  static func store(texture: MTLTexture, name: String) -> Int? {
    texture.label = name
    if let id = textureNameIdMap[name] {
      return id
    }
    textures.append(texture)
    let id = textures.count - 1
    textureNameIdMap[name] = id
    return id
  }
    
  static func getTexture(_ id: Int?) -> MTLTexture? {
    if let id = id {
      return textures[id]
    }
    return nil
  }

  // load from string file name
  static func loadTexture(filename: String) throws -> MTLTexture? {
    let textureLoader = MTKTextureLoader(device: MetalContext.device)

      let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
        .origin: MTKTextureLoader.Origin.bottomLeft,
        .SRGB: false,
        .generateMipmaps: NSNumber(value: true)
      ]
      
    if let texture = try? textureLoader.newTexture(
      name: filename,
      scaleFactor: 1.0,
      bundle: Bundle.main,
      options: textureLoaderOptions) {
      return texture
    }
    
    let fileExtension =
      URL(fileURLWithPath: filename).pathExtension.isEmpty ?
        "png" : nil
    guard let url = Bundle.main.url(
      forResource: filename,
      withExtension: fileExtension)
      else {
        print("Failed to load \(filename)")
        return nil
    }
    let texture = try textureLoader.newTexture(
      URL: url,
      options: textureLoaderOptions)
    return texture


//
//      let textureLoader = MTKTextureLoader(device: MetalContext.device)
//      var texture: MTLTexture? = nil
//
//      let textureLoaderOptions: [MTKTextureLoader.Option: Any]
//      if #available(iOS 10.0, *) {
//          textureLoaderOptions = [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]
//      } else {
//          textureLoaderOptions = [:]
//      }
//
//      let fileExtension =
//            URL(fileURLWithPath: filename).pathExtension.isEmpty ?
//              "png" : nil
//      if let textureURL = Bundle.main.url(forResource: filename, withExtension: fileExtension) {
//          do {
//              texture = try textureLoader.newTexture(URL: textureURL, options: textureLoaderOptions)
//          } catch {
//              print("texture not created")
//          }
//      }
//
//      return texture
  }
    
    static func buildHeap() -> MTLHeap? {
      let heapDescriptor = MTLHeapDescriptor()

      // add code here
      let descriptors = textures.map { texture in
        texture.descriptor
      }
      let sizeAndAligns = descriptors.map { descriptor in
          MetalContext.device.heapTextureSizeAndAlign(descriptor: descriptor)
      }
      heapDescriptor.size = sizeAndAligns.reduce(0) { total, sizeAndAlign in
        let size = sizeAndAlign.size
        let align = sizeAndAlign.align
        return total + size - (size & (align - 1)) + align
      }
      if heapDescriptor.size == 0 {
        return nil
      }
      guard let heap =
              MetalContext.device.makeHeap(descriptor: heapDescriptor)
        else { return nil }
      let heapTextures = descriptors.map { descriptor -> MTLTexture in
        descriptor.storageMode = heapDescriptor.storageMode
        descriptor.cpuCacheMode = heapDescriptor.cpuCacheMode
        guard let texture = heap.makeTexture(descriptor: descriptor) else {
          fatalError("Failed to create heap textures")
        }
        return texture
      }
      guard
        let commandBuffer = MetalContext.commandQueue.makeCommandBuffer(),
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
      else { return nil }
      zip(textures, heapTextures)
        .forEach { texture, heapTexture in
          heapTexture.label = texture.label
          var region =
            MTLRegionMake2D(0, 0, texture.width, texture.height)
          for level in 0..<texture.mipmapLevelCount {
            for slice in 0..<texture.arrayLength {
              blitEncoder.copy(
                from: texture,
                sourceSlice: slice,
                sourceLevel: level,
                sourceOrigin: region.origin,
                sourceSize: region.size,
                to: heapTexture,
                destinationSlice: slice,
                destinationLevel: level,
                destinationOrigin: region.origin)
            }
            region.size.width /= 2
            region.size.height /= 2
          }
        }
      blitEncoder.endEncoding()
      commandBuffer.commit()
      Self.textures = heapTextures
      return heap
    }
}

