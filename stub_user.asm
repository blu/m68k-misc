ea_user  equ $20000 ; MCP's user-process loading address
ea_stub  equ $50000 ; top of the ram for vbcc-generated code as per vlink.cmd

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_stub

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stub,a0 ; fictitious usp, before crt startup code sets its own
	move.l	a0,usp
	andi.w	#$dfff,sr

	; transfer control to ea_user
	movea.l	#ea_user,a0
	jmp	(a0)
