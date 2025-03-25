module terminal;

import pty;
import glfw;
import opengl;
import glyph;
import window;
import input;

import std::core::mem;
import std::thread;
import std::io;
import std::math;
import std::collections::list;

faultdef
    PTY_DEAD,
;

struct TermSettings
{
    uint[<2>] sco;
    uint[<2>] dec;
    bool showCursor;
    bool reportFocus;
    bool alternateBuffer;
    bool bracketedPaste;
}
struct Grid @local
{
    GridCharFg[] fg;
    GridCharBg[] bg;
    union
    {
        struct
        {
            uint width;
            uint height;
        }
        uint[<2>] dimensions;
    }
    float fontSize;
    usz size;
}
struct Cursor
{
    inline uint[<2>] position;
    char[<3>] bg;
    char[<3>] fg;
    bitstruct opts : char
    {
        bool bold;
        bool faint;
        bool italics;
        bool strikethrough;
        bool underline;
    }
}
struct Tabs
{
    inline char spaces;
    // positions where a tabstop has been added by user
    List{uint[<2>]} tabstopsNew;
    // positions where a tabstop has been removed by user
    List{uint[<2>]} tabstopsDel;
}
struct Scroll
{
    inline long amount;
    uint start;
    uint end;
}
struct Terminal
{
    window::Window window;
    FontAtlas fontAtlas;
    Cursor cursor;
    Grid grid;
    char[<3>] bg;
    char[<3>] fg;
    TermSettings settings;
    Tabs tabs;
    // if last command pty sent was incomplete, this will be populated and, on the next read, will be appended and interpreted
    Char32[] lastBuffer;
    // number of lines that will be clipped from the top of the screen
    Scroll scroll;
}
Terminal terminal @public @builtin;

<*
 Initializes the following:
 - Pty
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters

 @require window_width > 0 && window_height > 0
 @require font_name.ptr != null && font_name.len > 0
 @require window_name != null
 @require font_size > 0
 @require grid_size > 0
 *>
fn void? Terminal.init(&self, int window_width = 0, int window_height = 0, String font_name, ZString window_name = "terminal", float font_size = 20.0f, usz grid_size = 32400, char[<3>] bg = {0,0,0}, char[<3>] fg = {1,1,1})
{
    pty.init()!;

    window::init_system();
    self.window.init(window_width, window_height, window_name)!;
    defer catch { window::terminate_system(); }

    input_manager.init(&self.window);
    input_manager.add_key_press_callback(&key_press_callback);

    gl::enable(gl::GL_DEBUG_OUTPUT);
    gl::debugMessageCallback(&debug_message_callback, null);

    self.fontAtlas.init(font_name, font_size)!;
    defer catch { self.fontAtlas.free(); }

    self.grid = {
        .fg = mem::new_array(GridCharFg, grid_size),
        .bg = mem::new_array(GridCharBg, grid_size),
        .dimensions = {
            (uint)((float)window_width  / self.fontAtlas.charMaxX),
            (uint)((float)window_height / self.fontAtlas.charMaxY),
        },
        .fontSize = font_size,
        .size = grid_size,
    };
    defer catch { self.grid.free(); }
    self.bg = bg;
    self.fg = fg;
    for (usz i = 0; i < grid_size; i++)
    {
        self.grid.fg[i] = { ' ', fg };
        self.grid.bg[i].color = self.bg;
    }
    self.cursor = { .position = { 0, 0 }, .bg = self.bg, .fg = self.fg };

    self.tabs.spaces = 8;
    self.tabs.tabstopsNew.init(mem);
    self.tabs.tabstopsDel.init(mem);

    self.scroll = {
        .amount = 0,
        .start = 0,
        .end = self.grid.height - 1,
    };

    pty.set_winsize(self.grid.dimensions);
}
<*
 Assigns character to terminal's current cursor position

 @require self.grid.fg.ptr != null
 @require self.grid.bg.ptr != null
 *>
fn void Terminal.assign_char(&self, uint codepoint)
{
    self.grid.fg[self.get_grid_idx(self.cursor)] = { .codepoint = codepoint, .color = self.cursor.fg };
    self.grid.bg[self.get_grid_idx(self.cursor)].color = self.cursor.bg;
}
<*
 Assigns background color to terminal's current cursor position

 @require self.grid.bg.ptr != null
 *>
