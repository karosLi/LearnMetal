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
float4x4 scale_matrix(float3 scale) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[0][0] = scale.x;
    matrix[1][1] = scale.y;
    matrix[2][2] = scale.y;
    
    return matrix;
}

// 平移矩阵
float4x4 translate_matrix(float3 position) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[3][0] = position.x;
    matrix[3][1] = position.y;
    matrix[3][2] = position.z;
    
    return matrix;
}

// 旋转矩阵，先写死按 z 轴旋转
float4x4 rotation_matrix(float3 rotation) {
    // 单位矩阵
    float4x4 matrix(1.0);
    // 第一个索引表示列，第二个索引表示行
    matrix[0][0] = cos(rotation.z);
    matrix[0][1] = sin(rotation.z);
    matrix[1][0] = -sin(rotation.z);
    matrix[1][1] = cos(rotation.z);
    
    return matrix;
}

// This is the argument buffer that contains the ICB.
struct ICBContainer
{
    command_buffer commandBuffer [[ id(ArgumentBufferIDCommandBuffer) ]];
    render_pipeline_state renderPipelineState [[ id(ArgumentBufferIDPipeline) ]];
//    sampler samplerState [[ id(ArgumentBufferIDSampler) ]];
};

struct ComputeMaterial {
    constant float *materialBuffer;// 材质
};

kernel void model_matrix_compute(uint instanceId [[thread_position_in_grid]],
                                 constant uint *indices [[ buffer(KernelBufferIndexIndices) ]],
                                 constant Uniform &uniform [[ buffer(KernelBufferIndexUniform) ]],
                                 device InstanceUniform *instances [[ buffer(KernelBufferIndexInstanceUniforms) ]],
                                 device ICBContainer *icb_container [[ buffer(KernelBufferIndexICBContainer) ]],
                                 constant ComputeMaterial *materials [[ buffer(KernelBufferIndexTextures) ]]
                                 )
{
    // device 修饰，让 instance 可以被修改
    device InstanceUniform &instance = instances[instanceId];
    ComputeMaterial material = materials[instance.materialIndex];
    
    // 修改纹理
    instance.vertices[0].uv = instance.bottomLeftUV;
    instance.vertices[1].uv = instance.bottomRightUV;
    instance.vertices[2].uv = instance.topLeftUV;
    instance.vertices[3].uv = instance.topRightUV;
    
    // 为了处理丝带皮肤
    if (instance.stripRadians.x > 0 ||instance.stripRadians.y > 0 ) {
        half2 bottomCenter = half2(0, -0.5);
        // 底部右侧点到底部中心点的距离是 0.5，旋转后得到一个底部中心点指向底部右侧点的向量
        half2 bottomCenterToBottomRightVector = half2(0.5 * cos(instance.stripRadians.x), 0.5 * sin(instance.stripRadians.x));
        // 底部中心点加上旋转后的向量可以得到右侧点旋转后的点坐标
        half2 bottomRightVertice = bottomCenter + bottomCenterToBottomRightVector;
        // 底部左侧点旋转后的坐标可以通过对 bottomCenterToBottomRightVector 向量取反然后加上底部中心点得到
        half2 bottomLeftVertice = bottomCenter - bottomCenterToBottomRightVector;
        
        half2 topCenter = half2(0, 0.5);
        half2 topCenterToTopRightVector = half2(0.5 * cos(instance.stripRadians.y), 0.5 * sin(instance.stripRadians.y));
        half2 topRightVertice = topCenter + topCenterToTopRightVector;
        half2 topLeftVertice = topCenter - topCenterToTopRightVector;
        
        // 修改顶点数据
        instance.vertices[0].position.xy = float2(bottomLeftVertice.x, bottomLeftVertice.y);
        instance.vertices[1].position.xy = float2(bottomRightVertice.x, bottomRightVertice.y);
        instance.vertices[2].position.xy = float2(topLeftVertice.x, topLeftVertice.y);
        instance.vertices[3].position.xy = float2(topRightVertice.x, topRightVertice.y);
        
    //    vertices[0].position = float3(-0.5, -1, 0);
    }
    
    // 根据锚点移动单位正方形的位置
    float4x4 anchorTranslateMatrix = translate_matrix(float3(float2(0.5, 0.5) - instance.anchor, 0));
    // 在原点缩放
    float4x4 scaleMatrix = scale_matrix(instance.scale);
    // 在原点旋转
    float4x4 rotationMatrix = rotation_matrix(instance.rotation);
    // 平移到目标位置
    float4x4 translateMatrix = translate_matrix(instance.position);
    // 模型矩阵
    float4x4 instanceModelMatrix = translateMatrix * rotationMatrix * scaleMatrix * anchorTranslateMatrix;
    instance.modelMatrix = instanceModelMatrix;
    
    // Get indirect render commnd object from the indirect command buffer given the object's unique
    // index to set parameters for drawing (or not drawing) the object.
    render_command cmd(icb_container->commandBuffer, instanceId);
    
    cmd.set_render_pipeline_state(icb_container->renderPipelineState);
    // Set the buffers and add a draw command.
    cmd.set_vertex_buffer(instance.vertices, VertexBufferIndexVertices);
    cmd.set_vertex_buffer(&uniform, VertexBufferIndexUniform);
    cmd.set_vertex_buffer(instances, VertexBufferIndexInstanceUniforms);
    
    cmd.set_fragment_buffer(instances, FragmentBufferIndexInstanceUniforms);
    cmd.set_fragment_buffer(material.materialBuffer, FragmentBufferIndexMaterial);
//    cmd.set_fragment_buffer(icb_container.samplerState, FragmentBufferIndexSampler);
    
//    cmd.set_fragment_buffer(materials, FragmentBufferIndexMaterial);
    
    // METAL_FUNC void set_fragment_buffer(device T *buffer, uint index) thread、
//    METAL_FUNC void draw_indexed_primitives(primitive_type type, uint index_count, const constant T *index_buffer, uint instance_count, uint base_vertex = 0, uint base_instance = 0) thread
//    cmd.draw_indexed_primitives(primitive_type::triangle, 6, indices, 1, 0, instanceId);
    
//    cmd.draw_primitives(primitive_type::triangle, 0, 6, 1, instanceId);
    
    cmd.draw_indexed_primitives(primitive_type::triangle, 6, indices, 1, 0, instanceId);
}

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float2 textureCoords [[ attribute(1) ]];
};

