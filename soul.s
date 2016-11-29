.org 0x0
.section .iv,"a"

_start:

@---------------------------------------------------------------------------
@ VETOR DE INTERRUPCOES
@---------------------------------------------------------------------------

interrupt_vector:
    b RESET_HANDLER
.org 0x08
    b SYSCALL_HANDLER
.org 0x18
    b IRQ_HANDLER

.org 0x100
.text

@---------------------------------------------------------------------------
@ RESET HANDLER
@---------------------------------------------------------------------------

RESET_HANDLER:
	@ Zera o tempo do sistema
    ldr r2, =SYSTEM_TIME  @lembre-se de declarar esse contador em uma secao de dados!
    mov r0,#0
    str r0,[r2]

    @Set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

    msr  CPSR_c, #0x12       @ IRQ mode
    ldr sp, =IRQ_SP

    msr  CPSR_c, #0x1F       @ SYSTEM mode
    ldr sp, =SYSTEM_USER_SP

    msr  CPSR_c, #0x13       @ SUPERVISOR mode
    ldr sp, =SUPERVISOR_SP

@---------------------------------------------------------------------------
@ CONFIGURACOES
@---------------------------------------------------------------------------

GPT_CONFIG:
    .set GPT_BASE,            0x53FA0000
    .set GPT_CR,             	0x0
    .set GPT_PR,          		0x4
    .set GPT_SR,				      0x8
    .set GPT_OCR1,          	0x10
    .set GPT_IR,           		0xC
    .set TIME_SZ,  			      8192

  	ldr r1, =GPT_BASE

  	mov r0, #0x00000041
  	str r0, [r1, #GPT_CR]

  	mov r0, #0
  	str r0, [r1, #GPT_PR]

  	mov r0, #TIME_SZ
  	str r0, [r1, #GPT_OCR1]

  	mov r0, #1
  	str r0, [r1, #GPT_IR]

@---------------------------------------------------------------------------

GPIO_CONFIG:
    .set GPIO_BASE,             0x53F84000
    .set GPIO_DR,               0x0
    .set GPIO_GDIR,          		0x4
    .set GPIO_PSR,				      0x8

  	ldr r1, =GPIO_BASE

  	ldr r0, =0xFFFC003E           @ configuracao dos pinos de entrada e saida
  	str r0, [r1, #GPIO_GDIR]

    ldr r0, =0x0                  @ zera as os valores de cada pino
    str r0, [r1, #GPIO_DR]

@---------------------------------------------------------------------------

SET_TZIC:
    @ Constantes para os enderecos do TZIC
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

    @ Liga o controlador de interrupcoes
    @ R1 <= TZIC_BASE

    ldr	r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov	r0, #1
    str	r0, [r1, #TZIC_INTCTRL]

    @instrucao msr - habilita interrupcoes
    msr  CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled

@---------------------------------------------------------------------------
msr  CPSR_c, #0x10           @ USER mode, IRQ/FIQ enabled
ldr r0, =0x77802000
mov pc, r0

@---------------------------------------------------------------------------
@ HANDLERS
@---------------------------------------------------------------------------

SYSCALL_HANDLER:
    stmfd sp!, {lr}

    cmp r7, #16
    beq READ_SONNAR
    cmp r7, #17
    beq REGISTER_PROXIMITY_CALLBACK
    cmp r7, #18
    beq SET_MOTOR_SPEED
    cmp r7, #19
    beq SET_MOTOR_SPEEDS
    cmp r7, #20
    beq GET_TIME
    cmp r7, #21
    beq SET_TIME
    cmp r7, #22
    beq SET_ALARM

  SYSCALL_HANDLER_END:
    ldmfd sp!, {lr}
    movs pc, lr

@---------------------------------------------------------------------------

IRQ_HANDLER:
	  ldr r1, = GPT_BASE

	  mov r0, #1
	  str r0, [r1, #GPT_SR]

	@ Aumenta o tempo do sistema
    ldr r2, =SYSTEM_TIME
	  ldr r0, [r2]
    add r0, r0, #1
    str r0,[r2]
	  sub lr, lr, #4
	  movs pc, lr

@---------------------------------------------------------------------------
@ FUNCOES
@---------------------------------------------------------------------------

READ_SONNAR:
  b SYSCALL_HANDLER_END

REGISTER_PROXIMITY_CALLBACK:
  b SYSCALL_HANDLER_END

SET_MOTOR_SPEED:

  b SYSCALL_HANDLER_END

SET_MOTOR_SPEEDS:
  .set MOTOR_SPEED_MASK,    0x0000003F
  .set DR_MOTOR_SPEED_MASK, 0X0003FFFF
  stmfd sp!, {r0-r3}

  msr  CPSR_c, #0x1F                @ SYSTEM mode
  ldr r0, [sp]                      @ Carrego o valor da velocidade do motor0
  ldr r1, [sp, #4]                  @ valor da velocidade do motor 1

  ldr r3, =MOTOR_SPEED_MASK        @ mascara para pegar somente os 6 primeiros bits
  and r0, r0, r3
  and r1, r1, r3

  ldr r2, =GPIO_BASE              @ obtendo o estado atual dos pinos definido em PSR
  ldr r2, [r2, #GPIO_PSR]

  ldr r3, =DR_MOTOR_SPEED_MASK    @ mascara para zerar os valores atuais em PSR
  and r2, r2, r3

  orr r2, r2, r0, LSL #19         @ seta a nova velocidade do motor0 em R3 (PSR)
  orr r2, r2, r1, LSL #26         @ seta a nova velocidade do motor1 em R3 (PSR)

  mov r0, #1
  bic r2, r2, r0, LSL #18         @ seta o pino do MOTOR0_WRITE para 0
  bic r2, r2, r0, LSL #25         @ seta o pino do MOTOR1_WRITE para 0

  @ldr r2, =0Xfdf80000
  ldr r1, =GPIO_BASE              @ atualiza o pino DR do GPIO
  str r2, [r1, #GPIO_DR]          @ SET DEFINITIVO

  @eor r2, r2, r0, LSL #18         @ seta o pino do MOTOR0_WRITE para 0
  @eor r2, r2, r0, LSL #25         @ seta o pino do MOTOR1_WRITE para 0

  @ldr r1, =GPIO_BASE              @ atualiza o pino DR do GPIO
  @str r2, [r1, #GPIO_DR]

  msr  CPSR_c, #0x13       @ SUPERVISOR mode
  ldmfd sp!, {r0-r3}

  b SYSCALL_HANDLER_END

GET_TIME:
  ldr r2, =SYSTEM_TIME
  ldr r0, [r2]
  b SYSCALL_HANDLER_END

SET_TIME:
  b SYSCALL_HANDLER_END

SET_ALARM:
  b SYSCALL_HANDLER_END


@---------------------------------------------------------------------------
@ DATA E CONSTANTES
@---------------------------------------------------------------------------

.set MAX_ALARMS,        0x00000008
.set MAX_CALLBACKS,     0x00000008

.set SUPERVISOR_SP,   0x77801850
.set SYSTEM_USER_SP,  0x77801900
.set IRQ_SP,          0x77801950

.data
SYSTEM_TIME:          .word 0
