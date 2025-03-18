module terminal::ansi;

import terminal;

import std::core::mem;
import std::collections::list;
import std::collections::range;
import std::ascii;
import std::io;

fault AnsiError
{
    PARSE_FAILED,
    COMMAND_NOT_FOUND,
    INCOMPLETE,
}

fn void! Terminal.interpret(&self, Char32[] buffer)
{
    for (int char_idx = 0; char_idx < buffer.len;)
    {
        int prev_char_idx = char_idx;
        if (catch excuse = parse_c1(self, &char_idx, buffer)) { switch (excuse)
        {
            case AnsiError.INCOMPLETE:
                if (self.lastBuffer.ptr == null)
                {
                    self.lastBuffer = mem::new_array(uint, buffer.len - prev_char_idx);
                }
                else
                {
                    self.lastBuffer = ((Char32*)mem::realloc(self.lastBuffer, Char32.sizeof * (self.lastBuffer.len + buffer.len - prev_char_idx)))[:self.lastBuffer.len + buffer.len - prev_char_idx];
                }
                mem::move(self.lastBuffer.ptr, buffer[prev_char_idx..].ptr, self.lastBuffer.len);
                return excuse?;
            default:
                break;
        } }
        else { continue; }
        if (catch excuse = parse_c0(self, &char_idx, buffer)) { switch (excuse)
        {
            case AnsiError.INCOMPLETE:
                if (self.lastBuffer.ptr == null)
                {
                    self.lastBuffer = mem::new_array(uint, buffer.len - prev_char_idx);
                }
                else
                {
                    self.lastBuffer = ((Char32*)mem::realloc(self.lastBuffer, Char32.sizeof * (self.lastBuffer.len + buffer.len - prev_char_idx)))[:self.lastBuffer.len + buffer.len - prev_char_idx];
                }
                mem::move(self.lastBuffer.ptr, buffer[prev_char_idx..].ptr, buffer.len - prev_char_idx);
                return excuse?;
            default:
                break;
        } }
        else { continue; }
        if (char_idx >= buffer.len) break;

        self.assign_char(buffer[char_idx]);
        self.move_cursor({ 1, 0 });
        char_idx++;
    }
}

module terminal::ansi @private;

import pty;

import std::collections::tuple;
import std::collections::list;
import std::collections::range;
import std::io;
import std::math;

def AnsiCallback = fn void(Terminal* terminal, uint[] args);
def AnsiMap = Tuple{uint, AnsiCallback}[];
fn AnsiCallback! AnsiMap.find(&self, uint command)
{
    foreach (mapping : self) if (mapping.first == command) return mapping.second;
    return AnsiError.COMMAND_NOT_FOUND?;
}

