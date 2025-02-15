module terminal;

import window;
import input;
import renderer;
import glfw;
import schrift;

import std::io;

fn int main(String[] args)
{
    io::printn(schrift::version());

    int s = 2;
    schrift::Sft sft = {
        .xScale = 16.0 * s,
        .yScale = 16.0 * s,
        .flags = SFT_DOWNWARD_Y,
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
	char[] pixels = mem::new_array(char, (usz)img.width * (usz)img.height);
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
