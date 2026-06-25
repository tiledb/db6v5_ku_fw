onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+sem_ultra_vio_si1_so5  -L xil_defaultlib -L secureip -O5 xil_defaultlib.sem_ultra_vio_si1_so5

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure

do {sem_ultra_vio_si1_so5.udo}

run 1000ns

endsim

quit -force
