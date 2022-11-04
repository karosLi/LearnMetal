//
//  Common.h
//  MetalEnv
//
//  Created by karos li on 2022/9/29.
//

#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct
{
    vector_float3 position;
    vector_float2 uv;
    vector_float3 color;
} Vertex;

typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
} Uniform;

typedef struct {
    /// 实例位置
    vector_float3 position;
    /// 实例大小
    vector_float3 scale;
    /// 实例旋转弧度
    vector_float3 rotation;
    /// 实例纹理坐标
    vector_float4 textureFrame;
    
//    
//    
//    
//    // 用于丝带渲染
//    GLKVector4 stripPoints;// 丝带上下两个数据节点的位置，xy 是顶部数据节点的位置，zw 是底部数据节点的位置
//    GLKVector2 stripRadians;// 丝带上下两个数据节点的旋转弧度，x 是顶部数据节点的旋转弧度，y 是底部数据节点的旋转弧度
    
    /// CPU 侧计算出材质索引
    int materialIndex;
    /// GPU 侧计算出实例模型矩阵
    matrix_float4x4 modelMatrix;
} InstanceUniform;


// Buffer index values shared between the vertex shader and C code
typedef enum VertexBufferIndex
{
    VertexBufferIndexVertices,
    VertexBufferIndexIndices,
    VertexBufferIndexUniform,
    VertexBufferIndexInstanceUniforms,
} VertexBufferIndex;

// Buffer index values shared between the fragment shader and C code
typedef enum FragmentBufferIndex
{
    FragmentBufferIndexMaterial,
    FragmentBufferIndexSampler,
} FragmentBufferIndex;

// Buffer index values shared between the compute kernel and C code
typedef enum KernelBufferIndex
{
    KernelBufferIndexVertices,
    KernelBufferIndexIndices,
    KernelBufferIndexUniform,
    KernelBufferIndexInstanceUniforms,
    KernelBufferIndexICBContainer,
    KernelBufferIndexTextures,
    KernelBufferIndexMaterials,
} KernelBufferIndex;

// Argument buffer ID for the ICB encoded by the compute kernel
typedef enum ArgumentBufferBufferID
{
    ArgumentBufferIDCommandBuffer,
    ArgumentBufferIDPipeline,
    ArgumentBufferIDSampler,
} ArgumentBufferBufferID;

#endif /* Common_h */
