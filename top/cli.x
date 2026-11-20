; # x-top -- an interactive process viewer on x-lang
;
; ## top/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The options are htop's spellings where htop has them (-d in tenths of a
; second, -u, -s, -t, -F), declared once to the platform's Opts, which
; parses them and prints the help.  --dump draws one screen to standard
; output instead of the terminal: two samples a delay apart, so the CPU
; shares are real, at the window's size or COLUMNS and LINES.

(module top/cli)

(import x/sys/opts)
(import x/sys/posix)
(import x/sys/host)
(import x/repl/term)
(import x/tui/screen)
(import top/model sample-take)
(import top/state columns column-name state-make state-sample! state-delay)
(import top/view view-draw! view-text)
(import top/app app-run)

(def top-version "0.1.0")

(def top-options
  (Opts declare "x -l top --" "[OPTIONS]"
    "An interactive process viewer, after htop: processor, memory and swap meters, then the processes, sorted, filtered or as a tree.\nRunning, F1 or ? lists the keys."
    (list (Opts arg "-d" "--delay" "TENTHS" "Tenths of a second between samples (15)")
          (Opts arg "-u" "--user" "NAME" "Show only this user's processes: a name or a uid")
          (Opts arg "-s" "--sort-key" "COLUMN" "Sort by COLUMN: pid user pri ni virt res state cpu mem time command (cpu)")
          (Opts flag "-t" "--tree" "Show the tree of parent and child processes")
          (Opts arg "-F" "--filter" "TEXT" "Show only the processes whose command holds TEXT")
          (Opts flag "-D" "--dump" "Draw one screen to standard output and exit")
          (Opts flag "-V" "--version" "Print the version and exit")
          (Opts flag "-h" "--help" "Print this help and exit"))
    (pair (lit help) #f)))

(def %say (fn (_ fd text) (Sys fd-write fd text)))
(def %to-int (fn (_ s) (guard (e ()) ((prim-ref (lit convert) (lit to)) s (Type named INTEGER) 10))))

; A user: the uid the digits give, or the name itself, which the rows'
; user names are matched against.
(def %uid
  (fn (_ s)
    (def n (%to-int s))
    (if (null? n) s n)))

; The world the state is made with: the real one.
(def %name (fn (_ uid) (let ((u (Sys getpwuid uid))) (if (null? u) () (Assoc get (lit name) u)))))
(def %args (fn (_ pid) (Host args pid)))
(def %why (fn (_ what r pid) (Err text (Err from-errno (Err errno-of r) what pid))))
(def %signal (fn (_ pid sig) (let ((r (Sys kill pid sig))) (if (< r 0) (%why (lit kill) r pid) 0))))
(def %nice
  (fn (_ pid n)
    (if (< (Host %call "setpriority" 0 pid n) 0) (Str8 append "setpriority: cannot renice " (Str8 str pid)) 0)))

; The options as state-make takes them, or (error . TEXT).
(def top-settings
  (fn (_ o)
    (def bad (fn (_ text) (list (pair (lit error) text))))
    (def delay (if (null? (Opts value o "-d")) 15 (%to-int (Opts value o "-d"))))
    (def sort (if (null? (Opts value o "-s")) (lit cpu) (Str8 ->sym (Opts value o "-s"))))
    (def uid (if (null? (Opts value o "-u")) () (%uid (Opts value o "-u"))))
    (match
      ((if (null? delay) #t (< delay 1)) (bad "-d takes a number of tenths of a second, 1 or more"))
      ((null? (List find (fn (_ c) (eq? (column-name c) sort)) columns))
        (bad (Str8 append "-s takes one of " (Str8 join " " (List map (fn (_ c) (Str8 str (column-name c))) columns)))))

      (#t (list (pair (lit delay) (* delay 100)) (pair (lit sort) sort) (pair (lit tree) (Opts on? o "-t"))
                (pair (lit user) uid) (pair (lit filter) (Opts value o "-F" "")))))))

(def top-state (fn (_ settings) (state-make settings %name %args %signal %nice (Sys signals))))

; One screen to standard output.
(def %dump
  (fn (_ st)
    (def size (Term window 1))
    (def screen (Screen make (rest size) (first size)))
    (state-sample! st (sample-take))
    (Sys usleep (* 1000 (state-delay st)))
    (state-sample! st (sample-take))
    (view-draw! st screen)
    (List for-each (fn (_ l) (%say 1 (Str8 append l "\n"))) (view-text screen))
    0))

(def top-main
  (fn (_ args)
    (def o (Opts parse top-options args))
    (match
      ((not (null? (Opts unknown o)))
        (do (%say 2 (Str8 append "x-top: no such option: " (Opts unknown o) "\n" (Opts usage top-options))) 2))
      ((Opts on? o "-h") (do (%say 1 (Opts usage top-options)) 0))
      ((Opts on? o "-V") (do (%say 1 (Str8 append "x-top " top-version "\n")) 0))
      ((not (null? (Opts operands o)))
        (do (%say 2 (Str8 append "x-top: takes no operands\n" (Opts usage top-options))) 2))
      (#t (let ((s (top-settings o)))
            (if (not (null? (Assoc entry (lit error) s)))
              (do (%say 2 (Str8 append "x-top: " (Assoc get (lit error) s) "\n")) 2)
              (if (Opts on? o "-D") (%dump (top-state s))
                (do (Sys dup2 3 0) (Sys close 3) (app-run (top-state s))))))))))

(provide top/cli top-main top-options top-settings top-state top-version)
