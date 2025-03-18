module glyph;

module glyph::font_atlas;

import std::io;
import std::math;
import std::math::matrix;
import std::core::mem;
import std::collections::list;
import std::collections::triple;
import std::collections::range;
import std::ascii;

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
 @require file_name.ptr != null
 @require font_size > 0
 *>
fn void! FontAtlas.init(&self, String file_name, float font_size, uint start_codepoint = 0, uint end_codepoint = uint.max)
{
    self.startCodepoint = start_codepoint; self.endCodepoint = end_codepoint;
    self.width = 1024; self.height = 1024;
    self.fontSize = font_size;
    self.renderer.init()!;

    self.fontFile = mem::new_array(char, io::file::get_size(file_name))!!;
    read_file(file_name, self.fontFile)!;

    stb_truetype::initFont(&self.fontInfo, self.fontFile.ptr, 0);

    self.chars = mem::new_array(stb_truetype::PackedChar, self.fontInfo.numGlyphs);
    self.pixels = mem::new_array(char, (usz)(self.width * self.height));

    stb_truetype::PackContext ctx;

    if (stb_truetype::packBegin(&ctx, self.pixels.ptr, self.width, self.height, 0, 1, null) == 0) return FontAtlasError.PACKBEGIN_FAILED?;
    stb_truetype::packFontRange(&ctx, self.fontFile, 0, font_size, self.startCodepoint, self.fontInfo.numGlyphs, self.chars.ptr);
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

    self.charMaxX = self.get_char('#')!!.xadvance;
    self.charMaxY = self.fontSize;

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
    self.bind_texture();
}
<*
 @require self.chars.ptr != null
 *>
fn stb_truetype::PackedChar*! FontAtlas.get_char(&self, uint codepoint)
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
fn void FontAtlas.bind_texture(&self)
{
    gl::bindTexture(gl::GL_TEXTURE_2D, self.textureId);
}
struct GridCharFg
{
    uint codepoint;
    char[<3>] color;
}
<*
 @require (usz)(grid_w * grid_h) <= grid.len
 @require font_size > 0
 *>
fn void FontAtlas.render_grid_fg(&self, GridCharFg[] grid, uint width, uint height, uint grid_w, uint grid_h, float font_size, usz char_start = 0)
{
    int uniform_idx = 0;
    for (int y_idx = 0; y_idx < grid_h; y_idx++)
    {
        for (int x_idx = 0; x_idx < grid_w; x_idx++)
        {
            usz idx = ((usz)(x_idx + grid_w * y_idx) + char_start) % grid.len;
            GridCharFg c = grid[idx];
            if (ascii::is_space((char)c.codepoint)) continue;

            float x = (float)(int)(x_idx * width / grid_w);
            float y = (float)(int)((grid_h - y_idx - 1) * height / grid_h);

            stb_truetype::PackedChar*! pChar = self.get_char(c.codepoint);
            if (catch excuse = pChar) continue;

            float s = font_size / self.fontSize;

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

            if (uniform_idx >= renderer::ARRAY_MAX)
            {
                uniform_idx = 0;
                self.renderer.render_fg();
            }

            self.renderer.instanceData[uniform_idx].quadPos  = { x, y };
            self.renderer.instanceData[uniform_idx].quadSize = { w, h };
            self.renderer.instanceData[uniform_idx].texPos   = { texPosX, texPosY };
            self.renderer.instanceData[uniform_idx].texSize  = { texSizeX, texSizeY };
            self.renderer.instanceData[uniform_idx].color    = { c.color.x, c.color.y, c.color.z };

            uniform_idx++;
        }
    }
    self.renderer.render_fg(uniform_idx);
}
struct GridCharBg
{
    inline char[<3>] color;
}
def GridBgRange = List{Triple{uint, Range{uint}, char[<3>]}} @local;
GridBgRange bg_range @local;
macro get_grid_bg_ranges(grid, grid_w, grid_h, char_start) @local
{
    uint scroll = (uint)(char_start / grid_w);
    if (!bg_range.is_initialized())
    {
        bg_range.init(mem);
    }
    else
    {
        bg_range.clear();
    }
    uint x_idx;
    uint y_idx;
    for (; y_idx < grid_h; y_idx++)
    {
        x_idx = 0;
        uint idx = (uint)(char_start + x_idx + (usz)(grid_w * y_idx)) % grid.len;

        bg_range.push({
            .first = y_idx + scroll,
            .second.start = 0,
            .third = grid[idx],
        });
        for (; x_idx < grid_w; x_idx++)
        {
            idx = (uint)(char_start + x_idx + (usz)(grid_w * y_idx)) % grid.len;
            if (grid[idx].color == bg_range[^1].third)
            {
                bg_range[^1].second.end = x_idx;
            }
            else
            {
                bg_range.push({
                    .first = y_idx,
                    .second = { x_idx, (uint)(grid_w - 1) },
                    .third = grid[idx],
                });
            }
        }
    }
}
<*
 @require (usz)(grid_w * grid_h) <= grid.len
 @require font_size > 0
 *>
