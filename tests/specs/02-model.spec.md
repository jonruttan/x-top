# Rows from two samples
@weight 1

top/model: a row a process, its shares worked out between two samples,
sorted, and as a tree.

## rows

### a second apart: the CPU each used over the wall time, in tenths of a percent

```top
(def st (spec-state ()))
(write (List map (fn (_ r) (list (row-pid r) (row-cpu r) (row-mem r))) (state-rows st)))
```
---
    ((1 0 0) (2 0 0) (7 0 0) (40 10 0) (41 500 0) (50 250 15))

### the user's name, the priority from nice, the time and the threads

```top
(def r (List find (fn (_ r) (= (row-pid r) 50)) (state-rows (spec-state ()))))
(write (list (row-user r) (row-pri r) (row-nice r) (row-state r) (row-time r) (row-threads r) (row-kernel? r)))
```
---
    ("root" 15 -5 "D" 60250000000 8 #f)

### kthreadd and its children are kernel threads

```top
(write (List map row-pid (List filter row-kernel? (state-rows (spec-state ())))))
```
---
    (2 7)

### a process whose start changed between the samples is a new one: no share

```top
(def st (spec-state ()))
(state-sample! st (spec-sample 2 (list (spec-proc 41 40 501 "R" "vi" 0 1 1 9000000000 999 1)) (list (spec-cpu 0 0 0 1) (spec-cpu 0 0 0 1))))
(write (List map row-cpu (state-rows st)))
```
---
    (0)

### the first sample has no shares

```top
(def st (spec-state ()))
(def fresh (state-make () (fn (_ u) "u") (fn (_ p) ()) () () ()))
(state-sample! fresh (spec-sample 0 spec-procs-1 spec-cpus-1))
(write (List map row-cpu (state-rows fresh)))
```
---
    (0 0 0 0 0 0)

## order

### by CPU, largest first, is the default; kernel threads are hidden

```top
(write (spec-pids (spec-state ())))
```
---
    (41 50 40 1)

### N sorts by pid, I turns it over, M by memory, T by time

```top
(def st (spec-state ()))
(state-key! st "N")
(def a (spec-pids st))
(state-key! st "I")
(def b (spec-pids st))
(state-key! st "M")
(def c (spec-pids st))
(state-key! st "T")
(write (list a b c (spec-pids st)))
```
---
    ((1 40 41 50) (50 41 40 1) (50 1 40 41) (50 41 40 1))

### > steps to the next column, < back; user sorts by name

```top
(def st (spec-state ()))
(state-key! st ">")
(def a (state-sort st))
(state-key! st "<")
(state-key! st "<")
(state-key! st "<")
(state-key! st "<")
(state-key! st "<")
(state-key! st "<")
(state-key! st "<")
(write (list a (state-sort st) (spec-pids st)))
```
---
    ('mem 'user (40 41 1 50))

## the tree

### each process under its parent, siblings in the sort's order

```top
(def st (spec-state ()))
(state-key! st "t")
(List for-each (fn (_ e) (display (rest e)) (display (row-comm (first e))) (display "\n")) (state-shown st))
```
---
```output
init
├─ daemon
└─ sh
   └─ vi
```

### kernel threads shown under kthreadd, a root of its own

```top
(def st (spec-state ()))
(state-key! st "t")
(state-key! st "K")
(state-key! st "N")
(List for-each (fn (_ e) (display (rest e)) (display (row-comm (first e))) (display "\n")) (state-shown st))
```
---
```output
init
├─ sh
│  └─ vi
└─ daemon
kthreadd
└─ kworker
```
