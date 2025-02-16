module glyph;

import std::io;
import std::math;
import std::math::matrix;
import std::core::mem;

import opengl;
import schrift;
import window;
import renderer;

struct Glyph
{
    schrift::UChar codepoint;
    schrift::GMetrics metrics;
    double scale;
    uint textureId;
    Renderer* renderer;
}

fn Glyph* create(schrift::UChar codepoint, double scaling = 16)
{
    Glyph* out = mem::new(Glyph);
    
    double s = scaling;
    schrift::Sft sft = {
        .xScale = s,
        .yScale = s,
    };

    sft.font = schrift::loadfile("test.ttf");
    if (sft.font == null)
    {
        io::eprintn("font loading failed");
        return null;
    }
    defer schrift::freefont(sft.font);

    schrift::Glyph gid;  //  unsigned long gid;
	if (schrift::lookup(&sft, codepoint, &gid) < 0)
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
    gl::bindTexture(gl::GL_TEXTURE_2D, texture);

    out.metrics = mtx;
    out.codepoint = codepoint;
    out.scale = s / 2;
    out.textureId = texture;
    out.renderer = renderer::create();

    return out;
}
fn void Glyph.render(Glyph* self, window::Window* window, double x, double y, double fontSize)
{
    double s = fontSize / self.scale;
    x += self.metrics.leftSideBearing * s;
    y += self.metrics.yOffset * s;
    double w = self.metrics.minWidth * s;
    double h = self.metrics.minHeight * s;

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

    gl::bindTexture(gl::GL_TEXTURE_2D, self.textureId);
    self.renderer.render();
}
fn void Glyph.free(Glyph* self)
{
    gl::deleteTextures(1, &self.textureId);
    self.renderer.free();
    mem::free(self);
}
