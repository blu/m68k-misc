; control symbols:
; target_cpu (numerical): select target cpu
;	0: 68000
;	1: 68010
;	2: 68020
; 	3: 68030
;	4: 68040
;	6: 68060
; do_clip (define): enforce clipping in primitives
; do_morfe (define): enforce morfe compatibility

	if alt_plat == 0
	include "plat_a2560u.inc"
	else
	include "plat_a2560k.inc"
	endif

ea_bfb	equ $3fc000

tx0_w	equ 100
tx0_h	equ 75

tx1_w	equ 80
tx1_h	equ 60

fb_w	equ tx0_w
fb_h	equ tx0_h

quelen	equ 8
questep	equ 4

fract	equ 15

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code

	ifd do_morfe
	org	$020000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#$080000,a0
	move.l	a0,usp
	andi.w	#$dfff,sr

	else
	; FoenixMCP PGX header
	org	$10000

	dc.b	"PGX", $02
	dc.l	.start
.start:
	endif
	; set channel A to 800x600, text 100x75 fb (8x8 char matrix)
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	move.l	hw_vicky_border(a0),d1
	move.l	hw_vicky_cursor(a0),d2
	and.w	#$ffff&reset_master_mode,d0
	or.w	#set_master_mode_800x600,d0
	move.l	d0,hw_vicky_master(a0)
	and.b	#reset_border_enable,d1
	move.l	d1,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d2
	move.l	d2,hw_vicky_cursor(a0)

	ifnd do_morfe
	; disable all group0 interrupts (yes, that's lame)
	rept	8
	moveq	#4,d0 ; syscall_int_disable
	moveq	#REPTN,d1
	trap	#15
	endr

	; register SOF callback
	moveq	#2,d0 ; syscall_int_register
	moveq	#0,d1 ; INT_SOF_A
	move.l	#hnd_sof,d2
	trap	#15
	move.l	d0,orig_hnd_sof

	; enable SOF interrupt
	moveq	#3,d0 ; syscall_int_enable
	moveq	#0,d1
	trap	#15
	endif

	; set bg clut: $ggbb, $aarr
	lea	clut,a0
	lea	angle,a2
	movea.l	#ea_palb0+1*4,a1
.clut:
	move.w	(a0)+,(a1)+
	cmpa.l	a2,a0
	bcs	.clut

	; clear channel A -- symbols
	lea.l	pattern,a0
	jsr	clear_text0

	; frame constants
	movea.l	#ea_text0+tx0_h*tx0_w-4,a4
	movea.l	#ea_bfb,a5
	lea	sinLUT,a6
.frame:
	; clear channel A -- colors
	move.l	#$70707070,d0
	move.l	d0,d1
	move.l	d0,d2
	move.l	d0,d3
	move.l	d0,d4
	move.l	d0,d5
	move.l	d0,d6
	move.l	d0,d7
	lea	(fb_w*fb_h)&~31(a5),a1
.loop:
	movem.l	d0-d7,-(a1)
	cmpa.l	a5,a1
	bne	.loop

	move.b	#quelen,queue
.que:
	; compute scr coords for obj-space cinqs
	lea	cinq_obj_0,a0
	lea	cinq_scr_0,a1
	movea.l	a1,a2
	move.b	queue,d5
	subi.b	#1,d5
	ext.w	d5

	if target_cpu >= 2
	move.w	angle(d5.w*2),d5

	else
	add.w	d5,d5
	lea	angle,a3
	move.w	(a3,d5.w),d5

	endif
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
.vert:
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

	addi.w	#fb_w/2,d2
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

	addi.w	#fb_h/2,d2
	move.w	d2,(a1)+ ; v_out.y

	cmpa.l	a2,a0
	bcs	.vert

	; scan-convert the scr-space cinq edges
	movea.l	a1,a3
.cinq:
	move.w	cinq_p0+r2_x(a2),d0
	move.w	cinq_p0+r2_y(a2),d1
	move.w	cinq_p1+r2_x(a2),d2
	move.w	cinq_p1+r2_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	cinq_p1+r2_x(a2),d0
	move.w	cinq_p1+r2_y(a2),d1
	move.w	cinq_p2+r2_x(a2),d2
	move.w	cinq_p2+r2_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	cinq_p2+r2_x(a2),d0
	move.w	cinq_p2+r2_y(a2),d1
	move.w	cinq_p3+r2_x(a2),d2
	move.w	cinq_p3+r2_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	cinq_p3+r2_x(a2),d0
	move.w	cinq_p3+r2_y(a2),d1
	move.w	cinq_p4+r2_x(a2),d2
	move.w	cinq_p4+r2_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	cinq_p4+r2_x(a2),d0
	move.w	cinq_p4+r2_y(a2),d1
	move.w	cinq_p0+r2_x(a2),d2
	move.w	cinq_p0+r2_y(a2),d3
	movea.l	a5,a0
	jsr	line

	adda.l	#cinq_size,a2
	cmpa.l	a3,a2
	bne	.cinq

	subi.b	#1,queue
	bne	.que

	lea	fb_w*(fb_h-30)+(fb_w-64)/2(a5),a0
	lea	cinq_end,a1
	jsr	pixmap

	btst.b	#7,frame_i+1
	bne	.msg_alt

	lea	fb_w*(fb_h-20)+(fb_w-64)/2(a5),a0
	lea	cinq_end+192,a1
	jsr	pixmap
	bra	.msg_done
.msg_alt:
	lea	fb_w*(fb_h-20)+(fb_w-64)/2(a5),a0
	lea	cinq_end+64,a1
	jsr	pixmap

	lea	fb_w*(fb_h-10)+(fb_w-64)/2(a5),a0
	lea	cinq_end+128,a1
	jsr	pixmap
.msg_done:
	ifnd do_morfe
	; about to present -- wait for vblank
	; note: as we don't rely on any indication for
	; vblank end, our current scheme works iff our
	; frame time does not exceed our sink frame period;
	; if there's no such guarantee the SOF callback
	; should carry the presentation when frame is ready
.vsync_spin:
	tst.b	flag_sof
	beq	.vsync_spin
	move.b	#0,flag_sof
	endif

	; copy back-fb content to front-fb -- tx0
	movea.l	#ea_bfb,a0
	movea.l #ea_texa0,a1
	lea	(tx0_h*tx0_w)&~31(a1),a2
.loopp:
	movem.l	(a0)+,d0-d7
	move.l	d0,(a1)+
	move.l	d1,(a1)+
	move.l	d2,(a1)+
	move.l	d3,(a1)+
	move.l	d4,(a1)+
	move.l	d5,(a1)+
	move.l	d6,(a1)+
	move.l	d7,(a1)+
	cmpa.l	a1,a2
	bne	.loopp

	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i

	move.l	a4,a0
	jsr	print_u16

	move.w	d0,d1
	move.w	#questep,d0
	jsr	mul_sin
	moveq	#fract,d6
	moveq	#0,d7
	asr.l	d6,d0
	addx.w	d7,d0

	lea	angle,a3
	rept	quelen-1
	move.w	(quelen-2-REPTN)*2(a3),(quelen-1-REPTN)*2(a3)
	endr
	add.w	d0,(a3)

	bra	.frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

hnd_sof: ; SOF callback (dispatched by IRQ handler)
	move.b	#1,flag_sof
	rts

; struct r2
	clrso
r2_x	so.w 1
r2_y	so.w 1
r2_size = __SO

; struct cinq
	clrso
cinq_p0	so.w 2 ; r2
cinq_p1	so.w 2 ; r2
cinq_p2	so.w 2 ; r2
cinq_p3	so.w 2 ; r2
cinq_p4	so.w 2 ; r2
cinq_size = __SO

	inline
; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT ptr
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
mul_sin:
	and.w	#$ff,d1
	cmpi.b	#$80,d1
	bcs	.sign_done
	neg.w	d0
	subi.b	#$80,d1
.sign_done:
	cmpi.b	#$40,d1
	bcs	.fetch
	bne	.not_maximum
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
.not_maximum:
	subi.b	#$80,d1
	neg.b	d1
.fetch:
	if target_cpu >= 2
	muls.w	(a6,d1.w*2),d0

	else
	add.w	d1,d1
	muls.w	(a6,d1.w),d0

	endif
	rts

	einline

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT ptr
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
mul_cos:
	addi.w	#$40,d1
	bra	mul_sin

	inline
; draw a line in tx0-sized fb; line must be longer than a single dot
; d0.w: x0
; d1.w: y0
; d2.w: x1
; d3.w: y1
; a0: fb start addr
; clobbers: d4-d7, a1
line:
	; compute x0,y0 addr in fb
	move.w	d1,d4
	muls.w	#fb_w,d4
	adda.l	d4,a0
	adda.w	d0,a0

	moveq	#1,d6
	move.w	d2,d4
	sub.w	d0,d4 ; dx
	bge	.dx_done
	neg.w	d4
	neg.w	d6
.dx_done:
	moveq	#1,d7
	movea.w	#fb_w,a1
	move.w	d3,d5
	sub.w	d1,d5 ; dy
	bge	.dy_done
	neg.w	d5
	neg.w	d7
	movea.w	#-fb_w,a1
.dy_done:
	cmp.w	d4,d5
	bge	.high_slope

	; low slope: iterate along x
	add.w	d5,d5 ; 2 dy
	move.w	d5,d3
	sub.w	d4,d3 ; 2 dy - dx
	add.w	d4,d4 ; 2 dx
.loop_x:
	ifd do_clip
	cmp.w	#fb_w,d0
	bcc	.advance_x
	cmp.w	#fb_h,d1
	bcc	.advance_x
	endif
	move.b	queue,(a0)
.advance_x:
	adda.w	d6,a0
	add.w	d6,d0
	tst.w	d3
	ble	.x_done
	adda.w	a1,a0
	sub.w	d4,d3
	add.w	d7,d1
.x_done:
	add.w	d5,d3
	cmp.w	d0,d2
	bne	.loop_x
	rts
.high_slope: ; iterate along y
	add.w	d4,d4 ; 2 dx
	move.w	d4,d2
	sub.w	d5,d2 ; 2 dx - dy
	add.w	d5,d5 ; 2 dy
.loop_y:
	ifd do_clip
	cmp.w	#fb_w,d0
	bcc	.advance_y
	cmp.w	#fb_h,d1
	bcc	.advance_y
	endif
	move.b	queue,(a0)
.advance_y:
	adda.w	a1,a0
	add.w	d7,d1
	tst.w	d2
	ble	.y_done
	adda.w	d6,a0
	sub.w	d5,d2
	add.w	d6,d0
.y_done:
	add.w	d4,d2
	cmp.w	d1,d3
	bne	.loop_y
	rts

	einline

	inline
; draw stippled monochrome pixel map to tx1-sized fb
; map comprised of 8 pixel rows and 64 pixel columns
; a0: output ptr
; a1: msg ptr
; clobbers: d0-d2
pixmap:
	lea	64(a1),a2
.row:
	moveq	#0,d0
.byte:
	move.b	(a1)+,d1
.bit:
	lsl.b	d1
	bcc	.pixel_done
	move.b	#$4e,(a0,d0.w)
.pixel_done:
	addi.w	#1,d0
	move.l	d0,d2
	and.w	#$7,d2
	bne	.bit
	move.l	d0,d2
	and.w	#$38,d2
	bne	.byte
	adda.w	#fb_w,a0
	cmpa.l	a2,a1
	bne	.row
	rts

	einline
	include "util.inc"
orig_hnd_sof:
	ds.l	1
pattern:
	dcb.l	4, '    '
	dcb.l	4, $70707070
clut:
	dc.w	$44DC, $FFDC
	dc.w	$25AE, $FF9A
	dc.w	$1DA6, $FF92
	dc.w	$159E, $FF8A
	dc.w	$058E, $FF7A
	dc.w	$006E, $FF5A
	dc.w	$004E, $FF3A
	dc.w	$004E, $FF1A
angle:
	dcb.w	quelen, -32
frame_i:
	dc.w	0
flag_sof:
	dc.b	0
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
cinq_obj_0:
	dc.w	  0, -37
	dc.w	 32,  37
	dc.w	-37, -18
	dc.w	 37, -18
	dc.w	-32,  37
cinq_scr_0:
	ds.w	(cinq_scr_0-cinq_obj_0)/2
cinq_end:
	incbin "msga.bin"
	incbin "msgb.bin"
	incbin "msgc.bin"
	incbin "msgd.bin"
