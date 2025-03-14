module terminal::ansi;

import terminal;

import std::core::mem;
import std::collections::list;
import std::collections::range;
import std::ascii;
import std::io;

fn void Terminal.interpret(&self, String buffer)
{
    for (int i = 0; i < buffer.len; i++)
    {
        char c = buffer[i];
        switch (c)
        {
            case '\e':
                if (i + 1 < buffer.len)
                {
                    if (buffer[i + 1] == '[')
                    {
                        i += parse_csi(self, buffer[i + 2..]);
                    }
                    else if (buffer[i + 1] == 'P')
                    {
                        i += parse_dcs(self, buffer[i + 2..]);
                    }
                    else if (buffer[i + 1] == ']')
                    {
                        i += parse_osc(self, buffer[i + 2..]);
                    }
                    else
                    {
                        i += parse_esc(self, buffer[i + 1..]);
                    }
                }
                else
                {
                    i += parse_esc(self, buffer[i + 1..]);
                }
                break;
            case '\x9B':
                i += parse_csi(self, buffer[i + 1 ..]);
            case '\x90':
                i += parse_dcs(self, buffer[i + 1 ..]);
            case '\x9D':
                i += parse_osc(self, buffer[i + 1 ..]);
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
                self.newline();
            case '\v':
                self.move_cursor({0, 1});
            case '\f':
                self.clear();
            case '\r':
                self.newline();
            default:
                self.assign_char(c);
                self.move_cursor({ 1, 0 });
        }
    }
}

macro int parse_esc(Terminal* terminal, String ansi_func) => parse_ansi(terminal, ansi_func, esc_map);
macro int parse_csi(Terminal* terminal, String ansi_func) => parse_ansi(terminal, ansi_func, csi_map);
macro int parse_dcs(Terminal* terminal, String ansi_func) => parse_ansi(terminal, ansi_func, dcs_map);
macro int parse_osc(Terminal* terminal, String ansi_func) => parse_ansi(terminal, ansi_func, osc_map);
fn int parse_ansi(Terminal* terminal, String ansi_func, AnsiMap map)
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
            char c = ansi_func[new_idx];
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
        if (command == 0) return 0;
        int[] args_array = args.array_view();
        io::printfn("Interpreted ANSI code, function: %c, args: %s", command, args_array);
        for (int i = 0; i < map.len; i++)
        {
            if (command == map[i].first)
            {
                map[i].second(terminal, args_array);
                break;
            }
        }
        return new_idx;
    };
}

module terminal::ansi @private;
import std::collections::tuple;

def AnsiCallback = fn void(Terminal* terminal, int[] args);
def AnsiMap = Tuple{char, AnsiCallback}[];
AnsiMap esc_map = {
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
};
AnsiMap dcs_map = {
};
AnsiMap osc_map = {
};
