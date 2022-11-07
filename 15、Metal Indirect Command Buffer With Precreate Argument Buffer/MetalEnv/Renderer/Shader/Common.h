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
    /// 锚点，默认是 (0.5, 0.5), 表示单位正方形的中心
    vector_float2 anchor;
    /// 透明度
    float alpha;
    /// 纹理平铺次数，（水平方向和垂直方向纹理重复次数，默认应该是 (1,1)）
    vector_float2 tiling;
    /// 单位正方形的上边中心点和底边中心点的旋转弧度，用这种方式在 GPU 侧修改单位正方形的顶点坐标从而达到丝带的效果，默认应该 (0, 0)
    vector_float2 stripRadians;

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
