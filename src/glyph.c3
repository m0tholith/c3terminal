module glyph;

import std::io;
import std::math;
import std::math::matrix;
import std::core::mem;
import std::collections::list;

import opengl;
import schrift;
import window;
import renderer;

struct Font
{
    schrift::Sft ctx;
    list::List(<Glyph*>) glyphs;
    double renderSize;
    Renderer* renderer;
}
fault FontError
{
    FONT_LOAD_FAILED,
    GLYPH_NOT_FOUND,
}
fn Font*! createFont(ZString filename, double renderSize)
{
    Font* font = mem::new(Font);
    font.renderSize = renderSize;
    font.renderer = renderer::create();
    font.glyphs.new_init();

    font.ctx = {
        .xScale = renderSize * 2,
        .yScale = renderSize * 2,
    };
    font.ctx.font = schrift::loadfile(filename);
    if (font.ctx.font == null)
    {
        return FontError.FONT_LOAD_FAILED?;
    }
    return font;
}
/*
    Tries to find glyph, and if doesn't exist, creates it
*/
fn Glyph*! Font.getGlyph(Font* self, schrift::UChar codepoint)
{
    if (try g = self.findGlyph(codepoint)) return g;

    Glyph* glyph = createGlyph(self.ctx, codepoint);
    if (glyph == null) return FontError.GLYPH_NOT_FOUND?;
    if (self.glyphs.len() == 0)
    {
        self.glyphs.push(glyph);
        return glyph;
    }

    for (usz i = 0; i < self.glyphs.len(); i++)
    {
        if (self.glyphs[i].codepoint > codepoint)
        {
            self.glyphs.insert_at(i, glyph);
            return glyph;
        }
    }
    self.glyphs.push(glyph);

    return glyph;
}
/*
    Tries to find glyph, and if doesn't exist, returns FontError.GLYPH_NOT_FOUND
*/
fn Glyph*! Font.findGlyph(Font* self, schrift::UChar codepoint)
{
    long l = 0;
    long r = self.glyphs.len() - 1;
    long m;
    while (l <= r)
    {
        m = (usz)((l + r) / 2);
        Glyph* g = self.glyphs[m];
        if (g.codepoint == codepoint)
        {
            return g;
        }
        else if (g.codepoint < codepoint)
        {
            l = m + 1;
        }
        else
        {
            r = m - 1;
        }
    }
    return FontError.GLYPH_NOT_FOUND?;
}
fn double! Font.renderGlyph(Font* self, window::Window* window, schrift::UChar codepoint, double x, double y, double fontSize)
{
    Glyph*! glyph = self.getGlyph(codepoint);
    if (catch excuse = glyph)
    {
        return excuse?;
    }

    double s = fontSize / self.renderSize;
    x += glyph.metrics.leftSideBearing * s;
    y += glyph.metrics.yOffset * s;
    double w = glyph.metrics.minWidth * s;
    double h = glyph.metrics.minHeight * s;

    float x1 = (float)x / window.width  * 2 - 1;
    float y1 = (float)y / window.height * 2 - 1;
    float x2 = (float)(x + w) / window.width  * 2 - 1;
    float y2 = (float)(y + h) / window.height * 2 - 1;

    self.renderer.vertices[0].position = { x2, y2, 0 };
    self.renderer.vertices[1].position = { x2, y1, 0 };
    self.renderer.vertices[2].position = { x1, y1, 0 };
    self.renderer.vertices[3].position = { x1, y2, 0 };

    gl::bindBuffer(gl::GL_ARRAY_BUFFER, self.renderer.vbo);
    gl::bufferData(gl::GL_ARRAY_BUFFER, $sizeof(self.renderer.vertices), (void*)&self.renderer.vertices, gl::GL_DYNAMIC_DRAW);
    gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);

    gl::bindTexture(gl::GL_TEXTURE_2D, glyph.textureId);
    self.renderer.render();

    return glyph.metrics.advanceWidth * fontSize / self.renderSize;
}
fn void! Font.renderText(Font* self, window::Window* window, String text, double x, double y, double fontSize)
{
    foreach (c : text)
    {
        double! advance = self.renderGlyph(window, c, x, y, fontSize);
        if (catch excuse = advance) return excuse?;
        x += advance;
    }
}
fn void Font.free(Font* self)
{
    schrift::freefont(self.ctx.font);
    foreach (glyph : self.glyphs)
    {
        glyph.free();
    }
    self.glyphs.free();
    mem::free(self);
}

struct Glyph
{
    schrift::UChar codepoint;
    schrift::GMetrics metrics;
    uint textureId;
}
fn Glyph* createGlyph(schrift::Sft sft, schrift::UChar c)
{
    schrift::Glyph gid;  //  unsigned long gid;
    schrift::UChar codepoint = c;
	if (schrift::lookup(&sft, c, &gid) < 0)
    {
		io::eprintn("missing glyph");
        return null;
    }

	schrift::GMetrics mtx;
	if (schrift::gmetrics(&sft, gid, &mtx) < 0)
    {
        io::eprintn("bad glyph metrics");
        return null;
    }

	schrift::Image img = {
		.width  = (mtx.minWidth + 3) & ~3,
		.height = mtx.minHeight,
	};
	char* pixels = mem::new_array(char, (usz)img.width * (usz)img.height);
    defer mem::free(pixels);
	img.pixels = pixels;
	if (schrift::render(&sft, gid, img) < 0)
	{
        io::eprintn("could not render glyph");
        return null;
    }

    uint texture;
    gl::genTextures(1, &texture);
    gl::bindTexture(gl::GL_TEXTURE_2D, texture);
    // set the texture wrapping/filtering options (on the currently bound texture object)
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_REPEAT);	
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_REPEAT);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR_MIPMAP_LINEAR);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_LINEAR);
    // load and generate the texture
    gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_RGBA, img.width, img.height, 0, gl::GL_RED, gl::GL_UNSIGNED_BYTE, pixels);
    gl::generateMipmap(gl::GL_TEXTURE_2D);
    gl::bindTexture(gl::GL_TEXTURE_2D, 0);


    return mem::new(Glyph, { codepoint, mtx, texture });
}
fn void Glyph.free(Glyph* self)
{
    gl::deleteTextures(1, &self.textureId);
    mem::free(self);
}