fn void Terminal.assign_char_bg(&self, char[<3>] bg)
{
    self.cursor.bg = bg;
}
<*
 Assigns foreground color to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assign_char_fg(&self, char[<3>] fg)
{
    self.cursor.fg = fg;
}
macro void Terminal.clear(&self) => self.erase({ 0, 0 }, self.grid.size);
fn void Terminal.erase(&self, uint[<2>] start, usz length)
{
    usz start_idx = self.get_grid_idx(start);
    usz end_idx = start_idx + length;
    for (usz i = start_idx; i < end_idx; i++)
    {
        self.grid.fg[i % self.grid.size] = {
            .codepoint = ' ',
            .color = self.fg,
        };
        self.grid.bg[i % self.grid.size].color = self.bg;
    }
}
macro usz Terminal.get_grid_idx(&self, uint[<2>] position) => ((usz)position.x + self.grid.width * (usz)(position.y + self.scroll.amount)) % self.grid.size;
fn void Terminal.set_cursor(&self, long[<2>] position) @inline
{
    self.cursor.position = { (uint)math::clamp(position.x, 0, self.grid.width - 1), (uint)math::clamp(position.y, 0, self.grid.height - 1) };
}
fn void Terminal.move_cursor_clamp(&self, long[<2>] translation) @inline
{
    long[<2>] new_cursor = (long[<2>])self.cursor.position + translation;
    self.cursor.position = { (uint)math::clamp(new_cursor.x, 0, self.grid.width - 1), (uint)math::clamp(new_cursor.y, 0, self.grid.height - 1) };
}
fn void Terminal.move_cursor(&self, long[<2>] translation)
{
    long[<2>] new_cursor = (long[<2>])self.cursor.position + translation;
    while (new_cursor.x < 0)
    {
        new_cursor.x += self.grid.width;
        new_cursor.y -= 1;
    }
    while (new_cursor.x >= self.grid.width)
    {
        new_cursor.x -= self.grid.width;
        new_cursor.y += 1;
    }
    if (new_cursor.y < 0)
    {
        self.scroll_lines(new_cursor.y);
        new_cursor.y = 0;
    }
    else if (new_cursor.y >= self.grid.height)
    {
        self.scroll_lines(new_cursor.y - self.grid.height + 1);
        new_cursor.y = (long)self.grid.height - 1;
    }
    self.cursor.position = (uint[<2>])new_cursor;
}
macro void Terminal.save_cursor_sco(&self) => self.settings.sco = self.cursor;
macro void Terminal.save_cursor_dec(&self) => self.settings.dec = self.cursor;
macro void Terminal.restore_cursor_sco(&self) => self.cursor.position = self.settings.sco;
macro void Terminal.restore_cursor_dec(&self) => self.cursor.position = self.settings.dec;
macro Terminal.newline(&self, long row_translation = 1)
{
    self.set_cursor({ 0, (uint)((long)self.cursor.y + row_translation) });
    self.cursor.x = 0;
}
fn void Terminal.scroll_lines(&self, long amount) @inline => self.scroll.amount = (uint)((long)(self.scroll.amount + amount) % (self.grid.size / self.grid.width));
fn void Terminal.tab(&self, uint amount = 1)
{
    for (; amount > 0; amount--)
    {
        uint default_tabstop = (uint)math::ceil(++terminal.cursor.x / 8.0) * 8;
        if (!terminal.tabs.tabstopsDel.contains({ default_tabstop, terminal.cursor.y }))
        {
            terminal.set_cursor({ default_tabstop, terminal.cursor.y });
            continue;
        }
        for (; terminal.cursor.x < terminal.grid.width; terminal.cursor.x++)
        {
            if (terminal.tabs.tabstopsNew.contains(terminal.cursor.position)) break;
            if ((terminal.cursor.x + 1) % 8 == 0 &&
                !terminal.tabs.tabstopsDel.contains(terminal.cursor.position)) break;
        }
    }
}
fn void? Terminal.pre_render(&self)
{
    if (self.window.sizeChanged)
    {
        uint new_width  = (uint)((float)self.window.width  / self.fontAtlas.charMaxX);
        uint new_height = (uint)((float)self.window.height / self.fontAtlas.charMaxY);
        if (self.grid.width != new_width || self.grid.height != new_height)
        {
            self.grid.dimensions = { new_width, new_height };
            pty.set_winsize(self.grid.dimensions);
        }
    }

    if (!pty.is_alive())
    {
        io::printn("pty is dead");
        return PTY_DEAD?;
    }

    String? pty_read = pty.read();
    if (catch excuse = pty_read)
    {
        switch (excuse)
        {
            case pty::PTY_NOT_READY:
                break;
            default:
                io::eprintfn("failed to read from pty: %s", excuse);
                return excuse?;
        }
    }
    else
    {
        Allocator temp_alloc = tmem;
        if (try buffer = pty_read.to_utf32(temp_alloc))
        {
            List{uint} new_buf;
            new_buf.init(temp_alloc);
            new_buf.add_array(self.lastBuffer);
            new_buf.add_array(buffer);
            if (catch interpret_excuse = terminal.interpret(new_buf.array_view()))
            {
                io::eprintfn("couldnt interpret buffer: %s", interpret_excuse);
            }
            else
            {
                mem::free(self.lastBuffer);
                self.lastBuffer = {};
            }
        }
    }
}
fn void Terminal.render(&self)
{
    self.window.clear_color(self.bg);

    usz char_start = (usz)(self.grid.width * self.scroll.amount);
    self.fontAtlas.render_grid_bg(self.grid.bg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize, (uint[<2>])((long[<2>])self.cursor.position + {0,self.scroll}), {255,255,255}, char_start: char_start);
    self.fontAtlas.render_grid_fg(self.grid.fg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize, char_start: char_start);

    self.window.refresh();
}
fn void Grid.free(&self) @local
{
    mem::free(self.bg);
    mem::free(self.fg);
}
fn void Terminal.free(&self)
{
    self.grid.free();
    self.fontAtlas.free();
    input_manager.free();
    window::terminate_system();
    pty.free();
    self.tabs.tabstopsNew.free();
    self.tabs.tabstopsDel.free();
}

