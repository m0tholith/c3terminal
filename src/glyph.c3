module glyph;

module glyph::font_atlas;

import std::io;
import std::math;
import std::math::matrix;
import std::core::mem;
import std::collections::list;

import glyph::renderer;
import opengl;
import window;
import stb_truetype;

struct FontAtlas
{
    ushort width; ushort height;
    float fontSize;

    uint startCodepoint; uint endCodepoint;
    stb_truetype::PackedChar[] chars;
    stb_truetype::FontInfo fontInfo;
    char[] fontFile;
    char[] pixels;
    uint textureId;
    float charMaxX; float charMaxY;

    renderer::Renderer renderer;
}
fault FontAtlasError
{
    PACKBEGIN_FAILED,
    CHAR_NOT_FOUND,
}
<*
 @require filename.ptr != null
 @require fontSize > 0
 *>
fn void! FontAtlas.init(&self, String filename, float fontSize, uint startCodepoint = 0, uint endCodepoint = uint.max)
{
    self.startCodepoint = startCodepoint; self.endCodepoint = endCodepoint;
    self.width = 1024; self.height = 1024;
    self.fontSize = fontSize;
    self.renderer.init()!;

    self.fontFile = mem::new_array(char, io::file::get_size(filename))!!;
    readFile(filename, self.fontFile)!;

    stb_truetype::initFont(&self.fontInfo, self.fontFile.ptr, 0);

    self.chars = mem::new_array(stb_truetype::PackedChar, self.fontInfo.numGlyphs);
    self.pixels = mem::new_array(char, (usz)(self.width * self.height));

    stb_truetype::PackContext ctx;

    if (stb_truetype::packBegin(&ctx, self.pixels.ptr, self.width, self.height, 0, 1, null) == 0) return FontAtlasError.PACKBEGIN_FAILED?;
    stb_truetype::packFontRange(&ctx, self.fontFile, 0, fontSize, self.startCodepoint, self.fontInfo.numGlyphs, self.chars.ptr);
    stb_truetype::packEnd(&ctx);

    // flip image
    {
        int top = 0;
        int bottom = (self.height - 1) * self.width;
        while (top < bottom)
        {
            for (int j = 0; j < self.width; j++)
            {
                @swap(self.pixels[j + top], self.pixels[j + bottom]);
            }
            top += self.width;
            bottom -= self.width;
        }
    }
    // flip y values of chars
    for (int i = 0; i < self.chars.len; i++)
    {
        self.chars[i].y0 = self.height - self.chars[i].y0;
        self.chars[i].y1 = self.height - self.chars[i].y1;
        @swap(self.chars[i].y0, self.chars[i].y1);
    }

    self.charMaxX = self.getChar('#')!!.xadvance;
    self.charMaxY = fontSize;

    uint texture;
    gl::genTextures(1, &texture);
    gl::bindTexture(gl::GL_TEXTURE_2D, texture);
    // set the texture wrapping/filtering options (on the currently bound texture object)
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_REPEAT);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_REPEAT);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_LINEAR);
    // load and generate the texture
    gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_R8, self.width, self.height, 0, gl::GL_RED, gl::GL_UNSIGNED_BYTE, self.pixels.ptr);
    self.textureId = texture;
    self.bindTexture();
}
<*
 @require self.chars.ptr != null
 *>
fn stb_truetype::PackedChar*! FontAtlas.getChar(&self, uint codepoint)
{
    long l = 0; long r = self.chars.len - 1;
    long m;

    while (l >= 0 && l <= r)
    {
        m = (l + r) / 2;
        if (self.chars[m].codepoint == codepoint)
        {
            return &self.chars[m];
        }
        else if (m < codepoint)
        {
            l = m + 1;
        }
        else
        {
            r = m - 1;
        }
    }

    io::eprintfn("could not find char '%c' (%d)", codepoint, codepoint);
    return FontAtlasError.CHAR_NOT_FOUND?;
}
<*
 @require gl::isTexture(self.textureId)
 *>
fn void FontAtlas.bindTexture(&self)
{
    gl::bindTexture(gl::GL_TEXTURE_2D, self.textureId);           
}
struct GridCharFg
{
    uint codepoint;
    float[<3>] color;
}
<*
 @require gridW * gridH < grid.len
 @require fontSize > 0
 *>
