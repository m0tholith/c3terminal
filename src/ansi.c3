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
    };
    io::printfn("Interpreted ANSI code, function: %c, args: %s", command, args);
}
