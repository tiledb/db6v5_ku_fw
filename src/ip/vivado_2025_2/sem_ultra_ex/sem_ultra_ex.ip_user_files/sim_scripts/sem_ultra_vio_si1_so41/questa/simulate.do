onbreak {quit -f}
onerror {quit -f}

vsim  -lib xil_defaultlib sem_ultra_vio_si1_so41_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {sem_ultra_vio_si1_so41.udo}

run 1000ns

quit -force
