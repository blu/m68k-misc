	if alt_plat == 0
	include	"plat_a2560u.inc"
	else
	include "plat_a2560k.inc"
	endif

tx0_w	equ 80
tx0_h	equ 60

tx1_w	equ 80
tx1_h	equ 60

COLUMNS	equ 64
LINES	equ 48

spins	equ $10000

	ifnd memset
memset	equ memset8
	endif

	ifd do_morfe
	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

	else
	; FoenixMCP PGX header
	org $010000

	dc.b "PGX", $02
	dc.l start
start:
	endif
	; hide border and cursor
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_border(a0),d0
	move.l	hw_vicky_cursor(a0),d1
	and.b	#reset_border_enable,d0
	move.l	d0,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d1
	move.l	d1,hw_vicky_cursor(a0)

	; plot graph paper on channel A -- symbols
	lea.l	pattern,a0
	jsr	clear_text0
.again:
	move.b	#18,d5
	movea.l	#ea_texa0,a3
.forward:
	; plot graph paper on channel A -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa0

	jsr	frame
	adda.l	#1,a3

	subi.b	#1,d5
	bne	.forward

	move.b	#18,d5
.reverse:
	; plot graph paper on channel A -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa0

	suba.l	#1,a3
	jsr	frame

	subi.b	#1,d5
	bne	.reverse

	bra	.again

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

pattern:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dcb.l	4, $42434243

	inline
; memset a buffer to a given value; 4B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length
; returns: a0: last_written_address + 1
; clobbers: d2
memset4:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
;	addi.l	#2,d2 ; for higher alignmen versions
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	move.l	d1,d2
	lsr.l	#2,d2
.loop:
	move.l	#$40404040,(a0)+ ; imm just for the unit test; correct src: d0
	subi.l	#1,d2
	bne	.loop
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

	inline
; memset a buffer to a given value; 8B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length
; returns: a0: last_written_address + 1
; clobbers: d2
memset8:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	btst	#2,d2
	beq	.head2
	move.l	d0,(a0)+
;	addi.l	#4,d2 ; for higher alignmen versions
	subi.l	#4,d1
.head2:
	cmp.l	#8,d1
	bcs	.tail2

	move.l	d1,d2
	lsr.l	#3,d2
.loop:
	move.l	#$40404040,(a0)+ ; imm just for the unit test; correct src: d0
	move.l	#$3f3f3f3f,(a0)+ ; ditto
	subi.l	#1,d2
	bne	.loop
.tail2:
	btst	#2,d1
	beq	.tail1
	move.l	d0,(a0)+
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

	inline
; memset a buffer to a given value; 16B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length
; returns: a0: last_written_address + 1
; clobbers: d2
memset16:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	btst	#2,d2
	beq	.head2
	move.l	d0,(a0)+
	addi.l	#4,d2
	subi.l	#4,d1
.head2:
	cmp.l	#8,d1
	bcs	.tail2

	btst	#3,d2
	beq	.head3
	move.l	d0,(a0)+
	move.l	d0,(a0)+
;	addi.l	#8,d2 ; for higher alignmen versions
	subi.l	#8,d1
.head3:
	cmp.l	#16,d1
	bcs	.tail3

	move.l	d1,d2
	lsr.l	#4,d2
.loop:
	move.l	#$40404040,(a0)+ ; imm just for the unit test; correct src: d0
	move.l	#$3f3f3f3f,(a0)+ ; ditto
	move.l	#$3e3e3e3e,(a0)+ ; ditto
	move.l	#$3d3d3d3d,(a0)+ ; ditto
	subi.l	#1,d2
	bne	.loop
.tail3:
	btst	#3,d1
	beq	.tail2
	move.l	d0,(a0)+
	move.l	d0,(a0)+
.tail2:
	btst	#2,d1
	beq	.tail1
	move.l	d0,(a0)+
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

; plot one memset test frame on channel A
; a3: where to start the plot
; clobbers: d0-d4,a0-a2
frame:
	movea.l	a3,a1
	movea.l	#ea_texa0+tx0_w*LINES,a2
	moveq	#1,d3
	moveq	#1,d4
.line:
	movea.l	a1,a0
	move.l	#$41414141,d0
	move.l	d4,d1
	jsr	memset

	cmpi.w	#LINES/(COLUMNS-LINES),d3
	bne	.param
	moveq	#0,d3
	adda.w	#1,a1
.param:
	addi.w	#1,d3
	addi.w	#1,d4

	adda.w	#tx0_w,a1
	cmpa.l	a2,a1
	blt	.line

	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text0+tx0_w-4,a0
	jsr	print_u16

	ifd do_wait
	move.l	#spins,d0
	jsr	spin
	endif

	rts

	include "util.inc"
frame_i:
	dc.w	0
