module glyph;

import std::io;
import std::math;
import std::math::matrix;
import std::core::mem;
import std::collections::list;

import opengl;
import window;
import renderer;
import stb_truetype;

struct FontAtlas
{
    ushort width; ushort height;
    float fontSize;

    uint startCodepoint; uint endCodepoint;
    stb_truetype::PackedChar[] chars;
    char[] pixels;
    uint textureId;
    float charMaxX; float charMaxY;

    renderer::Renderer* renderer;
}
fault FontAtlasError
{
    PACKBEGIN_FAILED,
    CHAR_NOT_FOUND,
}
const uint START_CP = 32; const uint END_CP = 127;
fn FontAtlas*! createFontAtlas(String filename, float fontSize)
{
    FontAtlas* self = mem::new(FontAtlas);
    self.startCodepoint = START_CP; self.endCodepoint = END_CP;
    self.width = 128; self.height = 128;
    self.fontSize = fontSize;
    self.renderer = renderer::create()!;

    self.chars = mem::new_array(stb_truetype::PackedChar, END_CP);
    self.pixels = mem::new_array(char, (usz)(self.width * self.height));

    char[] contents = mem::new_array(char, io::file::get_size(filename))!!;
    defer mem::free(contents);
    readFile(filename, contents)!;

    stb_truetype::PackContext* ctx = mem::new(stb_truetype::PackContext);

    if (stb_truetype::packBegin(ctx, self.pixels.ptr, self.width, self.height, 0, 1, null) == 0) return FontAtlasError.PACKBEGIN_FAILED?;
    stb_truetype::packFontRange(ctx, contents, 0, fontSize, self.startCodepoint, self.endCodepoint, self.chars.ptr);
    stb_truetype::packEnd(ctx);
    mem::free(ctx);

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

    return self;
}
fn stb_truetype::PackedChar*! FontAtlas.getChar(FontAtlas* self, uint codepoint)
{
    long l = self.startCodepoint; long r = self.endCodepoint;
    long m;

    while (l >= 0 && l <= r)
    {
        m = (l + r) / 2;
        if (m == codepoint)
        {
            return &self.chars[m - self.startCodepoint];
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
fn void FontAtlas.bindTexture(FontAtlas* self)
{
    gl::bindTexture(gl::GL_TEXTURE_2D, self.textureId);           
}
struct GridChar
{
    uint codepoint;
    float[<3>] color;
}
fn void! FontAtlas.renderGrid(FontAtlas* self, GridChar[] grid, int width, int height, int gridW, int gridH, float fontSize)
{
    int uniformIdx = 0;
    for (int xIdx = 0; xIdx < gridW; xIdx++)
    {
        for (int yIdx = 0; yIdx < gridH; yIdx++)
        {
            int idx = xIdx + gridW * yIdx;
            GridChar c = grid[idx];

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
                self.renderer.render();
            }

            self.renderer.instanceData[uniformIdx].quadPos  = { x, y };
            self.renderer.instanceData[uniformIdx].quadSize = { w, h };
            self.renderer.instanceData[uniformIdx].texPos   = { texPosX, texPosY };
            self.renderer.instanceData[uniformIdx].texSize  = { texSizeX, texSizeY };
            self.renderer.instanceData[uniformIdx].fg       = c.color;

            uniformIdx++;
        }
    }
    self.renderer.render(uniformIdx);
}
fn void FontAtlas.free(FontAtlas* self)
{
    mem::free(self.chars);
    mem::free(self.pixels);
    gl::deleteTextures(1, &self.textureId);
    self.renderer.free();
    mem::free(self);
}

fn char[]! readFile(String filename, char[] buffer) @local
{
    File file = file::open(filename, "r")!;
    defer (void)file.close();
    file.read(buffer)!;
    return buffer; 
}
