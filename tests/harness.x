; # x-top -- an interactive process viewer on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The bundle kit's generator writes tests/lib/harness.gen.x: the dialect
; bundle.xon declares, the bundle's lib/ on the import path, then this file.
;
; Samples made by hand, so a screen comes out the same on any kernel:
; spec-proc a process record with Host's fields in Host's order,
; spec-sample a sample of them, spec-state a state over a world that
; touches nothing and writes down the signals and nice values asked for.
(import top/base)
(import x/sys/gc)
(import x/tui/screen)
(import x/tui/style)

(def spec-proc
  (fn (_ pid ppid uid state comm nice vsz rss cpu-ns start threads)
    (list (pair (lit pid) pid) (pair (lit ppid) ppid) (pair (lit pgid) pid) (pair (lit sid) pid)
          (pair (lit uid) uid) (pair (lit gid) uid) (pair (lit ruid) uid) (pair (lit rgid) uid)
          (pair (lit state) state) (pair (lit comm) comm) (pair (lit tty) ()) (pair (lit tty-major) ())
          (pair (lit tty-minor) ()) (pair (lit nice) nice) (pair (lit start) start) (pair (lit threads) threads)
          (pair (lit vsz) vsz) (pair (lit rss) rss) (pair (lit utime) cpu-ns) (pair (lit stime) 0)
          (pair (lit processor) ()))))

; A cpu record from user nice system idle, in nanoseconds.
(def spec-cpu
  (fn (_ user nice system idle)
    (list (pair (lit user) user) (pair (lit nice) nice) (pair (lit system) system) (pair (lit idle) idle)
          (pair (lit iowait) ()) (pair (lit irq) ()) (pair (lit softirq) ()) (pair (lit steal) ())
          (pair (lit guest) ()) (pair (lit guest-nice) ()))))

(def spec-memory
  (list (pair (lit total) 17179869184) (pair (lit free) 4294967296) (pair (lit buffers) 1073741824)
        (pair (lit cached) 2147483648) (pair (lit swap-total) 2147483648) (pair (lit swap-free) 1610612736)))

(def spec-boot 1790000000)

; A sample AT seconds after boot of PROCS, its two processors' records CPUS.
(def spec-sample
  (fn (_ at procs cpus)
    (sample-make (* (+ spec-boot at) 1000000) (first cpus) cpus spec-memory (list (Float / 3 2) (Float / 3 4) (Float / 1 4))
                 (list (pair (lit running) 1) (pair (lit total) 4) (pair (lit last-pid) 99)) spec-boot procs)))

; The machine two samples show: a second apart; init, a shell, its editor
; using half a processor, a busy root daemon and kthreadd's child.
(def spec-procs-1
  (list (spec-proc 1 0 0 "S" "init" 0 4194304 1048576 1000000000 100 1)
        (spec-proc 2 0 0 "S" "kthreadd" 0 0 0 0 100 1)
        (spec-proc 7 2 0 "S" "kworker" 0 0 0 0 100 1)
        (spec-proc 40 1 501 "S" "sh" 0 8388608 2097152 2000000000 200 1)
        (spec-proc 41 40 501 "R" "vi" 0 33554432 16777216 3000000000 300 2)
        (spec-proc 50 1 0 "S" "daemon" -5 1073741824 268435456 60000000000 150 8)))

(def spec-procs-2
  (list (spec-proc 1 0 0 "S" "init" 0 4194304 1048576 1000000000 100 1)
        (spec-proc 2 0 0 "S" "kthreadd" 0 0 0 0 100 1)
        (spec-proc 7 2 0 "S" "kworker" 0 0 0 0 100 1)
        (spec-proc 40 1 501 "S" "sh" 0 8388608 2097152 2010000000 200 1)
        (spec-proc 41 40 501 "R" "vi" 0 33554432 16777216 3500000000 300 2)
        (spec-proc 50 1 0 "D" "daemon" -5 1073741824 268435456 60250000000 150 8)))

(def spec-cpus-1 (list (spec-cpu 100 0 100 800) (spec-cpu 0 0 0 1000)))
(def spec-cpus-2 (list (spec-cpu 400 100 200 1300) (spec-cpu 0 0 0 2000)))

; What the world was asked: (signal PID SIG) and (nice PID N), newest first.
(def spec-asked ())

(def spec-state
  (fn (_ opts)
    (set! spec-asked ())
    (def st (state-make opts
              (fn (_ uid) (if (= uid 0) "root" (if (= uid 501) "jon" ())))
              (fn (_ pid) (if (= pid 41) (list "vi" "notes.txt") ()))
              (fn (_ pid sig) (set! spec-asked (pair (list (lit signal) pid sig) spec-asked)) 0)
              (fn (_ pid n) (set! spec-asked (pair (list (lit nice) pid n) spec-asked)) (if (< n 0) "setpriority: cannot renice 41" 0))
              (list (pair "HUP" 1) (pair "INT" 2) (pair "KILL" 9) (pair "TERM" 15))))
    (state-sample! st (spec-sample 0 spec-procs-1 spec-cpus-1))
    (state-sample! st (spec-sample 1 spec-procs-2 spec-cpus-2))
    st))

; The pids shown, in order.
(def spec-pids (fn (_ st) (List map (fn (_ e) (row-pid (first e))) (state-shown st))))

; ST drawn on a screen ROWS by COLS.
(def spec-screen
  (fn (_ st rows cols)
    (def screen (Screen make rows cols))
    (view-draw! st screen)
    screen))

; ST drawn, its lines printed, the trailing spaces cut.
(def spec-draw
  (fn (_ st rows cols)
    (display (Str8 join "\n" (List map (fn (_ l) (Str8 trim-right l)) (view-text (spec-screen st rows cols)))))))

; The (FG . BG) of each (ROW COL) cell.
(def spec-colours
  (fn (_ screen cells)
    (List map (fn (_ c) ((fn (_ s) (pair (Style fg s) (Style bg s))) (Screen style-at screen (first c) (first (rest c)))))
      cells)))
