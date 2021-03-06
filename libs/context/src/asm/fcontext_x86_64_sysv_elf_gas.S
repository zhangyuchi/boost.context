/*
            Copyright Oliver Kowalke 2009.
   Distributed under the Boost Software License, Version 1.0.
      (See accompanying file LICENSE_1_0.txt or copy at
            http://www.boost.org/LICENSE_1_0.txt)
*/

/****************************************************************************************
 *                                                                                      *
 *  ----------------------------------------------------------------------------------  *
 *  |    0    |    1    |    2    |    3    |    4     |    5    |    6    |    7    |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x0   |   0x4   |   0x8   |   0xc   |   0x10   |   0x14  |   0x18  |   0x1c  |  *
 *  ----------------------------------------------------------------------------------  *
 *  |        RBX        |        R12        |         R13        |        R14        |  *
 *  ----------------------------------------------------------------------------------  *
 *  ----------------------------------------------------------------------------------  *
 *  |    8    |    9    |   10    |   11    |    12    |    13   |    14   |    15   |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x20  |   0x24  |   0x28  |  0x2c   |   0x30   |   0x34  |   0x38  |   0x3c  |  *
 *  ----------------------------------------------------------------------------------  *
 *  |        R15        |        RBP        |         RSP        |        RIP        |  *
 *  ----------------------------------------------------------------------------------  *
 *  ----------------------------------------------------------------------------------  *
 *  |    16   |    17   |                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x40  |   0x44  |                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *  | fc_mxcsr|fc_x87_cw|                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *  ----------------------------------------------------------------------------------  *
 *  |   18    |   19    |   20    |    21   |                                        |  *
 *  ----------------------------------------------------------------------------------  *
 *  |  0x48   |  0x4c   |  0x50   |   0x54  |                                        |  *
 *  ----------------------------------------------------------------------------------  *
 *  |       sbase       |        slimit     |                                        |  *
 *  ----------------------------------------------------------------------------------  *
 *  ----------------------------------------------------------------------------------  *
 *  |    22   |    23   |                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x58  |   0x5c  |                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *  |      fc_link      |                                                            |  *
 *  ----------------------------------------------------------------------------------  *
 *                                                                                      *
 * **************************************************************************************/

.text
.globl boost_fcontext_jump
.type boost_fcontext_jump,@function
.align 16
boost_fcontext_jump:
    movq     %rbx,       (%rdi)         /* save RBX */
    movq     %r12,       0x8(%rdi)      /* save R12 */
    movq     %r13,       0x10(%rdi)     /* save R13 */
    movq     %r14,       0x18(%rdi)     /* save R14 */
    movq     %r15,       0x20(%rdi)     /* save R15 */
    movq     %rbp,       0x28(%rdi)     /* save RBP */

    stmxcsr  0x40(%rdi)                 /* save SSE2 control and status word */
    fnstcw   0x44(%rdi)                 /* save x87 control word */

    leaq     0x8(%rsp),  %rcx           /* exclude the return address and save as stack pointer */
    movq     %rcx,       0x30(%rdi)     /* save as stack pointer */
    movq     (%rsp),     %rcx           /* save return address */
    movq     %rcx,       0x38(%rdi)     /* save return address as RIP */


    movq     (%rsi),      %rbx      /* restore RBX */
    movq     0x8(%rsi),   %r12      /* restore R12 */
    movq     0x10(%rsi),  %r13      /* restore R13 */
    movq     0x18(%rsi),  %r14      /* restore R14 */
    movq     0x20(%rsi),  %r15      /* restore R15 */
    movq     0x28(%rsi),  %rbp      /* restore RBP */

    ldmxcsr  0x40(%rsi)             /* restore SSE2 control and status word */
    fldcw    0x44(%rsi)             /* restore x87 control word */

    movq     %rdx,        %rax      /* use third arg as return value after jump */

    movq     0x30(%rsi),  %rsp      /* restore RSP */
    movq     0x38(%rsi),  %rcx      /* fetch the address to return to */
    movq     %r13,        %rdi      /* restore void pointer as argument */

    jmp      *%rcx                  /* indirect jump to context */
.size boost_fcontext_jump,.-boost_fcontext_jump

.text
.globl boost_fcontext_make
.type boost_fcontext_make,@function
.align 16
boost_fcontext_make:
    movq   %rdi,                 (%rdi)     /* save the address of current context */
    movq   %rsi,                 0x38(%rdi) /* save the address of the function supposed to run */
    movq   %rdx,                 0x10(%rdi) /* save the the void pointer */
    movq   0x48(%rdi),           %rdx       /* load the stack base */

    pushq  %rdi                             /* save pointer to fcontext_t */
    movq   %rdx,                 %rdi       /* stack pointer as arg for boost_fcontext_align */
    call   boost_fcontext_align@PLT         /* align stack */
    movq   %rax,                 %rdx       /* begin of aligned stack */
    popq   %rdi                             /* restore pointer to fcontext_t */

    leaq   -0x8(%rdx),           %rdx       /* reserve space for the last frame on stack, (RSP + 8) % 16 == 0 */
    movq   %rdx,                 0x30(%rdi) /* save the address */
    movq   0x58(%rdi),           %rcx       /* load the address of the next context */
    movq   %rcx,                 0x8(%rdi)  /* save the address of next context */
    stmxcsr  0x40(%rdi)                     /* save SSE2 control and status word */
    fnstcw 0x44(%rdi)                       /* save x87 control word */
    leaq   link_fcontext(%rip),  %rcx       /* helper code executed after context function returns */
    movq   %rcx,                 (%rdx)
    xorq   %rax,                 %rax       /* set RAX to zero */
    ret

link_fcontext:
    movq   %r12,               %rsi         /* restore next context */
    testq  %rsi,               %rsi         /* test if a next context was given */
    je     1f                               /* jump to finish */

    movq   %rbx,               %rdi         /* restore current context */
    call   boost_fcontext_start@PLT         /* jump to next context */

1:
    xorq    %rdi,              %rdi         /* exit code is zero */
    call   _exit@PLT                        /* exit application */
    hlt
.size boost_fcontext_make,.-boost_fcontext_make

