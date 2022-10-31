//
//  Shader.metal
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

#include <metal_stdlib>
#include "Common.h"

using namespace metal;

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

// This is the argument buffer that contains the ICB.
struct ICBContainer
{
    command_buffer commandBuffer [[ id(ArgumentBufferIDCommandBuffer) ]];
};

struct ComputeMaterial {
    constant float *materialBuffer;
};


kernel void model_matrix_compute(uint instanceId [[thread_position_in_grid]],
                                 constant Vertex *vertices [[ buffer(KernelBufferIndexVertices) ]],
//                                 constant uint *indices [[ buffer(KernelBufferIndexIndices) ]],
                                 constant Uniform &uniform [[ buffer(KernelBufferIndexUniform) ]],
                                 device InstanceUniform *instances [[ buffer(KernelBufferIndexInstanceUniforms) ]],
                                 device ICBContainer *icb_container [[ buffer(KernelBufferIndexICBContainer) ]],
                                 device ComputeMaterial *materials [[ buffer(KernelBufferIndexTextures) ]]
                                 )
{
    // device 修饰，让 instance 可以被修改
    device InstanceUniform &instance = instances[instanceId];
    
    // 在原点缩放
    float4x4 scaleMatrix = scale_matrix(instance.size);
    // 在原点旋转
    float4x4 rotationMatrix = rotation_matrix(instance.radian);
    // 平移到目标位置
    float4x4 translateMatrix = translate_matrix(instance.center);
    // 模型矩阵
    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix;
    instance.modelMatrix = instanceModelMatrix;
    
    // Get indirect render commnd object from the indirect command buffer given the object's unique
    // index to set parameters for drawing (or not drawing) the object.
    render_command cmd(icb_container->commandBuffer, instanceId);
    
    ComputeMaterial material = materials[instance.textureIndex];
    
    // Set the buffers and add a draw command.
    cmd.set_vertex_buffer(vertices, VertexBufferIndexVertices);
    cmd.set_vertex_buffer(&uniform, VertexBufferIndexUniform);
    cmd.set_vertex_buffer(instances, VertexBufferIndexInstanceUniforms);
    
    cmd.set_fragment_buffer(material.materialBuffer, FragmentBufferIndexMaterials);
//    cmd.set_fragment_buffer(materials, FragmentBufferIndexMaterials);
    
    // METAL_FUNC void set_fragment_buffer(device T *buffer, uint index) thread、
//    METAL_FUNC void draw_indexed_primitives(primitive_type type, uint index_count, const constant T *index_buffer, uint instance_count, uint base_vertex = 0, uint base_instance = 0) thread
//    cmd.draw_indexed_primitives(primitive_type::triangle, 6, indices, 1, 0, instanceId);
    cmd.draw_primitives(primitive_type::triangle, 0, 6, 1, instanceId);
}

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float2 textureCoords [[ attribute(1) ]];
};

// Vertex shader outputs and per-fragment inputs.
struct RasterizerData {
    float4 position [[ position ]];
    float2 textureCoords;
    int textureIndex;
};

vertex RasterizerData instance_vertex_shader(uint vertexID [[ vertex_id ]],
                                             uint instanceId [[ instance_id ]],
                                             const device Vertex *vertices [[ buffer(VertexBufferIndexVertices) ]],
                                             const device Uniform &uniform [[ buffer(VertexBufferIndexUniform) ]],
                                             const device InstanceUniform *instances [[ buffer(VertexBufferIndexInstanceUniforms) ]]) {
    
    Vertex vertexIn = vertices[vertexID];
    InstanceUniform instance = instances[instanceId];
    
//    // 在原点缩放
//    float4x4 scaleMatrix = scale_matrix(instance.size);
//    // 在原点旋转
//    float4x4 rotationMatrix = rotation_matrix(instance.radian);
//    // 平移到目标位置
//    float4x4 translateMatrix = translate_matrix(instance.center);
//    // 模型矩阵
//    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix;
    float4x4 instanceModelMatrix = instance.modelMatrix;
    
    // 转换后的点坐标
    float4 position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * instanceModelMatrix * vertexIn.position;
    
    // 纹理坐标
    float2 textureAnchor = float2(0.5, 0.5);
    float2 textureCoords = instance.textureFrame.xy + (textureAnchor + (rotation_matrix(instance.textureRadian) * float4(vertexIn.textureCoords - textureAnchor, 0.0, 0.0)).xy) * instance.textureFrame.zw;
    
    RasterizerData vertexOut;
    vertexOut.position = position;
    vertexOut.textureCoords = textureCoords;
    vertexOut.textureIndex = instance.textureIndex;
    
    return vertexOut;
}

struct FragmentMaterial {
    texture2d<float> mainTexture;
    int index;
};

fragment half4 instance_fragment_shader(const RasterizerData vertexIn [[ stage_in ]],
//                                        device FragmentMaterial &materials [[ buffer(FragmentBufferIndexMaterials) ]]
                                        constant FragmentMaterial &material [[ buffer(FragmentBufferIndexMaterials)
                                                                     ]]
                                        ) {
    constexpr sampler texture_sampler (mag_filter::linear,
                                        min_filter::linear,
                                        mip_filter::linear);

//    device Material &material = materials[vertexIn.textureIndex];
    texture2d<float> mainTexture = material.mainTexture;
    int index = material.index;
//
    if (!is_null_texture(mainTexture)) {
        float4 color = mainTexture.sample(texture_sampler, vertexIn.textureCoords);
        return half4(color.r, color.g, color.b, 1);
//        return half4(1, 1, 0, 1);
    }

    return half4(index, 0, 0, 1);
}
