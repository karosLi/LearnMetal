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

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float2 textureCoords [[ attribute(2) ]];
    int textureIndex [[ attribute(3) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 textureCoords;
    int textureIndex;
};

vertex VertexOut vertex_shader(const VertexIn vertexIn [[ stage_in ]],
                               constant Uniform &uniform [[ buffer(1) ]]) {
    // Get the viewport size and cast to float.
    VertexOut vertexOut;
    vertexOut.position = uniform.projectionMatrix * uniform.viewMatrix * uniform.modelMatrix * vertexIn.position;
    vertexOut.color = vertexIn.color;
    vertexOut.textureCoords = vertexIn.textureCoords;
    vertexOut.textureIndex = vertexIn.textureIndex;
    
    return vertexOut;
}

fragment half4 fragment_shader(const VertexOut vertexIn [[ stage_in ]]) {
    return half4(vertexIn.color);
}

fragment half4 texture_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                       array<texture2d<float>, 8> textures [[ texture(0) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
//    constexpr sampler defaultSampler;
    float4 color = textures[vertexIn.textureIndex].sample(sampler2d, vertexIn.textureCoords);
    return half4(color.r, color.g, color.b, 1);
}
