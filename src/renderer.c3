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
}
struct Renderer
{
    Vertex[6] vertices;
    uint vao;
    uint vbo;
    uint shader;
}

ZString vertexShaderSource    = `
#version 330 core

layout (location = 0) in vec3 vertPos;
void main() {
    gl_Position = vec4(vertPos.x, vertPos.y, vertPos.z, 1.0);
}
`;
ZString fragmentShaderSource  = `
#version 330 core

out vec4 FragColor;
void main() {
    FragColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);
}
`;

fn Renderer* create()
{
    Renderer* renderer = mem::new(Renderer);
    renderer.vertices = { { {-0.5,-0.5, 0.0 } },
                          { { 0.5,-0.5, 0.0 } },
                          { {-0.5, 0.5, 0.0 } },

                          { { 0.5, 0.5, 0.0 } },
                          { { 0.5,-0.5, 0.0 } },
                          { {-0.5, 0.5, 0.0 } } }; 

    gl::genVertexArrays(1, &renderer.vao);
    gl::bindVertexArray(renderer.vao);

    gl::genBuffers(1, &renderer.vbo);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, renderer.vertices.len * Vertex.sizeof, (void*)&renderer.vertices, gl::GL_STATIC_DRAW);

    int attr = 0;
    gl::vertexAttribPointer(attr, 3, gl::GL_FLOAT, false, Vertex.position.sizeof, (void*)0);
    gl::enableVertexAttribArray(attr++);

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
    gl::drawArrays(gl::GL_TRIANGLES, 0, 6);
}

fn void Renderer.free(Renderer* renderer)
{
    gl::deleteVertexArrays(1, &renderer.vao);
    gl::deleteBuffers(1, &renderer.vbo);
    gl::deleteProgram(renderer.shader);
    mem::free(renderer);
}
