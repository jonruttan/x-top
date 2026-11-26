# x-top card

## Run

```sh
x -l top                                  # the viewer; q quits
x -l top -- -t -s mem                     # as a tree, sorted by memory
x -l top -- -u NAME -F TEXT               # one user's; commands holding TEXT
x -l top -- -D                            # one screen to standard output
x -l top -- -V -> x-top 0.1.0
x -l top -- -D | grep -c 'PID USER' -> 1
LINES=40 x -l top -- -D | wc -l | xargs -> 40
x -l top -- -D -s pid | grep -A1 'PID USER' | tail -1 | awk '{print $2}' -> root
x -l top -- -D -s nosuch > /dev/null 2>&1; echo $? -> 2
```

| Option                 | Does                                             |
|------------------------|--------------------------------------------------|
| `-d`, `--delay TENTHS` | tenths of a second between samples (15)          |
| `-u`, `--user NAME`    | only this user's processes: a name or a uid      |
| `-s`, `--sort-key COLUMN` | sort by COLUMN (cpu)                          |
| `-t`, `--tree`         | the tree of parent and child processes           |
| `-F`, `--filter TEXT`  | only the processes whose command holds TEXT      |
| `-D`, `--dump`         | draw one screen to standard output and exit      |
| `-V` `-h`              | the version; the help                            |
| COLUMN               | `pid user pri ni virt res state cpu mem time command` |
| `$LINES` `$COLUMNS`    | the screen's size, when there is no terminal     |

## Keys

| Key                    | Does                                             |
|------------------------|--------------------------------------------------|
| the arrows, PgUp PgDn, Home End | move the selection                      |
| `F1` `h` `?`           | help                                             |
| `F3` `/`               | search the commands; `F3` again for the next     |
| `F4` `\`               | filter by command; Enter keeps it, Esc drops it  |
| `F5` `t`               | the tree view                                    |
| `F6` `>` `<`           | the next sort column; the previous               |
| `P` `M` `T` `N`        | sort by CPU%, MEM%, TIME+, PID                   |
| `I`                    | invert the order                                 |
| `F7` `]`               | nice down: a higher priority                     |
| `F8` `[`               | nice up: a lower priority                        |
| `F9` `k`               | send a signal, TERM chosen first                 |
| `u`                    | only the selected process's user; again for all  |
| `K`                    | show kernel threads                              |
| `F10` `q` `^C`         | quit                                             |

## Screen

| Part                   | Is                                               |
|------------------------|--------------------------------------------------|
| a numbered bar         | a processor: nice, user, system, steal and guest |
| `Mem` `Swp`            | memory: used, buffers, cache; swap               |
| `Tasks`                | the processes, their threads, how many run       |
| `Load average` `Uptime` | over 1, 5 and 15 minutes; since the boot        |
| `PID` `USER`           | the process's id; its owner                      |
| `PRI` `NI`             | its priority; its nice value                     |
| `VIRT` `RES`           | its virtual size; its resident size              |
| `S`                    | its state: `R` running, `S` sleeping             |
| `CPU%`                 | its CPU time between two samples, over the time  |
| `MEM%`                 | its resident size over the machine's memory      |
| `TIME+`                | its CPU time in all                              |
| `Command`              | its command line; in the tree, under its parent  |

## Differs

| Here                                        | In htop                       |
|---------------------------------------------|-------------------------------|
| no SHR column                               | a shared size                 |
| a row is a process                          | a thread, too                 |
| the filter matches the process's name       | its command line              |
| `u` takes the selected process's user       | offers a list                 |
| no setup screen, tagging or mouse           | F2, Space, the mouse          |
| the tree's branches do not collapse         | `+` and `-`                   |

## More

| Where                          | What                                     |
|--------------------------------|------------------------------------------|
| `x -l top -- -h`               | the options                              |
| `F1` in the viewer             | the keys                                 |
| `README.md`                    | the screen, and each difference from htop |
| `tests/specs/`                 | the formats, the keys, the screen        |
