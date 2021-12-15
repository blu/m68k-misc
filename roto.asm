ea_user  equ $020000
ea_stack equ $080000
ea_vicky equ $c40000
ea_text0 equ $c60000
ea_texa0 equ $c68000
ea_text1 equ $ca0000
ea_texa1 equ $ca8000

tx0_w	equ 72
tx0_h	equ 56

tx1_w	equ 80
tx1_h	equ 60

fract	equ 15

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

	movea.l	#ea_texa1,a1

	if neg_length
	; negative sincos multiplicand
	moveq	#tx1_h/2-1,d2
	neg.w	d2

	else
	; positive sincos multiplicand
	moveq	#tx1_h/2-1,d2

	endif
	moveq	#0,d3     ; angle ticks
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
point:
	move.w	d2,d0
	move.w	d3,d1
	jsr	mul_sin
	; fx16.15 -> int16
	asr.l	d6,d0
	addx.w	d7,d0

	addi.w	#tx1_h/2,d0
	mulu.w	#tx1_w,d0
	movea.w	d0,a0

	move.w	d2,d0
	move.w	d3,d1
	jsr	mul_cos
	; fx16.15 -> int16
	asr.l	d6,d0
	addx.w	d7,d0

	addi.w	#tx1_w/2,d0
	adda.w	d0,a0
	adda.l	a1,a0

	move.b	#$41,(a0)

	addi.b	#1,d3
	bne	point

	moveq	#0,d0 ; syscall_exit
	trap	#15

; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
	mc68020
mul_sin:
	and.w	#$ff,d1
	cmpi.b	#$80,d1
	bcs	sign_done
	neg.w	d0
	subi.b	#$80,d1
sign_done:
	cmpi.b	#$40,d1
	bne	not_maximum
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
not_maximum:
	if !lut_symmetry
	bcs	symmetry_done
	subi.b	#$80,d1
	neg.b	d1
symmetry_done:
	endif
	muls.w	sinLUT(d1.w*2),d0
	rts

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
	mc68000
mul_cos:
	addi.w	#$40,d1
	bra	mul_sin

	align 4
	if 0
sinLUT: ; 16 fractional bits; for unsigned arithmetics
	dc.w $0000, $0648, $0C90, $12D5, $1918, $1F56, $2590, $2BC4
	dc.w $31F1, $3817, $3E34, $4447, $4A50, $504D, $563E, $5C22
	dc.w $61F8, $67BE, $6D74, $731A, $78AD, $7E2F, $839C, $88F6
	dc.w $8E3A, $9368, $9880, $9D80, $A268, $A736, $ABEB, $B086
	dc.w $B505, $B968, $BDAF, $C1D8, $C5E4, $C9D1, $CD9F, $D14D
	dc.w $D4DB, $D848, $DB94, $DEBE, $E1C6, $E4AA, $E76C, $EA0A
	dc.w $EC83, $EED9, $F109, $F314, $F4FA, $F6BA, $F854, $F9C8
	dc.w $FB15, $FC3B, $FD3B, $FE13, $FEC4, $FF4E, $FFB1, $FFEC
	if lut_symmetry
	dc.w $0000, $FFEC, $FFB1, $FF4E, $FEC4, $FE13, $FD3B, $FC3B
	dc.w $FB15, $F9C8, $F854, $F6BA, $F4FA, $F314, $F109, $EED9
	dc.w $EC83, $EA0A, $E76C, $E4AA, $E1C6, $DEBE, $DB94, $D848
	dc.w $D4DB, $D14D, $CD9F, $C9D1, $C5E4, $C1D8, $BDAF, $B968
	dc.w $B505, $B086, $ABEB, $A736, $A268, $9D80, $9880, $9368
	dc.w $8E3A, $88F6, $839C, $7E2F, $78AD, $731A, $6D74, $67BE
	dc.w $61F8, $5C22, $563E, $504D, $4A50, $4447, $3E34, $3817
	dc.w $31F1, $2BC4, $2590, $1F56, $1918, $12D5, $0C90, $0648
	endif
	else
sinLUT: ; 15 fractional bits; for signed arithmetics
	dc.w $0000, $0324, $0648, $096B, $0C8C, $0FAB, $12C8, $15E2
	dc.w $18F9, $1C0C, $1F1A, $2224, $2528, $2827, $2B1F, $2E11
	dc.w $30FC, $33DF, $36BA, $398D, $3C57, $3F17, $41CE, $447B
	dc.w $471D, $49B4, $4C40, $4EC0, $5134, $539B, $55F6, $5843
	dc.w $5A82, $5CB4, $5ED7, $60EC, $62F2, $64E9, $66D0, $68A7
	dc.w $6A6E, $6C24, $6DCA, $6F5F, $70E3, $7255, $73B6, $7505
	dc.w $7642, $776C, $7885, $798A, $7A7D, $7B5D, $7C2A, $7CE4
	dc.w $7D8A, $7E1E, $7E9D, $7F0A, $7F62, $7FA7, $7FD9, $7FF6
	if lut_symmetry
	dc.w $0000, $7FF6, $7FD9, $7FA7, $7F62, $7F0A, $7E9D, $7E1E
	dc.w $7D8A, $7CE4, $7C2A, $7B5D, $7A7D, $798A, $7885, $776C
	dc.w $7642, $7505, $73B6, $7255, $70E3, $6F5F, $6DCA, $6C24
	dc.w $6A6E, $68A7, $66D0, $64E9, $62F2, $60EC, $5ED7, $5CB4
	dc.w $5A82, $5843, $55F6, $539B, $5134, $4EC0, $4C40, $49B4
	dc.w $471D, $447B, $41CE, $3F17, $3C57, $398D, $36BA, $33DF
	dc.w $30FC, $2E11, $2B1F, $2827, $2528, $2224, $1F1A, $1C0C
	dc.w $18F9, $15E2, $12C8, $0FAB, $0C8C, $096B, $0648, $0324
	endif
	endif