fn void! FontAtlas.renderGridFg(&self, GridCharFg[] grid, int width, int height, int gridW, int gridH, float fontSize)
{
    int uniformIdx = 0;
    for (int xIdx = 0; xIdx < gridW; xIdx++)
    {
        for (int yIdx = 0; yIdx < gridH; yIdx++)
        {
            int idx = xIdx + gridW * yIdx;
            GridCharFg c = grid[idx];

            float x = (float)(int)(xIdx * width / gridW);
            float y = (float)(int)((gridH - yIdx - 1) * height / gridH);

            stb_truetype::PackedChar* pChar = self.getChar(c.codepoint)!;

            float s = fontSize / self.fontSize;

            float w = (float)(pChar.x1 - pChar.x0) * s;
            float h = (float)(pChar.y1 - pChar.y0) * s;

            float xo = pChar.xoff * s;
            float yo = pChar.yoff * s - 4;

            x += xo;
            y -= yo + h;

            x = x / width  * 2 - 1;
            y = y / height * 2 - 1;
            w = w / width  * 2;
            h = h / height * 2;

            float texPosX  = (float)pChar.x0 / self.width;
            float texPosY  = (float)pChar.y0 / self.height;
            float texSizeX = (float)(pChar.x1 - pChar.x0) / self.width;
            float texSizeY = (float)(pChar.y1 - pChar.y0) / self.height;

            if (uniformIdx >= renderer::ARRAY_MAX)
            {
                uniformIdx = 0;
                self.renderer.renderFg();
            }

            self.renderer.instanceData[uniformIdx].quadPos  = { x, y };
            self.renderer.instanceData[uniformIdx].quadSize = { w, h };
            self.renderer.instanceData[uniformIdx].texPos   = { texPosX, texPosY };
            self.renderer.instanceData[uniformIdx].texSize  = { texSizeX, texSizeY };
            self.renderer.instanceData[uniformIdx].color    = c.color;

            uniformIdx++;
        }
    }
    self.renderer.renderFg(uniformIdx);
}
struct GridCharBg
{
    inline float[<3>] color;
}
<*
 @require gridW * gridH < grid.len
 @require fontSize > 0
 *>
fn void! FontAtlas.renderGridBg(&self, GridCharBg[] grid, int width, int height, int gridW, int gridH, float fontSize)
{
    int uniformIdx = 0;
    int gridStartIdx = 0; GridCharBg gridStartChar = grid[0];
    for (int xIdx = 0; xIdx < gridW; xIdx++)
    {
        for (int yIdx = 0; yIdx < gridH; yIdx++)
        {
            int idx = xIdx + gridW * yIdx;
            GridCharBg c = grid[idx];

            float x = (float)(int)(xIdx * width / gridW);
            float y = (float)(int)((gridH - yIdx - 1) * height / gridH);

            float s = fontSize / self.fontSize;

            float w = (float)(int)(width / gridW) * s;
            float h = (float)(int)(height / gridH) * s;

            x = x / width  * 2 - 1;
            y = y / height * 2 - 1;
            w = w / width  * 2;
            h = h / height * 2;

            if (uniformIdx >= renderer::ARRAY_MAX)
            {
                uniformIdx = 0;
                self.renderer.renderFg();
            }

            self.renderer.instanceData[uniformIdx].quadPos  = { x, y };
            self.renderer.instanceData[uniformIdx].quadSize = { w, h };
            self.renderer.instanceData[uniformIdx].texPos   = { 0, 0 };
            self.renderer.instanceData[uniformIdx].texSize  = { 0, 0 };
            self.renderer.instanceData[uniformIdx].color    = c.color;

            uniformIdx++;
        }
    }
    self.renderer.renderBg(uniformIdx);
}
fn void FontAtlas.free(&self)
{
    mem::free(self.fontFile);
    mem::free(self.chars);
    mem::free(self.pixels);
    gl::deleteTextures(1, &self.textureId);
    self.renderer.free();
}

<*
 @require filename.ptr != null
 @require buffer.ptr != null
 *>
fn char[]! readFile(String filename, char[] buffer) @local
{
    File file = file::open(filename, "r")!;
    defer (void)file.close();
    file.read(buffer)!;
    return buffer; 
}

module glyph::renderer;
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

    Vec3f color;
}
struct Renderer
{
    Vertex[6] vertices;
    uint vao;
    uint vbo;
    uint shader;

    uint instanceVbo;
    InstanceData[ARRAY_MAX] instanceData;

    uint uniformUseTexture;
}

