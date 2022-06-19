	#if alt_plat == 0
	#include "plat_a2560u.inc"
	#else
	#include "plat_a2560k.inc"
	#endif

tx0_w	.equ 72
tx0_h	.equ 56

tx1_w	.equ 80
tx1_h	.equ 60

fb_w	.equ tx1_w
fb_h	.equ tx1_h

color	.equ 0x41

fract	.equ 15

spins	.equ 0x8000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#0x080000,a1
	move.l	a1,usp
	andi.w	#0xdfff,sr

	; plot graph paper on channel B -- symbols
	lea.l	pattern,a0
	jsr	clear_text1
frame$:
	; plot graph paper on channel B -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	lea	sinLUT,a6
	movea.l	a1,a2
	move.w	angle,d5
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
vert$:
	move.w	(a0)+,d3 ; v_in.x
	move.w	(a0)+,d4 ; v_in.y

	; transform vertex x-coord: cos * x - sin * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_cos
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_sin

	sub.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_w/2,d2
	move.w	d2,(a1)+ ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_sin
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_cos

	add.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_h/2,d2
	move.w	d2,(a1)+ ; v_out.y

	cmpa.l	a2,a0
	bcs	vert$

	; scan-convert the scr-space tri edges
	lea	tri_scr_0,a2
	lea	tri_end,a3
	movea.l	#ea_texa1,a6
tri$:
	move.w	tri_p0+r2_x(a2),d0
	move.w	tri_p0+r2_y(a2),d1
	move.w	tri_p1+r2_x(a2),d2
	move.w	tri_p1+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	move.w	tri_p1+r2_x(a2),d0
	move.w	tri_p1+r2_y(a2),d1
	move.w	tri_p2+r2_x(a2),d2
	move.w	tri_p2+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	move.w	tri_p2+r2_x(a2),d0
	move.w	tri_p2+r2_y(a2),d1
	move.w	tri_p0+r2_x(a2),d2
	move.w	tri_p0+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	adda.l	#tri_size,a2
	cmpa.l	a3,a2
	bne	tri$

	addi.w	#1,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text1+tx1_w-4,a0
	jsr	print_u16

	#ifdef do_wait
	move.l	#spins,d0
	jsr	spin
	#endif

	bra	frame$

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; struct r2
r2_x	.equ	0 ; word x1
r2_y	.equ	2 ; word x1
r2_size .equ	4

; struct tri
tri_p0	.equ	0 ; word x2 ; r2
tri_p1	.equ	4 ; word x2 ; r2
tri_p2	.equ	8 ; word x2 ; r2
tri_size .equ	12

; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT15 ptr
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
mul_sin:
	and.w	#0xff,d1
	cmpi.b	#0x80,d1
	bcs	sign_done$
	neg.w	d0
	subi.b	#0x80,d1
sign_done$:
	cmpi.b	#0x40,d1
	bcs	fetch$
	bne	not_maximum$
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
not_maximum$:
	subi.b	#0x80,d1
	neg.b	d1
fetch$:
	add.w	d1,d1
	muls.w	0(a6,d1.w),d0
	rts

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT15 ptr
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
mul_cos:
	addi.w	#0x40,d1
	bra	mul_sin

	#include "util.inc"
	#include "line.inc"

pattern:
	.long	0x30313233, 0x34353637, 0x38394142, 0x43444546
	.long	0x42434243, 0x42434243, 0x42434243, 0x42434243
angle:
	.word	0
frame_i:
	.word	0

	.align 16
sinLUT:
	#include "sinLUT15_64.inc"
tri_obj_0:
	.word	  0, -29
	.word	 25,  14
	.word	-25,  14
tri_scr_0:
	.space	tri_scr_0-tri_obj_0
tri_end:
