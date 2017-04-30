;===============================================================================
; Breakout Arcade -- 1976
; Conceptualized by Nolan Bushnell and Steve Bristow.
; Built by Steve Wozniak.
; https://en.wikipedia.org/wiki/Breakout_(video_game)
;===============================================================================
; C64 Breakout clone -- 2016
; Written by Darren Du Vall aka Sausage-Toes
; source at: 
; Github: https://github.com/Sausage-Toes/C64_Breakout
;===============================================================================
; C64 Breakout clone ported to Atari 8-bit -- 2017
; Atari-fied by Ken Jennings
; Build for Atari using eclipse/wudsn/atasm on linux
; Source at:
; Github: https://github.com/kenjennings/C64-Breakout-for-Atari
; Google Drive: https://drive.google.com/drive/folders/0B2m-YU97EHFESGVkTXp3WUdKUGM
;===============================================================================
; Breakout: Gratuitous Eye Candy Edition -- 2017
; Written by Ken Jennings
; Build for Atari using eclipse/wudsn/atasm on linux
; Source at:
; Github: https://github.com/kenjennings/Atari-Breakout-GECE
; Google Drive: https://drive.google.com/drive/folders/
;===============================================================================

;===============================================================================
; History V 1.0
;===============================================================================
; dli.asm contains all the Display List Interupts.
; See display.asm for all the display list data.
; See screen.asm for the 6502 code managing the display.
;===============================================================================

DISPLAY_LIST_INTERRUPT


; Do the color bars in the scrolling title text.
; Since the line scrolls, the beginning of the color
; bars changes.  Also, the number of visible scan 
; lines of the title changes as the title scrolls 
; up.  The VBI maintains the reference for these
; so the DLI doesn't have to figure out anything.

DLI_1 ; Save registers 
	pha
	txa
	pha
	tya
	pha

	ldy TITLE_WSYNC_OFFSET ; Number of lines to skip above the text

	beq DLI_Color_Bars ; no lines to skip; do color bars.
DLI_Delay_Top
	sty WSYNC
	dey
	bne DLI_Delay_Top

	; This used to have a lot of junk including value testing 
	; to figure out how to color the Player/flying character.
	; However, giving the player a permanent page 0 pointer to 
	; a color table (ZTITLE_COLPM0) and having the VBI decide 
	; which to use simplified this logic considerably.
  	
DLI_Color_Bars	
	ldx TITLE_WSYNC_COLOR ; Number of lines in color bars.
	
	beq End_DLI_1 ; No lines, so the DLI is finished.
	
	ldy TITLE_COLOR_COUNTER

DLI_Loop_Color_Bars
	lda (ZTITLE_COLPM0),y ; Set by VBI to point at one of the COLPF tables
	sta WSYNC
	sta COLPM0
	
	lda TITLE_COLPF1,y
	sta COLPF0
	
	lda TITLE_COLPF1,y
	sta COLPF1
	
	lda TITLE_COLPF2,y
	sta COLPF2

	lda TITLE_COLPF3,y
	sta COLPF3	

	iny
	dex
	bne DLI_Loop_Color_Bars

End_DLI_1 ; End of routine.  Point to next routine.
	lda #<DLI_2
	sta VDSLST
	lda >#DLI_2
	sta VDSLST+1

	pla ; Restore registers for exit
	tay
	pla
	tax
	pla
	
	rti


; DLI2: Occurs as the last line of the Display List in the Title Scroll section.
; Set Normal Screen, VSCROLL=0, COLPF0 for horizontal bumper.
; Set PRIOR for Fifth Player.
; Set HPOSP3/HPOSM0, COLPM3/COLPF3, SIZEP3, SIZEM 
; for left and right Thumper-bumpers.
; set HITCLR for Playfield.
;-------------------------------------------
; Set HPOSP0/P1/P2, COLPM0/PM1/PM2, SIZEP0/P1/P2 for top row Boom objects.
;
;-------------------------------------------
; color 1 = horizontal/top bumper.
; Player 3 = Left bumper 
; Missile (5th Player) = Right Bumper
;-------------------------------------------
; COLPF0, 
; COLPM3, COLPF3
; HPOSP3, HPOSM0
; SIZEP3, SIZEM0
;-------------------------------------------

