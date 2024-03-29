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
};

struct ComputeInstanceUniform {
    float2 center;
    float2 size;
    float radian;
    int textureIndex;
    float4 textureFrame;
    float textureRadian;
};

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float2 textureCoords [[ attribute(1) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 textureCoords;
    int textureIndex;
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

kernel void add_arrays(device const float* inA [[ buffer(0) ]],
                       device const float* inB [[ buffer(1) ]],
                       device float* result [[ buffer(2) ]],
                       uint index [[thread_position_in_grid]])
{
    // the for-loop is replaced with a collection of threads, each of which
    // calls this function.
    result[index] = inA[index] + inB[index];
}

//vertex VertexOut compute_instance_vertex_shader(const VertexIn vertexIn [[ stage_in ]],
//                                        constant Uniform &uniform [[ buffer(1) ]],
//                                        constant float4x4 *instanceModelMatrixs [[ buffer(2) ]],
//                                        uint instanceId [[instance_id]]) {
//
//    // 模型矩阵
//    float4x4 instanceModelMatrix = instanceModelMatrixs[instanceId];
//
//    // 转换后的点坐标
//    float4 position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * instanceModelMatrix * vertexIn.position;
//
//    // 纹理坐标
//    float2 textureAnchor = float2(0.5, 0.5);
//    float2 textureCoords = instance.textureFrame.xy + (textureAnchor + (rotation_matrix(instance.textureRadian) * float4(vertexIn.textureCoords - textureAnchor, 0.0, 0.0)).xy) * instance.textureFrame.zw;
//
//    VertexOut vertexOut;
//    vertexOut.position = position;
//    vertexOut.textureCoords = textureCoords;
//    vertexOut.textureIndex = instance.textureIndex;
//
//    return vertexOut;
//}


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
    
    return vertexOut;
}

fragment half4 instance_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                       array<texture2d<float>, 8> textures [[ texture(0) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
    float4 color = textures[vertexIn.textureIndex].sample(sampler2d, vertexIn.textureCoords);
    return half4(color.r, color.g, color.b, 1);
}
