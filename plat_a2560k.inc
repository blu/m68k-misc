; platform A2560K
ea_user  equ $020000
ea_stack equ $080000
ea_vicky equ $c40000
ea_text0 equ $c60000
ea_texa0 equ $c68000
ea_palf0 equ $c6c400
ea_palb0 equ $c6c440
ea_text1 equ $ca0000
ea_texa1 equ $ca8000
ea_palf1 equ $cac400
ea_palb1 equ $cac440

; some hw regs
hw_vicky_master equ $0000
hw_vicky_border equ $0004
hw_vicky_cursor equ $0010

; some fields in hw regs
pos_master_mode   equ $8
msk_master_mode   equ $3

pos_master_clk    equ $f
msk_master_clk    equ $1

pos_border_enable equ $0
msk_border_enable equ $1

pos_cursor_enable equ $0
msk_cursor_enable equ $1

; some values in fields in hw regs
master_mode_640x480 equ %00
master_mode_800x600 equ %01
master_mode_640x400 equ %11

master_clk_25mhz    equ %0
master_clk_40mhz    equ %1

; some hw reg helpers (-spaces CLI required)
reset_master_mode equ ~((msk_master_mode << pos_master_mode) | (msk_master_clk << pos_master_clk))
set_master_mode_640x480 equ ((msk_master_mode & master_mode_640x480) << pos_master_mode) | ((msk_master_clk & master_clk_25mhz) << pos_master_clk)
set_master_mode_800x600 equ ((msk_master_mode & master_mode_800x600) << pos_master_mode) | ((msk_master_clk & master_clk_40mhz) << pos_master_clk)
set_master_mode_640x400 equ ((msk_master_mode & master_mode_640x400) << pos_master_mode) | ((msk_master_clk & master_clk_25mhz) << pos_master_clk)

reset_border_enable equ ~(msk_border_enable << pos_border_enable)
set_border_enable   equ msk_border_enable << pos_border_enable

reset_cursor_enable equ ~(msk_cursor_enable << pos_cursor_enable)
set_cursor_enable   equ msk_cursor_enable << pos_cursor_enable
