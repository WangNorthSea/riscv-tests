# See LICENSE for license details.

#*****************************************************************************
# supervisor.S
#-----------------------------------------------------------------------------
#
# Test CSRRx and CSRRxI instructions.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64S

.section .text.init;                                            
        .align  6;                                                           
        .weak run_supervisor;                         
        .weak machine_trap_handler;
        .weak supervisor_trap_handler;            
        .weak test_fail;
        .globl _start;                                                 
_start:
        li a0, 1
        
        # test machine timer interrupt
        la t0, machine_trap_handler
        csrw mtvec, t0
        li t0, 0
        csrw 0x7c0, t0 # mtime
        li t0, 200
        csrw 0x7c2, t0 # mtimecmp

        # enable interrupt
        li t0, MSTATUS_MIE
        csrs mstatus, t0
        li t0, 0x80 # mie.mtie
        csrs mie, t0

wait_for_interrupt:
        j wait_for_interrupt  # stuck here if machine timer interrupt never comes...

continue:
        # set mstatus_mpp to supervisor
        li t0, MSTATUS_MPP
        csrc mstatus, t0
        li t0, MSTATUS_MPP & (MSTATUS_MPP >> 1)       
        csrs mstatus, t0;     
        # set delegation for supervisor timer interrupt
        li t0, SIP_STIP
        csrs mideleg, t0

        # set mepc
        la t0, run_supervisor
        csrw mepc, t0
        # jump to 'run_supervisor' with priviledge level set to Supervisor
        mret

run_supervisor:
        # test supervisor timer interrupt
        la t0, supervisor_trap_handler
        csrw stvec, t0

        li t0, 0
        csrw 0x7c0, t0 # mtime
        li t0, 200
        csrw 0x7c2, t0 # mtimecmp

        # enable supervisor interrupt
        li t0, SSTATUS_SIE
        csrs sstatus, t0
        li t0, 0x20 # sie.stie
        csrs sie, t0

wait_here:
        j wait_here # stuck here if supervisor timer interrupt never comes...

supervisor_continue:
        # test illegal CSR operation without delegation
        li a0, 1
        csrr t0, mstatus
        ecall

supervisor_continue2:
        # test illegal CSR operation with delegation
        li a0, 1
        csrr t0, mcause
        ecall

supervisor_continue3:
        li a0, 0
        ecall


machine_trap_handler:
         # check mcause
        csrr t0, mcause
        li t1, 0x8000000000000007 # machine timer interrupt
        beq t0, t1, machine_ti
        li t1, 0x2 # illegal instruction
        bne t0, t1, test_fail

        # illegal instruction
        # check mstatus.mpp
        csrr t0, mstatus
        li t1, MSTATUS_MPP & (MSTATUS_MPP >> 1)
        li t2, MSTATUS_MPP
        and t0, t0, t2
        bne t0, t1, test_fail # if MPP is not supervisor, then fail

        # set illegal instruction exception delegation
        li t0, 0x4
        csrs medeleg, t0
        
        # set mepc
        la t0, supervisor_continue2
        csrw mepc, t0
        mret # go back

machine_ti:
        # check mstatus.mpp
        csrr t0, mstatus
        li t1, MSTATUS_MPP
        and t0, t0, t1
        bne t0, t1, test_fail # if MPP is not machine, then fail (delegation didn't work)

        li t0, 0
        csrw 0x7c0, t0 # write to mtime, clear mip.mtip
        li t0, 0x80
        csrc mie, t0 # set mie.mtie to 0
        la t0, continue
        csrw mepc, t0
        mret # jump to 'continue', priviledge level machine


supervisor_trap_handler:
        # check sstatus.spp
        csrr t0, sstatus
        li t1, SSTATUS_SPP
        and t0, t0, t1
        bne t0, t1, test_fail # if SPP is not supervisor, then fail

        # check scause
        csrr t0, scause
        li t1, 0x8000000000000005 # supervisor timer interrupt
        beq t0, t1, supervisor_ti
        li t1, 0x2 # illegal instruction
        bne t0, t1, test_fail
        
        # illegal instruction, from supervisor
        # set sepc
        la t0, supervisor_continue3
        csrw sepc, t0
        sret

supervisor_ti:
        # clear sip.stip
        li t0, 0
        csrw 0x7c0, t0
        # set sie.stie to 0
        li t0, 0x20
        csrc sie, t0

        # go back
        la t0, supervisor_continue
        csrw sepc, t0
        sret


test_fail:
        li a0, 1
        ecall


RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END