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

	; Here's to hoping that the badline is short enough to allow
	; the player color and four playfield color registers to change 
	; before they are displayed.  This is part of the reason 
	; for the narrow playfield.
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
	; If not then a wsync needs to be inserted.  somewhere.  hope not.  The end
	;  of the loop already did a wsync when it corrected the scrolling, so
	; it might mean the rows from 2 to 8 have the boom animations setting
	; written one scan line too high....  thinking.   thinking....
DLI3_DO_BOOM_AND_BRICKS
	lda BOOM_1_HPOS,x
	ldy BOOM_2_HPOS,x
	sta WSYNC ; need to drop one line more to line up with boom lines.
	; six store, four load after wsync.   This is unlikely to work well.
	; At least there's no graphics or character set DMA on this line.
	; Highly possible that this will need to be reduced to 1 Boom animation
	; object which is the least desireable choice.
	; Otherwise, the the Boom animation height cannot exceed the height of the
	; bricks.  The alternate plan means there would be two completely blank
	; scan line to affect all the changes, so that will definitely work well.
	; (And, this could be used to reduce the gap between brick lines to one scan
	; line compressing the brick playfield by 7 scan lines, nearly one full text line.)
	sta HPOSP1
	sty HPOSP2

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
	; Because we are toggling VSCROL values to trigger unnatural behavior
	; in ANTIC, stricter timing may be required here.  The WSYNC below 
	; may need to move up here before updating VSCROL.
	lda #11  ; Trick Antic into extending the line.  11, 12, 13, 14, 15.
	sta VSCROL

	; Due to the VSCROL set large than the number of scan lines in 
	; this graphics mode ANTIC is now having a small brain fart and 
	; stuttering out the same line of graphics for several scan lines.  
	; Apply color to those lines.
	ldy BRICK_CURRENT_COLOR,x
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

	; thinking...  that vscroll correction happens at the last line
	; a brick line.  therefore , this jump to loop happens on the
	; first blank line after the bricks...  This means the loop writes
	; new boom animation settings one line too high...  So, there
	; needs to be a wsync either here, or at the  beginning of the
	; loop  to drop down one more line.
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


; DLI4: Set Narrow Width, Set the mode 3 chracter set.
; Set VSCROLL for window.
; Fade text in.

; Sets the narrow screen size for the scrolling credits window.
; It provides a few more cycles for the MAIN code, but its not
; like I'm counting cycles.  (Yet.)

DLI_4
	pha
	txa
	pha
	tya
	pha

	; set the Mode 3 character set.
	lda #>CHARACTER_SET_00
	sta CHBASE
	; set the fine scroll for the credits.
	lda SCROLL_CURRENT_VSCROLL
	sty VSCROL
	; Set Narrow screen.
	lda #[ENABLE_DL_DMA|ENABLE_PM_DMA|PLAYFIELD_WIDTH_NARROW|PM_1LINE_RESOLUTION]
	sta DMACTL
	; set black text background.
	ldx #$00
	stx COLPF2

	ldy #$06  ; to read 6 table entries
	ldx SCROLL_CURRENT_FADE
	
	; 10 instructions of loads and stores should put this past 
	; the end of the scan line that started the DLI.
	
	; Fade in the scrolling text window.

Loop_Fade_In_Scroll_Text
	lda SCROLL_FADE_START_LINE_TABLE,x
	sta WSYNC
	sta COLPF1   ; Set new text color (luminance)
	inx          ; Next luminance value
	dey          ; reached the end?  0 ?
	bne Loop_Fade_In_Scroll_Text ; No.  Continue updates.

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



; DLI5: Fade text out at bottom of scrolling text.
; The trick here is that the start of the fade changes
; based on the value of vscroll.
DLI_5
	pha
	txa
	pha
	tya
	pha

	; Because the DLI is moving away while VSCROL 
	; increments, the DLI needs to skip a variable number
	; of scan lines before starting to fade out the text.
	lda SCROLL_CURRENT_VSCROLL
	clc
	adc #3
	tax
Loop_Fade_Out_Skip_Lines
	sta WSYNC
	dex
	bne Loop_Fade_Out_Skip_Lines
	
	ldx SCROLL_CURRENT_FADE

Loop_Fade_Out_Scroll_Text
	lda SCROLL_FADE_END_LINE_TABLE,x
	sta WSYNC
	sta COLPF1   ; Set new text color (luminance)
	dex          ; Next luminance value.  Reached end?
	bpl Loop_Fade_Out_Scroll_Text
	
	; Do a couple of preliminary things for 
	; the Paddle to simplify what needs to be 
	; done in DLI6.
	; Set parameters for PM1 and PM2 here. 
	; DLI6 will work on only PM3.
	lda PADDLE_HPOS    ; Horizontal position(s)
	sta HPOSP1
	sta HPOSP2

	lda #$00           ; Normal Hosrizontal Size(s)
	sta SIZEP1
	sta SIZEP2
	
	
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


; DLI6: Sets Paddle specs. 
; PMWIDTH, HPOS,changes colors for paddle.
; Then set HSCROLL for Scores.
; 
; The initial states for Player1 and Player2 
; were set at the end of the prior DLI to 
; simplify what goes on here.
; This routine only adjusts the Player3 state. 
; This is a little more time critical, because 
; there is no gap between the last scan line of 
; the left thumper-bumper and the first scan 
; line of the paddle.
;
; Finish up by re-setting the character set back
; to the custom set for mode 6 color text and
; normal playfield width.
DLI_6
	pha
	txa
	pha

	lda PADDLE_HPOS ; Horizontal position
	ldx #$00        ; For size
	
	sta WSYNC       ; sync to end of line
	sta HPOSP3      ; stuff in postion
	sta SIZEP3      ; stuff in size
	
	ldx PADDLE_FRAME               ; Get the animated 
	lda PADDLE_STRIKE_COLOR_ANIM,x ;  pddle color.

	sta COLPM3      ; Stuff in color. 
	sta WSYNC       ; sync to end of line.
	
	ldx #$94        ; For second  scan line reset paddle color 
	sta COLPM3      ; to its intended default. 
	
	lda #>CHARACTER_SET_01 ; Mode 6 text. Title and score.
	sta CHBASE
	
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




; DLI7: Fairly basic.  Just prettify the text.
; "BALLS" is a little indicator in the top left 
; corner of the last row of text.
; The other two colors are for the score.

DLI_7
	pha
	txa
	pha
	tya
	pha
	
	; Since the "Balls" is at the top of the line, and 
	; the Score is 12 scan lines centered over two lines
	; then we don;t have to count out 16 entire sca lines.
	; Therefore 13...
	ldy #13    
	ldx DISPLAYED_BALLS_SCORE_COLOR_INDEX

Loop_Color_Balls_Score	
	lda DISPLAYED_BALLS_COLOR,x      ; "Balls" indicator color
	sta WSYNC
	sta COLPF3
	
	lda DISPLAYED_SCORE_COLOR0,x     ; Score digits are two colors...
	sta COLPF0

	lda DISPLAYED_SCORE_COLOR1,x
	sta COLPF1

	inx
	dey 
	bpl Loop_Color_Balls_Score
	

End_DLI_7 ; End of routines.  Point to first routine.
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
