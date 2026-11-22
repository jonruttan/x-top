; # x-top -- an interactive process viewer on x-lang
;
; ## lib/top/run.x -- the entry
;
; @description `x -l top -- [OPTIONS]`.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module top/run)
(import top/base)

(set! %lang-name "top")
(set! %repl-prompt "top> ")

; The operands: what follows the "--" after the launcher's own options.
; x-os's launcher passes the engine's own flags ahead of them, with no
; "--" between; they are left out, so `x -l top` there is a REPL too.
(def %engine-flag?
  (fn (_ a) (List any? (fn (_ f) (str=? a f)) (list "--batch" "--quiet" "--no-color"))))
(def %operands
  (fn (self l) (if (if (null? l) #f (%engine-flag? (first l))) (self (rest l)) l)))

; With no operands the session goes on to the REPL.
(def main
  (fn (_)
    (let ((ops (%operands (rest (Sys args (lit program))))))
      (unless (null? ops) (Sys exit (top-main ops))))))

(provide top/run main)
