;
; semaforoforo.asm
;
; Created: 07/10/2026 11:25:39
; Authors :

;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;????????????????????????????????????????
;?????????????????????????????????


; Determina um segmento de código para a FLASH
.cseg

; Manda PC para o endereço 0
.org 0

; Define um registrador para armazenar o contador de estados
.def state_count = r16
.def segundos = r18

; Registrador auxiliar
.def temp = r17
.def tophigh = r19
.def toplow = r20

; Define um limite de estados
.set state_limit = 3

; Pula para o inicializador do maldito programa
jmp reset

; Move o PC para o endereço da interrupção do timer
.org OC1Aaddr
; Desvia para a subrotina de tratamento do timer
rjmp OCI1A_Interrupt

; ============================================================
; Inicia todos os parâmetros
; ============================================================
reset:
	; ---- Inicia a pilha para podermos utilizar subrotinas ----
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp
	; ----------------------------------------------------------

	; Fixa o prescale máximo que essa bagaça usa, pelo amor de Deus... É muito pouco D:
	.equ prescale = 0b0101

	; Pra configurar o timer no modo ctc (contar tanto cansa)
	.equ WGM = 0b0100


	; ---- Carregamento inicial da entrada ----
	; Configurando z com o mapeamento inicial
	ldi ZH, high(mapeamento << 1)
	ldi ZL, low(mapeamento << 1)

	; Configura uma porta como saída somente para teste
	ldi temp, $FF
	out DDRD, temp

	; Carrega o primeiro estado na saída
	lpm temp, Z
	; Joga a configuração de z na porta D como saída, faz o led ligar 'o'
	out PORTD, temp
	; ----------------------------------------------------------

	; zera state_count
	clr state_count

	; ---- Configura inicialmente o timer ----
	; Carregando o top inicial em Z
	ldi ZH, high(tops << 1)
	ldi ZL, low(tops << 1)

	; Carrega o byte menos significativo do top
	lpm toplow, z+
	; Carrega o myte mais significativo do top
	lpm tophigh, z

	; Carrega o top no timer
	sts OCR1AH, tophigh
	sts OCR1AL, toplow

	;Habilita as interrupções do timer
	;Carrega o valor do registrador de controle do timer, evita carregar bagunça no TIMSK1
	lds temp, TIMSK1
	;Seta OCIE1A para 1, habilitando as interrupções via timer
	sbr temp, 1 << OCIE1A
	;Carrega para o registrador de controle do timer
	sts TIMSK1, temp

	; Configurar o timer bolado pra contar (maldito só sabe contar até 4.12s)
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	ldi temp, ((WGM&0b11) << WGM10)
	sts TCCR1A, temp

	;2 bits mais significativos de WGM e seleção de clock
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b101 << 0 = 0b101
	; 0b0001000 | 0b101 = 0b0001101
	ldi temp, ((WGM>>2)<<WGM12)|(prescale << CS10)
	sts TCCR1B, temp
	; ----------------------------------------------------------

	; Habilita globalmente as interrupções
	sei
; ============================================================
	

; ============================================================
; Looping principal
; ============================================================
loop:
	jmp loop

; ============================================================


; ============================================================
; Tratamendo da interrupção
; ============================================================
OCI1A_Interrupt:
	; conceitualmente salvando o sreg ¯\_(?)_/¯
	push temp
	in temp, SREG
	push temp

	; Passa pro próximo estado
	inc state_count

	; Verifica se chegou ao último estado
	cpi state_count, state_limit
	; Caso não pula pra carregar o próximo estado
	brlo estado_valido

	; Volta pro estado inicial
	clr state_count

	; Atualiza o estado
	estado_valido:
		; ---- Carrega o próximo estado ----
		ldi ZH, high(mapeamento << 1)
		ldi ZL, low(mapeamento << 1)

		; É que nem que igual fazer um incremento dinâmico pra pegar o próximo estado :B
		add ZL, state_count
		clr temp
		adc ZH, temp

		; Carrega o próximo estado em temp
		lpm temp, Z

		; Atualiza os leds
		out PORTD, temp
		; ----------------------------------------------------------

		; ---- Carrega o próximo tempo ----
		; Carregando o top inicial em Z
		ldi ZH, high(tops << 1)
		ldi ZL, low(tops << 1)

		; Artimanha pra multiplicar por 2
		; Precisa dessa miséria pra ele pegar a próxima palavra certinha do "vetor" tops
		; O caba não deixa fazer << 1 só porque state_count é registrador :(
		mov temp, state_count
		lsl temp

		; Funciona igual ao carregamento do próximo estado
		add ZL, temp
		clr temp
		adc ZH, temp

		; Carrega o byte menos significativo do top
		lpm toplow, z+
		; Carrega o myte mais significativo do top
		lpm tophigh, z

		; Carrega o top no timer
		sts OCR1AH, tophigh
		sts OCR1AL, toplow
		; ----------------------------------------------------------

	; Saida
	; Despusha o SREG
	pop temp
	out SREG, temp
	pop temp

	reti
; ============================================================


; ============================================================
; Mapeamento dos leds marotos
; ============================================================
mapeamento:
	; LED verde
	.db 0b00000001, 0b00000010, 0b00000100, 0
; ============================================================


; ============================================================
; Mapeamento dos tops :)
; ============================================================
tops:
	; Estado 1
	.dw 31249
	; Estado 2
	.dw 15624
	; Estado 3
	.dw 46874
; ============================================================?