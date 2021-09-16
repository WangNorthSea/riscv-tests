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
        .weak supervisor_trap_handler_from_umode;
        .weak supervisor_trap_handler_from_smode;   
        .weak supervisor_ti;
        .weak user_ti;
        .weak supervisor_continue;         
        .weak test_fail;
        .globl _start;                                                 
_start:
        li a0, 1
        # set mtvec to an illegal addr
        li t0, 0
        csrw mtvec, t0
        
        # set mstatus.mpp to supervisor
        li t0, MSTATUS_MPP
        csrc mstatus, t0
        li t0, MSTATUS_MPP & (MSTATUS_MPP >> 1)       
        csrs mstatus, t0;     
        # set delegation for supervisor timer interrupt and user timer interrupt
        li t0, SIP_STIP | MIP_UTIP
        csrs mideleg, t0
        # set delegation for illegal instruction
        li t0, 0x4
        csrs medeleg, t0

        # set mepc
        la t0, run_supervisor
        csrw mepc, t0
        # jump to 'run_supervisor' with priviledge level set to Supervisor
        mret

run_supervisor:
        # test supervisor timer interrupt
        la t0, supervisor_trap_handler_from_smode
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
        # set sstatus_spp to user
        li t0, SSTATUS_SPP
        csrc sstatus, t0

        # set sepc
        la t0, run_user
        csrw sepc, t0
        #j jump to "run_user" with priviledge level set to User
        la t0, supervisor_trap_handler_from_umode
        csrw stvec, t0
        sret
        j test_fail

run_user:
        # now running on User mode
        # test user timer interrupt without delegation
        # set utvec to an illegal addr
        li t0, 0
        csrw utvec, t0

wait_here_user:
        j wait_here_user # stuck here if user timer interrupt never comes...

user_continue:
        # test illegal CSR operation without delegation
        li a0, 1
        csrr t0, sstatus
        ecall

user_continue2:
        # test illegal CSR operation with delegation
        la t0, user_trap_handler
        csrw utvec, t0
        li a0, 1
        csrr t0, sstatus
        ecall

user_continue3:
        li a0, 0        # test passed
        ecall

supervisor_trap_handler_from_umode:
        # check sstatus.spp
        csrr t0, sstatus
        li t1, SSTATUS_SPP
        and t0, t0, t1
        bne t0, zero, test_fail # if SPP is not user, then fail

        # check scause
        csrr t0, scause
        li t1, 0x8000000000000004 # user timer interrupt
        beq t0, t1, user_ti
        li t1, 0x2 # illegal instruction
        bne t0, t1, test_fail

        # illegal instruction from user
        # set sepc
        la t0, user_continue2
        csrw sepc, t0

        # set delegation
        li t0, 0x4
        csrs sedeleg, t0
        sret

user_ti:
        # clear uip.utip
        li t0, 0
        csrw 0x7c0, t0
        # set uie.utie to 0
        li t0, 0x10
        csrc uie, t0

        # go back
        la t0, user_continue
        csrw sepc, t0
        sret

supervisor_trap_handler_from_smode:
        # check sstatus.spp
        csrr t0, sstatus
        li t1, SSTATUS_SPP
        and t0, t0, t1
        bne t0, t1, test_fail # if SPP is not supervisor, then fail

        # check scause
        csrr t0, scause
        li t1, 0x8000000000000005 # supervisor timer interrupt
        beq t0, t1, supervisor_ti
        j test_fail

user_trap_handler:
        # check ucause
        csrr t0, ucause
        li t1, 0x2 #illegal instruction
        bne t0, t1, test_fail

        # illegal instruction from user
        # set uepc
        la t0, user_continue3
        csrw uepc, t0
        uret

supervisor_ti:
        # clear sip.stip
        li t0, 0
        csrw 0x7c0, t0 # mtime
        li t0, 400
        csrw 0x7c2, t0 # mtimecmp
        # remain sstatus.sie and sie.stie set
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