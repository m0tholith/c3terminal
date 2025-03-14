module terminal::ansi;

import terminal;

import std::core::mem;
import std::collections::list;
import std::collections::range;
import std::ascii;
import std::io;

fault AnsiError
{
    ANSI_FUNCTION_NOT_FOUND,
}

fn void! Terminal.interpret(&self, Char32[] buffer)
{
    for (int i = 0; i < buffer.len; i++)
    {
        uint c = buffer[i];
        switch (c)
        {
            case '\e':
                if (i + 1 < buffer.len)
                {
                    if (buffer[i + 1] == '[')
                    {
                        i += parse_csi(self, buffer[i + 2..])!;
                    }
                    else if (buffer[i + 1] == 'P')
                    {
                        i += parse_dcs(self, buffer[i + 2..])!;
                    }
                    else if (buffer[i + 1] == ']')
                    {
                        i += parse_osc(self, buffer[i + 2..])!;
                    }
                    else
                    {
                        i += parse_esc(self, buffer[i + 1..])!;
                    }
                }
                else
                {
                    i += parse_esc(self, buffer[i + 1..])!;
                }
                break;
            case '\x9B':
                i += parse_csi(self, buffer[i + 1 ..])!;
            case '\x90':
                i += parse_dcs(self, buffer[i + 1 ..])!;
            case '\x9D':
                i += parse_osc(self, buffer[i + 1 ..])!;
            case '\a':
                // io::printn("bell");
                break;
            case '\b':
                self.move_cursor({ -1, 0 });
                self.assign_char(' ');
            case '\t':
                for (int j = 0; j < 4; j++)
                {
                    self.assign_char(' ');
                    self.move_cursor({ 1, 0 });
                }
            case '\n':
                self.move_cursor({ 0, 1 });
            case '\v':
                self.move_cursor({0, 1});
            case '\f':
                self.clear();
            case '\r':
                self.set_cursor({ 0, self.cursor.y });
            default:
                self.assign_char(c);
                self.move_cursor({ 1, 0 });
        }
    }
}

module terminal::ansi @private;

import std::collections::tuple;
import std::collections::list;
import std::ascii;
import std::io;

macro int! parse_esc(Terminal* terminal, Char32[] ansi_func) => parse_ansi(terminal, ansi_func, esc_map);
macro int! parse_csi(Terminal* terminal, Char32[] ansi_func) => parse_ansi(terminal, ansi_func, csi_map);
macro int! parse_dcs(Terminal* terminal, Char32[] ansi_func) => parse_ansi(terminal, ansi_func, dcs_map);
macro int! parse_osc(Terminal* terminal, Char32[] ansi_func) => parse_ansi(terminal, ansi_func, osc_map);
fn int! parse_ansi(Terminal* terminal, Char32[] ansi_func, AnsiMap map)
{
    List{int} args;
    char command;

    allocator::Allocator tmem = allocator::temp();
    @pool(tmem)
    {
        args.init(tmem);

        int current_arg = -1;
        int new_idx;
        for (new_idx = 0; new_idx < ansi_func.len; new_idx++)
        {
            char c = (char)ansi_func[new_idx];
            if (ascii::is_digit(c))
            {
                if (current_arg == -1)
                {
                    current_arg = (int)args.len();
                    args.push(0);
                }
                args[current_arg] = args[current_arg] * 10 + (int)(c - '0');
            }
            else if (ascii::is_space(c))
            {
                continue;
            }
            else if (c == ';')
            {
                current_arg = -1;
            }
            else if (ascii::is_alpha(c))
            {
                command = c;
                break;
            }
            else
            {
                break;
            }
        }
        new_idx++;
        if (command == 0) return 0;
        int[] args_array = args.array_view();
        io::printfn("Interpreted ANSI code, function: %c, args: %s", command, args_array);
        map.search(command)!(terminal, args_array);
        return new_idx + 1;
    };
}

def AnsiCallback = fn void(Terminal* terminal, int[] args);
def AnsiMap = Tuple{char, AnsiCallback}[];
fn AnsiCallback! AnsiMap.search(&self, char key)
{
    foreach (command : self) if (command.first == key) return command.second;
    return AnsiError.ANSI_FUNCTION_NOT_FOUND?;
}
AnsiMap esc_map = {
    { 'M', fn (Terminal* term, args) => term.move_cursor({ 0, (long)args[0] }) },

    { '7', fn (Terminal* term, args) => term.save_cursor_dec()    },
    { '8', fn (Terminal* term, args) => term.restore_cursor_dec() },
};
AnsiMap csi_map = {
    { 'H', fn (Terminal* term, args) => term.set_cursor(args.len == 0 ? { 0, 0 } : { args[0], args[1] }) },
    { 'f', fn (Terminal* term, args) => term.set_cursor({ args[0], args[1] })                            },
    { 'G', fn (Terminal* term, args) => term.set_cursor({ args[0],  term.cursor.y })                     },

    { 'A', fn (Terminal* term, args) => term.move_cursor({  0, (long)-args[0] }) },
    { 'B', fn (Terminal* term, args) => term.move_cursor({  0, (long) args[0] }) },
    { 'C', fn (Terminal* term, args) => term.move_cursor({ (long) args[0],  0 }) },
    { 'D', fn (Terminal* term, args) => term.move_cursor({ (long)-args[0],  0 }) },
    { 'E', fn (Terminal* term, args) => term.newline((long)-args[0])             },
    { 'F', fn (Terminal* term, args) => term.newline((long) args[0])             },

    { 's', fn (Terminal* term, args) => term.save_cursor_sco()    },
    { 'u', fn (Terminal* term, args) => term.restore_cursor_sco() },

    { 'J', &j_erase },
    { 'K', &k_erase },
};
AnsiMap dcs_map = {
};
AnsiMap osc_map = {
};

fn void j_erase(Terminal* term, int[] args)
{
    if (args.len == 0)
    {
        term.erase(term.cursor, term.grid.fg.len - term.get_grid_idx(term.cursor) + 1);
        return;
    }
    switch (args[0])
    {
        case 0:
            term.erase(term.cursor, term.grid.fg.len - term.get_grid_idx(term.cursor) + 1);
        case 1:
            term.erase({ 0, 0 }, (usz)(term.get_grid_idx(term.cursor) + 1));
        case 2:
            term.clear();
        case 3:
            break;
    }
}
fn void k_erase(Terminal* term, int[] args)
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
