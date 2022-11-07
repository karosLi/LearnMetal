//
//  Node.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Node: NSObject {
    private var name: String = "Node"
    private var id: String!
    
    var children: [Node] = []
    
    init(name: String){
        self.name = name
        self.id = UUID().uuidString
    }
    
    func addChild(_ child: Node){
        children.append(child)
    }
}
