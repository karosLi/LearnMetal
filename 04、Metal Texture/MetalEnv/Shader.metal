//
//  Shader.metal
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

#include <metal_stdlib>
using namespace metal;

struct Constants {
    float moveBy;
};

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float2 textureCoords [[ attribute(2) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 textureCoords;
};

vertex VertexOut vertex_shader(const VertexIn vertexIn [[ stage_in ]]) {
    VertexOut vertexOut;
    vertexOut.position = vertexIn.position;
    vertexOut.color = vertexIn.color;
    vertexOut.textureCoords = vertexIn.textureCoords;
    
    return vertexOut;
}

fragment half4 fragment_shader(const VertexOut vertexIn [[ stage_in ]]) {
    return half4(vertexIn.color);
}

fragment half4 texture_fragment_shader(const VertexOut vertexIn [[ stage_in ]],
                                       texture2d<float> texture [[ texture(0) ]],
                                       sampler sampler2d [[ sampler(0) ]]) {
//    constexpr sampler defaultSampler;
    float4 color = texture.sample(sampler2d, vertexIn.textureCoords);
    return half4(color.r, color.g, color.b, 1);
}
