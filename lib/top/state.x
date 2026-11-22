; # x-top -- an interactive process viewer on x-lang
;
; ## top/state.x -- what is shown, and what the keys do to it
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The state is a vector of the slots below.  The world reaches it through
; four functions it is made with, so a spec drives every key with no
; process touched: NAME answers a uid's user name, ARGS a process's
; argument vector or nil, SIGNAL sends a signal and NICE sets a nice
; value, each of the last two answering 0 or an error's text.
;
; The keys are htop's: the arrows, the page keys, Home and End move the
; selection; P M T N sort by CPU, memory, time and pid, I turns the
; order over, F6 or > and < step through the columns; F5 or t is the
; tree; K shows kernel threads; u shows only the selected process's user
; and again everyone's; F3 or / searches the commands and F3 again finds
; the next, F4 or \ keeps only the rows whose command holds the text,
; Enter keeping it and Escape dropping it; F9 or k sends a signal from a
; list, TERM first chosen; F7 or ] and F8 or [ lower and raise the nice
; value; F1, h or ? is the help; F10, q and ^C quit.

(module top/state)

(import top/model rows-make rows-sort rows-tree rows-flat sample-at sample-procs sample-memory
  row-pid row-uid row-user row-nice row-pri row-virt row-res row-state row-cpu row-mem row-time row-comm
  row-start row-kernel?)

; --- slots -------------------------------------------------------------------------

(def %ROWS 0)       ; the latest sample's rows, by pid
(def %PREV 1)       ; the sample before
(def %CUR 2)        ; the latest sample
(def %SORT 3)       ; the sort column's name
(def %DOWN 4)       ; descending?
(def %TREE 5)       ; the tree view?
(def %PID 6)        ; the selected process
(def %TOP 7)        ; the shown row on the table's first line
(def %FILTER 8)     ; text a command must hold, "" for none
(def %USER 9)       ; the only uid shown, or nil for all
(def %KERNEL 10)    ; kernel threads shown?
(def %MODE 11)      ; main help kill search filter
(def %INPUT 12)     ; the text being typed
(def %SIGNAL 13)    ; the kill list's chosen line
(def %QUIT 14)      ; leave?
(def %MESSAGE 15)   ; a line for the bottom, or nil
(def %NAMES 16)     ; (uid . name), the names looked up
(def %ARGS 17)      ; (pid start . text), the commands looked up
(def %DELAY 18)     ; milliseconds between samples
(def %SHOWN 19)     ; ((row . prefix) ...), in the order shown
(def %PAGE 20)      ; the table's lines when last drawn
(def %AT 21)        ; the selected line, from 0
(def %NAME-FN 22)
(def %ARGS-FN 23)
(def %SIGNAL-FN 24)
(def %NICE-FN 25)
(def %SIGNALS 26)   ; ((NAME . NUMBER) ...), the kill list
(def %SEARCH 27)    ; the last text searched for
(def %SLOTS 28)

; Two numbers, either of which may be nil, the same.
(def %same? (fn (_ a b) (if (null? a) (null? b) (if (null? b) #f (= a b)))))

(def %ref (fn (_ st k) (Vector ref k st)))
(def %set! (fn (_ st k v) (Vector set! k v st)))

; --- the columns -------------------------------------------------------------------

; (NAME TITLE WIDTH RIGHT? KEY DOWN?): KEY answers the value a row is
; sorted by, DOWN? whether the column sorts largest first when chosen.
(def columns
  (list (list (lit pid) "PID" 7 #t row-pid #f)
        (list (lit user) "USER" 9 #f row-user #f)
        (list (lit pri) "PRI" 3 #t row-pri #t)
        (list (lit ni) "NI" 3 #t row-nice #t)
        (list (lit virt) "VIRT" 6 #t row-virt #t)
        (list (lit res) "RES" 6 #t row-res #t)
        (list (lit state) "S" 1 #f row-state #f)
        (list (lit cpu) "CPU%" 5 #t row-cpu #t)
        (list (lit mem) "MEM%" 5 #t row-mem #t)
        (list (lit time) "TIME+" 9 #t row-time #t)
        (list (lit command) "Command" 0 #f row-comm #f)))

(def column-name first)
(def column-title (fn (_ c) (first (rest c))))
(def column-width (fn (_ c) (first (rest (rest c)))))
(def column-right? (fn (_ c) (first (rest (rest (rest c))))))
(def column-key (fn (_ c) (first (rest (rest (rest (rest c)))))))
(def column-down? (fn (_ c) (first (rest (rest (rest (rest (rest c))))))))

(def column-named (fn (_ name) (List find (fn (_ c) (eq? (column-name c) name)) columns)))

; --- making ------------------------------------------------------------------------

; A state: OPTS an alist of (sort . NAME) (tree . #t) (user . UID)
; (filter . TEXT) (delay . MS) (pid . PID), and the four world functions.
(def state-make
  (fn (_ opts name args signal nice signals)
    (def st (Vector make %SLOTS ()))
    (def opt (fn (_ k d) (let ((c (Assoc entry k opts))) (if (null? c) d (rest c)))))
    (def sort (opt (lit sort) (lit cpu)))
    (%set! st %SORT sort)
    (%set! st %DOWN (column-down? (column-named sort)))
    (%set! st %TREE (opt (lit tree) #f))
    (%set! st %PID (opt (lit pid) ()))
    (%set! st %TOP 0)
    (%set! st %AT 0)
    (%set! st %FILTER (opt (lit filter) ""))
    (%set! st %USER (opt (lit user) ()))
    (%set! st %KERNEL #f)
    (%set! st %MODE (lit main))
    (%set! st %INPUT "")
    (%set! st %SIGNAL 0)
    (%set! st %QUIT #f)
    (%set! st %DELAY (opt (lit delay) 1500))
    (%set! st %PAGE 1)
    (%set! st %NAME-FN name)
    (%set! st %ARGS-FN args)
    (%set! st %SIGNAL-FN signal)
    (%set! st %NICE-FN nice)
    (%set! st %SIGNALS signals)
    (%set! st %SEARCH "")
    st))

(def state-sort (fn (_ st) (%ref st %SORT)))
(def state-down? (fn (_ st) (%ref st %DOWN)))
(def state-tree? (fn (_ st) (%ref st %TREE)))
(def state-mode (fn (_ st) (%ref st %MODE)))
(def state-input (fn (_ st) (%ref st %INPUT)))
(def state-quit? (fn (_ st) (%ref st %QUIT)))
(def state-message (fn (_ st) (%ref st %MESSAGE)))
(def state-delay (fn (_ st) (%ref st %DELAY)))
(def state-shown (fn (_ st) (%ref st %SHOWN)))
(def state-top (fn (_ st) (%ref st %TOP)))
(def state-at (fn (_ st) (%ref st %AT)))
(def state-filter (fn (_ st) (%ref st %FILTER)))
(def state-user (fn (_ st) (%ref st %USER)))
(def state-kernel? (fn (_ st) (%ref st %KERNEL)))
(def state-rows (fn (_ st) (%ref st %ROWS)))
(def state-prev (fn (_ st) (%ref st %PREV)))
(def state-cur (fn (_ st) (%ref st %CUR)))
(def state-signals (fn (_ st) (%ref st %SIGNALS)))
(def state-signal-at (fn (_ st) (%ref st %SIGNAL)))
(def state-search (fn (_ st) (%ref st %SEARCH)))

; The table's height, set by the view as it draws.
(def state-quit! (fn (_ st) (%set! st %QUIT #t)))
(def state-page! (fn (_ st n) (%set! st %PAGE (if (< n 1) 1 n))))

; --- the world ---------------------------------------------------------------------

; A uid's name, looked up once.
(def state-user-name
  (fn (_ st uid)
    (if (null? uid) "?"
      (let ((hit (List find (fn (_ e) (= (first e) uid)) (%ref st %NAMES))))
        (if (not (null? hit)) (rest hit)
          (let ((n ((%ref st %NAME-FN) uid)))
            (def s (if (null? n) (Str8 str uid) n))
            (%set! st %NAMES (pair (pair uid s) (%ref st %NAMES)))
            s))))))

; A row's command line: its arguments joined, looked up once for the
; process, or its name when the kernel gives none, as for a
; kernel thread or another user's process on Darwin.
(def state-command
  (fn (_ st row)
    (def pid (row-pid row))
    (def hit (List find (fn (_ e) (if (= (first e) pid) (%same? (first (rest e)) (row-start row)) #f)) (%ref st %ARGS)))
    (if (not (null? hit)) (rest (rest hit))
      (let ((a ((%ref st %ARGS-FN) pid)))
        (def s (if (if (null? a) #t (null? (List filter (fn (_ x) (not (Str8 empty? x))) a)))
                 (Str8 append (row-comm row))
                 (Str8 join " " a)))
        (%set! st %ARGS (pair (pair pid (pair (row-start row) s)) (%ref st %ARGS)))
        s))))

; Commands looked up for processes no longer shown are dropped.
(def %forget!
  (fn (_ st)
    (def live (List map (fn (_ e) (row-pid (first e))) (%ref st %SHOWN)))
    (%set! st %ARGS (List filter (fn (_ e) (List includes? (first e) live)) (%ref st %ARGS)))))

; --- what is shown -----------------------------------------------------------------

(def %holds?
  (fn (_ text part) (if (Str8 empty? part) #t (not (null? (Str8 index-of part text))))))

; The user shown is a uid, or a name matched against the rows' names.
(def %other-user?
  (fn (_ st r)
    (def u (%ref st %USER))
    (match ((null? u) #f) ((str? u) (not (str=? u (row-user r)))) (#t (not (%same? u (row-uid r)))))))

(def %kept?
  (fn (_ st r)
    (match
      ((if (row-kernel? r) (not (%ref st %KERNEL)) #f) #f)
      ((%other-user? st r) #f)
      (#t (%holds? (row-comm r) (%ref st %FILTER))))))

; The shown rows again from the latest rows: kept, sorted, flat or a tree.
; FOLLOW keeps the selection on its process, as after a key that changes
; the order; without it the selection keeps its line, as htop's does when
; a new sample moves the processes under it.
(def %show!
  (fn (_ st follow)
    (def col (column-named (%ref st %SORT)))
    (def sorted (rows-sort (List filter (fn (_ r) (%kept? st r)) (%ref st %ROWS)) (column-key col) (%ref st %DOWN)))
    (%set! st %SHOWN (if (%ref st %TREE) (rows-tree sorted) (rows-flat sorted)))
    (def pid (%ref st %PID))
    (def i (if (if follow (not (null? pid)) #f) (List find-index (fn (_ e) (= (row-pid (first e)) pid)) (%ref st %SHOWN)) ()))
    (%select! st (if (null? i) (%ref st %AT) i))
    (%forget! st)))

(def state-show! (fn (_ st) (%show! st #t)))

; A new sample: the rows worked out against the last ones, then shown.
(def state-sample!
  (fn (_ st sample)
    (def prev (%ref st %CUR))
    (def wall (if (null? prev) 0 (- (sample-at sample) (sample-at prev))))
    (def total (Assoc get (lit total) (sample-memory sample)))
    (%set! st %ROWS (rows-make (if (null? prev) () (%ref st %ROWS)) wall (sample-procs sample) total
                      (fn (_ uid) (state-user-name st uid))))
    (%set! st %PREV prev)
    (%set! st %CUR sample)
    (%show! st #f)))

; The line I selected, kept on the table and in sight.
(def %select!
  (fn (_ st i)
    (def n (List length (%ref st %SHOWN)))
    (def at (match ((< i 0) 0) ((< i n) i) (#t (if (= n 0) 0 (- n 1)))))
    (%set! st %AT at)
    (%set! st %PID (if (= n 0) () (row-pid (first (List ref at (%ref st %SHOWN))))))
    (def page (%ref st %PAGE))
    (def top (%ref st %TOP))
    (%set! st %TOP (match ((< at top) at) ((< at (+ top page)) (if (> top (- n page)) (if (< (- n page) 0) 0 (- n page)) top)) (#t (+ (- at page) 1))))))

(def state-selected
  (fn (_ st)
    (def s (%ref st %SHOWN))
    (if (null? s) () (first (List ref (%ref st %AT) s)))))

; --- keys --------------------------------------------------------------------------

(def %is? (fn (_ key s) (if (str? key) (str=? key s) #f)))

(def %sort-by!
  (fn (_ st name)
    (%set! st %SORT name)
    (%set! st %DOWN (column-down? (column-named name)))
    (state-show! st)))

(def %sort-step!
  (fn (_ st by)
    (def names (List map column-name columns))
    (def i (List index-of (%ref st %SORT) names))
    (def n (List length names))
    (%sort-by! st (List ref (% (+ (+ i by) n) n) names))))

(def %search!
  (fn (_ st text from)
    (def s (%ref st %SHOWN))
    (def n (List length s))
    (def go
      (fn (self k)
        (if (< k n)
          (let ((i (% (+ from k) n)))
            (if (%holds? (state-command st (first (List ref i s))) text) (%select! st i) (self (+ k 1))))
          (%set! st %MESSAGE (Str8 append "No process holds " text)))))
    (unless (Str8 empty? text) (go 0))))

(def %error (fn (_ st r) (when (str? r) (%set! st %MESSAGE r))))

(def %nice!
  (fn (_ st by)
    (def r (state-selected st))
    (unless (null? r)
      (let ((v (+ (if (null? (row-nice r)) 0 (row-nice r)) by)))
        (%error st ((%ref st %NICE-FN) (row-pid r) (match ((< v -20) -20) ((> v 19) 19) (#t v))))))))

(def %main-key!
  (fn (_ st key)
    (def page (%ref st %PAGE))
    (def at (%ref st %AT))
    (match
      ((null? key) (%set! st %QUIT #t))
      ((if (eq? key (lit f10)) #t (if (eq? key (lit interrupt)) #t (%is? key "q"))) (%set! st %QUIT #t))
      ((eq? key (lit up)) (%select! st (- at 1)))
      ((eq? key (lit down)) (%select! st (+ at 1)))
      ((eq? key (lit page-up)) (do (%set! st %TOP (if (< (%ref st %TOP) page) 0 (- (%ref st %TOP) page))) (%select! st (- at page))))
      ((eq? key (lit page-down)) (do (%set! st %TOP (+ (%ref st %TOP) page)) (%select! st (+ at page))))
      ((eq? key (lit home)) (%select! st 0))
      ((eq? key (lit end)) (%select! st (List length (%ref st %SHOWN))))
      ((%is? key "P") (%sort-by! st (lit cpu)))
      ((%is? key "M") (%sort-by! st (lit mem)))
      ((%is? key "T") (%sort-by! st (lit time)))
      ((%is? key "N") (%sort-by! st (lit pid)))
      ((%is? key "I") (do (%set! st %DOWN (not (%ref st %DOWN))) (state-show! st)))
      ((if (eq? key (lit f6)) #t (%is? key ">")) (%sort-step! st 1))
      ((%is? key "<") (%sort-step! st -1))
      ((if (eq? key (lit f5)) #t (%is? key "t")) (do (%set! st %TREE (not (%ref st %TREE))) (state-show! st)))
      ((%is? key "K") (do (%set! st %KERNEL (not (%ref st %KERNEL))) (state-show! st)))
      ((%is? key "u")
        (do (%set! st %USER (if (null? (%ref st %USER)) (let ((r (state-selected st))) (if (null? r) () (row-uid r))) ()))
            (state-show! st)))
      ((if (eq? key (lit f3)) #t (%is? key "/")) (do (%set! st %MODE (lit search)) (%set! st %INPUT "")))
      ((if (eq? key (lit f4)) #t (%is? key "\\")) (do (%set! st %MODE (lit filter)) (%set! st %INPUT (%ref st %FILTER))))
      ((if (eq? key (lit f9)) #t (%is? key "k"))
        (unless (null? (state-selected st))
          (%set! st %MODE (lit kill))
          (%set! st %SIGNAL (let ((i (List find-index (fn (_ s) (str=? (first s) "TERM")) (%ref st %SIGNALS)))) (if (null? i) 0 i)))))
      ((if (eq? key (lit f7)) #t (%is? key "]")) (%nice! st -1))
      ((if (eq? key (lit f8)) #t (%is? key "[")) (%nice! st 1))
      ((if (eq? key (lit f1)) #t (if (%is? key "h") #t (%is? key "?"))) (%set! st %MODE (lit help)))
      (#t ()))))

; Typing a search or a filter: text added, Backspace, Enter keeps it,
; Escape drops it; a search moves as it is typed, F3 to the next.
(def %input-key!
  (fn (_ st key)
    (def mode (%ref st %MODE))
    (def text (%ref st %INPUT))
    (def done! (fn (_) (%set! st %MODE (lit main))))
    (def typed!
      (fn (_ t)
        (%set! st %INPUT t)
        (if (eq? mode (lit search)) (%search! st t (%ref st %AT)) (do (%set! st %FILTER t) (state-show! st)))))
    (match
      ((null? key) (done!))
      ((if (eq? key (lit escape)) #t (eq? key (lit abort)))
        (do (when (eq? mode (lit filter)) (%set! st %FILTER "") (state-show! st)) (done!)))
      ((eq? key (lit enter)) (do (when (eq? mode (lit search)) (%set! st %SEARCH text)) (done!)))
      ((eq? key (lit backspace)) (unless (Str8 empty? text) (typed! (Str8 sub 0 (- (Str8 length text) 1) text))))
      ((if (eq? mode (lit search)) (eq? key (lit f3)) #f) (%search! st text (+ (%ref st %AT) 1)))
      ((str? key) (typed! (Str8 append text key)))
      (#t ()))))

(def %kill-key!
  (fn (_ st key)
    (def n (List length (%ref st %SIGNALS)))
    (def i (%ref st %SIGNAL))
    (match
      ((null? key) (%set! st %MODE (lit main)))
      ((eq? key (lit up)) (%set! st %SIGNAL (if (> i 0) (- i 1) 0)))
      ((eq? key (lit down)) (%set! st %SIGNAL (if (< (+ i 1) n) (+ i 1) i)))
      ((eq? key (lit enter))
        (do (let ((r (state-selected st)))
              (unless (null? r)
                (%error st ((%ref st %SIGNAL-FN) (row-pid r) (rest (List ref i (%ref st %SIGNALS)))))))
            (%set! st %MODE (lit main))))
      ((if (eq? key (lit escape)) #t (if (eq? key (lit abort)) #t (if (eq? key (lit f10)) #t (%is? key "q"))))
        (%set! st %MODE (lit main)))
      (#t ()))))

; KEY, as Term key answers one, acted on.
(def state-key!
  (fn (_ st key)
    (%set! st %MESSAGE ())
    (def mode (%ref st %MODE))
    (match
      ((eq? mode (lit help)) (%set! st %MODE (lit main)))
      ((eq? mode (lit kill)) (%kill-key! st key))
      ((if (eq? mode (lit search)) #t (eq? mode (lit filter))) (%input-key! st key))
      (#t (%main-key! st key)))))

(provide top/state columns column-name column-title column-width column-right? column-key column-named
  state-make state-sample! state-show! state-key! state-page! state-quit! state-selected state-command state-user-name
  state-sort state-down? state-tree? state-mode state-input state-quit? state-message state-delay state-shown
  state-top state-at state-filter state-user state-kernel? state-rows state-prev state-cur state-signals
  state-signal-at state-search)
