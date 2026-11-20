; # x-top -- an interactive process viewer on x-lang
;
; ## top/format.x -- numbers as the columns and meters show them
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Sizes arrive in bytes, CPU times in nanoseconds and shares in tenths of
; a percent; each answer here is the text a cell holds.  Sizes pass 2^31
; on a 4-byte word, so they go through the generic operators, never the
; int doors.

(module top/format)

(def %two (fn (_ n) (Str8 pad-left 2 #\0 (Str8 str n))))

; S padded with spaces to W on the left, or on the right.
(def fmt-right (fn (_ w s) (Str8 pad-left w #\space s)))
(def fmt-left (fn (_ w s) (Str8 pad-right w #\space s)))

; S cut to at most W bytes.
(def fmt-cut (fn (_ w s) (if (> (Str8 length s) w) (Str8 sub 0 w s) s)))

; Tenths of a percent: one decimal below 100, whole from 100 up, so the
; column keeps four cells.
(def fmt-percent
  (fn (_ t)
    (if (< t 1000) (Str8 str (/ t 10) "." (% t 10)) (Str8 str (/ t 10)))))

; A process size: KiB below 100000 KiB, then MiB with an M below 100000
; MiB, then GiB with a G, one decimal below 100.
(def fmt-size
  (fn (_ b)
    (if (null? b) "-"
      ((fn (_ k)
         (match
           ((< k 100000) (Str8 str k))
           ((< k 102400000) (Str8 str (/ k 1024) "M"))
           (#t ((fn (_ t) (if (< t 1000) (Str8 str (/ t 10) "." (% t 10) "G") (Str8 str (/ t 10) "G")))
                (/ (* k 10) 1048576)))))
       (/ b 1024)))))

; A meter's size: MiB with an M below 1 GiB, then GiB with two decimals
; below 10, one below 100, none from there.
(def fmt-meter-size
  (fn (_ b)
    (def m (/ b 1048576))
    (match
      ((< m 1024) (Str8 str m "M"))
      (#t ((fn (_ h)
             (match
               ((< h 1000) (Str8 str (/ h 100) "." (%two (% h 100)) "G"))
               ((< h 10000) (Str8 str (/ h 100) "." (/ (% h 100) 10) "G"))
               (#t (Str8 str (/ h 100) "G"))))
           (/ (* b 100) 1073741824))))))

; CPU time: M:SS.hh under an hour, HhMM:SS under a hundred hours, then Nh.
(def fmt-time
  (fn (_ ns)
    (def h (/ (if (null? ns) 0 ns) 10000000))
    (def s (/ h 100))
    (def m (/ s 60))
    (def hr (/ m 60))
    (match
      ((> hr 99) (Str8 str hr "h"))
      ((> hr 0) (Str8 str (fmt-right 2 (Str8 str hr)) "h" (%two (% m 60)) ":" (%two (% s 60))))
      (#t (Str8 str (fmt-right 2 (Str8 str m)) ":" (%two (% s 60)) "." (%two (% h 100)))))))

; Seconds up as "N days, HH:MM:SS", the day dropped under a day.
(def fmt-uptime
  (fn (_ secs)
    (def d (/ secs 86400))
    (def clock (Str8 str (%two (/ (% secs 86400) 3600)) ":" (%two (/ (% secs 3600) 60)) ":" (%two (% secs 60))))
    (match
      ((= d 0) clock)
      ((= d 1) (Str8 str "1 day, " clock))
      (#t (Str8 str d " days, " clock)))))

; Hundredths as "N.NN".
(def fmt-hundredths
  (fn (_ c) (Str8 str (/ c 100) "." (%two (% c 100)))))

(provide top/format fmt-right fmt-left fmt-cut fmt-percent fmt-size fmt-meter-size fmt-time fmt-uptime
  fmt-hundredths)
