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
    .set TIME_SZ,  			      107

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
    @.set GPIO_PSR,				      0x8

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
@laco:
    @b laco

    msr  CPSR_c, #0x12       @ IRQ mode
    ldr sp, =IRQ_SP

    msr  CPSR_c, #0x1F       @ SYSTEM mode
    ldr sp, =SYSTEM_USER_SP

    msr  CPSR_c, #0x13       @ SUPERVISOR mode
    ldr sp, =SUPERVISOR_SP

    msr  CPSR_c, #0x10       @ USER mode, IRQ/FIQ enabled
    ldr r0, =0x77802000
    mov pc, r0

@---------------------------------------------------------------------------
@ HANDLERS
@---------------------------------------------------------------------------

SYSCALL_HANDLER:
    stmfd sp!, {lr}

    cmp r7, #16
    beq READ_SONAR
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
    stmfd sp!, {r0-r1}

	  ldr r1, =GPT_BASE
	  mov r0, #1
	  str r0, [r1, #GPT_SR]

	@ Aumenta o tempo do sistema
    ldr r0, =SYSTEM_TIME
	  ldr r1, [r0]
    add r1, r1, #1
    str r1,[r0]

    ldmfd sp!, {r0-r1}

	  sub lr, lr, #4
	  movs pc, lr

@---------------------------------------------------------------------------
@ FUNCOES
@---------------------------------------------------------------------------

READ_SONAR:
    stmfd sp!, {r1-r3}

    msr  CPSR_c, #0x1F                @ SYSTEM mode
    ldr r0, [sp]                      @ Id sonar

    @cmp r0, #15
    @bls READ_SONAR_INI
    @mov r0, #-1

    @msr  CPSR_c, #0x13                @ SUPERVISOR mode
    @ldmfd sp!, {r1-r3}

    @b SYSCALL_HANDLER_END

  READ_SONAR_INI:

    mov r3, #0xF                      @ mascara para pegar somente os 4 bits do sonar
    and r0, r0, r3

    ldr r2, =GPIO_BASE                @ obtendo o estado atual dos pinos definido em PSR
    ldr r2, [r2, #GPIO_DR]

    bic r2, r2, r3, LSL #2            @ zera os sonars_mux usando a mascara

    orr r2, r2, r0, LSL #2            @ seta o id do sonar em R2 (PSR)

    ldr r3, =GPIO_BASE                @ atualiza o pino DR do GPIO

    bic r2, r2, #0x2                  @ TRIGGER = 0
    str r2, [r3, #GPIO_DR]            @ SET DEFINITIVO

    mov r0, #4096
  LOOP_TRIGGER_1:
    sub r0, r0, #1
    cmp r0, #0
    bge LOOP_TRIGGER_1

    orr r2, r2, #0x2                  @ TRIGGER = 1
    str r2, [r3, #GPIO_DR]            @ SET DEFINITIVO

    mov r0, #4096
  LOOP_TRIGGER_2:
    sub r0, r0, #1
    cmp r0, #0
    bge LOOP_TRIGGER_2

    bic r2, r2, #0x2                  @ TRIGGER = 0
    ldr r1, =GPIO_BASE                @ atualiza o pino DR do GPIO
    str r2, [r1, #GPIO_DR]            @ SET DEFINITIVO

  LOOP_FLAG:
    ldr r2, =GPIO_BASE                @ obtendo o estado atual dos pinos definido em PSR
    ldr r2, [r2, #GPIO_DR]

    and r2, r2, #1
    cmp r2, #1
    beq FLAG_ONE

    mov r0, #8192

  FLAG_DELAY:
    sub r0, r0, #1
    cmp r0, #0
    bgt FLAG_DELAY
    b LOOP_FLAG

  FLAG_ONE:

    ldr r2, =GPIO_BASE                @ obtendo o estado atual dos pinos definido em PSR
    ldr r2, [r2, #GPIO_DR]

    ldr r3, =SONAR_DISTANCE_MASK      @ mascara para pegar somente os 4 bits do sonar
    and r2, r2, r3, LSL #6

    mov r2, r2, LSR #6
    mov r0, r2

    ldr r2, =DEBUGAR
    str r0, [r2]

    msr  CPSR_c, #0x13       @ SUPERVISOR mode
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

REGISTER_PROXIMITY_CALLBACK:
    b SYSCALL_HANDLER_END

SET_MOTOR_SPEED:
    stmfd sp!, {r1-r3}

    msr  CPSR_c, #0x1F                @ SYSTEM mode
    ldr r0, [sp]                      @ Carrego o valor do id
    ldr r1, [sp, #4]                  @ valor da velocidade do motor

    cmp r0, #1
    bls SET_MOTOR_SPEED_VALID_ID      @ Verifica se o ID é 0 ou 1

    mov r0, #-1
    msr  CPSR_c, #0x13                @ SUPERVISOR mode
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

  SET_MOTOR_SPEED_VALID_ID:           @ Verifica se a velocidade é <= 0xF e >= 0

    cmp r1, #0x3F
    bls SET_MOTOR_SPEED_INI

    mov r0, #-2
    msr  CPSR_c, #0x13                @ SUPERVISOR mode
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

  SET_MOTOR_SPEED_INI:

    ldr r3, =MOTOR_SPEED_MASK        @ mascara para pegar somente os 6 primeiros bits
    and r1, r1, r3

    ldr r2, =GPIO_BASE              @ obtendo o estado atual dos pinos definido em PSR
    ldr r2, [r2, #GPIO_DR]

    ldr r3, =DR_MOTOR_SPEED_MASK    @ mascara para zerar os valores atuais em PSR

    cmp r0, #1
    beq MOTOR_1

    bic r2, r2, r3, LSL #24
    orr r2, r2, r1, LSL #26         @ seta a nova velocidade do motor1 em R2 (PSR)
    mov r0, #1
    bic r2, r2, r0, LSL #25        @ seta o pino do MOTOR0_WRITE para 0
    b FIM_SET_MOTOR_SPEED

  MOTOR_1:
    bic r2, r2, r3, LSL #17
    orr r2, r2, r1, LSL #19         @ seta a nova velocidade do motor0 em R2 (PSR)
    mov r0, #1
    bic r2, r2, r0, LSL #18         @ seta o pino do MOTOR0_WRITE para 0

  FIM_SET_MOTOR_SPEED:
    @ldr r2, =0Xfdf80000
    ldr r1, =GPIO_BASE              @ atualiza o pino DR do GPIO
    str r2, [r1, #GPIO_DR]          @ SET DEFINITIVO

    msr  CPSR_c, #0x13              @ SUPERVISOR mode
    mov r0, #0                      @ Retorno correto da funcao
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

SET_MOTOR_SPEEDS:
    stmfd sp!, {r1-r3}

    msr  CPSR_c, #0x1F                @ SYSTEM mode
    ldr r0, [sp]                      @ Carrego o valor da velocidade do motor 0
    ldr r1, [sp, #4]                  @ valor da velocidade do motor 1

    cmp r0, #0x3F                       @ Verifica a velocidade do motor 0
    bls SET_MOTOR_SPEEDS_VALID_1

    mov r0, #-1
    msr  CPSR_c, #0x13                @ SUPERVISOR mode
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

  SET_MOTOR_SPEEDS_VALID_1:

    cmp r1, #0x3F                       @ Verifica a velocidade do motor 1
    bls SET_MOTOR_SPEEDS_VALID_2

    mov r0, #-2
    msr  CPSR_c, #0x13                @ SUPERVISOR mode
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

  SET_MOTOR_SPEEDS_VALID_2:

    ldr r3, =MOTOR_SPEED_MASK        @ mascara para pegar somente os 6 primeiros bits
    and r0, r0, r3
    and r1, r1, r3

    ldr r2, =GPIO_BASE              @ obtendo o estado atual dos pinos definido em PSR
    ldr r2, [r2, #GPIO_DR]

    ldr r3, =DR_MOTOR_SPEED_MASK    @ mascara para zerar os valores atuais em PSR
    bic r2, r2, r3, LSL #24
    bic r2, r2, r3, LSL #17

    orr r2, r2, r0, LSL #19         @ seta a nova velocidade do motor0 em R3 (PSR)
    orr r2, r2, r1, LSL #26         @ seta a nova velocidade do motor1 em R3 (PSR)

    mov r0, #1
    bic r2, r2, r0, LSL #18         @ seta o pino do MOTOR0_WRITE para 0
    bic r2, r2, r0, LSL #25         @ seta o pino do MOTOR1_WRITE para 0

    @ldr r2, =0Xfdf80000
    ldr r1, =GPIO_BASE              @ atualiza o pino DR do GPIO
    str r2, [r1, #GPIO_DR]          @ SET DEFINITIVO

    msr  CPSR_c, #0x13       @ SUPERVISOR mode
    mov r0, #0
    ldmfd sp!, {r1-r3}

    b SYSCALL_HANDLER_END

GET_TIME:
    ldr r0, =SYSTEM_TIME
    ldr r0, [r0]

    b SYSCALL_HANDLER_END

SET_TIME:
    stmfd sp!, {r0-r1}

    msr  CPSR_c, #0x1F                @ SYSTEM mode
    ldr r0, [sp]                      @ Carrego o valor do id

    ldr r1, =SYSTEM_TIME
    str r0, [r1]

    msr  CPSR_c, #0x13                @ SUPERVISOR mode

    ldmfd sp!, {r0-r1}
    b SYSCALL_HANDLER_END

SET_ALARM:
    b SYSCALL_HANDLER_END

@---------------------------------------------------------------------------
@ DATA E CONSTANTES
@---------------------------------------------------------------------------

.set MAX_ALARMS,            0x00000008
.set MAX_CALLBACKS,         0x00000008

.set MOTOR_SPEED_MASK,      0x0000003F
.set DR_MOTOR_SPEED_MASK,   0X0000007F
.set SONAR_MASK,            0x0000000F
.set SONAR_DISTANCE_MASK,   0x00000FFF

.set SYSTEM_TIME,           0x77801800
.set TRIGGER_INIT,          0x77801804
.set SONAR_COUNTER,         0x77801808
.set DEBUGAR,         0x7780180C

.set SUPERVISOR_SP,   0x77801850
.set SYSTEM_USER_SP,  0x77801900
.set IRQ_SP,          0x77801950

.data
@SYSTEM_TIME:
@TRIGGER_INIT:
@SONAR_COUNTER:
