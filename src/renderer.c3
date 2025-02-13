module renderer;
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
    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, &fragmentShaderSource, null);
    gl::compileShader(fragmentShader);
    renderer.shader = gl::createProgram();
    gl::attachShader(renderer.shader, vertexShader);
    gl::attachShader(renderer.shader, fragmentShader);
    gl::linkProgram(renderer.shader);
    gl::deleteShader(vertexShader);
    gl::deleteShader(fragmentShader);

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
