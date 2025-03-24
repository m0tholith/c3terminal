module terminal::ansi;

import terminal;

import std::core::mem;
import std::collections::list;
import std::collections::range;
import std::ascii;
import std::io;

faultdef
    PARSE_FAILED,
    COMMAND_NOT_FOUND,
    INCOMPLETE,
;

fn void? Terminal.interpret(&self, Char32[] buffer)
{
    for (uint char_idx = 0; char_idx < buffer.len;)
    {
        uint prev_char_idx = char_idx;
        if (catch excuse = parse_c1(self, &char_idx, buffer)) { switch (excuse)
        {
            case INCOMPLETE:
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
            case INCOMPLETE:
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

alias AnsiCallback = fn void(Terminal* terminal, uint[] args);
alias AnsiMap = Tuple{uint, AnsiCallback}[];
fn AnsiCallback? AnsiMap.find(&self, uint command)
{
    foreach (mapping : self) if (mapping.first == command) return mapping.second;
    return COMMAND_NOT_FOUND?;
}

macro in_range(x, a, b) => (Range{$typeof(x)}){ a, b }.contains(x);
fn void? parse_c1(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;

    if (buffer[*char_idx] < 0x80) return PARSE_FAILED?;
    buffer[*char_idx] -= 0x40;
    parse_fe(terminal, char_idx, buffer)!;
}
fn void? parse_c0(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;

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
            terminal.tab();
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
            return PARSE_FAILED?;
    }
}
fn void? parse_fe(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;

    switch (buffer[*char_idx])
    {
        case 'E': // next line
            (*char_idx)++;
            terminal.move_cursor({ 0, 1 });
            terminal.cursor.x = 0;
        case 'F': // move cursor to bottom left
            (*char_idx)++;
            terminal.set_cursor({ 0, (long)terminal.grid.height - 1 });
        case 'H': // add tabstop
            (*char_idx)++;
            terminal.tabs.tabstopsNew.push(terminal.cursor);
        case 'P': // device control string
            (*char_idx)++;
            parse_dcs(terminal, char_idx, buffer)!;
        case '[': // control sequence indicator
            (*char_idx)++;
            parse_csi(terminal, char_idx, buffer)!;
        case '\\': // ST (string terminator)
            (*char_idx)++;
        case ']': // operating system command
            (*char_idx)++;
            parse_osc(terminal, char_idx, buffer)!;
        case '_': // application program command
            (*char_idx)++;
            parse_apc(terminal, char_idx, buffer)!;
        case 'c': // full reset
            (*char_idx)++;
            terminal.cursor   = {
                .position = {},
                .bg = terminal.bg,
                .fg = terminal.fg,
            };
            terminal.settings = {};
            terminal.tabs     = {};
            terminal.scroll   = 0;
            terminal.clear();
        case '(':
            (*char_idx)++;
            if (buffer.len <= *char_idx) return INCOMPLETE?;
            // TODO: implement charsets (next char is charset)
            (*char_idx)++;
        default:
            return PARSE_FAILED?;
    }
}
fn void? parse_dcs(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;

    uint start_idx = *char_idx;
    Char32[] str_to_parse;
    for (; *char_idx < buffer.len; *char_idx++)
    {
        if (buffer.len <= *char_idx) return INCOMPLETE?;
        uint c = buffer[*char_idx];

        // catch ST (string terminator)
        if (c == 0x9c ||
                (c == '\\' &&
                buffer.len > *char_idx - 1 &&
                buffer[*char_idx-1] == '\e')
            )
        {
            str_to_parse = buffer[start_idx..*char_idx];
        }
    }
    if (str_to_parse.ptr == null) return PARSE_FAILED?;
}
fn void? parse_csi(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;

    List{uint} parameters;
    parameters.init(tmem);
    Range{uint} param_range_normal  = { '0', '9' }; // numbers
    Range{uint} param_range_sep     = { ';', ';' }; // separator
    Range{uint} param_range_private = { '<', '?' }; // private function parameters

    List{uint} intermediates;
    intermediates.init(tmem);
    Range{uint} intermediate_range = { '!', '/' }; // any number of these chars can come before the command

    uint command;
    Range{uint} command_range = { 0x40, 0x7E };

    uint current_param = 0;
    for (; *char_idx < buffer.len; (*char_idx)++)
    {
        if (buffer.len <= *char_idx) return INCOMPLETE?;
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
fn void? parse_osc(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;
}
fn void? parse_apc(Terminal* terminal, uint* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return INCOMPLETE?;
    if (buffer.len <= *char_idx) return INCOMPLETE?;
}

AnsiMap csi_map = {
    // insert space (ICH)
    { '@', &insert_space },

    // cursor up/down/forward/back (CUU,CUD,CUF,CUB)
    { 'A', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ? -1 : -(long)args[0] }) },
    { 'B', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ?  1 :  (long)args[0] }) },
    { 'C', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ?  1 :  (long)args[0], 0 }) },
    { 'D', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ? -1 : -(long)args[0], 0 }) },

    // move cursor to the beginning of line, n lines down/up (CNL,CPL)
    { 'E', fn (term, args) => term.newline(args.len == 0 ?  1 :  args[0]) },
    { 'F', fn (term, args) => term.newline(args.len == 0 ? -1 : -args[0]) },

    // move cursor to column n (CHA)
    { 'G', fn (term, args) => term.set_cursor({ args.len == 0 ? 0 : (long)args[0] - 1,
                                                term.cursor.y }) },

    // set cursor position (CUP)
    { 'H', fn (term, args) => term.set_cursor({ args.len <= 1 ? 0 : (long)args[1] - 1,
                                                args.len == 0 ? 0 : (long)args[0] - 1 }) },

    // tabulation n times (CHT)
    { 'I', fn (term, args) => term.tab(args.len > 0 ? args[0] : 1) },

    // erase in display (ED)
    { 'J', &j_erase },
    // erase in line (EL)
    { 'K', &k_erase },

    // insert line (IL)
    { 'L', &insert_line },
    // delete line (DL)
    { 'M', &delete_line },

    // delete chars (DCH)
    { 'P', &delete_chars },

    // scroll up/down (SU,SD)
    { 'S', &scroll_up   },
    { 'T', &scroll_down },

    // set cursor position (HVP)
    { 'f', fn (term, args) => term.set_cursor({ args.len <= 1 ? 0 : (long)args[1] - 1,
                                                args.len == 0 ? 0 : (long)args[0] - 1 }) },

    // enable setting (SM / DECSET)
    { 'h', &h_parse },

    // enable and disable aux; don't care (MC)
    { 'i', fn (term, args) => (void)0 },

    // disable setting (RM / DECRST)
    { 'l', &l_parse },

    // select graphic rendition (SGR)
    { 'm', &select_graphic_rendition },

    // report cursor position (DSR)
    { 'n', &send_cursor_pos },

    // save/restore cursor to sco (SCOSC, SCORC)
    { 's', fn (term, args) => term.save_cursor_sco() },
    { 'u', fn (term, args) => term.restore_cursor_sco() },
};
fn void j_erase(Terminal* term, uint[] args)
{
    if (args.len == 0)
    {
        term.erase(term.cursor, term.get_grid_idx(term.grid.dimensions - {1,1}) - term.get_grid_idx(term.cursor) + 1);
        return;
    }
    switch (args[0])
    {
        case 0:
            term.erase(term.cursor, term.get_grid_idx(term.grid.dimensions - {1,1}) - term.get_grid_idx(term.cursor) + 1);
        case 1:
            term.erase({ 0, 0 }, (usz)(term.get_grid_idx(term.cursor.position) - term.get_grid_idx({ 0, 0 }) + 1));
        case 2:
            term.erase({ 0, 0 }, (usz)(term.get_grid_idx(term.grid.dimensions - {1,1}) + 1));
        case 3:
            term.clear();
    }
}
fn void k_erase(Terminal* term, uint[] args)
{
    if (args.len == 0)
    {
        term.erase(term.cursor, (usz)(term.grid.width - term.cursor.x));
        return;
    }
    switch (args[0])
    {
        case 0:
            term.erase(term.cursor, (usz)(term.grid.width - term.cursor.x));
        case 1:
            term.erase({ 0, term.cursor.y }, (usz)(term.cursor.x + 1));
        case 2:
            term.erase({ 0, term.cursor.y }, term.grid.width);
    }
}
fn void send_cursor_pos(Terminal* term, uint[] args)
{
    DString builder;
    builder.init(tmem);
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
fn void insert_space(Terminal* term, uint[] args)
{
    uint amount = args.len == 0 ? 1 : args[0];
    usz start_idx = amount + term.get_grid_idx(term.cursor);
    usz end_idx = term.get_grid_idx({ term.grid.width - 1, term.cursor.y });
    for (usz i = end_idx; i >= start_idx; i--)
    {
        term.grid.fg[i] = term.grid.fg[(i - amount) % term.grid.size];
        term.grid.bg[i] = term.grid.bg[(i - amount) % term.grid.size];
    }
    for (usz i = start_idx - amount; i < start_idx; i++)
    {
        term.grid.fg[i] = { .codepoint = ' ', .color = term.fg };
        term.grid.bg[i].color = term.bg;
    }
}
fn void delete_chars(Terminal* term, uint[] args)
{
    uint amount = args.len == 0 ? 1 : args[0];
    usz start_idx = term.get_grid_idx(term.cursor);
    usz end_idx = term.get_grid_idx({ term.grid.width - 1, term.cursor.y });
    for (usz i = start_idx; i < end_idx - amount; i++)
    {
        term.grid.fg[i] = term.grid.fg[(i + amount) % term.grid.size];
        term.grid.bg[i] = term.grid.bg[(i + amount) % term.grid.size];
    }
    for (usz i = end_idx; i > end_idx - amount; i--)
    {
        term.grid.fg[i] = { .codepoint = ' ', .color = term.fg };
        term.grid.bg[i].color = term.bg;
    }
}
fn void insert_line(Terminal* term, uint[] args)
{
    uint amount = args.len == 0 ? 1 : args[0];
    for (int y = term.grid.height - amount; y >= term.cursor.y; y--)
    {
        for (int x = 0; x < term.grid.width; x++)
        {
            term.grid.fg[term.get_grid_idx({ x, math::clamp(y + amount, 0, term.grid.height - 1) })] = term.grid.fg[term.get_grid_idx({ x, y })];
            term.grid.bg[term.get_grid_idx({ x, math::clamp(y + amount, 0, term.grid.height - 1) })] = term.grid.bg[term.get_grid_idx({ x, y })];
        }
    }
    for (int y = term.cursor.y; y < term.cursor.y + amount; y++)
    {
        for (int x = 0; x < term.grid.width; x++)
        {
            term.grid.fg[term.get_grid_idx({ x, y })] = { .codepoint = ' ', .color = term.fg };
            term.grid.bg[term.get_grid_idx({ x, y })].color = term.bg;
        }
    }
}
fn void delete_line(Terminal* term, uint[] args)
{
    uint amount = args.len == 0 ? 1 : args[0];
    for (int y = term.cursor.y; y < term.grid.height - amount; y++)
    {
        for (int x = 0; x < term.grid.width; x++)
        {
            term.grid.fg[term.get_grid_idx({ x, y })] = term.grid.fg[term.get_grid_idx({ x, math::clamp(y + amount, 0, term.grid.height - 1) })];
            term.grid.bg[term.get_grid_idx({ x, y })] = term.grid.bg[term.get_grid_idx({ x, math::clamp(y + amount, 0, term.grid.height - 1) })];
        }
    }
    for (int y = term.grid.height - 1; y >= term.grid.height - amount; y--)
    {
        for (int x = 0; x < term.grid.width; x++)
        {
            term.grid.fg[term.get_grid_idx({ x, y })] = { .codepoint = ' ', .color = term.fg };
            term.grid.bg[term.get_grid_idx({ x, y })].color = term.bg;
        }
    }
}
fn void scroll_up(Terminal* term, uint[] args)
{
    long amount = args.len == 0 ? 1 : args[0];
    uint[<2>] old_cursor = term.cursor.position;
    term.cursor.position = { 0, term.grid.height - 1 };
    term.scroll_lines(1);
    insert_line(term, { (uint)amount });
    term.scroll_lines(-1);
    term.cursor.position = old_cursor;
}
fn void scroll_down(Terminal* term, uint[] args)
{
    long amount = args.len == 0 ? -1 : -args[0];
    uint[<2>] old_cursor = term.cursor.position;
    term.cursor.position = { 0, 0 };
    // term.scroll_lines(amount - 1);
    insert_line(term, { (uint)(-amount) });
    term.cursor.position = old_cursor;
}
