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

quelen	equ 4
questep	equ 4

fract	equ 15

spins	equ $8000

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

frame:
	; clear channel B -- colors
	lea.l	pattern,a0
	jsr	clear_texa1

	move.b	#quelen,queue
que:
	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	movea.l	a1,a2
	move.w	angle,d5
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
vert:
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
	bcs	vert

	; scan-convert the scr-space tri edges
	lea	tri_scr_0,a2
	lea	tri_end,a3
	movea.l	#ea_texa1,a6
tri:
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
	bne	tri

	addi.w	#questep,angle
	subi.b	#1,queue
	bne	que

	lea	tx1_w*(tx1_h-30)+(tx1_w-64)/2(a6),a0
	lea	tri_end,a1
	jsr	pixmap

	btst.b	#7,frame_i+1
	bne	msg_alt

	lea	tx1_w*(tx1_h-20)+(tx1_w-64)/2(a6),a0
	lea	tri_end+192,a1
	jsr	pixmap
	bra	msg_done
msg_alt:
	lea	tx1_w*(tx1_h-20)+(tx1_w-64)/2(a6),a0
	lea	tri_end+64,a1
	jsr	pixmap

	lea	tx1_w*(tx1_h-10)+(tx1_w-64)/2(a6),a0
	lea	tri_end+128,a1
	jsr	pixmap
msg_done:
	subi.w	#quelen*questep-1,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text1+tx1_w-4,a0
	jsr	print_u16

	move.l	#spins,d0
	jsr	spin

	bra	frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; produce ascii from word
; d0.w: word to print
; a0: output address
; clobbers: d1, a1
print_u16:
	lea	4(a0),a1
nibble:
	rol.w	#4,d0
	move.b	d0,d1
	andi.b	#$f,d1
	addi.b	#'0',d1
	cmpi.b	#'0'+10,d1
	bcs	digit_ready
	addi.b	#'a'-'9'-1,d1
digit_ready:
	move.b	d1,(a0)+
	cmpa.l	a1,a0
	bcs	nibble
	rts

; spinloop
; d0: number of cycles
spin:
	subi.l	#1,d0
	bne	spin
	rts

; struct r2
	clrso
r2_x	so.w 1
r2_y	so.w 1
r2_size = __SO

; struct tri
	clrso
tri_p0	so.w 2 ; r2
tri_p1	so.w 2 ; r2
tri_p2	so.w 2 ; r2
tri_size = __SO

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
	bcs	symmetry_done
	subi.b	#$80,d1
	neg.b	d1
symmetry_done:
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

; draw a line in tx1-sized fb; line must be longer than a single dot
; d0.w: x0
; d1.w: y0
; d2.w: x1
; d3.w: y1
; a0: fb start addr
; clobbers: d4-d7, a1
line:
	; compute x0,y0 addr in fb
	move.w	d1,d4
	muls.w	#tx1_w,d4
	adda.l	d4,a0
	adda.w	d0,a0

	moveq	#1,d6
	move.w	d2,d4
	sub.w	d0,d4 ; dx
	bge	dx_done
	neg.w	d4
	neg.w	d6
dx_done:
	addi.w	#1,d4

	moveq	#1,d7
	movea.w	#tx1_w,a1
	move.w	d3,d5
	sub.w	d1,d5 ; dy
	bge	dy_done
	neg.w	d5
	neg.w	d7
	movea.w	#-tx1_w,a1
dy_done:
	addi.w	#1,d5

	cmp.w	d4,d5
	bge	high_slope

	; low slope: iterate along x
	moveq	#0,d3
loop_x:
	ifd do_clip
	tst.w	d0
	blt	advance_x
	cmp.w	#tx1_w,d0
	bge	advance_x
	tst.w	d1
	blt	advance_x
	cmp.w	#tx1_h,d1
	bge	advance_x
	endif
	move.b	queue,(a0)
advance_x:
	adda.w	d6,a0
	add.w	d6,d0
	add.w	d5,d3
	cmp.w	d4,d3
	bcs	x_done
	adda.w	a1,a0
	sub.w	d4,d3
	add.w	d7,d1
x_done:
	cmp.w	d0,d2
	bne	loop_x
	rts
high_slope: ; iterate along y
	moveq	#0,d2
loop_y:
	ifd do_clip
	tst.w	d0
	blt	advance_y
	cmp.w	#tx1_w,d0
	bge	advance_y
	tst.w	d1
	blt	advance_y
	cmp.w	#tx1_h,d1
	bge	advance_y
	endif
	move.b	queue,(a0)
advance_y:
	adda.w	a1,a0
	add.w	d7,d1
	add.w	d4,d2
	cmp.w	d5,d2
	bcs	y_done
	adda.w	d6,a0
	sub.w	d5,d2
	add.w	d6,d0
y_done:
	cmp.w	d1,d3
	bne	loop_y
	rts

; draw stippled monochrome pixel map to tx1-sized fb
; map comprised of 8 pixel rows and 64 pixel columns
; a0: output ptr
; a1: msg ptr
; clobbers: d0-d1
	mc68020
pixmap:
	lea	64(a1),a2
row:
	moveq	#0,d0
byte:
	move.b	(a1)+,d1
bit:
	lsl.b	d1
	bcc	pixel_done
	move.b	#$4d,(a0,d0.w)
pixel_done:
	addi.w	#1,d0
	bftst	d0{29:3}
	bne	bit
	bftst	d0{26:6}
	bne	byte
	adda.w	#tx1_w,a0
	cmpa.l	a2,a1
	bne	row
	rts

; clear attr channel B
; a0: pattern ptr
; clobbers d0-d3, a1
	mc68000
clear_texa1:
	movem.l (a0),d0-d3
	movea.l	#ea_texa1,a0
	lea	tx1_w*tx1_h(a0),a1
LLloop:
	movem.l	d0-d3,(a0)
	adda.w	#4*4,a0
	cmpa.l	a1,a0
	bcs	LLloop
	rts

angle:
	dc.w	0
frame_i:
	dc.w	0
pattern:
	dcb.l	4, $70707070
queue:
	ds.b	1

	align 4
sinLUT:
	dc.w $0000, $0324, $0648, $096B, $0C8C, $0FAB, $12C8, $15E2
	dc.w $18F9, $1C0C, $1F1A, $2224, $2528, $2827, $2B1F, $2E11
	dc.w $30FC, $33DF, $36BA, $398D, $3C57, $3F17, $41CE, $447B
	dc.w $471D, $49B4, $4C40, $4EC0, $5134, $539B, $55F6, $5843
	dc.w $5A82, $5CB4, $5ED7, $60EC, $62F2, $64E9, $66D0, $68A7
	dc.w $6A6E, $6C24, $6DCA, $6F5F, $70E3, $7255, $73B6, $7505
	dc.w $7642, $776C, $7885, $798A, $7A7D, $7B5D, $7C2A, $7CE4
	dc.w $7D8A, $7E1E, $7E9D, $7F0A, $7F62, $7FA7, $7FD9, $7FF6
tri_obj_0:
	dc.w	  0, -29
	dc.w	 25,  14
	dc.w	-25,  14
tri_scr_0:
	ds.w	(tri_scr_0-tri_obj_0)/2
tri_end:
	incbin "msga.bin"
	incbin "msgb.bin"
	incbin "msgc.bin"
	incbin "msgd.bin"
