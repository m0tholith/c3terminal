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
}

fn void! Terminal.interpret(&self, Char32[] buffer)
{
    for (int char_idx = 0; char_idx < buffer.len;)
    {
        if (try parse_c1(self, &char_idx, buffer)) continue;
        if (try parse_c0(self, &char_idx, buffer)) continue;

        // render-able
        if (char_idx >= buffer.len) break;
        if (in_range(buffer[char_idx], 32, 126))
        {
            self.assign_char(buffer[char_idx]);
            self.move_cursor({ 1, 0 });
        }
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
    parse_fe(terminal, char_idx, buffer)!;
}
fn void! parse_c0(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;

    switch (buffer[*char_idx])
    {
        case 0x07: // bell
            (*char_idx)++;
            io::printn("bell");
        case 0x08: // backspace
            (*char_idx)++;
            terminal.move_cursor({ -1, 0 });
            terminal.assign_char(' ');
        case 0x09: // horizontal tab
            (*char_idx)++;
            usz movement = (usz)math::ceil(++terminal.cursor.x / 8.0);
            movement *= 8;
            movement -= terminal.cursor.x;
            terminal.move_cursor({ movement, 0 });
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
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;

    switch (buffer[*char_idx])
    {
        case 'P':
            (*char_idx)++;
            parse_dcs(terminal, char_idx, buffer)!;
        case '[':
            (*char_idx)++;
            parse_csi(terminal, char_idx, buffer)!;
        case ']':
            (*char_idx)++;
            parse_osc(terminal, char_idx, buffer)!;
        default:
            return AnsiError.PARSE_FAILED?;
    }
}
fn void! parse_dcs(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;
}
fn void! parse_csi(Terminal* terminal, int* char_idx, Char32[] buffer)
{
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;

    List{uint} parameters;
    parameters.init(allocator::temp());
    Range{uint} param_range_normal  = { '0', '9' }; // numbers
    Range{uint} param_range_sep     = { ';', ';' }; // separator
    Range{uint} param_range_private = { '<', '?' }; // private function parameters

    uint command;
    Range{uint} command_range = { 0x40, 0x7E };

    int current_param = 0;
    for (; *char_idx < buffer.len; (*char_idx)++)
    {
        uint c = buffer[*char_idx];

        if (param_range_normal.contains(c))
        {
            if (current_param >= parameters.len()) parameters.push(0);
            parameters[current_param] = parameters[current_param] * 10 + (c - '0');
        }
        else if (param_range_sep.contains(c))
        {
            while (current_param >= parameters.len()) parameters.push(1);
            current_param++;
        }
        else if (param_range_private.contains(c))
        {
            if (current_param >= parameters.len()) parameters.push(0);
            parameters[current_param] = c;
            current_param++;
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
    if (buffer.len == 0) return AnsiError.PARSE_FAILED?;
    if (buffer.len <= *char_idx) return AnsiError.PARSE_FAILED?;
}

AnsiMap csi_map = {
    { 'A', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ? -1 : -(long)args[0] })        },
    { 'B', fn (term, args) => term.move_cursor_clamp({ 0, args.len == 0 ?  1 :  (long)args[0] })        },
    { 'C', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ?  1 :  (long)args[0], 0 })        },
    { 'D', fn (term, args) => term.move_cursor_clamp({ args.len == 0 ? -1 : -(long)args[0], 0 })        },

    { 'E', fn (term, args) => term.newline(args.len == 0 ?  1 :  args[0])                               },
    { 'F', fn (term, args) => term.newline(args.len == 0 ? -1 : -args[0])                               },

    { 'G', fn (term, args) => term.set_cursor({ args.len == 0 ? 0 : args[0], term.cursor.y })           },

    { 'H', fn (term, args) => term.set_cursor({args.len == 0? 0 : args[0], args.len <= 1? 0 : args[1]}) },

    { 'J', &j_erase                                                                                     },
    { 'K', &k_erase                                                                                     },

    { 'S', fn (term, args) => term.scroll_lines(args.len == 0 ? -1 : args[0])                           },
    { 'T', fn (term, args) => term.scroll_lines(args.len == 0 ?  1 : args[0])                           },

    { 'f', fn (term, args) => term.set_cursor(args.len == 0 ? { 0, 0 } : { args[0] - 1, args[1] - 1 })  },

    // enable and disable aux; don't care
    { 'i', fn (term, args) => (void)0                                                                   },

    { 'n', &send_cursor_pos                                                                             },

    /// private sequences

    { 's', fn (term, args) => term.save_cursor_sco()                                                   },
    { 'u', fn (term, args) => term.restore_cursor_sco()                                                },

    { 'h', &h_parse                                                                                    },
    { 'l', &l_parse                                                                                    },
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
            term.clear();
        case 3:
            break;
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
        case 3:
            break;
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
        case 25:
        case 1004:
        case 1049:
        case 2004:
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
        case 25:
        case 1004:
        case 1049:
        case 2004:
        default:
            return;
    }
}