DLI_2
	pha
	txa
	pha
	tya
	pha

	; GTIA Fifth Player.
    lda #[FIFTH_PLAYER|1] ; Missiles = COLPF3.  Player/Missiles Priority on top.  
	sta PRIOR
	sta HITCLR
	
	; Screen parameters...
	lda #[ENABLE_DL_DMA|ENABLE_PM_DMA|PLAYFIELD_WIDTH_NORMAL|PM_1LINE_RESOLUTION]
	STA WSYNC
	sta DMACTL

	; Top thumper-bumper.  Only set color.  The rest of the animation is 
	; done in the Display list and set by the VBI.
    lda THUMPER_COLOR_TOP
    sta COLPF0
    
    ; Left thumper-bumper -- Player 3. P/M color, position, and size.
    lda THUMPER_COLOR_LEFT
    sta COLPM3
    
    ldy THUMPER_FRAME_LEFT        ; Get animation frame
    lda THUMPER_LEFT_HPOS_TABLE,y ; P/M position 
    sta HPOSP3
    lda THUMPER_LEFT_SIZE_TABLE,y ; P/M size
    sta SIZEP3

    ; Right thumper-bumper -- Missile 0.  Set P/M color, position, and size.
    lda THUMPER_COLOR_RIGHT
    sta COLPF3 ; because 5th player is enabled.
    
    ldy THUMPER_FRAME_RIGHT        ; Get animation frame
    lda THUMPER_RIGHT_HPOS_TABLE,y ; P/M position 
    sta HPOSM0
    lda THUMPER_RIGHT_SIZE_TABLE,y ; P/M size
    sta SIZEM

	; Magic here
	
End_DLI_2 ; End of routine.  Point to next routine.
	lda #<DLI_3
	sta VDSLST
	lda >#DLI_3
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti

; DLI3: Hkernel 8 times....
;      Set HSCROLL for line, VSCROLL = 5, then Set COLPF0 for 5 lines.
;      Reset VScroll to 1 (allowing 2 blank lines.)
;      Set P/M Boom objects, HPOS, COLPM, SIZE
;      Repeat HKernel.
;
; Define 8 rows of Bricks.  
; Each is 5 lines of mode C graphics, plus 2 blank line.
; The 5 rows of graphics are defined by using the VSCROL
; exploit to expand one line of mode C into five lines.
;
; This:
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL
;   .byte DL_BLANK_2
; Becomes this:
;   DL_MAP_C
;   DL_MAP_C
;   DL_MAP_C
;   DL_MAP_C
;   DL_MAP_C
;   Blank Line
;   Blank Line
;
; The Blank lines provide space for expansion of the boom blocks over the bricks.
; Therefore they must be positioned in the blank line before the brick line.
; (An extra blank scan line follows the line starting the DLI to allow for this 
; space on the first line)
;
; So, here is the DLI line change order:
;   DL_BLANK_1|DL_DLI                      Set hpos, size, color for Boom 1 and Boom2 (1)
;   DL_BLANK_1                             Set Vscroll 11 and HSCROLL for Brick Line 1 - set color COLPF0 (1)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (1)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (1)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (1)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (1)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set VScroll 0
;   DL_BLANK_1                             Set hpos, size, color for Boom 1 and Boom2 (2)
;   DL_BLANK_1                             Set Vscroll and HSCROLL for Brick Line 2 - set color COLPF0 (2)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (2)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (2)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (2)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (2)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set VScroll 0
;   DL_BLANK_1                             Set hpos, size, color for Boom 1 and Boom2 (3)
;   DL_BLANK_1                             Set Vscroll and HSCROLL for Brick Line 3 - set color COLPF0
; etc. . . .
;   DL_BLANK_1                             Set hpos, size, color for Boom 1 and Boom2 (8)
;   DL_BLANK_1                             Set Vscroll and HSCROLL for Brick Line 8 - set color COLPF0 (8)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (8)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (8)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (8)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set color COLPF0 (8)
;   DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL  Set VScroll 0
;   DL_BLANK_1
;   DL_BLANK_1
;-------------------------------------------
; color 1 = bricks.
; Player 1 = Boom animation 1
; Player 2 = Boom animation 2
;-------------------------------------------
; per brick line
; COLPM1, COLPM2
; HPOSP1, HPOSP2
; SIZEP1, SIZEP2
; COLPF0, HSCROLL 
;-------------------------------------------
DLI_3
	pha
	txa
	pha
	tya
	pha
	
	ldx #0  ; Starting at line 0 first line of bricks.
	;
	; Set the Boom animation postitions.
	; Hopefully, this is enough load/stores to cross the end of the blank scan line...  
	; If not then a wsync needs to be inserted.  somewhere.
