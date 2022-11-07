//
//  Types.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import simd

extension VertexBufferIndex {
  var index: Int {
    return Int(rawValue)
  }
}

extension KernelBufferIndex {
  var index: Int {
    return Int(rawValue)
  }
}

extension FragmentBufferIndex {
  var index: Int {
    return Int(rawValue)
  }
}

extension ArgumentBufferBufferID {
  var index: Int {
    return Int(rawValue)
  }
}
