module renderer;
import std::io;
import std::core::mem;
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
}

ZString vertexShaderSource    = `
#version 330 core

layout (location = 0) in vec3 vertPos;
layout (location = 1) in vec2 vertUV;

out vec2 vUV;

void main() {
    gl_Position = vec4(vertPos.x, vertPos.y, vertPos.z, 1.0);
    vUV = vertUV;
}
`;
ZString fragmentShaderSource  = `
#version 330 core

in vec2 vUV;
uniform sampler2D tex;

out vec4 FragColor;

void main() {
    vec4 color = texture(tex, vUV - vec2(0.025));
    vec4 result = vec4(vec3(color.x), color.x);
    FragColor = result;
}
`;

fn Renderer* create()
{
    Renderer* renderer = mem::new(Renderer);
    renderer.vertices = { 
                          { { 0.5, 0.5, 0.0 }, { 1.0, 1.0 } }, // top right
                          { { 0.5,-0.5, 0.0 }, { 1.0, 0.0 } }, // bottom right
                          { {-0.5,-0.5, 0.0 }, { 0.0, 0.0 } }, // bottom left
                          { {-0.5, 0.5, 0.0 }, { 0.0, 1.0 } }, // top left
                        }; 
    renderer.indices = {
                         0, 1, 3,
                         1, 2, 3
                       };

    gl::genVertexArrays(1, &renderer.vao);
    gl::genBuffers(1, &renderer.vbo);
    gl::genBuffers(1, &renderer.ebo);

    gl::bindVertexArray(renderer.vao);

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(renderer.vertices), (void*)&renderer.vertices, gl::GL_STATIC_DRAW);

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

    return renderer;
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
