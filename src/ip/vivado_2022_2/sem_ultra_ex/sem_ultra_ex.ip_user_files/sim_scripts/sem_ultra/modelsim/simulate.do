onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc "  -L sem_ultra_v3_1_24 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -lib xil_defaultlib xil_defaultlib.sem_ultra xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {sem_ultra.udo}

run 1000ns

quit -force
