; # x-top -- an interactive process viewer on x-lang
;
; ## top/view.x -- the meters, the process table and the key bar, on a screen
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Laid out as htop lays out its defaults.  The header is two columns: the
; left holds the first half of the processors' bars, then memory and
; swap; the right the other half, then the task counts, the load
; averages and the uptime.  A half with more than eight processors sets
; its bars side by side.  A processor's bar is coloured by where its time
; went since the last sample: nice blue, user green, system (and
; interrupts) red, steal and guest cyan; memory's is used green, buffers
; blue and cache yellow, used being what is in neither nor free.
;
; Under the header, the column titles, the sort column's marked, then a
; row a process, the selected one in reverse colours; the last row lists
; the function keys, or the text being typed for a search or a filter.
; The kill list takes the table's left side while it is open, and the
; help the whole screen.

(module top/view)

(import x/tui/screen Screen screen-put! screen-fill!)
(import x/tui/style Style)
(import top/format fmt-right fmt-left fmt-cut fmt-percent fmt-size fmt-meter-size fmt-time fmt-uptime fmt-hundredths)
(import top/model sample-at sample-cpu sample-cpus sample-memory sample-load sample-tasks sample-boot
  row-pid row-user row-pri row-nice row-virt row-res row-state row-cpu row-mem row-time row-threads row-kernel?)
(import top/state columns column-name column-title column-width column-right? state-shown state-top state-at
  state-sort state-mode state-input state-message state-cur state-prev state-page! state-command state-signals
  state-signal-at state-tree? state-filter state-user state-user-name state-rows state-kernel?)

; --- styles ------------------------------------------------------------------------

(def %style (fn (_ attrs fg bg) (Style make attrs fg bg)))

(def %PLAIN 0)
(def %LABEL (%style () 6 ()))           ; a meter's name, cyan
(def %BRACKET (%style (list (lit bold)) () ()))
(def %SHADOW (%style (list (lit bold)) 0 ()))   ; a meter's text on no bar
(def %VALUE (%style (list (lit bold)) 6 ()))    ; the task counts and the rest
(def %BLUE (%style () 4 ()))
(def %GREEN (%style () 2 ()))
(def %RED (%style () 1 ()))
(def %CYAN (%style () 6 ()))
(def %YELLOW (%style () 3 ()))
(def %TITLE (%style () 0 2))            ; the column titles, black on green
(def %SORTED (%style () 0 6))           ; the sort column's title, black on cyan
(def %SELECTED (%style () 0 6))         ; the selected row
(def %KEY %PLAIN)                       ; a function key's name
(def %KEY-LABEL (%style () 0 6))        ; and what it does
(def %RUNNING (%style (list (lit bold)) 2 ()))
(def %WAITING (%style (list (lit bold)) 1 ()))
(def %TREE (%style () 6 ()))

; --- meters ------------------------------------------------------------------------

; Cells put in runs: (TEXT . STYLE) from COL along ROW.
(def %runs!
  (fn (self screen row col runs)
    (unless (null? runs)
      (screen-put! screen row col (first (first runs)) (rest (first runs)))
      (self screen row (+ col (Str8 length (first (first runs)))) (rest runs)))))

; A bar W cells wide at ROW and COL: LABEL in three cells, then the bar
; in brackets, its SEGMENTS (TENTHS . STYLE) of a thousand filled with |
; from the left and TEXT on its right end.
(def %bar!
  (fn (_ screen row col w label segments text)
    (def inner (- w 5))
    (when (> inner 0)
      (screen-put! screen row col (fmt-right 3 label) %LABEL)
      (screen-put! screen row (+ col 3) "[" %BRACKET)
      (screen-put! screen row (+ col 4 inner) "]" %BRACKET)
      (def t (fmt-cut inner text))
      (def text-at (- inner (Str8 length t)))
      ; each cell's style: the segment it falls in, or none
      (def cells
        (fn (self segs from i acc)
          (if (null? segs) (List reverse acc)
            (let ((to (+ from (/ (* (first (first segs)) inner) 1000))))
              (def end (if (> to inner) inner to))
              (self (rest segs) end i (if (> end from) (pair (list from end (rest (first segs))) acc) acc))))))
      (def spans (cells segments 0 0 ()))
      (def filled (if (null? spans) 0 (first (rest (List last spans)))))
      ; bars, then the text over them: where a bar runs under the text the
      ; text takes the bar's colour, elsewhere the shadow
      (List for-each
        (fn (_ s)
          (def from (first s))
          (def end (first (rest s)))
          (def bar-end (if (< end text-at) end text-at))
          (when (> bar-end from) (screen-put! screen row (+ col 4 from) (Str8 repeat (- bar-end from) "|") (first (rest (rest s)))))
          (when (> end text-at)
            (let ((a (if (> from text-at) from text-at)))
              (screen-put! screen row (+ col 4 a) (Str8 sub (- a text-at) (- end a) t) (first (rest (rest s)))))))
        spans)
      (when (< filled inner)
        (let ((a (if (> filled text-at) filled text-at)))
          (when (< a inner) (screen-put! screen row (+ col 4 a) (Str8 sub (- a text-at) (- inner a) t) %SHADOW)))))))

(def %z (fn (_ n) (if (null? n) 0 n)))
(def %d (fn (_ k now was) (let ((v (- (%z (Assoc get k now)) (%z (Assoc get k was))))) (if (< v 0) 0 v))))

; A processor's segments and text from two cpu records.
(def %cpu-bar
  (fn (_ now was)
    (def keys (list (lit user) (lit nice) (lit system) (lit idle) (lit iowait) (lit irq) (lit softirq) (lit steal)))
    (def total (List fold (fn (_ acc k) (+ acc (%d k now was))) 0 keys))
    (def part (fn (_ n) (if (= total 0) 0 (/ (* n 1000) total))))
    (def nice (part (%d (lit nice) now was)))
    (def user (part (- (%d (lit user) now was) (+ (%d (lit guest) now was) 0))))
    (def system (part (+ (%d (lit system) now was) (+ (%d (lit irq) now was) (%d (lit softirq) now was)))))
    (def virt (part (+ (%d (lit steal) now was) (%d (lit guest) now was))))
    (def busy (+ nice (+ (if (< user 0) 0 user) (+ system virt))))
    (pair (list (pair nice %BLUE) (pair (if (< user 0) 0 user) %GREEN) (pair system %RED) (pair virt %CYAN))
          (Str8 append (fmt-percent busy) "%"))))

(def %mem-bar
  (fn (_ m)
    (def total (%z (Assoc get (lit total) m)))
    (def buffers (%z (Assoc get (lit buffers) m)))
    (def cache (+ (%z (Assoc get (lit cached) m)) (%z (Assoc get (lit reclaimable) m))))
    (def used (- (- (- total (%z (Assoc get (lit free) m))) buffers) cache))
    (def part (fn (_ n) (if (= total 0) 0 (/ (* n 1000) total))))
    (pair (list (pair (part used) %GREEN) (pair (part buffers) %BLUE) (pair (part cache) %YELLOW))
          (Str8 append (fmt-meter-size (if (< used 0) 0 used)) "/" (fmt-meter-size total)))))

(def %swap-bar
  (fn (_ m)
    (def total (%z (Assoc get (lit swap-total) m)))
    (def used (- total (%z (Assoc get (lit swap-free) m))))
    (pair (list (pair (if (= total 0) 0 (/ (* used 1000) total)) %RED))
          (Str8 append (fmt-meter-size used) "/" (fmt-meter-size total)))))

; Text meters: (LABEL . ((TEXT . STYLE) ...)).
(def %text!
  (fn (_ screen row col w label runs)
    (screen-put! screen row col label %LABEL)
    (%runs! screen row (+ col (Str8 length label)) runs)))

