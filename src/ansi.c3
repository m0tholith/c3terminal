module terminal::ansi;

import terminal;

import std::core::mem;
import std::collections::list;
import std::collections::range;
import std::ascii;
import std::io;

fn void Terminal.interpret_ansi(&self, String ansi)
{
    for (int i = 0; i < ansi.len; i++)
    {
        char c = ansi[i];
        if (c == '\e') parse_ansi_func(self, ansi[i + 1 ..]);
    }
}

fn void parse_ansi_func(Terminal* terminal, String ansi_func)
{
    if (ansi_func[0] == '[') ansi_func = ansi_func[1..];
    List{int} args;
    char command;

    allocator::Allocator tmem = allocator::temp();
    @pool(tmem)
    {
        args.init(tmem);

        int current_arg = -1;
        for (int i = 0; i < ansi_func.len; i++)
        {
            char c = ansi_func[i];
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
        if (command == 0) return;
        int[] args_array = args.array_view();
        io::printfn("Interpreted ANSI code, function: %c, args: %s", command, args_array);
        for (int i = 0; i < ansi_map.len; i++)
        {
            if (command == ansi_map[i].first)
            {
                ansi_map[i].second(terminal, args_array);
                break;
            }
        }
    };
}

module terminal::ansi @private;
import std::collections::tuple;

def AnsiCallback = fn void(Terminal* terminal, int[] args);
Tuple{char, AnsiCallback}[] ansi_map = {
    { 'H', fn (Terminal* term, args) => term.set_cursor_pos(args.len == 0 ? { 0, 0 } : args) },
    { 'f', fn (Terminal* term, args) => term.set_cursor_pos(args) },
};
<*
 @require position.len >= 2
 *>
fn void Terminal.set_cursor_pos(&self, int[] position = { 0, 0 }) @inline => self.cursor = { position[0], position[1] };