macro in_range(x, a, b) => (Range{$typeof(x)}){ a, b }.contains(x);
fn void! parse_c1(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;

    if (buffer[*char_idx] < 0x80) return AnsiError.PARSE_FAILED?;
    buffer[*char_idx] -= 0x80;
    parse_fe(terminal, char_idx, buffer)!;
}
fn void! parse_c0(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.INCOMPLETE?;
    if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;

    switch (buffer[*char_idx])
    {
        case 0x07: // bell
            (*char_idx)++;
            io::printn("bell");
        case 0x08: // backspace
            (*char_idx)++;
            terminal.move_cursor({ -1, 0 });
        case 0x09: // horizontal tab
            (*char_idx)++;
            uint default_tabstop = (uint)math::ceil(++terminal.cursor.x / 8.0) * 8;
            if (!terminal.tabs.tabstopsDel.contains({ default_tabstop, terminal.cursor.y }))
            {
                terminal.set_cursor({ default_tabstop, terminal.cursor.y });
                return;
            }
            for (; terminal.cursor.x < terminal.grid.width; terminal.cursor.x++)
            {
                if (terminal.tabs.tabstopsNew.contains(terminal.cursor.position)) break;
                if ((terminal.cursor.x + 1) % 8 == 0 &&
                    !terminal.tabs.tabstopsDel.contains(terminal.cursor.position)) break;
            }
        case 0x0A: // line feed
            (*char_idx)++;
            terminal.move_cursor({ 0, 1 });
        case 0x0B: // vertical tab
            (*char_idx)++;
            terminal.move_cursor({ 0, 1 });
        case 0x0C: // form feed
            (*char_idx)++;
            terminal.clear();
        case 0x0D: // carriage return
            (*char_idx)++;
            terminal.cursor.x = 0;
        case 0x1B: // escape
            (*char_idx)++;
            parse_fe(terminal, char_idx, buffer)!;
        default:
            return AnsiError.PARSE_FAILED?;
    }
}
fn void! parse_fe(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.INCOMPLETE?;
    if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;

    switch (buffer[*char_idx])
    {
        case 'E': // next line
            (*char_idx)++;
            terminal.move_cursor({ 0, 1 });
            terminal.cursor.x = 0;
        case 'P': // device control string
            (*char_idx)++;
            parse_dcs(terminal, char_idx, buffer)!;
        case '[': // control sequence indicator
            (*char_idx)++;
            parse_csi(terminal, char_idx, buffer)!;
        case ']': // operating system command
            (*char_idx)++;
            parse_osc(terminal, char_idx, buffer)!;
        case '(':
            (*char_idx)++;
            if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;
            // TODO: implement charsets (next char is charset)
            (*char_idx)++;
        default:
            return AnsiError.PARSE_FAILED?;
    }
}
fn void! parse_dcs(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.INCOMPLETE?;
    if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;
}
fn void! parse_csi(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.INCOMPLETE?;
    if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;

    List{uint} parameters;
    parameters.init(allocator::temp());
    Range{uint} param_range_normal  = { '0', '9' }; // numbers
    Range{uint} param_range_sep     = { ';', ';' }; // separator
    Range{uint} param_range_private = { '<', '?' }; // private function parameters

    List{uint} intermediates;
    intermediates.init(allocator::temp());
    Range{uint} intermediate_range = { '!', '/' }; // any number of these chars can come before the command

    uint command;
    Range{uint} command_range = { 0x40, 0x7E };

    int current_param = 0;
    for (; *char_idx < buffer.len; (*char_idx)++)
    {
        if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;
        uint c = buffer[*char_idx];

        if (param_range_normal.contains(c))
        {
            if (current_param >= parameters.len()) parameters.push(0);
            parameters[current_param] = parameters[current_param] * 10 + (c - '0');
        }
        else if (param_range_sep.contains(c))
        {
            while (current_param >= parameters.len()) parameters.push(0);
            current_param++;
        }
        else if (param_range_private.contains(c))
        {
            if (current_param >= parameters.len()) parameters.push(0);
            parameters[current_param] = c;
            current_param++;
        }
        else if (intermediate_range.contains(c))
        {
            intermediates.push(c);
        }
        else if (command_range.contains(c))
        {
            command = c;
            break;
        }
    }
    (*char_idx)++;

    (void)csi_map.find(command)(terminal, parameters.array_view());
}
fn void! parse_osc(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.INCOMPLETE?;
    if (buffer.len <= *char_idx) return AnsiError.INCOMPLETE?;
}

