#!/bin/bash
riscv64-unknown-elf-gcc -march=rv64g -mabi=lp64 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -I/home/wangns/riscv-tests/env/p -I/home/wangns/riscv-tests/isa/macros/scalar -T/home/wangns/riscv-tests/env/p/link.ld $1 -o $2
riscv64-unknown-elf-objdump -D $2 > dump.txt