module terminal @private;

import opengl;
import glfw;
import pty;

import std::io;
import std::ascii;
import std::core::mem;

fn void debug_message_callback(GLenum source,
                               GLenum type,
                               uint id,
                               GLenum severity,
                               usz length,
                               ZString message,
                               void* user_param)
{
    io::eprintfn("GL CALLBACK: type = 0x%x, severity = 0x%x, message = %s\n", type, severity, message);
}

fn void key_press_callback(Char32[] codepoints, int mods = 0)
{
    Allocator temp_alloc = tmem;
    if (codepoints.len == 1) if (mods > 0)
    {
        if (codepoints[0].is_alpha())
        {
            if (mods == glfw::MOD_CONTROL)
            {
                // ctrl-c => 0x03 ; ctrl-g -> 0x07 ; etc.
                codepoints[0] -= 'A' - 1;
            }
            else if (mods == glfw::MOD_ALT || mods == glfw::MOD_ALT | glfw::MOD_SHIFT)
            {
                codepoints[0] += mods & glfw::MOD_SHIFT ? 0 : 'a' - 'A';
                codepoints = { '\e', codepoints[0] };
            }
            else
            {
                mods_sequence_codepoints(codepoints, mods, temp_alloc);
            }
        }
        else if (codepoints[0].is_digit())
        {
            if (mods == glfw::MOD_ALT)
            {
                codepoints[0] += 0;
                codepoints = { '\e', codepoints[0] };
            }
            else
            {
                mods_sequence_codepoints(codepoints, mods, temp_alloc);
            }
        }
        else
        {
            mods_sequence_codepoints(codepoints, mods, temp_alloc);
        }
    }

    String? buffer = string::from_utf32(temp_alloc, codepoints);
    if (catch excuse = buffer) return;
    if (catch excuse = pty.write(buffer))
    {
        io::eprintfn("failed to write to pty: %s", excuse);
    }
}
macro mods_sequence_codepoints(codepoints, mods, alloc)
{
    uint new_mod = 1;
    new_mod |= mods & glfw::MOD_SHIFT   ? 1 : 0;
    new_mod |= mods & glfw::MOD_ALT     ? 2 : 0;
    new_mod |= mods & glfw::MOD_CONTROL ? 4 : 0;
    new_mod |= mods & glfw::MOD_SUPER   ? 8 : 0;
    DString builder;
    builder.init(alloc);
    builder.appendf("\e[%d;%d~", codepoints[0], new_mod);
    codepoints = builder.str_view().to_utf32(alloc)!!;
    return codepoints;
}
