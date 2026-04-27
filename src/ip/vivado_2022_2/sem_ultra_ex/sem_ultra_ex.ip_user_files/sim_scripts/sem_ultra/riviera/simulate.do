onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+sem_ultra  -L sem_ultra_v3_1_24 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.sem_ultra xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure

do {sem_ultra.udo}

run 1000ns

endsim

quit -force
