; control symbols:
; target_cpu (numerical): select target cpu
;	0: 68000
;	1: 68010
;	2: 68020
; 	3: 68030
;	4: 68040
;	6: 68060
; do_clear (define): enforce fb clear at start of frame
; do_morfe (define): enforce morfe compatibility

	#if alt_plat == 0
	#include "plat_a2560u.inc"
	#else
	#include "plat_a2560k.inc"
	#endif

tx0_w	.equ 80
tx0_h	.equ 60

tx1_w	.equ 80
tx1_h	.equ 60

paddlen	.equ 9
padd_y	.equ tx0_h-3

ball_w	.equ 1
ball_h	.equ 1

frames	.equ 1<<12

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code

	#ifdef do_morfe
;	org	0x020000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#0x080000,a0
	move.l	a0,usp
	andi.w	#0xdfff,sr

	#else
	; FoenixMCP PGX header
;	org	0x010000

	.byte	"PGX", 0x02
	.long	start
start:
	#endif
	; disable all vicky engines but text
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	andi.b	#0x41,d0
	move.l	d0,hw_vicky_master(a0)
	; hide border and cursor
	move.l	hw_vicky_border(a0),d0
	andi.b	#reset_border_enable,d0
	move.l	d0,hw_vicky_border(a0)
	move.l	hw_vicky_cursor(a0),d0
	andi.b	#reset_cursor_enable,d0
	move.l	d0,hw_vicky_cursor(a0)

	; disable all group0 interrupts
	moveq.l	#7,d2
dis_one:
	moveq	#4,d0 ; syscall_int_disable
	move.l	d2,d1
	trap	#15
	subq.l	#1,d2
	bcc	dis_one

	moveq	#2,d0 ; syscall_int_register
	moveq	#0,d1 ; INT_SOF_A
	move.l	#hnd_sof,d2
	trap	#15
	move.l	d0,orig_hnd_sof

	; enable SOF interrupt
	moveq	#3,d0 ; syscall_int_enable
	moveq	#0,d1
	trap	#15

	#ifdef do_clear
	lea.l	pattern,a0
	jsr	clear_text0
	#endif

	; frame state
	moveq	#tx0_w/2,d4  ; curr_x
	moveq	#padd_y-1,d5 ; curr_y
	moveq	#-1,d6       ; step_x
	moveq   #-1,d7       ; step_y
frame:
	#ifndef do_morfe
	tst.b	flag_sof
	beq	frame
	move.b	#0,flag_sof
	#endif

	lea.l	pattern+4*4,a0
	jsr	clear_texa0

	move.w	d4,d0
	move.w	d5,d1
	jsr	ball

	move.w	d4,d0
	jsr	paddle

	; update positions
	add.w	d6,d4
	beq	neg_step_x
	cmpi.w	#tx0_w-ball_w,d4
	bcs	done_x
neg_step_x:
	neg.w	d6
done_x:
	add.w	d7,d5
	beq	neg_step_y
	cmpi.w	#padd_y-ball_h,d5
	bcs	done_y
neg_step_y:
	neg.w	d7
done_y:
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text0+tx0_w-4,a0
	jsr	print_u16

	cmpi.w	#frames,d0
	bne	frame

	moveq	#2,d0 ; syscall_int_register
	moveq	#0,d1 ; INT_SOF_A
	move.l	orig_hnd_sof,d2
	trap	#15

	moveq	#0,d0 ; syscall_exit
	trap	#15
hnd_sof:
	move.b	#1,flag_sof
	rts
orig_hnd_sof:
	.long	0
frame_i:
	.word	0
flag_sof:
	.byte	0

	.align	2
; draw ball
; d0.w: x-coord -- left of ball
; d1.w: y-coord -- top of ball
; clobbers: a0
ball:
	movea.w	d0,a0
	adda.l	#ea_texa0,a0
	mulu.w	#tx0_w,d1
	adda.l	d1,a0
	move.b	#0xf,(a0)
	rts

; draw paddle
; d0.w: x-coord -- middle of paddle
; clobbers: d1-d2, a0
paddle:
	subi.w	#paddlen/2,d0
	bge	min_done
	moveq	#0,d0
	bra	max_done
min_done:
	cmpi.w	#tx0_w-paddlen,d0
	ble	max_done
	moveq	#tx0_w-paddlen,d0
max_done:
	movea.w	d0,a0
	adda.l	#ea_texa0+tx0_w*padd_y,a0
	move.l	#0x41414141,d0
	moveq.l	#paddlen,d1
	jsr	memset1
	rts

; memset a buffer to a given value; 1B inner loop
; a0: target
; d0.b: value
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
memset1:
	move.b	d0,(a0)+
	subi.l	#1,d1
	bne	memset1
	rts

; clear tx0-sized text channel A
; a0: pattern ptr
; clobbers d0-d3, a1
clear_text0:
	movem.l	(a0),d0-d3
	movea.l	#ea_text0,a0
	lea	(tx0_w*tx0_h)&~15(a0),a1
1$:
	movem.l	d0-d3,-(a1)
	cmpa.l	a0,a1
	bne	1$
	rts

; clear tx0-sized attr channel A
; a0: pattern ptr
; clobbers d0-d3, a1
clear_texa0:
	movem.l (a0),d0-d3
	movea.l	#ea_texa0,a0
	lea	(tx0_w*tx0_h)&~15(a0),a1
1$:
	movem.l	d0-d3,-(a1)
	cmpa.l	a0,a1
	bne	1$
	rts

; produce ascii from word
; d0.w: word to print
; a0: output address
; clobbers: d1, a1
print_u16:
	lea	4(a0),a1
1$:
	rol.w	#4,d0
	move.b	d0,d1
	andi.b	#0xf,d1
	addi.b	#'0',d1
	cmpi.b	#'0'+10,d1
	bcs	2$
	addi.b	#'a'-'9'-1,d1
2$:
	move.b	d1,(a0)+
	cmpa.l	a1,a0
	bcs	1$
	rts

	.align 4
pattern:
	.long	0x20202020, 0x20202020, 0x20202020, 0x20202020
	.long	0x42434243, 0x42434243, 0x42434243, 0x42434243