DLI3_DO_BOOM_AND_BRICKS
	lda BOOM_1_HPOS,x
	sta HPOSP1
	lda BOOM_2_HPOS,x
	sta HPOSP2

    lda BOOM_1_SIZE,x
	sta SIZEP1
	lda BOOM_2_SIZE,x
	sta SIZEP2

    lda BOOM_1_COLPM,x
	sta COLPM1
	lda BOOM_2_COLPM,x
	sta COLPM2
	
	; Still in the blank line area.  (I hope.)
	; Set hscroll for brick line which is next.
	lda BRICK_CURRENT_HSCROL,x 
	sta HSCROL
	lda #11  ; Trick Antic into extending the line.  11, 12, 13, 14, 15.
	sta VSCROL
	
	; ANTIC is now having a small brain fart and stuttering
	; for several scan lines.  Apply color to those lines.
	lda BRICK_CURRENT_COLOR,x
    sta WSYNC
	sta COLPF0                ; scan line 1
	iny
	iny
    sta WSYNC
	sta COLPF0                ; scan line 2
	iny
	iny
    sta WSYNC
	sta COLPF0                ; scan line 3
	iny
	iny
    sta WSYNC
	sta COLPF0                ; scan line 4
	iny
	iny
    sta WSYNC
	sta COLPF0                ; scan line 5

	; Fix VSCROL for the  two blank lines that follow
	lda #0
	sta WSYNC
	sta VSCROL
 
	inx                   ; next line
	cpx #8                
	bne DLI3_DO_BOOM_AND_BRICKS
	
End_DLI_3 ; End of routine.  Point to next routine.
	lda #<DLI_4
	sta VDSLST
	lda >#DLI_4
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti
	
	
	
	
	
DLI_4
	pha
	txa
	pha
	tya
	pha

	; Magic here
	
End_DLI_4 ; End of routine.  Point to next routine.
	lda #<DLI_5
	sta VDSLST
	lda >#DLI_5
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti
	
	
	
	
DLI_5
	pha
	txa
	pha
	tya
	pha

	; Magic here
	
End_DLI_5 ; End of routine.  Point to next routine.
	lda #<DLI_6
	sta VDSLST
	lda >#DLI_6
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti
	
	
	
	
	
DLI_6
	pha
	txa
	pha
	tya
	pha

	; Magic here
	
End_DLI_6 ; End of routine.  Point to next routine.
	lda #<DLI_7
	sta VDSLST
	lda >#DLI_7
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti
	
	

	
	
DLI_7
	pha
	txa
	pha
	tya
	pha

	; Magic here
	
End_DLI_7 ; End of routine.  Point to first routine.
	lda #<DLI_1
	sta VDSLST
	lda >#DLI_1
	sta VDSLST+1

	pla
	tay
	pla
	tax
	pla
	
	rti
