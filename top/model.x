; # x-top -- an interactive process viewer on x-lang
;
; ## top/model.x -- two samples of the machine, and the rows they give
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A sample is what Host (x/sys/host) reports at one moment:
; (AT CPU CPUS MEMORY LOAD TASKS BOOT PROCS), AT the wall clock in
; microseconds.  Everything shown is worked out from two samples, the
; last and the one before, so a spec hands in two made by hand and the
; screen comes out the same on any kernel.
;
; A row is a list: pid ppid uid user nice virt res state cpu mem time comm
; start threads kernel? box.  cpu and mem are tenths of a percent: cpu is
; the process's CPU time between the samples over the wall time between
; them, so one busy processor is 100; mem is its resident size over the
; machine's memory.  box is a pair the tree view fills: its children,
; then whether it has a parent among the rows.
;
; Host's process records keep their fields in the order its processes
; documents, the same on both kernels; a row is read from a record in one
; walk when the record's keys are in that order, and by name when not.

(module top/model)

(import x/core/doors int< int= int+ int-)

; --- samples -----------------------------------------------------------------------

(def sample-at (fn (_ s) (first s)))
(def sample-cpu (fn (_ s) (first (rest s))))
(def sample-cpus (fn (_ s) (first (rest (rest s)))))
(def sample-memory (fn (_ s) (first (rest (rest (rest s))))))
(def sample-load (fn (_ s) (first (rest (rest (rest (rest s)))))))
(def sample-tasks (fn (_ s) (first (rest (rest (rest (rest (rest s))))))))
(def sample-boot (fn (_ s) (first (rest (rest (rest (rest (rest (rest s)))))))))
(def sample-procs (fn (_ s) (first (rest (rest (rest (rest (rest (rest (rest s))))))))))

(def sample-make
  (fn (_ at cpu cpus memory load tasks boot procs) (list at cpu cpus memory load tasks boot procs)))

; What the machine reports now.
(def sample-take
  (fn (_)
    (def t (Sys time-of-day))
    (sample-make (+ (* (first t) 1000000) (rest t)) (Host cpu) (Host cpus) (Host memory) (Host load)
                 (Host tasks) (Host boot-time) (Host processes))))

