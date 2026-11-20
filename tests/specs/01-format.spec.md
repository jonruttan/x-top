# Numbers as the columns show them
@weight 1

top/format: sizes, shares, CPU times and the uptime.

## sizes

### KiB below 100000 KiB, then M, then G with a decimal

```top
(write (List map fmt-size (list () 0 1048576 102399999 102400000 1073741824 10737418240 104857600000 214748364800)))
```
---
    ("-" "0" "1024" "99999" "97M" "1024M" "10240M" "97.6G" "200G")

### a meter's sizes: M below a GiB, then G with two, one or no decimals

```top
(write (List map fmt-meter-size (list 0 536870912 1073741824 17179869184 1610612736 214748364800)))
```
---
    ("0M" "512M" "1.00G" "16.0G" "1.50G" "200G")

## shares and times

### tenths of a percent: one decimal below 100

```top
(write (List map fmt-percent (list 0 5 123 999 1000 2345)))
```
---
    ("0.0" "0.5" "12.3" "99.9" "100" "234")

### CPU time: M:SS.hh, then HhMM:SS, then Nh

```top
(write (List map fmt-time (list 0 1234560000000 3599990000000 3600000000000 359999000000000 360000000000000)))
```
---
    (" 0:00.00" "20:34.56" "59:59.99" " 1h00:00" "99h59:59" "100h")

### the uptime: the day dropped under a day

```top
(write (List map fmt-uptime (list 59 3661 86400 266400)))
```
---
    ("00:00:59" "01:01:01" "1 day, 00:00:00" "3 days, 02:00:00")
