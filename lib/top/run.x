; # x-top -- an interactive process viewer on x-lang
;
; ## lib/top/run.x -- the entry
;
; @description `x -l top [-- OPTIONS]`.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The module top/run.  x.sh boots the dialect bundle.xon declares, arms the
; bundle's lib/ with import-path!, imports this module and then calls its
; main, which starts the viewer: `x -l top` with no options is the viewer,
; as htop with none is.
(module top/run)
(import top/base)

(set! %lang-name "top")

; The operands: what follows the "--" after the launcher's own options.
; x-os's launcher passes the engine's own flags ahead of them, with no
; "--" between; they are left out.
(def %engine-flag?
  (fn (_ a) (List any? (fn (_ f) (str=? a f)) (list "--batch" "--quiet" "--no-color"))))
(def %operands
  (fn (self l) (if (if (null? l) #f (%engine-flag? (first l))) (self (rest l)) l)))

(def main
  (fn (_)
    (Sys exit (top-main (%operands (rest (Sys args (lit program))))))))

(provide top/run main)