; A field of a record: the walk Assoc get makes, without its class send.
(def %get
  (fn (self k r) (match ((null? r) ()) ((eq? (first (first r)) k) (rest (first r))) (#t (self k (rest r))))))

(def %zero (fn (_ n) (if (null? n) 0 n)))

; --- rows --------------------------------------------------------------------------

(def %nth (fn (self n l) (if (int= n 0) (first l) (self (int- n 1) (rest l)))))

(def row-pid first)
(def row-ppid (fn (_ r) (first (rest r))))
(def row-uid (fn (_ r) (%nth 2 r)))
(def row-user (fn (_ r) (%nth 3 r)))
(def row-nice (fn (_ r) (%nth 4 r)))
(def row-virt (fn (_ r) (%nth 5 r)))
(def row-res (fn (_ r) (%nth 6 r)))
(def row-state (fn (_ r) (%nth 7 r)))
(def row-cpu (fn (_ r) (%nth 8 r)))
(def row-mem (fn (_ r) (%nth 9 r)))
(def row-time (fn (_ r) (%nth 10 r)))
(def row-comm (fn (_ r) (%nth 11 r)))
(def row-start (fn (_ r) (%nth 12 r)))
(def row-threads (fn (_ r) (%nth 13 r)))
(def row-kernel? (fn (_ r) (%nth 14 r)))
(def %row-box (fn (_ r) (%nth 15 r)))

; The priority the kernel schedules a time-shared process at: 20 and
; its nice, as /proc/PID/stat's priority field reads for one.
(def row-pri (fn (_ r) (+ 20 (%zero (row-nice r)))))

; The record's keys in Host's order, and the walk that reads them.
(def %order
  (list (lit pid) (lit ppid) (lit pgid) (lit sid) (lit uid) (lit gid) (lit ruid) (lit rgid) (lit state)
        (lit comm) (lit tty) (lit tty-major) (lit tty-minor) (lit nice) (lit start) (lit threads)
        (lit vsz) (lit rss) (lit utime) (lit stime) (lit processor)))

(def %in-order?
  (fn (self ks r)
    (match ((null? ks) #t) ((null? r) #f) ((not (eq? (first ks) (first (first r)))) #f) (#t (self (rest ks) (rest r))))))

(def %values
  (fn (_ r)
    (if (%in-order? %order r) (List map rest r) (List map (fn (_ k) (%get k r)) %order))))

; A kernel thread: kthreadd, pid 2 on Linux, and what it starts.  Darwin
; hands out pid 2 to no such process, so the rule is the same there.
(def %kernel? (fn (_ pid ppid) (if (null? pid) #f (if (int= pid 2) #t (if (null? ppid) #f (int= ppid 2))))))

; The row for a record, before the shares: NAME answers a uid's user name.
(def %row
  (fn (_ r name)
    (def v (%values r))
    (def pid (first v))
    (def ppid (%zero (first (rest v))))
    (def uid (%nth 4 v))
    (def utime (%nth 18 v))
    (def stime (%nth 19 v))
    (list pid ppid uid (name uid) (%nth 13 v) (%nth 16 v) (%nth 17 v) (%nth 8 v) 0 0
          (if (null? utime) () (+ utime (%zero stime)))
          (%zero (%nth 9 v)) (%nth 14 v) (%nth 15 v) (%kernel? pid ppid)
          (pair () #f))))

(def %with-shares
  (fn (_ r cpu mem)
    (def go (fn (self r i) (if (int= i 8) (pair cpu (pair mem (rest (rest r)))) (pair (first r) (self (rest r) (int+ i 1))))))
    (go r 0)))

(def %by-pid (fn (_ rows) (List sort (fn (_ a b) (int< (first a) (first b))) rows)))

; The rows of the latest sample, by pid, each with its shares: its CPU
; time since PREV's row for the same process (the same pid and start)
; over the wall time since PREV.  PREV is the last call's rows, or nil.
(def rows-make
  (fn (_ prev-rows wall-us procs total name)
    (def rows (%by-pid (List map (fn (_ r) (%row r name)) procs)))
    (def mem (fn (_ r) (if (if (null? (row-res r)) #t (null? total)) 0 (/ (* (row-res r) 1000) total))))
    (def share
      (fn (_ r was)
        (if (if (null? was) #t (if (null? (row-time r)) #t (if (null? (row-time was)) #t (< wall-us 1))))
          0
          ((fn (_ d) (if (< d 0) 0 (/ d wall-us))) (- (row-time r) (row-time was))))))
    ; d is nanoseconds; tenths of a percent of the wall time is d * 1000 /
    ; (wall-us * 1000), the two thousands cancelling.
    (def same? (fn (_ a b) (if (null? (row-start a)) (null? (row-start b)) (if (null? (row-start b)) #f (= (row-start a) (row-start b))))))
    (def walk
      (fn (self rs ps acc)
        (match
          ((null? rs) (List reverse acc))
          ((if (null? ps) #t (int< (first (first rs)) (first (first ps))))
            (self (rest rs) ps (pair (%with-shares (first rs) (share (first rs) ()) (mem (first rs))) acc)))
          ((int< (first (first ps)) (first (first rs))) (self rs (rest ps) acc))
          (#t (self (rest rs) (rest ps)
                (pair (%with-shares (first rs) (share (first rs) (if (same? (first rs) (first ps)) (first ps) ()))
                                    (mem (first rs)))
                      acc))))))
    (walk rows prev-rows ())))

; --- order -------------------------------------------------------------------------

; The rows in KEY's order, ascending, or descending when DOWN; ties keep
; pid order.  A key answers a number or a string for a row.
(def rows-sort
  (fn (_ rows key down)
    (def less
      (fn (_ a b)
        (match
          ((null? a) (not (null? b)))
          ((null? b) #f)
          ((str? a) (Str8 <? a b))
          (#t (< a b)))))
    (List sort (if down (fn (_ x y) (less (key y) (key x))) (fn (_ x y) (less (key x) (key y)))) rows)))

; --- the tree ----------------------------------------------------------------------

; ROWS, in the order given, as the tree of parent and child: a list of
; (ROW . PREFIX), each row after its parent and its siblings in the
; order given, PREFIX the lines drawn before its command.  A row whose
; parent is not among the rows is a root.
(def rows-tree
  (fn (_ rows)
    (List for-each (fn (_ r) (%set-first! (%row-box r) ()) (%set-rest! (%row-box r) #f)) rows)
    ; by parent, the given order kept within each family (the sort is stable)
    (def by-parent (List sort (fn (_ a b) (int< (row-ppid a) (row-ppid b))) rows))
    (def attach
      (fn (self ps kids)
        (match
          ((null? ps) ())
          ((null? kids) ())
          ((int< (row-ppid (first kids)) (first (first ps))) (self ps (rest kids)))
          ((int< (first (first ps)) (row-ppid (first kids))) (self (rest ps) kids))
          (#t (let ((p (first ps)))
                (def take
                  (fn (self ks acc)
                    (if (if (null? ks) #f (int= (row-ppid (first ks)) (first p)))
                      (do (unless (int= (first (first ks)) (first p)) (%set-rest! (%row-box (first ks)) #t))
                          (self (rest ks) (if (int= (first (first ks)) (first p)) acc (pair (first ks) acc))))
                      (pair (List reverse acc) ks))))
                (def got (take kids ()))
                (%set-first! (%row-box p) (first got))
                (self (rest ps) (rest got)))))))
    (attach (%by-pid rows) by-parent)
    (def out (Vector of ()))
    (def emit! (fn (_ r prefix) (Vector set! 0 (pair (pair r prefix) (Vector ref 0 out)) out)))
    (def visit
      (fn (self kids lead)
        (unless (null? kids)
          (let ((last? (null? (rest kids))))
            (emit! (first kids) (Str8 append lead (if last? "\xe2\x94\x94\xe2\x94\x80 " "\xe2\x94\x9c\xe2\x94\x80 ")))
            (self (first (%row-box (first kids))) (Str8 append lead (if last? "   " "\xe2\x94\x82  ")))
            (self (rest kids) lead)))))
    (List for-each
      (fn (_ r)
        (unless (rest (%row-box r))
          (emit! r "")
          (visit (first (%row-box r)) "")))
      rows)
    (List reverse (Vector ref 0 out))))

(def rows-flat (fn (_ rows) (List map (fn (_ r) (pair r "")) rows)))

(provide top/model sample-make sample-take sample-at sample-cpu sample-cpus sample-memory sample-load sample-tasks
  sample-boot sample-procs
  rows-make rows-sort rows-tree rows-flat
  row-pid row-ppid row-uid row-user row-nice row-pri row-virt row-res row-state row-cpu row-mem row-time
  row-comm row-start row-threads row-kernel?)
