; control symbols:
; target_cpu (numerical): select target cpu
;	0: 68000
;	1: 68010
;	2: 68020
; 	3: 68030
;	4: 68040
;	6: 68060
; do_wait (define): enforce spinloop at end of frame
; do_morfe (define): enforce morfe compatibility

	if alt_plat == 0
	include	"plat_a2560u.inc"
	else
	include "plat_a2560k.inc"
	endif

tx0_w	equ 100
tx0_h	equ 75

tx1_w	equ 80
tx1_h	equ 60

fb_w	equ tx0_w
fb_h	equ tx0_h

color	equ $41

spins	equ 0

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
	dc.l	start
start:
	endif
	; disable all vicky engines but text
	; set channel A to 800x600, text 100x75
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	move.l	hw_vicky_border(a0),d1
	move.l	hw_vicky_cursor(a0),d2
	and.w	#$ffff&(reset_master_mode&%01000000),d0
	or.w	#$ffff&(set_master_mode_800x600|%00000001),d0
	move.l	d0,hw_vicky_master(a0)
	and.b	#reset_border_enable,d1
	move.l	d1,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d2
	move.l	d2,hw_vicky_cursor(a0)

	; clear channel A -- symbols
	lea.l	pattern,a0
	jsr	clear_text0

	; clear channel A -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa0
.frame:
	lea	tri_0,a2
	lea	tri_end,a3
	movea.l	#ea_texa0,a6
.tri_edge:
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

	adda.w	#tri_size,a2
	cmp.l	a3,a2
	bcs	.tri_edge

	; compute bases for a few on-screeen tris
	lea	tri_0,a0
	lea	pb_0,a1
	lea	tri_end,a2
.cpb:
	jsr	init_pb
	adda.w	#tri_size,a0
	adda.w	#pb_size,a1
	cmpa.l	a2,a0
	bcs	.cpb

	movea.l	#ea_texa0,a2
	lea	tx0_h*tx0_w(a2),a3
	moveq	#0,d5 ; curr_x
	moveq	#0,d6 ; curr_y
.pixel:
	lea	pb_0,a0
	lea	pb_0+(tri_end-tri_0)/tri_size*pb_size,a1
	moveq	#$47,d7
.tri:
	move.w	d5,d0
	move.w	d6,d1
	jsr	get_coord

	; if {s|t} < 0 || (s+t) > area then pixel is outside
	tst.l	d0
	blt	.skip
	tst.l	d1
	blt	.skip
	add.l	d1,d0
	cmp.l	pb_area(a0),d0
	bgt	.skip
	; tri pixel -- plot and exit tri loop
	move.b	d7,(a2)
	bra	.tri_done
.skip:
	addi.b	#1,d7
	adda.w	#pb_size,a0
	cmpa.l	a1,a0
	bne	.tri
.tri_done:
	addi.w	#1,d5
	cmpi.w	#tx0_w,d5
	blt	.param
	moveq	#0,d5
	addi.w	#1,d6
.param:
	adda.w	#1,a2
	cmpa.l	a3,a2
	bne	.pixel

	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text0,a0
	jsr	print_u16

	ifd do_wait
	move.l	#spins,d0
	jsr	spin
	endif

	bra	.frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

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

; parallelogram basis
; a triangle defines a basis such that:
;   p0 is the basis origin;
;   p1-p0 is the 1st basis vector;
;   p2-p0 is the 2nd basis vector;
; basis is RH if positive area
; struct pb
	clrso
pb_p0	so.w 2 ; r2
pb_e01	so.w 2 ; r2
pb_e02	so.w 2 ; r2
pb_area	so.l 1
pb_size = __SO

; compute parallelogram basis from a tri:
;   e01 = p1 - p0
;   e02 = p2 - p0
;   area = e01.x * e02.y - e02.x * e01.y
; a0: tri ptr
; a1: basis ptr
; clobbers: d0-d5
init_pb:
	move.w	tri_p0+r2_x(a0),d0
	move.w	tri_p0+r2_y(a0),d1

	move.w	tri_p1+r2_x(a0),d2
	move.w	tri_p1+r2_y(a0),d3

	move.w	tri_p2+r2_x(a0),d4
	move.w	tri_p2+r2_y(a0),d5

	sub.w	d0,d2 ; e01.x = p1.x - p0.x
	sub.w	d1,d3 ; e01.y = p1.y - p0.y

	sub.w	d0,d4 ; e02.x = p2.x - p0.x
	sub.w	d1,d5 ; e02.y = p2.y - p0.y

	move.w	d0,pb_p0+r2_x(a1)
	move.w	d1,pb_p0+r2_y(a1)

	move.w	d2,pb_e01+r2_x(a1)
	move.w	d3,pb_e01+r2_y(a1)

	move.w	d4,pb_e02+r2_x(a1)
	move.w	d5,pb_e02+r2_y(a1)

	; area = e01.x * e02.y - e02.x * e01.y
	muls.w	d5,d2
	muls.w	d4,d3
	sub.l	d3,d2

	move.l	d2,pb_area(a1)
	rts

; get barycentric coords of the given point in the given parallelogram basis;
; coords are before normalization!
; a0: basis ptr
; d0.w: pt.x
; d1.w: pt.y
; returns: d0.l: s coord before normalization
;          d1.l: t coord before normalization
; clobbers: d2-d3
get_coord:
	; dx = p.x - pb.p0.x
	; dy = p.y - pb.p0.y
	sub.w	pb_p0+r2_x(a0),d0
	sub.w	pb_p0+r2_y(a0),d1
	; s = dx * pb.e02.y - dy * pb.e02.x
	; t = dy * pb.e01.x - dx * pb.e01.y
	move.w	d0,d2
	move.w	d1,d3
	muls.w	pb_e01+r2_x(a0),d1 ; dy * e01.x
	muls.w	pb_e01+r2_y(a0),d2 ; dx * e01.y
	muls.w	pb_e02+r2_x(a0),d3 ; dy * e02.x
	muls.w	pb_e02+r2_y(a0),d0 ; dx * e02.y
	sub.l	d3,d0
	sub.l	d2,d1
	rts

	include "line.inc"
	include "util.inc"

pattern:
	dcb.l	4, '    '
	dcb.l	4, $70707070
frame_i:
	dc.w	0
tri_0:
	dc.w	99,  0
	dc.w	55, 37
	dc.w	 0, 33

	dc.w	99,  0
	dc.w	63, 74
	dc.w	55, 37

	dc.w	63, 74
	dc.w	 0, 33
	dc.w	55, 37
tri_end:
	align 4
pb_0:
	ds.w	(tri_end-tri_0)/tri_size*pb_size/2
