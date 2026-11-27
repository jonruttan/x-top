# x-top

An interactive process viewer on [x-lang](https://github.com/jonruttan/x-lang),
after htop: a bar a processor, memory and swap meters, the task counts, load
and uptime, then the processes, sorted, searched, filtered or as a tree, with
signals and nice values sent from the keyboard.

    x -l top [-- OPTIONS]

It reads the machine through x-lang's `Host` records, so it runs on Linux
(`/proc`) and macOS (sysctl and the Mach calls) alike and never asks which.

## Options

    -d, --delay TENTHS     Tenths of a second between samples (15)
    -u, --user NAME        Show only this user's processes: a name or a uid
    -s, --sort-key COLUMN  Sort by COLUMN: pid user pri ni virt res state cpu mem time command (cpu)
    -t, --tree             Show the tree of parent and child processes
    -F, --filter TEXT      Show only the processes whose command holds TEXT
    -D, --dump             Draw one screen to standard output and exit
    -V, --version          Print the version and exit
    -h, --help             Print this help and exit

## Keys

    Arrows PgUp PgDn Home End   move the selection
    F1 h ?                      help
    F3 /                        search the commands; F3 again for the next
    F4 \                        filter by command; Enter keeps it, Esc drops it
    F5 t                        tree view
    F6 > <                      next or previous sort column
    P M T N                     sort by CPU%, MEM%, TIME+, PID
    I                           invert the order
    F7 ]   F8 [                 nice - (higher priority), nice + (lower)
    F9 k                        send a signal, TERM first chosen
    u                           only the selected process's user; again for all
    K                           show kernel threads
    F10 q ^C                    quit

## The screen

The columns are htop's defaults but SHR: PID USER PRI NI VIRT RES S CPU%
MEM% TIME+ Command.  CPU% is the process's CPU time between two samples over
the wall time between them, so a busy processor is 100; MEM% is its resident
size over the machine's memory.  A processor's bar is nice (blue), user
(green), system and interrupts (red), steal and guest (cyan); memory's is used
(green), buffers (blue) and cache (yellow), used being what is in none of them
nor free.

Where x-top differs from htop:

- No SHR column: `Host` reports no shared size for a process yet.
- A row a process, not a thread; the task line still counts the threads.
- The filter and the search match the process's name, the search also its
  command line.
- `u` takes the selected process's user rather than offering a list.
- No setup screen (F2), tagging, mouse or collapsing a branch of the tree.

macOS reports another user's memory and CPU time only to root, as for htop.

## Tests

    make test     # every spec, loud
    make check    # the gate CI runs
    make card     # docs/card.md: its format and its rows

[docs/card.md](docs/card.md) is the card: the options, the keys and the
screen in tables, and rows that `make card` runs.

The specs make their samples by hand, so a screen comes out the same on any
kernel; one case reads the machine it runs on.

## Licence

MIT No Attribution (MIT-0).
