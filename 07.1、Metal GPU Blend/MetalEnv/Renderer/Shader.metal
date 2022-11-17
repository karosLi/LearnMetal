//
//  Shader.metal
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

#include <metal_stdlib>

using namespace metal;

struct Uniform {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct InstanceUniform {
    float2 center;
    float2 size;
    float radian;
    int textureIndex;
    float4 textureFrame;
    float textureRadian;
    float4 color;
};

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float2 textureCoords [[ attribute(1) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 textureCoords;
    int textureIndex;
    int instanceId;
    float4 instanceColor;
};

// 缩放矩阵
float4x4 scale_matrix(float2 size) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[0][0] = size.x;
    matrix[1][1] = size.y;
    
    return matrix;
}

// 平移矩阵
float4x4 translate_matrix(float2 position) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[3][0] = position.x;
    matrix[3][1] = position.y;
    
    return matrix;
}

// 旋转矩阵
float4x4 rotation_matrix(float radians) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[0][0] = cos(radians);
    matrix[0][1] = sin(radians);
    matrix[1][0] = -sin(radians);
    matrix[1][1] = cos(radians);
    
    return matrix;
}

vertex VertexOut instance_vertex_shader(const VertexIn vertexIn [[ stage_in ]],
                                        constant Uniform &uniform [[ buffer(1) ]],
                                        constant InstanceUniform *instances [[ buffer(2) ]],
                                        uint instanceId [[instance_id]]) {
    
    InstanceUniform instance = instances[instanceId];
    
    // 在原点缩放
    float4x4 scaleMatrix = scale_matrix(instance.size);
    // 在原点旋转
    float4x4 rotationMatrix = rotation_matrix(instance.radian);
    // 平移到目标位置
    float4x4 translateMatrix = translate_matrix(instance.center);
    // 模型矩阵
    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix;
    
    // 转换后的点坐标
    float4 position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * instanceModelMatrix * vertexIn.position;
    
    // 纹理坐标
    float2 textureAnchor = float2(0.5, 0.5);
    float2 textureCoords = instance.textureFrame.xy + (textureAnchor + (rotation_matrix(instance.textureRadian) * float4(vertexIn.textureCoords - textureAnchor, 0.0, 0.0)).xy) * instance.textureFrame.zw;
    
    VertexOut vertexOut;
    vertexOut.position = position;
    vertexOut.textureCoords = textureCoords;
    vertexOut.textureIndex = instance.textureIndex;
    vertexOut.instanceId = instanceId;
    vertexOut.instanceColor = instance.color;
    
    return vertexOut;
}

fragment half4 instance_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                       array<texture2d<float>, 8> textures [[ texture(0) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
    float4 color = textures[vertexIn.textureIndex].sample(sampler2d, vertexIn.textureCoords);
    return half4(color.r, color.g, color.b, color.a);
}

vertex VertexOut offline_protect_instance_vertex_shader(const VertexIn vertexIn [[ stage_in ]],
                                        constant Uniform &uniform [[ buffer(1) ]],
                                        constant InstanceUniform *instances [[ buffer(2) ]],
                                        uint instanceId [[instance_id]]) {
    
    InstanceUniform instance = instances[instanceId];
    
    // 在原点缩放
    float4x4 scaleMatrix = scale_matrix(instance.size + float2(100.0, 100.0));
    // 在原点旋转
    float4x4 rotationMatrix = rotation_matrix(instance.radian);
    // 平移到目标位置
    float4x4 translateMatrix = translate_matrix(instance.center);
    // 模型矩阵
    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix;
    
    // 转换后的点坐标
    float4 position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * instanceModelMatrix * vertexIn.position;
    
    // 纹理坐标
    float2 textureAnchor = float2(0.5, 0.5);
    float2 textureCoords = instance.textureFrame.xy + (textureAnchor + (rotation_matrix(instance.textureRadian) * float4(vertexIn.textureCoords - textureAnchor, 0.0, 0.0)).xy) * instance.textureFrame.zw;
    
    VertexOut vertexOut;
    vertexOut.position = position;
    vertexOut.textureCoords = textureCoords;
    vertexOut.textureIndex = instance.textureIndex;
    vertexOut.instanceId = instanceId;
    vertexOut.instanceColor = instance.color;
    
    return vertexOut;
}

fragment half4 offline_protect_instance_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                        texture2d<float> protectTexture [[ texture(0) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
    float4 color = protectTexture.sample(sampler2d, vertexIn.textureCoords);
//    if (color.a < 0.001) {
//        discard_fragment();
//    }
//    float alpha = max(color.a - 0.7, 0.0);
//    return half4(151/255, 224/255, 255/255, alpha);
    return half4(color.a, color.a, color.a, color.a);
}

vertex VertexOut protect_instance_vertex_shader(const VertexIn vertexIn [[ stage_in ]],
                                        constant Uniform &uniform [[ buffer(1) ]],
                                        constant InstanceUniform *instances [[ buffer(2) ]],
                                        uint instanceId [[instance_id]]) {
    
    InstanceUniform instance = instances[instanceId];
    
    // 在原点缩放
    float4x4 scaleMatrix = scale_matrix(instance.size);
    // 在原点旋转
    float4x4 rotationMatrix = rotation_matrix(instance.radian);
    // 平移到目标位置
    float4x4 translateMatrix = translate_matrix(instance.center);
    // 模型矩阵
    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix;
    
    // 转换后的点坐标
    float4 position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * instanceModelMatrix * vertexIn.position;
    
    // 纹理坐标
    float2 textureAnchor = float2(0.5, 0.5);
    float2 textureCoords = instance.textureFrame.xy + (textureAnchor + (rotation_matrix(instance.textureRadian) * float4(vertexIn.textureCoords - textureAnchor, 0.0, 0.0)).xy) * instance.textureFrame.zw;
    
    VertexOut vertexOut;
    vertexOut.position = position;
    vertexOut.textureCoords = textureCoords;
    vertexOut.textureIndex = instance.textureIndex;
    vertexOut.instanceId = instanceId;
    vertexOut.instanceColor = instance.color;
    
    return vertexOut;
}

fragment half4 protect_instance_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                        texture2d<float> protectTexture [[ texture(0) ]],
                                        texture2d<float> alphaTexture [[ texture(1) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
//    float4 color = protectTexture.sample(sampler2d, vertexIn.textureCoords);
    /// 透明纹理的纹理坐标需要是 (x, 1 - y), 因为创建出来的 render target 纹理对象原点是在左上角的
    float4 alphaColor = alphaTexture.sample(sampler2d, float2(vertexIn.textureCoords.x, 1 - vertexIn.textureCoords.y));
    float alpha = alphaColor.a;
//    if (alpha > 0.4 && alpha < 0.5) {
//        alpha = 0.7;
//    }
    return half4(vertexIn.instanceColor.r, vertexIn.instanceColor.g, vertexIn.instanceColor.b, alpha);
}
