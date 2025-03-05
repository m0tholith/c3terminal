module renderer;
import std::io;
import std::core::mem;
import std::math;
import std::math::matrix;

import opengl;

const ARRAY_MAX = 16384;

def Vec2f = float[2] @local;
def Vec3f = float[3] @local;
struct Vertex
{
    Vec2f position;
}
struct InstanceData @packed
{
    Vec2f quadPos;
    Vec2f quadSize;
    Vec2f texPos;
    Vec2f texSize;

    Vec3f fg;
}
struct Renderer
{
    Vertex[6] vertices;
    uint vao;
    uint vbo;
    uint shader;

    uint instanceVbo;

    InstanceData[ARRAY_MAX] instanceData;
}

ZString vertexShaderSource    = `
#version 330 core

layout (location = 0) in vec2 vertPos;
layout (location = 1) in vec2 quadPos;
layout (location = 2) in vec2 quadSize;
layout (location = 3) in vec2 texPos;
layout (location = 4) in vec2 texSize;
layout (location = 5) in vec3 fg;

vec2 getPos(vec2 inVec) {
    return quadPos + quadSize * inVec;
}

out VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    vec3 fg;
} vs_out;

void main() {
    gl_Position = vec4(getPos(vertPos), 0.0, 1.0);
    vs_out.uv = vertPos;
    vs_out.idx = gl_InstanceID;
    vs_out.texPos  = texPos;
    vs_out.texSize = texSize;
    vs_out.fg      = fg;
}
`;
ZString fragmentShaderSource  = `
#version 330 core

in VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    vec3 fg;
} fs_in;

uniform sampler2D tex;
uniform vec4 bg = vec4(0, 0, 0, 1);

out vec4 FragColor;

void main() {
    vec2 uv = fs_in.texPos + fs_in.texSize * fs_in.uv;
    float color = texture(tex, uv).x;
    vec4 result = mix(bg, vec4(fs_in.fg, 1), color);
    FragColor = result;
}
`;

fault RendererError
{
    CREATE_SHADER_VERT_FAIL,
    CREATE_SHADER_FRAG_FAIL,
    LINK_SHADER_FAIL,
}
fn Renderer*! create()
{
    Renderer* renderer = mem::new(Renderer);
    renderer.vertices = {
                          { { 0.0, 0.0 } }, // bottom left
                          { { 1.0, 0.0 } }, // bottom right
                          { { 0.0, 1.0 } }, // top left
                          { { 1.0, 0.0 } }, // bottom right
                          { { 0.0, 1.0 } }, // top left
                          { { 1.0, 1.0 } }, // top right
                        };

    gl::genVertexArrays(1, &renderer.vao);
    gl::genBuffers(1, &renderer.vbo);

    gl::bindVertexArray(renderer.vao);

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(renderer.vertices), (void*)&renderer.vertices, gl::GL_STATIC_DRAW);

    int attr = 0;
    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, Vertex.sizeof, (void*)Vertex.position.offsetof);
    attr++;

    gl::genBuffers(1, &renderer.instanceVbo);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.instanceVbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(renderer.instanceData), (void*)&renderer.instanceData, gl::GL_DYNAMIC_DRAW);

    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.quadPos.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;
    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.quadSize.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;
    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.texPos.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;
    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.texSize.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;

    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 3, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.fg.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;

    bool success;
    char[512] infoLog;
    uint vertexShader = gl::createShader(gl::GL_VERTEX_SHADER);
    gl::shaderSource(vertexShader, 1, &vertexShaderSource, null);
    gl::compileShader(vertexShader);

    gl::getShaderiv(vertexShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(vertexShader, 512, null, (ZString)&infoLog);
        io::eprintfn("Failed to compile vertex shader: %s", (ZString)&infoLog);
        return RendererError.CREATE_SHADER_VERT_FAIL?;
    }

    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, &fragmentShaderSource, null);
    gl::compileShader(fragmentShader);

    gl::getShaderiv(fragmentShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(fragmentShader, 512, null, (ZString)&infoLog);
        io::eprintfn("Failed to compile fragment shader: %s", (ZString)&infoLog);
        return RendererError.CREATE_SHADER_FRAG_FAIL?;
    }

    renderer.shader = gl::createProgram();
    gl::attachShader(renderer.shader, vertexShader);
    gl::attachShader(renderer.shader, fragmentShader);
    gl::linkProgram(renderer.shader);

    gl::deleteShader(vertexShader);
    gl::deleteShader(fragmentShader);

    gl::getProgramiv(renderer.shader, gl::GL_LINK_STATUS, (int*)&success);
    if (!success)
    {
        gl::getProgramInfoLog(renderer.shader, 512, null, (ZString)&infoLog);
        io::eprintfn("Failed to compile shader program: %s", (ZString)&infoLog);
        return RendererError.LINK_SHADER_FAIL?;
    }

    gl::useProgram(renderer.shader);

    return renderer;
}

fn void Renderer.render(Renderer* renderer, usz count = ARRAY_MAX)
{
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.instanceVbo);
    gl::bufferSubData(gl::GL_ARRAY_BUFFER, 0, count * InstanceData.sizeof, &renderer.instanceData);

    gl::drawArraysInstanced(gl::GL_TRIANGLES, 0, renderer.vertices.len, count);
}

fn void Renderer.free(Renderer* renderer)
{
    gl::deleteVertexArrays(1, &renderer.vao);
    gl::deleteBuffers(1, &renderer.vbo);
    gl::deleteBuffers(1, &renderer.instanceVbo);
    gl::deleteProgram(renderer.shader);
    mem::free(renderer);
}
