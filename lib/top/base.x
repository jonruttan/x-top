; # x-top -- an interactive process viewer on x-lang
;
; ## top/base.x -- every module, for the entry and the specs
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)

(import x/sys/host)
(import x/sys/posix)
(import top/format fmt-right fmt-left fmt-cut fmt-percent fmt-size fmt-meter-size fmt-time fmt-uptime fmt-hundredths)
(import top/model sample-make sample-take sample-at sample-cpu sample-cpus sample-memory sample-load sample-tasks
  sample-boot sample-procs rows-make rows-sort rows-tree rows-flat
  row-pid row-ppid row-uid row-user row-nice row-pri row-virt row-res row-state row-cpu row-mem row-time
  row-comm row-start row-threads row-kernel?)
(import top/state columns column-name column-title column-width column-right? column-key column-named
  state-make state-sample! state-show! state-key! state-page! state-quit! state-selected state-command state-user-name
  state-sort state-down? state-tree? state-mode state-input state-quit? state-message state-delay state-shown
  state-top state-at state-filter state-user state-kernel? state-rows state-prev state-cur state-signals
  state-signal-at state-search)
(import top/view view-draw! view-text help-lines)
(import top/app app-run)
(import top/cli top-main top-options top-settings top-state top-version)
