; # x-top -- an interactive process viewer on x-lang
;
; ## top/app.x -- the terminal: samples, keys and redraws
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Takes the terminal raw, on the alternate screen with the cursor hidden,
; and gives all of it back on the way out, an error included.  A sample
; is taken every delay; between samples the keys are read as they come
; and the screen redrawn after each, only the cells that changed sent.
; The window's size is asked before every draw.
;
; Term key reads a key through a byte reader.  After an escape it asks
; for the rest of the sequence; this reader answers nil when nothing
; follows within 30 ms, which Term reads as the escape key itself.

(module top/app)

(import x/sys/posix)
(import x/sys/gc)
(import x/repl/term)
(import x/tui/screen)
(import x/core/doors io-display-to-str)
(import top/model sample-take)
(import top/state state-sample! state-key! state-quit? state-quit! state-delay)
(import top/view view-draw!)

(def %esc (fn (_ text) (Str8 append "\x1b" text)))

; Whether a byte comes on standard input within MS milliseconds.
(def %ready? (fn (_ ms) (not (null? (Sys poll (list (pair 0 (list (lit in)))) ms)))))

; A byte reader over standard input: BOX holds the bytes read and not
; taken; a read takes up to 64 at once.  Nil when nothing comes in 30 ms.
(def %reader
  (fn (_ box)
    (fn (_)
      (when (if (null? (Vector ref 0 box)) (%ready? 30) #f)
        (Vector set! 0 (Sys fd-read 0 64) box))
      (def bs (Vector ref 0 box))
      (if (null? bs) () (do (Vector set! 0 (rest bs) box) (first bs))))))

(def %clock-ms (fn (_) (let ((t (Sys time-of-day))) (+ (* (first t) 1000) (/ (rest t) 1000)))))

(def %show!
  (fn (_ st screen)
    (def size (Term window 0))
    (unless (if (= (first size) (Screen cols screen)) (= (rest size) (Screen rows screen)) #f)
      (Screen resize screen (rest size) (first size)))
    (view-draw! st screen)
    (Term emit 1 (Screen render screen))))

; Keys until the next sample is due at DUE, each acted on and drawn.
(def %keys
  (fn (self st screen box due)
    (def left (- due (%clock-ms)))
    (unless (state-quit? st)
      (when (if (not (null? (Vector ref 0 box))) #t (if (> left 0) (%ready? left) #f))
        (let ((key (Term key (%reader box))))
          (if (null? key) (state-quit! st) (state-key! st key))
          (%show! st screen)
          (self st screen box due))))))

(def %loop
  (fn (self st screen box)
    (state-sample! st (sample-take))
    (%show! st screen)
    (Heap collect)
    (%keys st screen box (+ (%clock-ms) (state-delay st)))
    (unless (state-quit? st) (self st screen box))))

; Show ST on the terminal until a key quits: the exit status.
(def app-run
  (fn (_ st)
    (def size (Term window 0))
    (def screen (Screen make (rest size) (first size)))
    (def token (Term raw! 0))
    (Term emit 1 (Str8 append (%esc "[?1049h") (%esc "[?25l")))
    (def failed (guard (e e) (do (%loop st screen (Vector of ())) ())))
    (Term emit 1 (Str8 append (%esc "[0m") (%esc "[?25h") (%esc "[?1049l")))
    (Term restore! 0 token)
    (if (null? failed) 0
      (do (Sys fd-write 2 (Str8 append "x-top: " (if (Err err? failed) (failed msg) (io-display-to-str failed)) "\n")) 1))))

(provide top/app app-run)