AnsiMap csi_map = {
    // cursor up/down/forward/back
    { 'A', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ? -1 : -(long)args[0] }) },
    { 'B', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ?  1 :  (long)args[0] }) },
    { 'C', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ?  1 :  (long)args[0], 0 }) },
    { 'D', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ? -1 : -(long)args[0], 0 }) },

    // move cursor to the beginning of line, n lines down/up
    { 'E', fn (term, args) => term.newline(args.len == 0 ?  1 :  args[0]) },
    { 'F', fn (term, args) => term.newline(args.len == 0 ? -1 : -args[0]) },

    // move cursor to column n
    { 'G', fn (term, args) => (void)(term.cursor.x = args.len == 0 ? 1 : (long)args[0] - 1) },

    // set cursor position
    { 'H', fn (term, args) => term.set_cursor({ args.len <= 1 ? 0 : (long)args[1] - 1,
                                                args.len == 0 ? 0 : (long)args[0] - 1 }) },

    // erase in display
    { 'J', &j_erase },
    // erase in line
    { 'K', &k_erase },

    // scroll up/down
    { 'S', fn (term, args) => term.scroll_lines(args.len == 0 ? -1 : -args[0]) },
    { 'T', fn (term, args) => term.scroll_lines(args.len == 0 ?  1 :  args[0]) },

    // set cursor position
    { 'f', fn (term, args) => term.set_cursor({ args.len <= 1 ? 0 : (long)args[1] - 1,
                                                args.len == 0 ? 0 : (long)args[0] - 1 }) },

    // select graphic rendition
    { 'm', &select_graphic_rendition },

    // enable and disable aux; don't care
    { 'i', fn (term, args) => (void)0 },

    // report cursor position
    { 'n', &send_cursor_pos },

    /// private sequences

    // save/restore cursor to sco
    { 's', fn (term, args) => term.save_cursor_sco() },
    { 'u', fn (term, args) => term.restore_cursor_sco() },

    // enable setting
    { 'h', &h_parse },
    // disable setting
    { 'l', &l_parse },
};
fn void j_erase(Terminal* term, uint[] args)
{
    if (args.len == 0)
    {
        term.erase(term.cursor, term.grid.size - term.get_grid_idx(term.cursor));
        return;
    }
    switch (args[0])
    {
        case 0:
            term.erase(term.cursor, term.grid.size - term.get_grid_idx(term.cursor));
        case 1:
            term.erase({ 0, 0 }, (usz)(term.get_grid_idx(term.cursor) + 1));
        case 2:
            term.erase({ 0, 0 }, (usz)(term.get_grid_idx(term.grid.dimensions) + 1));
        case 3:
            term.clear();
    }
}
fn void k_erase(Terminal* term, uint[] args)
{
    if (args.len == 0)
    {
        term.erase(term.cursor, (usz)(term.grid.width - term.cursor.x + 1));
        return;
    }
    switch (args[0])
    {
        case 0:
            term.erase(term.cursor, (usz)(term.grid.width - term.cursor.x + 1));
        case 1:
            term.erase({ 0, term.cursor.y }, (usz)(term.cursor.x + 1));
        case 2:
            term.erase({ 0, term.cursor.y }, term.grid.width);
    }
}
fn void send_cursor_pos(Terminal* term, uint[] args)
{
    DString builder;
    builder.init(allocator::temp());
    builder.appendf("\e[%d;%dR", term.cursor.x, term.cursor.y);
    (void)pty.write(builder.str_view());
}
fn void h_parse(Terminal* term, uint[] args)
{
    if (args.len < 2) return;

    if (args[0] != '?')
    {
        // maybe i'll find a spec that defines this
        return;
    }
    uint c = args[1];
    switch (c)
    {
        case 25:   // show cursor
            term.settings.showCursor = true;
        case 1004: // enable reporting focus
            term.settings.reportFocus = true;
        case 1049: // enable alternate screen buffer
            term.settings.alternateBuffer = true;
        case 2004: // enable bracketed paste
            term.settings.bracketedPaste = true;
        default:
            return;
    }
}
fn void l_parse(Terminal* term, uint[] args)
{
    if (args.len < 2) return;

    if (args[0] != '?')
    {
        // maybe i'll find a spec that defines this
        return;
    }
    uint c = args[1];
    switch (c)
    {
        case 25:   // hide cursor
            term.settings.showCursor = false;
        case 1004: // disable reporting focus
            term.settings.reportFocus = false;
        case 1049: // disable alternate screen buffer
            term.settings.alternateBuffer = false;
        case 2004: // disable bracketed paste
            term.settings.bracketedPaste = false;
        default:
            return;
    }
}
fn void select_graphic_rendition(Terminal* term, uint[] args)
{
    switch (args.len)
    {
        case 0:
            args = { 0 };
            nextcase;
        default:
            switch (args[0])
            {
                case 0:
                    term.cursor.bg = term.bg;
                    term.cursor.fg = term.fg;
                    term.cursor.opts = {};
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 1:
                    term.cursor.opts.bold          = true;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 2:
                    term.cursor.opts.faint         = true;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 3:
                    term.cursor.opts.italics       = true;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 4:
                    term.cursor.opts.underline     = true;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 7:
                    @swap(term.cursor.fg, term.cursor.bg);
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 9:
                    term.cursor.opts.strikethrough = true;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 21:
                    term.cursor.opts.bold          = false;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 22:
                    term.cursor.opts.bold          = false;
                    term.cursor.opts.faint         = false;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 23:
                    term.cursor.opts.italics       = false;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 24:
                    term.cursor.opts.underline     = false;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 29:
                    term.cursor.opts.strikethrough = false;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 38:
                    switch (args[1])
                    {
                        // 8-bit color
                        case 5:
                            if (args.len < 3) return;
                            term.cursor.fg = color_8_bit(args[2], args[2] & 4);
                        // 24-bit color
                        case 2:
                            if (args.len < 5) return;
                            // 38;2;<r>;<g><b>
                            term.cursor.fg = { (char)args[2], (char)args[3], (char)args[4] };
                    }
                case 39:
                    term.cursor.fg = term.fg;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                case 48:
                    switch (args[1])
                    {
                        // 8-bit color
                        case 5:
                            if (args.len < 3) return;
                            term.cursor.bg = color_8_bit(args[2], args[2] & 4);
                        // 24-bit color
                        case 2:
                            if (args.len < 5) return;
                            // 48;2;<r>;<g><b>
                            term.cursor.bg = { (char)args[2], (char)args[3], (char)(char)args[4] };
                    }
                case 49:
                    term.cursor.bg = term.bg;
                    if (args.len > 1) select_graphic_rendition(term, args[1..]);
                default:
                    // 8-bit foreground
                    if (args[0].in_range(30, 8)) // 30-37
                    {
                        term.cursor.fg = color_8_bit(args[0] - 30, false);
                        if (args.len > 1) select_graphic_rendition(term, args[1..]);
                    }
                    // 8-bit background
                    else if (args[0].in_range(40, 8)) // 40-47
                    {
                        term.cursor.bg = color_8_bit(args[0] - 40, false);
                        if (args.len > 1) select_graphic_rendition(term, args[1..]);
                    }
                    // 8-bit bright foreground
                    if (args[0].in_range(90, 8)) // 90-97
                    {
                        term.cursor.fg = color_8_bit(args[0] - 90, true);
                        if (args.len > 1) select_graphic_rendition(term, args[1..]);
                    }
                    // 8-bit bright background
                    else if (args[0].in_range(100, 8)) // 100-107
                    {
                        term.cursor.bg = color_8_bit(args[0] - 100, true);
                        if (args.len > 1) select_graphic_rendition(term, args[1..]);
                    }
            }
    }
}
macro char[<3>] color_8_bit(idx, bright)
{
    // 3/4-bit mode
    if (idx < 16) return  {
        idx & 1 ? 128 + (bright ? 127 : 0) : 0,
        idx & 2 ? 128 + (bright ? 127 : 0) : 0,
        idx & 4 ? 128 + (bright ? 127 : 0) : 0
    };
    // 8-bit mode
    idx -= 16;
    if (idx <= 215)
    {
        char[<3>] result;
        char m = (char)idx;
        result.r = m / 36;
        result.g = (m - result.r * 36) / 6;
        result.b = m - result.r * 36 - result.g * 6;
        return result * 51;
    }
    idx -= 216;
    return (char[<3>]){1,1,1} * (char)(idx * 255.0f / 24.0f);
}
