; platform A2560U
ea_vicky .equ 0xb40000
ea_text  .equ 0xb60000
ea_texa  .equ 0xb68000
ea_palfg .equ 0xb6c400
ea_palbg .equ 0xb6c440
ea_vram0 .equ 0xc00000

ea_text0 .equ ea_text
ea_texa0 .equ ea_texa

ea_palf0 .equ ea_palfg
ea_palb0 .equ ea_palbg

; some hw regs
hw_vicky_master .equ 0x0000
hw_vicky_border .equ 0x0004
hw_vicky_cursor .equ 0x0010

; some fields in hw regs
pos_master_text   .equ 0x0
msk_master_text   .equ 0x1

pos_master_ovrly  .equ 0x1
msk_master_ovrly  .equ 0x1

pos_master_graph  .equ 0x2
msk_master_graph  .equ 0x1

pos_master_mode   .equ 0x8
msk_master_mode   .equ 0x7

pos_master_clk    .equ 0xf
msk_master_clk    .equ 0x1

pos_border_enable .equ 0x0
msk_border_enable .equ 0x1

pos_cursor_enable .equ 0x0
msk_cursor_enable .equ 0x1

; some values in fields in hw regs
master_mode_640x480 .equ 0x0
master_mode_800x600 .equ 0x1
master_mode_640x400 .equ 0x3
master_mode_double  .equ 0x4

master_clk_25mhz    .equ 0x0
master_clk_40mhz    .equ 0x1

; some hw reg helpers (-spaces CLI required)
reserved_master   .equ 0x1840
reset_master_mode .equ reserved_master

set_master_text   .equ msk_master_text  << pos_master_text
set_master_ovrly  .equ msk_master_ovrly << pos_master_ovrly
set_master_graph  .equ msk_master_graph << pos_master_graph

set_master_mode_640x480 .equ ((msk_master_mode & master_mode_640x480) << pos_master_mode) | ((msk_master_clk & master_clk_25mhz) << pos_master_clk)
set_master_mode_800x600 .equ ((msk_master_mode & master_mode_800x600) << pos_master_mode) | ((msk_master_clk & master_clk_40mhz) << pos_master_clk)
set_master_mode_640x400 .equ ((msk_master_mode & master_mode_640x400) << pos_master_mode) | ((msk_master_clk & master_clk_25mhz) << pos_master_clk)
set_master_mode_double  .equ ((msk_master_mode & master_mode_double)  << pos_master_mode)

reset_border_enable .equ ~(msk_border_enable << pos_border_enable)
set_border_enable   .equ msk_border_enable << pos_border_enable

reset_cursor_enable .equ ~(msk_cursor_enable << pos_cursor_enable)
set_cursor_enable   .equ msk_cursor_enable << pos_cursor_enable