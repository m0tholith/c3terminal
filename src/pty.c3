module pty;

import libc;
import libc::termios;

import std::io;
import std::core::mem;
import std::core::mem::allocator;
import std::os;
import std::os::env;
import std::thread;
import std::net;

fault PtyError
{
    FORK_FAILED,
    ENV_SHELL_FAILED,
    SHELL_EXEC_FAILED,
    READ_ERROR,
    PROCESS_DEAD,
    POLL_FAILED,
    PTY_NOT_READY,
    GET_FLAGS_ERROR,
    SET_FLAGS_ERROR,
}

struct Pty
{
    inline CInt master;
    libc::Pid_t pid;
    String nextWrite;
}
pty::Pty pty @public @builtin;

fn void! Pty.init(&self)
{
    Termios termios;
    termios.getAttr(libc::STDIN_FD);
    termios.c_cc[(int)termios::VMIN] = 0;
    termios.c_cc[(int)termios::VTIME] = 1;
    termios.setAttr(libc::STDIN_FD, 0);
    self.pid = forkpty(&self.master, null, &termios, &&(Winsize){});
    if (self.pid == -1)
    {
        io::eprintfn("failed to forkpty");
        return PtyError.FORK_FAILED?;
    }
    else if (self.pid == 0)
    {
        if (catch excuse = child_process()) return excuse?;
    }

    int flags = fcntl(self.master, os::F_GETFL, 0);
    if (flags == -1)
    {
        io::eprintfn("can't get master fd flags: %s", libc::errno());
        return PtyError.GET_FLAGS_ERROR?;
    }

    int a = fcntl(self.master, os::F_SETFL, flags | os::O_NONBLOCK);
    if (a == -1)
    {
        io::eprintfn("can't set master fd flags: %s", libc::errno());
        return PtyError.SET_FLAGS_ERROR?;
    }
}

fn void! child_process()
{
    String! shell = env::get_var(mem, "SHELL");
    if (catch excuse = shell)
    {
        io::eprintfn("failed to get shell var: %s", excuse);
        return PtyError.ENV_SHELL_FAILED?;
    }
    defer mem::free(shell);
    ZString[] args = { shell.zstr_tcopy(), null };
    if (execvp(args[0], args.ptr) == -1)
    {
        io::eprintfn("failed to execute shell");
        thread::exit(-1);
    }
}
fn String! Pty.read(&self, Allocator allocator = allocator::temp()) {
    if (!self.is_alive()) return PtyError.PROCESS_DEAD?;

    net::Poll[] polls = {
        {
            .socket = (os::NativeSocket)self.master,
            .events = net::SUBSCRIBE_READ,
        }
    };
    if (catch excuse = net::poll(polls, 0))
    {
        io::eprintfn("read poll failed: %s", excuse);
        return PtyError.POLL_FAILED?;
    }
    if (polls[0].revents != net::POLL_EVENT_READ) return PtyError.PTY_NOT_READY?;

    const usz BUF_SIZE = 32400;
    String buf = (String)allocator::alloc_array(allocator, char, BUF_SIZE);
    isz s = libc::read(self.master, buf.ptr, BUF_SIZE);
    if (s == -1)
    {
        io::eprintfn("error while reading errno: %s", libc::errno());
        return PtyError.READ_ERROR?;
    }
    if (s == 0)
    {
        io::printfn("read was 0");
    }

    return buf[:s];
}
fn void! Pty.write(&self, String buffer)
{
    if (!self.is_alive()) return PtyError.PROCESS_DEAD?;

    defer catch {
        if (self.nextWrite.ptr == null)
        {
            self.nextWrite = buffer.copy(mem);
        }
        else
        {
            String prev_write = self.nextWrite;
            self.nextWrite = self.nextWrite.concat(mem, buffer);
            mem::free(prev_write);
        }
    }

    net::Poll[] polls = {
        {
            .socket = (os::NativeSocket)self.master,
            .events = net::SUBSCRIBE_WRITE,
        }
    };
    if (catch excuse = net::poll(polls, 0))
    {
        io::eprintfn("write poll failed: %s", excuse);
        return PtyError.POLL_FAILED?;
    }
    if (polls[0].revents != net::POLL_EVENT_WRITE) return PtyError.PTY_NOT_READY?;

    libc::write(self.master, self.nextWrite.ptr, self.nextWrite.len);
    libc::write(self.master, buffer.ptr, buffer.len);

    mem::free(self.nextWrite.ptr);
    self.nextWrite = {};
}
fn void Pty.set_winsize(&self, uint[<2>] new_dimensions)
{
    Winsize w = { (ushort)new_dimensions.y, (ushort)new_dimensions.x, 0, 0 };
    ioctl(self.master, 21524, &w);
    kill(0, 28);
}
fn bool Pty.is_alive(&self) @inline => waitpid(self.pid, null, 1) >= 0;
fn void Pty.free(&self)
{
    if (self.nextWrite.ptr != null) mem::free(self.nextWrite.ptr);
}

module pty @private;

import libc;

struct Winsize
{
    ushort ws_row;    /* rows, in characters */
    ushort ws_col;    /* columns, in characters */
    ushort ws_xpixel; /* horizontal size, pixels */
    ushort ws_ypixel; /* vertical size, pixels */
}
struct Pollfd
{
    CInt fd;
    short events;
    short revents;
}
extern fn CInt forkpty(CInt* amaster, char* name, Termios* termp, Winsize* winp);
extern fn CInt kill(libc::Pid_t pid, int sig);
extern fn CInt execvp(ZString file, ZString* argv);
extern fn libc::Pid_t waitpid(libc::Pid_t pid, int* wstatus, int options);
extern fn libc::Pid_t getppid();
extern fn int fcntl(CInt socket, int cmd, ...);
extern fn int ioctl(CInt fd, int cmd, ...);
