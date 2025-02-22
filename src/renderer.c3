module renderer;
import std::io;
import std::core::mem;
import std::math;
import std::math::matrix;

import opengl;

struct Vector2
{
    float x;
    float y;
}
struct Vector3
{
    float x;
    float y;
    float z;
}
struct Vertex
{
    Vector3 position;
    Vector2 uv;
}
struct Renderer
{
    Vertex[4] vertices;
    uint[6]   indices;
    uint vao;
    uint vbo;
    uint ebo;
    uint shader;

    uint uniformTexPos;
    uint uniformTexSize;
}

ZString vertexShaderSource    = `
#version 330 core

layout (location = 0) in vec3 vertPos;
layout (location = 1) in vec2 vertUV;

out vec2 vUV;

void main() {
    gl_Position = vec4(vec2(vertPos), 0.0, 1.0);
    vUV = vertUV;
}
`;
ZString fragmentShaderSource  = `
#version 330 core

in vec2 vUV;
uniform sampler2D tex;
uniform vec2 texPos;
uniform vec2 texSize;
uniform vec4 bg = vec4(0.1176, 0.1176, 0.1803, 0);
uniform vec4 fg = vec4(0.8039, 0.8392, 0.9568, 1);

out vec4 FragColor;

void main() {
    vec2 uv = texPos + texSize * vUV;
    float color = texture(tex, uv).x;
    vec4 result = mix(bg, fg, color);
    FragColor = result;
}
`;

fn Renderer* create()
{
    Renderer* renderer = mem::new(Renderer);
    renderer.vertices = { 
                          { {-1.0,-1.0, 0.0 }, { 0.0, 0.0 } }, // bottom left
                          { { 1.0,-1.0, 0.0 }, { 1.0, 0.0 } }, // bottom right
                          { {-1.0, 1.0, 0.0 }, { 0.0, 1.0 } }, // top left
                          { { 1.0, 1.0, 0.0 }, { 1.0, 1.0 } }, // top right
                        }; 
    renderer.indices = {
                         0, 1, 2,
                         1, 2, 3
                       };

    gl::genVertexArrays(1, &renderer.vao);
    gl::genBuffers(1, &renderer.vbo);
    gl::genBuffers(1, &renderer.ebo);

    gl::bindVertexArray(renderer.vao);

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(renderer.vertices), (void*)&renderer.vertices, gl::GL_DYNAMIC_DRAW);

    gl::bindBuffer(gl::GL_ELEMENT_ARRAY_BUFFER, renderer.ebo);
    gl::bufferData(gl::GL_ELEMENT_ARRAY_BUFFER, $sizeof(renderer.indices), (void*)&renderer.indices, gl::GL_STATIC_DRAW);

    int attr = 0;
    gl::vertexAttribPointer(attr, 3, gl::GL_FLOAT, false, Vertex.sizeof, (void*)Vertex.position.offsetof);
    gl::enableVertexAttribArray(attr++);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, Vertex.sizeof, (void*)Vertex.uv.offsetof);
    gl::enableVertexAttribArray(attr++);

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);
    gl::bindVertexArray(0);

    bool success;
    char[512] infoLog;
    uint vertexShader = gl::createShader(gl::GL_VERTEX_SHADER);
    gl::shaderSource(vertexShader, 1, &vertexShaderSource, null);
    gl::compileShader(vertexShader);

    gl::getShaderiv(vertexShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(vertexShader, 512, null, (char*)&infoLog);
        io::eprintfn("Failed to compile vertex shader: %s", infoLog);
    }

    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, &fragmentShaderSource, null);
    gl::compileShader(fragmentShader);

    gl::getShaderiv(fragmentShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(fragmentShader, 512, null, (char*)&infoLog);
        io::eprintfn("Failed to compile fragment shader: %s", infoLog);
    }

    renderer.shader = gl::createProgram();
    gl::attachShader(renderer.shader, vertexShader);
    gl::attachShader(renderer.shader, fragmentShader);
    gl::linkProgram(renderer.shader);

    gl::deleteShader(vertexShader);
    gl::deleteShader(fragmentShader);

    gl::getProgramiv(renderer.shader, gl::GL_LINK_STATUS, (int*)&success);
    if (!success) {
        gl::getProgramInfoLog(renderer.shader, 512, null, (char*)&infoLog);
        io::eprintfn("Failed to compile shader program: %s", infoLog);
    }

    gl::useProgram(renderer.shader);
    renderer.uniformTexPos  = gl::getUniformLocation(renderer.shader, "texPos");
    renderer.uniformTexSize = gl::getUniformLocation(renderer.shader, "texSize");
    gl::useProgram(0);

    return renderer;
}

fn void Renderer.updateQuad(Renderer* self, float x1, float y1, float x2, float y2)
{
    self.vertices[0].position = { x1, y1, 0 };
    self.vertices[1].position = { x2, y1, 0 };
    self.vertices[2].position = { x1, y2, 0 };
    self.vertices[3].position = { x2, y2, 0 };

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(self.vertices),
                   (void*)&self.vertices, gl::GL_DYNAMIC_DRAW);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);
}

fn void Renderer.render(Renderer* renderer)
{
    gl::useProgram(renderer.shader);
    gl::bindVertexArray(renderer.vao);
    gl::drawElements(gl::GL_TRIANGLES, renderer.indices.len, gl::GL_UNSIGNED_INT, (void*)0);
}

fn void Renderer.free(Renderer* renderer)
{
    gl::deleteVertexArrays(1, &renderer.vao);
    gl::deleteBuffers(1, &renderer.vbo);
    gl::deleteBuffers(1, &renderer.ebo);
    gl::deleteProgram(renderer.shader);
    mem::free(renderer);
}