// Vertex shader outputs and per-fragment inputs.
struct RasterizerData {
    float4 position [[ position ]];
    float2 uv;
    float3 color;
    uint instanceId [[flat]];// flat 表示不线性插值
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
    float4 position = uniform.projectionMatrix * uniform.viewMatrix * instanceModelMatrix * float4(vertexIn.position, 1);
    
    RasterizerData vertexOut;
    vertexOut.position = position;
    vertexOut.uv = vertexIn.uv;
    vertexOut.color = vertexIn.color;
    vertexOut.instanceId = instanceId;
    
    return vertexOut;
}

struct FragmentMaterial {
    texture2d<float> texture;
    float3 color;
};

struct FragmentSampler {
    sampler sampler2d;
};

fragment half4 instance_fragment_shader(const RasterizerData vertexIn [[ stage_in ]],
//                                        sampler sampler2d [[ sampler(0) ]],
                                        constant InstanceUniform *instances [[ buffer(FragmentBufferIndexInstanceUniforms) ]],
                                        constant FragmentMaterial &material [[ buffer(FragmentBufferIndexMaterial) ]]
                                        ) {
    constexpr sampler texture_sampler(
      filter::linear,
      address::repeat,
      mip_filter::linear,
      max_anisotropy(8));
    
    InstanceUniform instance = instances[vertexIn.instanceId];
    
    texture2d<float> mainTexture = material.texture;
    if (!is_null_texture(mainTexture)) {
        // tiling 为 (1, 1) 时，表示显示整纹理完整的一份贴图，如果超过 1 则会重复贴图，如果小于 1 则显示的就是贴补的部分内容
        float4 color = mainTexture.sample(texture_sampler, vertexIn.uv * instance.tiling);
//        if (color.a < 0.2) {
//            discard_fragment();
//        }
        return half4(color.r, color.g, color.b, color.a) * instance.alpha;
    }
    
    return half4(material.color.r, material.color.g, material.color.b, 1) * instance.alpha;
//    return half4(vertexIn.color.r, vertexIn.color.g, vertexIn.color.b, 1) * instance.alpha;
}
