# The keys
@weight 1

top/state: what each key does to what is shown, with a world that only
writes down what it is asked.

## moving

### the selection follows its process when the order changes

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'down)
(def keys-a (row-pid (state-selected keys-st)))
(state-key! keys-st "N")
(write (list keys-a (row-pid (state-selected keys-st)) (state-at keys-st)))
```
---
    (50 50 3)

### Home, End, and the arrows stop at the ends

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'end)
(state-key! keys-st 'down)
(def keys-a (state-at keys-st))
(state-key! keys-st 'home)
(state-key! keys-st 'up)
(write (list keys-a (state-at keys-st)))
```
---
    (3 0)

## search and filter

### / searches the commands as they are typed, from the selection; Enter keeps the text

```top
(def keys-st (spec-state ()))
(state-key! keys-st "/")
(state-key! keys-st "s")
(state-key! keys-st "h")
(def keys-a (row-pid (state-selected keys-st)))
(state-key! keys-st 'enter)
(write (list keys-a (state-mode keys-st) (state-search keys-st)))
```
---
    (40 'main "sh")

### a search that finds nothing says so

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'f3)
(state-key! keys-st "z")
(write (state-message keys-st))
```
---
    "No process holds z"

### \ keeps the rows whose command holds the text; Escape drops it

```top
(def keys-st (spec-state ()))
(state-key! keys-st "\\")
(state-key! keys-st "i")
(def keys-a (spec-pids keys-st))
(state-key! keys-st 'escape)
(write (list keys-a (spec-pids keys-st) (state-filter keys-st)))
```
---
    ((41 1) (41 50 40 1) "")

### u shows the selected process's user, and again everyone

```top
(def keys-st (spec-state ()))
(state-key! keys-st "u")
(def keys-a (spec-pids keys-st))
(state-key! keys-st "u")
(write (list keys-a (spec-pids keys-st)))
```
---
    ((41 40) (41 50 40 1))

### a user named on the command line is matched by name

```top
(def keys-st (spec-state (list (pair 'user "root"))))
(write (spec-pids keys-st))
```
---
    (50 1)

## signals and nice

### F9 opens the list on TERM; Enter sends it to the selected process

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'f9)
(def keys-a (list (state-mode keys-st) (state-signal-at keys-st)))
(state-key! keys-st 'up)
(state-key! keys-st 'enter)
(write (list keys-a spec-asked (state-mode keys-st)))
```
---
    (('kill 3) (('signal 41 9)) 'main)

### Escape closes the list and sends nothing

```top
(def keys-st (spec-state ()))
(state-key! keys-st "k")
(state-key! keys-st 'escape)
(write (list spec-asked (state-mode keys-st)))
```
---
    (() 'main)

### F8 raises the nice value; F7 lowers it, and a refusal is shown

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'f8)
(state-key! keys-st 'f7)
(write (list spec-asked (state-message keys-st)))
```
---
    ((('nice 41 -1) ('nice 41 1)) "setpriority: cannot renice 41")

## the rest

### F1 shows the help, any key leaves it; q quits

```top
(def keys-st (spec-state ()))
(state-key! keys-st 'f1)
(def keys-a (state-mode keys-st))
(state-key! keys-st "x")
(def keys-b (state-mode keys-st))
(state-key! keys-st "q")
(write (list keys-a keys-b (state-quit? keys-st)))
```
---
    ('help 'main #t)

### the command line: the arguments, or the name when the kernel gives none

```top
(def keys-st (spec-state ()))
(write (List map (fn (_ e) (state-command keys-st (first e))) (state-shown keys-st)))
```
---
    ("vi notes.txt" "daemon" "sh" "init")