(def %tasks-runs
  (fn (_ st)
    ; every process, filtered or not; kernel threads only when shown
    (def shown (List filter (fn (_ r) (if (row-kernel? r) (state-kernel? st) #t)) (state-rows st)))
    (def threads (List fold (fn (_ acc r) (+ acc (if (null? (row-threads r)) 0 (- (row-threads r) 1)))) 0 shown))
    (def running (List count-if (fn (_ r) (if (str? (row-state r)) (str=? (row-state r) "R") #f)) shown))
    (list (pair (Str8 str (List length shown)) %VALUE) (pair ", " %LABEL)
          (pair (Str8 str threads) %VALUE) (pair " thr; " %LABEL)
          (pair (Str8 str running) %VALUE) (pair " running" %LABEL))))

(def %load-runs
  (fn (_ load)
    (def c (fn (_ l) (fmt-hundredths (Float ->int (Float * l 100)))))
    (if (null? load) (list (pair "?" %VALUE))
      (list (pair (c (first load)) %VALUE) (pair " " %PLAIN)
            (pair (c (first (rest load))) %CYAN) (pair " " %PLAIN)
            (pair (c (first (rest (rest load)))) %CYAN)))))

; The header's rows: two columns, each a list of meters drawn by
; (fn (_ screen row col w) ...); answers the rows it took.
(def %header!
  (fn (_ st screen cols)
    (def now (state-cur st))
    (def was (state-prev st))
    (def cpus (sample-cpus now))
    (def befores (if (null? was) (List map (fn (_ c) ()) cpus) (sample-cpus was)))
    (def bars (List map (fn (_ n b) (%cpu-bar n (if (null? b) () b))) cpus
                (if (= (List length befores) (List length cpus)) befores (List map (fn (_ c) ()) cpus))))
    (def numbered (List map (fn (_ b i) (pair i b)) bars (List range 0 (List length bars))))
    (def half (/ (+ (List length numbered) 1) 2))
    (def left-cpus (List take half numbered))
    (def right-cpus (List drop half numbered))
    (def per (fn (_ n) (if (> n 8) (/ (+ n 7) 8) 1)))
    (def cpu-rows
      ; a half's processors, k side by side: rows of (i . bar) lists
      (fn (_ l)
        (def k (per (List length l)))
        (List chunk k l)))
    (def mem (sample-memory now))
    (def boot (sample-boot now))
    (def secs (- (/ (sample-at now) 1000000) (if (null? boot) 0 boot)))
    (def colw (/ cols 2))
    (def draw-cpus!
      (fn (_ row col w chunk)
        (def k (List length chunk))
        (def each (/ w (if (= k 0) 1 k)))
        (List for-each
          (fn (_ e j)
            (%bar! screen row (+ col (* j each)) (- each (if (< (+ j 1) k) 1 0)) (Str8 str (first e))
                   (first (rest e)) (rest (rest e))))
          chunk (List range 0 k))))
    (def left
      (List append
        (List map (fn (_ c) (fn (_ row col w) (draw-cpus! row col w c))) (cpu-rows left-cpus))
        (list (fn (_ row col w) (let ((b (%mem-bar mem))) (%bar! screen row col w "Mem" (first b) (rest b))))
              (fn (_ row col w) (let ((b (%swap-bar mem))) (%bar! screen row col w "Swp" (first b) (rest b)))))))
    (def right
      (List append
        (List map (fn (_ c) (fn (_ row col w) (draw-cpus! row col w c))) (cpu-rows right-cpus))
        (list (fn (_ row col w) (%text! screen row col w "Tasks: " (%tasks-runs st)))
              (fn (_ row col w) (%text! screen row col w "Load average: " (%load-runs (sample-load now))))
              (fn (_ row col w) (%text! screen row col w "Uptime: " (list (pair (fmt-uptime secs) %VALUE)))))))
    (List for-each (fn (_ m i) (m i 1 (- colw 2))) left (List range 0 (List length left)))
    (List for-each (fn (_ m i) (m i (+ colw 1) (- (- cols colw) 2))) right (List range 0 (List length right)))
    (+ (if (> (List length left) (List length right)) (List length left) (List length right)) 1)))

; --- the table ---------------------------------------------------------------------

(def %cell
  (fn (_ c r)
    (def name (column-name c))
    (match
      ((eq? name (lit pid)) (Str8 str (row-pid r)))
      ((eq? name (lit user)) (fmt-cut (- (column-width c) 1) (row-user r)))
      ((eq? name (lit pri)) (Str8 str (row-pri r)))
      ((eq? name (lit ni)) (if (null? (row-nice r)) "-" (Str8 str (row-nice r))))
      ((eq? name (lit virt)) (fmt-size (row-virt r)))
      ((eq? name (lit res)) (fmt-size (row-res r)))
      ((eq? name (lit state)) (if (null? (row-state r)) "?" (row-state r)))
      ((eq? name (lit cpu)) (fmt-percent (row-cpu r)))
      ((eq? name (lit mem)) (fmt-percent (row-mem r)))
      ((eq? name (lit time)) (if (null? (row-time r)) "-" (fmt-time (row-time r))))
      (#t ""))))

(def %fit (fn (_ c s) (if (column-right? c) (fmt-right (column-width c) s) (fmt-left (column-width c) s))))

(def %titles!
  (fn (_ st screen row cols)
    (screen-fill! screen row 0 cols %TITLE)
    (def go
      (fn (self cs col)
        (unless (null? cs)
          (let ((c (first cs)))
            (def text (if (= (column-width c) 0) (column-title c) (%fit c (column-title c))))
            (screen-put! screen row col text (if (eq? (column-name c) (state-sort st)) %SORTED %TITLE))
            (self (rest cs) (+ col (+ (Str8 length text) 1)))))))
    (go columns 0)))

(def %row!
  (fn (_ st screen row cols e selected?)
    (def r (first e))
    (when selected? (screen-fill! screen row 0 cols %SELECTED))
    (def style (fn (_ s) (if selected? %SELECTED s)))
    (def go
      (fn (self cs col)
        (unless (null? cs)
          (let ((c (first cs)))
            (if (= (column-width c) 0)
              (do (screen-put! screen row col (rest e) (style %TREE))
                  (screen-put! screen row (+ col (Str8 length (rest e))) (state-command st r) (style %PLAIN)))
              (let ((text (%fit c (%cell c r))))
                (screen-put! screen row col text
                  (style (if (eq? (column-name c) (lit state))
                           (match ((not (str? (row-state r))) %PLAIN) ((str=? (row-state r) "R") %RUNNING)
                                  ((str=? (row-state r) "D") %WAITING) (#t %PLAIN))
                           %PLAIN)))
                (self (rest cs) (+ col (+ (Str8 length text) 1)))))))))
    (go columns 0)))

(def %table!
  (fn (_ st screen from rows cols)
    (def shown (List drop (state-top st) (state-shown st)))
    (def go
      (fn (self l i)
        (when (< i rows)
          (unless (null? l)
            (%row! st screen (+ from i) cols (first l) (= (+ (state-top st) i) (state-at st)))
            (self (rest l) (+ i 1))))))
    (go shown 0)))

; --- the bottom row ----------------------------------------------------------------

(def %keys
  (list (pair "F1" "Help  ") (pair "F3" "Search") (pair "F4" "Filter") (pair "F5" "Tree  ")
        (pair "F6" "SortBy") (pair "F7" "Nice -") (pair "F8" "Nice +") (pair "F9" "Kill  ") (pair "F10" "Quit  ")))

(def %bar-row!
  (fn (_ st screen row cols)
    (def mode (state-mode st))
    (match
      ((not (null? (state-message st)))
        (do (screen-fill! screen row 0 cols %KEY-LABEL) (screen-put! screen row 0 (state-message st) %KEY-LABEL)))
      ((eq? mode (lit search))
        (%runs! screen row 0 (list (pair "Search: " %KEY-LABEL) (pair (state-input st) %PLAIN))))
      ((eq? mode (lit filter))
        (%runs! screen row 0 (list (pair "Filter: " %KEY-LABEL) (pair (state-input st) %PLAIN))))
      (#t (do (%runs! screen row 0
                (List flat-map (fn (_ k) (list (pair (first k) %KEY) (pair (rest k) %KEY-LABEL))) %keys))
              ; a filter kept shows on the right
              (unless (Str8 empty? (state-filter st))
                (let ((t (Str8 append " FILTER: " (state-filter st) " ")))
                  (screen-put! screen row (- cols (Str8 length t)) t %KEY-LABEL))))))))

; --- the kill list and the help ----------------------------------------------------

(def %kill-list!
  (fn (_ st screen from rows)
    (def w 16)
    (screen-fill! screen from 0 w %TITLE)
    (screen-put! screen from 0 "Send signal:" %TITLE)
    (def sigs (state-signals st))
    (def at (state-signal-at st))
    (def top (if (< at (- rows 1)) 0 (+ (- at rows) 2)))
    (def go
      (fn (self l i)
        (when (if (< i (- rows 1)) (not (null? l)) #f)
          (let ((k (+ top i)) (s (first l)))
            (def text (fmt-left w (Str8 append (fmt-right 3 (Str8 str (rest s))) " " (first s))))
            (screen-put! screen (+ from (+ i 1)) 0 text (if (= k at) %SELECTED %PLAIN))
            (self (rest l) (+ i 1))))))
    (go (List drop top sigs) 0)))

(def help-lines
  (list "x-top -- an interactive process viewer on x-lang"
        ""
        "CPU bars: [nice  normal  kernel  virt   used%]   (blue green red cyan)"
        "Mem bar:  [used  buffers  cache   used/total]    (green blue yellow)"
        "Swp bar:  [used                  used/total]"
        ""
        " Arrows PgUp PgDn Home End: move the selection"
        " F1 h ?: this help          F10 q ^C: quit"
        " F3 /: search, F3 for the next; Enter keeps the text, Esc ^G drop it"
        " F4 \\: filter by command    F5 t: tree view"
        " F6 > <: next/previous sort column      I: invert the order"
        " P M T N: sort by CPU%, MEM%, TIME+, PID"
        " F7 ]: nice - (higher priority)          F8 [: nice + (lower)"
        " F9 k: send a signal         u: only the selected process's user, again all"
        " K: show kernel threads"
        ""
        "Press any key to return."))

(def %help!
  (fn (_ screen)
    (List for-each (fn (_ l i) (screen-put! screen i 0 l (if (= i 0) %BRACKET %PLAIN)))
      help-lines (List range 0 (List length help-lines)))))

; --- the screen --------------------------------------------------------------------

; Everything ST shows drawn on SCREEN, the screen cleared first.
(def view-draw!
  (fn (_ st screen)
    (def rows (Screen rows screen))
    (def cols (Screen cols screen))
    (Screen clear screen)
    (if (eq? (state-mode st) (lit help)) (%help! screen)
      (let ((h (%header! st screen cols)))
        (def page (- (- rows h) 2))
        (state-page! st page)
        (%titles! st screen h cols)
        (%table! st screen (+ h 1) page cols)
        (when (eq? (state-mode st) (lit kill)) (%kill-list! st screen (+ h 1) page))
        (%bar-row! st screen (- rows 1) cols)))
    (Screen cursor screen (- rows 1) (if (if (eq? (state-mode st) (lit search)) #t (eq? (state-mode st) (lit filter)))
                                       (+ 8 (Str8 length (state-input st))) 0))))

; The screen's rows as text, trailing blanks dropped: what a dump prints.
(def view-text
  (fn (_ screen)
    (List map (fn (_ i) (Str8 trim-right (Screen row-text screen i))) (List range 0 (Screen rows screen)))))

(provide top/view view-draw! view-text help-lines)
