# The screen
@weight 1

top/view: the meters, the table and the key bar, drawn from two samples
made by hand.

## the main screen

### meters on the left and right, the titles, a row a process, the keys

```top
(spec-draw (spec-state ()) 12 100)
```
---
```output
   0[||||||||||||||||||||                  50.0%]    1[                                       0.0%]
 Mem[||||||||||||||||||||||||||||||| 9.00G/16.0G]  Tasks: 4, 8 thr; 1 running
 Swp[||||||||||                       512M/2.00G]  Load average: 1.50 0.75 0.25
                                                   Uptime: 00:00:01

    PID USER      PRI  NI   VIRT    RES S  CPU%  MEM%     TIME+ Command
     41 jon        20   0  32768  16384 R  50.0   0.0   0:03.50 vi notes.txt
     50 root       15  -5  1024M   256M D  25.0   1.5   1:00.25 daemon
     40 jon        20   0   8192   2048 S   1.0   0.0   0:02.01 sh
      1 root       20   0   4096   1024 S   0.0   0.0   0:01.00 init

F1Help  F3SearchF4FilterF5Tree  F6SortByF7Nice -F8Nice +F9Kill  F10Quit
```

### the tree, filtered

```top
(def screen-st (spec-state ()))
(state-key! screen-st "t")
(state-key! screen-st "\\")
(state-key! screen-st "v")
(spec-draw screen-st 12 80)
```
---
```output
   0[|||||||||||||||             50.0%]    1[                             0.0%]
 Mem[||||||||||||||||||||||9.00G/16.0G]  Tasks: 4, 8 thr; 1 running
 Swp[||||||||               512M/2.00G]  Load average: 1.50 0.75 0.25
                                         Uptime: 00:00:01

    PID USER      PRI  NI   VIRT    RES S  CPU%  MEM%     TIME+ Command
     41 jon        20   0  32768  16384 R  50.0   0.0   0:03.50 vi notes.txt




Filter: v
```

## the styles

### the bracket plain, the bar's nice share first in blue, the titles black on green, the sort column's title and the selected row black on cyan

```top
(def screen-s (spec-screen (spec-state ()) 12 100))
(def screen-cpu (Str8 index-of "CPU%" (Screen row-text screen-s 5)))
(write (spec-colours screen-s (list (list 0 4) (list 0 5) (list 5 0) (list 5 screen-cpu) (list 6 0) (list 7 0))))
```
---
    ((()) (4) (0 . 2) (0 . 6) (0 . 6) (()))

## the kill list and the help

### the kill list over the table's left side

```top
(def screen-st (spec-state ()))
(state-key! screen-st 'f9)
(spec-draw screen-st 12 80)
```
---
```output
   0[|||||||||||||||             50.0%]    1[                             0.0%]
 Mem[||||||||||||||||||||||9.00G/16.0G]  Tasks: 4, 8 thr; 1 running
 Swp[||||||||               512M/2.00G]  Load average: 1.50 0.75 0.25
                                         Uptime: 00:00:01

    PID USER      PRI  NI   VIRT    RES S  CPU%  MEM%     TIME+ Command
Send signal:       20   0  32768  16384 R  50.0   0.0   0:03.50 vi notes.txt
  1 HUP            15  -5  1024M   256M D  25.0   1.5   1:00.25 daemon
  2 INT            20   0   8192   2048 S   1.0   0.0   0:02.01 sh
  9 KILL           20   0   4096   1024 S   0.0   0.0   0:01.00 init
 15 TERM
F1Help  F3SearchF4FilterF5Tree  F6SortByF7Nice -F8Nice +F9Kill  F10Quit
```

### the help

```top
(def screen-st (spec-state ()))
(state-key! screen-st "?")
(spec-draw screen-st 17 80)
```
---
```output
x-top -- an interactive process viewer on x-lang

CPU bars: [nice  normal  kernel  virt   used%]   (blue green red cyan)
Mem bar:  [used  buffers  cache   used/total]    (green blue yellow)
Swp bar:  [used                  used/total]

 Arrows PgUp PgDn Home End: move the selection
 F1 h ?: this help          F10 q ^C: quit
 F3 /: search, F3 for the next; Enter keeps the text, Esc ^G drop it
 F4 \: filter by command    F5 t: tree view
 F6 > <: next/previous sort column      I: invert the order
 P M T N: sort by CPU%, MEM%, TIME+, PID
 F7 ]: nice - (higher priority)          F8 [: nice + (lower)
 F9 k: send a signal         u: only the selected process's user, again all
 K: show kernel threads

Press any key to return.
```
