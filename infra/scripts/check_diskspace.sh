#!bin/bash

sudo lsof | grep REG | grep -v "stat: No such file or directory" | grep -v DEL | awk '{if ($NF=="(deleted)") {x=3;y=1} else {x=2;y=0}; {print $(NF-x) "  " $(NF-y) } }'  | sort -n -u  | numfmt  --field=1 --to=iec