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
    int width; int height;
    float fontSize;

    uint startCodepoint; uint endCodepoint;
    stb_truetype::PackedChar[] chars;
    char[] pixels;
    uint textureId;

    renderer::Renderer* renderer;
}
fault FontAtlasError
{
    PACKBEGIN_FAILED,
    CHAR_NOT_FOUND,
}
const uint START_CP = 32; const uint END_CP = 127;
fn FontAtlas*! createFontAtlas(float fontSize)
{
    FontAtlas* self = mem::new(FontAtlas);
    self.startCodepoint = START_CP; self.endCodepoint = END_CP;
    self.width = 128; self.height = 128;
    self.fontSize = fontSize;
    self.renderer = renderer::create();

    self.chars = mem::new_array(stb_truetype::PackedChar, END_CP);
    self.pixels = mem::new_array(char, (usz)(self.width * self.height));

    char[] contents = mem::new_array(char, io::file::get_size("test.ttf"))!!;
    defer mem::free(contents);
    readFile("test.ttf", contents)!;

    stb_truetype::PackContext* ctx = mem::new(stb_truetype::PackContext);

    if (stb_truetype::packBegin(ctx, self.pixels.ptr, self.width, self.height, 0, 1, null) == 0) return FontAtlasError.PACKBEGIN_FAILED?;
    stb_truetype::packFontRange(ctx, contents, 0, fontSize, self.startCodepoint, self.endCodepoint, self.chars.ptr);
    stb_truetype::packEnd(ctx);
    mem::free(ctx);

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

    return self;
}
fn stb_truetype::PackedChar*! FontAtlas.getChar(FontAtlas* self, uint codepoint)
{
    long l = self.startCodepoint; long r = self.endCodepoint;
    long m;

    while (l >= 0 && l <= r)
    {
        m = (l + r) / 2;
        // io::printfn("comparing %03d to %03d (%c to %c)", codepoint, m, codepoint, m);
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

    // io::eprintfn("ERROR: could not find codepoint '%c'", codepoint);
    return FontAtlasError.CHAR_NOT_FOUND?;
}
fn void FontAtlas.bindTexture(FontAtlas* self)
{
    gl::bindTexture(gl::GL_TEXTURE_2D, self.textureId);           
}
fn void! FontAtlas.renderGlyph(FontAtlas* self, window::Window* window, uint codepoint, float x, float y, float fontSize)
{
    stb_truetype::PackedChar* pChar = self.getChar(codepoint)!;

    float s = fontSize / self.fontSize;
    x += pChar.xoff * s;
    y += pChar.yoff * s;
    float w = (float)math::abs(pChar.x1 - pChar.x0) * s;
    float h = (float)math::abs(pChar.y1 - pChar.y0) * s;

    float x1 = (float)x / window.width  * 2 - 1;
    float y1 = (float)y / window.height * 2 - 1;
    float x2 = (float)(x + w) / window.width  * 2 - 1;
    float y2 = (float)(y + h) / window.height * 2 - 1;

    self.renderer.vertices[0].position = { x2, y1, 0 };
    self.renderer.vertices[1].position = { x2, y2, 0 };
    self.renderer.vertices[2].position = { x1, y2, 0 };
    self.renderer.vertices[3].position = { x1, y1, 0 };

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(self.renderer.vertices),
                   (void*)&self.renderer.vertices, gl::GL_DYNAMIC_DRAW);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);

    float texPosX  = (float)pChar.x0 / self.width;
    float texPosY  = (float)pChar.y0 / self.height;
    float texSizeX = (float)(pChar.x1 - pChar.x0) / self.width;
    float texSizeY = (float)(pChar.y1 - pChar.y0) / self.height;

    gl::uniform2f(gl::getUniformLocation(self.renderer.shader, "texPos"), texPosX, texPosY);
    gl::uniform2f(gl::getUniformLocation(self.renderer.shader, "texSize"), texSizeX, texSizeY);

    self.bindTexture();
    self.renderer.render();
}

fn char[]! readFile(String filename, char[] buffer) @local
{
    File file = file::open(filename, "r")!;
    defer (void)file.close();
    file.read(buffer)!;
    return buffer; 
}