fault RendererError
{
    CREATE_SHADER_VERT_FAIL,
    CREATE_SHADER_FRAG_FAIL,
    LINK_SHADER_FAIL,
}
fn void! Renderer.init(&self)
{
    self.vertices = {
                      { { 0.0, 0.0 } }, // bottom left
                      { { 1.0, 0.0 } }, // bottom right
                      { { 0.0, 1.0 } }, // top left
                      { { 1.0, 0.0 } }, // bottom right
                      { { 0.0, 1.0 } }, // top left
                      { { 1.0, 1.0 } }, // top right
                    };

    gl::genVertexArrays(1, &self.vao);
    gl::genBuffers(1, &self.vbo);

    gl::bindVertexArray(self.vao);

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(self.vertices), (void*)&self.vertices, gl::GL_STATIC_DRAW);

    int attr = 0;
    gl::enableVertexAttribArray(attr);
    gl::vertexAttribPointer(attr, 2, gl::GL_FLOAT, false, Vertex.sizeof, (void*)Vertex.position.offsetof);
    attr++;

    gl::genBuffers(1, &self.instanceVbo);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.instanceVbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(self.instanceData), (void*)&self.instanceData, gl::GL_DYNAMIC_DRAW);

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
    gl::vertexAttribPointer(attr, 3, gl::GL_FLOAT, false, InstanceData.sizeof, (void*)InstanceData.color.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;

    self.shader = loadShader(&vertexShaderSource, &fragmentShaderSource)!;
    self.uniformUseTexture = gl::getUniformLocation(self.shader, "useTexture");
    gl::useProgram(self.shader);
}

<*
 @require gl::isBuffer(self.instanceVbo)
 *>
fn void Renderer.renderFg(&self, usz count = ARRAY_MAX)
{
    if (count == 0) return;

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.instanceVbo);
    gl::bufferSubData(gl::GL_ARRAY_BUFFER, 0, count * InstanceData.sizeof, &self.instanceData);
    gl::uniform1i(self.uniformUseTexture, 1);
    gl::drawArraysInstanced(gl::GL_TRIANGLES, 0, self.vertices.len, count);
}
<*
 @require gl::isBuffer(self.instanceVbo)
 *>
fn void Renderer.renderBg(&self, usz count = ARRAY_MAX)
{
    if (count == 0) return;

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.instanceVbo);
    gl::bufferSubData(gl::GL_ARRAY_BUFFER, 0, count * InstanceData.sizeof, &self.instanceData);
    gl::uniform1i(self.uniformUseTexture, 0);
    gl::drawArraysInstanced(gl::GL_TRIANGLES, 0, self.vertices.len, count);
}

fn void Renderer.free(&self)
{
    gl::deleteVertexArrays(1, &self.vao);
    gl::deleteBuffers(1, &self.vbo);
    gl::deleteBuffers(1, &self.instanceVbo);
    gl::deleteProgram(self.shader);
}

<*
 @param [&in] vert
 @param [&in] frag
 *>
fn uint! loadShader(ZString* vert, ZString* frag) @private
{
    bool success;
    char[512] infoLog;

    uint vertexShader = gl::createShader(gl::GL_VERTEX_SHADER);
    gl::shaderSource(vertexShader, 1, vert, null);
    gl::compileShader(vertexShader);
    defer gl::deleteShader(vertexShader);

    uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(fragmentShader, 1, frag, null);
    gl::compileShader(fragmentShader);
    defer gl::deleteShader(fragmentShader);

    uint shader = gl::createProgram();
    gl::attachShader(shader, vertexShader);
    gl::attachShader(shader, fragmentShader);
    gl::linkProgram(shader);

    return shader;
}


ZString vertexShaderSource @private = `
#version 330 core

layout (location = 0) in vec2 vertPos;
layout (location = 1) in vec2 quadPos;
layout (location = 2) in vec2 quadSize;
layout (location = 3) in vec2 texPos;
layout (location = 4) in vec2 texSize;
layout (location = 5) in vec3 color;

vec2 getPos(vec2 inVec) {
    return quadPos + quadSize * inVec;
}

out VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    vec3 color;
} vs_out;

void main() {
    gl_Position = vec4(getPos(vertPos), 0.0, 1.0);
    vs_out.uv = vertPos;
    vs_out.idx = gl_InstanceID;
    vs_out.texPos  = texPos;
    vs_out.texSize = texSize;
    vs_out.color   = color;
}
`;
ZString fragmentShaderSource @private = `
#version 330 core

in VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    vec3 color;
} fs_in;

uniform sampler2D tex;
uniform int useTexture = 1; // boolean

out vec4 FragColor;

void main() {
    vec2 uv = fs_in.texPos + fs_in.texSize * fs_in.uv;
    float color = texture(tex, uv).x * useTexture + (1 - useTexture); // same as comparison
    vec4 result = vec4(fs_in.color, color);
    FragColor = result;
}
`;
