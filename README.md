## Project Overview
This project demonstrates a mini CPU through several modules. The graduate extension allows opcode 100 to a jump instruction where the target is an absolute unisgned address in the range 0-7. 

## Project Layout
src/stored_cpu.sv // Top level wrapper for enables, datapath, and controller for the cpu operation
    src/cpu_datapath.sv //  Datapath intaking a .mem file with hex instructions. Instantiates pc, rom, registers for insturctions and alu result and register file, decoder, and alu.
        src/regN
        src/program_counter
        src/cpu_rom
        src/cpu_decode
        src/cpu_register_file.sv
        src/cpu_alu.sv
            src/op_block.sv
            src/eqN.sv
    src/stored_cpu_controller
sim/
constr/Basys.xdc

## Extension Related Files
src/ext_cpu_decode.sv
src/ext_cpu_controller
JNZ program ROM file
sim/tb

lab7report.pdf
demo481.MOV
demo581.MOV



## Github Location: