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
    Vertex[4] vertices;
    uint vao;
    uint vbo;
    uint shader;
}

ZString vertexShaderSource    = "#version 330 core\nlayout (location = 0) in vec3 aPos; void main() { gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0); }\0";
ZString fragmentShaderSource  = "#version 330 core\nout vec4 FragColor; void main() { FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f); }\0";

fn Renderer* create()
{
    Renderer* renderer = mem::new(Renderer);
    renderer.vertices = { { { 0.0, 0.0, 0.0 } }, 
                          { { 1.0, 0.0, 0.0 } },
                          { { 1.0, 1.0, 0.0 } }, 
                          { { 0.0, 1.0, 0.0 } } };

    gl::genVertexArrays(1, &renderer.vao);
    gl::bindVertexArray(renderer.vao);
    int attr = 0;
    gl::vertexAttribPointer(attr, 3, gl::GL_FLOAT, false, Vector3.sizeof, (void*)0);
    gl::enableVertexAttribArray(attr++);

    gl::genBuffers(gl::GL_ARRAY_BUFFER, &renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, Vertex.sizeof * renderer.vertices.len, (void*)&renderer.vertices, gl::GL_STATIC_DRAW);

    uint vertexShader = gl::createShader(gl::GL_VERTEX_SHADER);
    gl::shaderSource(vertexShader, 1, &vertexShaderSource, null);
    gl::compileShader(vertexShader);

    bool success;
    char* infoLog = malloc(512 * char.sizeof);
    defer mem::free(infoLog);
    gl::getShaderiv(vertexShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(vertexShader, 512, null, infoLog);
        io::eprintn("Failed to compile vertex shader");
    }

    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, &fragmentShaderSource, null);
    gl::compileShader(fragmentShader);

    gl::getShaderiv(fragmentShader, gl::GL_COMPILE_STATUS, (int*)&success);
    if (!success)
    {
        gl::getShaderInfoLog(fragmentShader, 512, null, infoLog);
        io::eprintn("Failed to compile fragment shader");
    }

    renderer.shader = gl::createProgram();
    gl::attachShader(renderer.shader, vertexShader);
    gl::attachShader(renderer.shader, fragmentShader);
    gl::linkProgram(renderer.shader);
    gl::deleteShader(vertexShader);
    gl::deleteShader(fragmentShader);

    gl::getProgramiv(renderer.shader, gl::GL_LINK_STATUS, (int*)&success);
    if (!success) {
        gl::getProgramInfoLog(renderer.shader, 512, null, infoLog);
        io::eprintn("Failed to compile shader program");
    }

    return renderer;
}

fn void Renderer.render(Renderer* renderer)
{
    gl::useProgram(renderer.shader);
    gl::bindVertexArray(renderer.vao);
    gl::drawArrays(gl::GL_TRIANGLES, 0, renderer.vertices.len);
}

fn void Renderer.free(Renderer* renderer)
{
    gl::deleteBuffers(2, &renderer.vao);
    gl::deleteProgram(renderer.shader);
}