fn void FontAtlas.render_grid_bg(&self, GridCharBg[] grid, uint width, uint height, uint grid_w, uint grid_h, float font_size, usz char_start = 0)
{
    get_grid_bg_ranges(grid, grid_w, grid_h, char_start);
    usz uniform_idx = 0;
    foreach (elem : bg_range)
    {
        uint y_idx = elem.first;
        uint last_grid_x_idx = elem.second.start;
        uint x_idx = elem.second.end;
        usz block_size = elem.second.len();
        char[<3>] c = elem.third;

        float x = (float)(int)(last_grid_x_idx * width / grid_w);
        float y = (float)(int)((grid_h - y_idx - 1) * height / grid_h);

        float s = font_size / self.fontSize;

        float w = (float)(int)(width / grid_w) * s * block_size;
        float h = (float)(int)(height / grid_h) * s;

        x = x / width  * 2 - 1;
        y = y / height * 2 - 1;
        w = w / width  * 2;
        h = h / height * 2;

        if (uniform_idx >= renderer::ARRAY_MAX)
        {
            uniform_idx = 0;
            self.renderer.render_bg();
        }

        self.renderer.instanceData[uniform_idx].quadPos  = { x, y };
        self.renderer.instanceData[uniform_idx].quadSize = { w, h };
        self.renderer.instanceData[uniform_idx].texPos   = { 0, 0 };
        self.renderer.instanceData[uniform_idx].texSize  = { 0, 0 };
        self.renderer.instanceData[uniform_idx].color    = { c.x, c.y, c.z };

        uniform_idx++;
    }
    self.renderer.render_bg(uniform_idx);
}
fn void FontAtlas.free(&self)
{
    mem::free(self.fontFile);
    mem::free(self.chars);
    mem::free(self.pixels);
    gl::deleteTextures(1, &self.textureId);
    self.renderer.free();
    bg_range.free(); // if more than one font atlas, it will be reinitialized no problem
}

<*
 @require file_name.ptr != null
 @require buffer.ptr != null
 *>
fn char[]! read_file(String file_name, char[] buffer) @local
{
    File file = file::open(file_name, "r")!;
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
def Vec3i =  char[3] @local;
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

    union
    {
        Vec3i color;
        struct
        {
            char r;
            char g;
            char b;
        }
    }
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
    gl::vertexAttribIPointer(attr, 3, gl::GL_UNSIGNED_BYTE, InstanceData.sizeof, (void*)InstanceData.color.offsetof);
    gl::vertexAttribDivisor(attr, 1);
    attr++;

    self.shader = loadShader(&vert_shader_source, &frag_shader_source)!;
    self.uniformUseTexture = gl::getUniformLocation(self.shader, "useTexture");
    gl::useProgram(self.shader);
}

<*
 @require gl::isBuffer(self.instanceVbo)
 *>
fn void Renderer.render_fg(&self, usz count = ARRAY_MAX)
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
fn void Renderer.render_bg(&self, usz count = ARRAY_MAX)
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

    uint vert_shader = gl::createShader(gl::GL_VERTEX_SHADER);
    gl::shaderSource(vert_shader, 1, vert, null);
    gl::compileShader(vert_shader);
    defer gl::deleteShader(vert_shader);

    uint frag_shader = gl::createShader(gl::GL_FRAGMENT_SHADER);
    gl::shaderSource(frag_shader, 1, frag, null);
    gl::compileShader(frag_shader);
    defer gl::deleteShader(frag_shader);

    uint shader = gl::createProgram();
    gl::attachShader(shader, vert_shader);
    gl::attachShader(shader, frag_shader);
    gl::linkProgram(shader);

    return shader;
}


ZString vert_shader_source @private = `
#version 330 core

layout (location = 0) in vec2 vertPos;
layout (location = 1) in vec2 quadPos;
layout (location = 2) in vec2 quadSize;
layout (location = 3) in vec2 texPos;
layout (location = 4) in vec2 texSize;
layout (location = 5) in ivec3 color;

vec2 getPos(vec2 inVec) {
    return quadPos + quadSize * inVec;
}

out VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    flat ivec3 color;
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
ZString frag_shader_source @private = `
#version 330 core

in VS_OUT {
    flat int idx;
    vec2 uv;
    vec2 texPos;
    vec2 texSize;
    flat ivec3 color;
} fs_in;

uniform sampler2D tex;
uniform int useTexture = 1; // boolean

out vec4 FragColor;

void main() {
    FragColor = vec4(fs_in.color / 255.0, useTexture == 0? 1 : texture(tex, fs_in.texPos + fs_in.texSize * fs_in.uv).x);
}
`;
