//
//  Vector+Int.m
//  MathLib
//
//  Created by Junhao Wang on 1/5/22.
//

extension Int2 {
    public var width: Int { x }
    public var height: Int { y }
    
    public init(x: Int, y: Int) {
        self.init(x, y)
    }
    
    public var str: String {
        return String(format: "Int2 [ %4d, %4d ]", x, y)
    }
}

extension Int3 {
    public init(xy: Int2, z: Int) {
        self.init(xy.x, xy.y, z)
    }
    
    public init(x: Int, yz: Int2) {
        self.init(x, yz.x, yz.y)
    }
    
    public var xy: Int2 {
        get { Int2(x, y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }
    public var yz: Int2 {
        get { Int2(y, z) }
        set {
            y = newValue.x
            z = newValue.y
        }
    }

    public init(x: Int, y: Int, z: Int) {
        self.init(x, y, z)
    }
    
    public var str: String {
        return String(format: "Int3 [ %4d, %4d, %4d ]", x, y, z)
    }
}

extension Int4 {
    public init(xy: Int2, zw: Int2) {
        self.init(xy.x, xy.y, zw.x, zw.y)
    }
    
    public init(xyz: Int3, w: Int) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }
    
    public init(x: Int, yzw: Int3) {
        self.init(x, yzw.x, yzw.y, yzw.z)
    }
    
    public var xyz: Int3 {
        get { Int3(x, y, z) }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    public var xy: Int2 {
        get { Int2(x, y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }
    
    public var zw: Int2 {
        get { Int2(z, w) }
        set {
            z = newValue.x
            w = newValue.y
        }
    }

    public init(x: Int, y: Int, z: Int, w: Int) {
        self.init(x, y, z, w)
    }
    
    public var str: String {
        return String(format: "Int4 [ %4d, %4d, %4d, %4d ]", x, y, z, w)
    }
}

