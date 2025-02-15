module terminal;

import window;
import input;
import renderer;
import glfw;
import opengl;
import schrift;

import std::io;
import std::math;

fn int main(String[] args)
{
    io::printn(schrift::version());

    int s = 2;
    schrift::Sft sft = {
        .xScale = 16.0 * s,
        .yScale = 16.0 * s,
    };

    sft.font = schrift::loadfile("test.ttf");
    if (sft.font == null)
    {
        io::eprintn("font loading failed");
        return -1;
    }
    defer schrift::freefont(sft.font);

    schrift::Glyph gid;  //  unsigned long gid;
	if (schrift::lookup(&sft, 'A', &gid) < 0)
    {
		io::eprintn("missing glyph");
        return -1;
    }

	schrift::GMetrics mtx;
	if (schrift::gmetrics(&sft, gid, &mtx) < 0)
    {
        io::eprintn("bad glyph metrics");
        return -1;
    }

	schrift::Image img = {
		.width  = (mtx.minWidth + 3) & ~3,
		.height = mtx.minHeight,
	};
    img.width = (int)math::pow(2, math::ceil(math::log(img.width, 10) / math::log(2, 10)));
    img.height = (int)math::pow(2, math::ceil(math::log(img.height, 10) / math::log(2, 10)));
	char* pixels = mem::new_array(char, (usz)img.width * (usz)img.height);
	img.pixels = pixels;
	if (schrift::render(&sft, gid, img) < 0)
	{
        io::eprintn("could not render glyph");
        return -1;
    }


    window::initSystem();
    defer window::terminateSystem();

    window::Window* window = window::create(800, 600, "m0th")!!;
    defer window.free();

    input::InputHandler* inputHandler = input::createHandler(input::InputButton[] {
        { "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 }
    });
    defer inputHandler.free();

    input::InputButton* quitInput = inputHandler.getInput("quit")!!;

    renderer::Renderer* renderer = renderer::create();
    defer renderer.free();

    
    uint texture;
    gl::genTextures(1, &texture);
    gl::bindTexture(gl::GL_TEXTURE_2D, texture);
    // set the texture wrapping/filtering options (on the currently bound texture object)
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_REPEAT);	
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_REPEAT);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR_MIPMAP_LINEAR);
    gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_LINEAR);
    // load and generate the texture
    char* data = pixels;
    gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_RED, img.width, img.height, 0, gl::GL_RED, gl::GL_UNSIGNED_BYTE, data);
    gl::generateMipmap(gl::GL_TEXTURE_2D);
    gl::bindTexture(gl::GL_TEXTURE_2D, texture);

    while (!window.shouldClose)
    {
        renderer.render();

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.refresh();
        window.clearColor(0.2f, 0.3f, 0.3f);
    }

	return 0;
}
