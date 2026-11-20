# The command line
@weight 1

top/cli: the options, declared once to Opts.

## settings

### the defaults: a second and a half, by CPU, flat, everyone

```top
(write (top-settings (Opts parse top-options ())))
```
---
    (('delay . 1500) ('sort . 'cpu) ('tree . #f) ('user) ('filter . ""))

### -d in tenths, -s a column, -t, -u a uid or a name, -F text

```top
(write (list (top-settings (Opts parse top-options (list "-d" "5" "-s" "mem" "-t" "-u" "501" "-F" "vi")))
             (Assoc get 'user (top-settings (Opts parse top-options (list "--user=root"))))))
```
---
    ((('delay . 500) ('sort . 'mem) ('tree . #t) ('user . 501) ('filter . "vi")) "root")

### a delay that is not a number, a column there is none of

```top
(write (list (top-settings (Opts parse top-options (list "-d" "x")))
             (top-settings (Opts parse top-options (list "-d" "0")))
             (top-settings (Opts parse top-options (list "-s" "zap")))))
```
---
    ((('error . "-d takes a number of tenths of a second, 1 or more")) (('error . "-d takes a number of tenths of a second, 1 or more")) (('error . "-s takes one of pid user pri ni virt res state cpu mem time command")))

## what the main answers

### -V, an unknown option, an operand

```top
(write (list (top-main (list "-V")) (top-main (list "--zap")) (top-main (list "now"))))
```
---
    (0 2 2)

## the machine itself

### a live sample: this process is among the rows, with its user

```top
(def cli-st (top-state (top-settings (Opts parse top-options ()))))
(state-sample! cli-st (sample-take))
(def cli-me (List find (fn (_ r) (= (row-pid r) (Sys getpid))) (state-rows cli-st)))
(write (list (not (null? cli-me)) (str=? (row-user cli-me) (Assoc get 'name (Sys getpwuid (Sys getuid))))))
```
---
    (#t #t)
