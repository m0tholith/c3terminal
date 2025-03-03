module renderer;
import std::io;
import std::core::mem;
import std::math;
import std::math::matrix;

import opengl;

const ARRAY_MAX = 256;

def Vec2f = float[2] @local;
def Vec3f = float[3] @local;
struct Vertex
{
    Vec2f position;
}
struct Renderer
{
    Vertex[6] vertices;
    uint vao;
    uint vbo;
    uint shader;

    uint uniformQuadPos;
    uint uniformQuadSize;
    uint uniformTexPos;
    uint uniformTexSize;
    uint uniformBg;
    uint uniformFg;

    Vec2f[ARRAY_MAX] arrQuadPos;
    Vec2f[ARRAY_MAX] arrQuadSize;
    Vec2f[ARRAY_MAX] arrTexPos;
    Vec2f[ARRAY_MAX] arrTexSize;
    Vec3f[ARRAY_MAX] arrBg;
    Vec3f[ARRAY_MAX] arrFg;
}

ZString vertexShaderSource    = `
#version 330 core

const int ARRAY_MAX = 256;

layout (location = 0) in vec2 vertPos;
uniform vec2 quadPos[ARRAY_MAX];
uniform vec2 quadSize[ARRAY_MAX];

vec2 getPos(vec2 inVec) {
    return quadPos[gl_InstanceID] + quadSize[gl_InstanceID] * inVec;
}

out VS_OUT {
    flat int idx;
    vec2 uv;
} vs_out;

void main() {
    gl_Position = vec4(getPos(vertPos), 0.0, 1.0);
    vs_out.uv = vertPos;
    vs_out.idx = gl_InstanceID;
}
`;
ZString fragmentShaderSource  = `
#version 330 core

const int ARRAY_MAX = 256;

in VS_OUT {
    flat int idx;
    vec2 uv;
} fs_in;

uniform sampler2D tex;
uniform vec2 texPos[ARRAY_MAX];
uniform vec2 texSize[ARRAY_MAX];
uniform vec3 bg[ARRAY_MAX];
uniform vec3 fg[ARRAY_MAX];

out vec4 FragColor;

void main() {
    vec2 uv = texPos[fs_in.idx] + texSize[fs_in.idx] * fs_in.uv;
    float color = texture(tex, uv).x;
    vec4 result = vec4(mix(bg[fs_in.idx], fg[fs_in.idx], color), 1);
    FragColor = result;
}
`;

fn Renderer* create()
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
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, Vertex.sizeof, (void*)Vertex.position.offsetof);
    gl::enableVertexAttribArray(attr++);

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
    }

    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, &fragmentShaderSource, null);
    gl::compileShader(fragmentShader);

    gl::getShaderiv(fragmentShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(fragmentShader, 512, null, (ZString)&infoLog);
        io::eprintfn("Failed to compile fragment shader: %s", (ZString)&infoLog);
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
    }

    gl::useProgram(renderer.shader);
    renderer.uniformQuadPos   = gl::getUniformLocation(renderer.shader, "quadPos");
    renderer.uniformQuadSize  = gl::getUniformLocation(renderer.shader, "quadSize");
    renderer.uniformTexPos    = gl::getUniformLocation(renderer.shader, "texPos");
    renderer.uniformTexSize   = gl::getUniformLocation(renderer.shader, "texSize");
    renderer.uniformBg        = gl::getUniformLocation(renderer.shader, "bg");
    renderer.uniformFg        = gl::getUniformLocation(renderer.shader, "fg");

    return renderer;
}

fn void Renderer.render(Renderer* renderer)
{
    gl::uniform2fv(renderer.uniformQuadPos,  ARRAY_MAX, (float*)&renderer.arrQuadPos);
    gl::uniform2fv(renderer.uniformQuadSize, ARRAY_MAX, (float*)&renderer.arrQuadSize);
    gl::uniform2fv(renderer.uniformTexPos,   ARRAY_MAX, (float*)&renderer.arrTexPos);
    gl::uniform2fv(renderer.uniformTexSize,  ARRAY_MAX, (float*)&renderer.arrTexSize);
    gl::uniform3fv(renderer.uniformBg,       ARRAY_MAX, (float*)&renderer.arrBg);
    gl::uniform3fv(renderer.uniformFg,       ARRAY_MAX, (float*)&renderer.arrFg);

    gl::drawArraysInstanced(gl::GL_TRIANGLES, 0, renderer.vertices.len, ARRAY_MAX);
}

fn void Renderer.free(Renderer* renderer)
{
    gl::deleteVertexArrays(1, &renderer.vao);
    gl::deleteBuffers(1, &renderer.vbo);
    gl::deleteProgram(renderer.shader);
    mem::free(renderer);
}
