//
//  MetalContext.swift
//  MetalEnv
//
//  Created by karos li on 2022/11/2.
//

import MetalKit

public class MetalContext: NSObject {
    public static var device:  MTLDevice!
    public static var commandQueue: MTLCommandQueue!
}
