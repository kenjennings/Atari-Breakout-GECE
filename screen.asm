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
; screen.asm contains all the general code for creating 
; and managing the display EXCLUDING the display list 
; interrupt itself.  
; include display.asm first for all the display data and declarations.
; See dli.asm for the display list interrupts.
;===============================================================================





;---------------------------------------------------------------------------------------------------
; Atari Stop Screen
;---------------------------------------------------------------------------------------------------
; Stop all screen activity.
; Stop DLI activity.
; Kill Sprites (Player/Missile graphics)
;
; No registers modified.
;---------------------------------------------------------------------------------------------------

AtariStopScreen

	saveRegs ; put CPU flags and registers on stack

	lda #0
	sta SDMCTL ; ANTIC stop DMA for display list, screen, and player/missiles

; Note that SDMCTL is copied to DMACTL during the Vertical Blank Interrupt, so 
; this won't take effect until the start of the next frame.  
; Therefore, remember to make sure the end of frame is reached before resetting 
; the display list address, the display list interrupt vector, and turning
; on the display DMA.  

	sta GRACTL ; GTIA -- stop accepting DMA data for Player/Missiles

	lda #NMI_VBI ; set Non-Maskable Interrupts without NMI_DLI for display list interrupts
	sta NMIEN

; Excessive cleanliness.  
; Make sure all players/missiles are off screen
; Clear Player/Missile bitmap images.
	jsr AtariMovePMOffScreen
	jsr AtariClearPMImage

	safeRTS ; restore registers and CPU flags, then RTS


;---------------------------------------------------------------------------------------------------
; Atari Start Screen
;---------------------------------------------------------------------------------------------------
; Start Player/Missiles and the screen.
; P/M Horizontal positions were moved off screen earlier, so there 
; should be no glitches during startup.
;
; No registers modified.
;---------------------------------------------------------------------------------------------------

AtariStartScreen

	saveRegs ; put CPU flags and registers on stack

	; Tell ANTIC where to find the custom character set.
	lda #>CUSTOM_CSET 
	sta CHBAS

	;  tell ANTIC where to find the new display list.
	lda #<DISPLAY_LIST 
	sta SDLSTL
	lda #>DISPLAY_LIST ;
	sta SDLSTH 

	; Tell ANTIC where P/M memory occurs for DMA to GTIA
	lda #>PLAYER_MISSILE_BASE
	sta PMBASE

	; Enable GTIA to accept DMA to the GRAFxx registers.
	lda #ENABLE_PLAYERS | ENABLE_MISSILES 
	sta GRACTL

	; Start screen and P/M graphics
	; The OS copies SDMCTL to DMACTL during the Vertical Blank Interrupt, 
	; so we are guaranteed that this cleanly restarts the display 
	; during the next VBI.
	lda #ENABLE_DL_DMA | PM_1LINE_RESOLUTION | ENABLE_PM_DMA | PLAYFIELD_WIDTH_NORMAL
	sta SDMCTL

	; Conveniently, the C64 game is only using 4 colors for bricks,  
	; so the C64 color cells will be simulated on the Atari using 
	; the multi-color character mode, a custom character set, and 
	; four color registers.

	lda #COLOR_PINK+$04  ; "Red"
	sta COLOR0 ; COLPF0	character block $20  
	
	lda #COLOR_RED_ORANGE+$06  ; "Orange"
	sta COLOR1 ; COLPF1    character block $40 
	
	lda #COLOR_GREEN+$06  ; "Green"
	sta COLOR2 ; COLPF2    character block $60  
	
	lda #COLOR_LITE_ORANGE+$0C  ; "Yellow"
	sta COLOR3 ; COLPF3 ; character block $E0  ($60 + high bit $80) 

	safeRTS ; restore registers and CPU flags, then RTS

	
	
	.local	
;===============================================================================
; Determine Brick X and Y from current X/Y test coordinate.
;===============================================================================
; Input: 
; X reg: X coordinate to convert to brick position
; Y reg: Y coordinate to convert to brick position
; 
; Output:
; ZCOORD_X:    Copy of input X coordinate
; ZCOORD_Y:    Copy of input Y coordinate
; ZBRICK_COL:  Calculated brick number of X coordinate. (1-14)  Or -1 if not valid
; ZBRICK_LINE:  Calculated line number of bricks.  (1-8) or -1 if not valid 
;===============================================================================
DetermineBrickXY

	saveRegs ; put CPU flags and registers on stack

	jsr DetermineBrickX
	jsr DetermineBrickY

	safeRTS ; restore registers and CPU flags, then RTS
	
	

.local	
;===============================================================================
; Determine Brick X from current X test coordinate.
;===============================================================================
; Input: 
; X reg: X coordinate to convert to brick position
; 
; Output:
; ZCOORD_X:   Copy of input X coordinate
; ZBRICK_COL: Calculated brick number of X coordinate.(1-14) Or -1 if not valid
;
; Coordinates are tightly managed by other code, so it should not be possible
; for the tested value to exceed the established screen borders.
;===============================================================================
DetermineBrickX

	saveRegs ; put CPU flags and registers on stack

	stx ZCOORD_X     ; Save X color clock coordinate
	
	lda #$FF         ; Column = -1 (until a better value is calculated)
	sta ZBRICK_COL
	
	txa              ; Adjust the 51 to 203 range to 0 to 152 
	
	sec              
	sbc #MIN_PIXEL_X ; PLAYFIELD_LEFT_EDGE_NORMAL + BRICK_LEFT_OFFSET = 51
	cmp #[PIXEL_COLS]; should be 153

	bcs ?ExitRoutine ; greater than lookup range.
	
	tax 
	lda BALL_XPOS_TO_BRICK_TABLE,x ; convert X Color clock to brick column number
	sta ZBRICK_COL                 ; Save brick column.

?ExitRoutine	
	safeRTS ; restore registers and CPU flags, then RTS
	


.local	
;===============================================================================
; Determine Brick Y from current Y test coordinate.
;===============================================================================
; Input: 
; Y reg: Y coordinate to convert to brick position
; 
; Output:
; ZCOORD_Y:    Copy of input Y coordinate
; ZBRICK_LINE:  Calculated line number of bricks.  (1-8) or -1 if not valid 
;===============================================================================
DetermineBrickY

	saveRegs ; put CPU flags and registers on stack

	sty ZCOORD_Y     ; Save Y scan line coordinate

	lda #$FF         ; Line = -1 (until a better value is calculated)
	sta ZBRICK_LINE

	tya              
	
	cmp #BRICK_TOP_OFFSET ; Less than the first scan line of bricks?
	bcc ?ExitRoutine

	cmp #[BRICK_BOTTOM_OFFSET+1] ; 132 = 131 + 1 
	bcs ?ExitRoutine
	
	sec                  ; Adjust the 78 to 131 range to 0 to 53 
	sbc #BRICK_TOP_OFFSET
	
	tay
	lda BALL_YPOS_TO_BRICK_TABLE,y ; convert y scan line to brick line number
	sta ZBRICK_LINE                ; save brick line.
	
?ExitRoutine
	safeRTS ; restore registers and CPU flags, then RTS


	
.local	
;===============================================================================
; Determine if there is a brick at position X/Y
;===============================================================================
; Input: 
; ZBRICK_COL:  Calculated brick number of X coordinate. (1-14)  Or -1 if not valid
; ZBRICK_LINE:  Calculated line number of bricks.  (1-8) or -1 if not valid 
; 
; Output:
; ZCOLLISION:  There is/is not a brick at the given line/column.
;              0 = No Brick. !0 = Yes, there is a brick.
;===============================================================================
DetermineBrickCollision

	saveRegs ; put CPU flags and registers on stack

	lda #0           ; Clear Collision flag
	sta ZCOLLISION

	ldx ZBRICK_LINE  ; Get the line number (1-8) 
	beq ?ExitRoutine ; Zero?  Then no line, no collision.
	bmi ?ExitRoutine ; negative?  Then no line, no collision.
	
	dex              ; Adjust line value 1-8 to 0-7.
	
	lda BRICK_BASE_LINE_TABLE_LO,x ; Setup Zero Page pointer to 
	sta ZBRICK_BASE                ; the Brick Base address for 
	lda BRICK_BASE_LINE_TABLE_HI,x ; this line.
	sta ZBRICK_BASE+1

	ldy ZBRICK_COL                 ; Get the column number (1-14)
	beq ?ExitRoutine               ; Zero? Then no column, so no collision.
	bmi ?ExitRoutine               ; Negative? Then no column, so no collision.
	
	dey              ; adjust column value 1-14 to 0-13
	
	tya              ; Multiply by 4 for index into BRICK_TEST_TABLE
	asl a            ; times 2
	asl a            ; times 4
	tax
	
	ldy BRICK_TEST_TABLE,x ; First entry in record is byte offset for brick

	inx                    ; Next entry in record is a byte of test data

?LoopCheckBrick
	lda (ZBRICK_BASE),y    ; Read byte from brick line at offset.
	and BRICK_TEST_TABLE,x ; Test bits.

	sta ZCOLLISION         ; store result - 0 or !0

	bne ?ExitRoutine       ; if !0 then a collision is found.  Comparison done.
	
	iny                    ; Next byte in brick screen memory
	inx                    ; Next entry in the Test table.
	
	cpx #4                 ; If exceeded record length then comparison is done.
	bne ?LoopCheckBrick
		
?ExitRoutine
	safeRTS ; restore registers and CPU flags, then RTS
	

.local	
;===============================================================================
; Erase the brick at position X/Y
;===============================================================================
; Input: 
; ZBRICK_COL:  Calculated brick number of X coordinate. (1-14)  Or -1 if not valid
; ZBRICK_LINE:  Calculated line number of bricks.  (1-8) or -1 if not valid 
; 
; Output:
; N/A:  Brick in screen memory is erased.  Surrounding bricks are untouched.
;===============================================================================
ClearBrickXY

	saveRegs ; put CPU flags and registers on stack

	ldx ZBRICK_LINE  ; Get the line number (1-8) 
	beq ?ExitRoutine ; Zero?  Then no line, no brick to erase.
	bmi ?ExitRoutine ; negative?  Then no line, no brick to erase.
	
	dex              ; Adjust line value 1-8 to 0-7.
	
	lda BRICK_BASE_LINE_TABLE_LO,x ; Setup Zero Page pointer to 
	sta ZBRICK_BASE                ; the Brick Base address for 
	lda BRICK_BASE_LINE_TABLE_HI,x ; this line.
	sta ZBRICK_BASE+1

	ldy ZBRICK_COL                 ; Get the column number (1-14)
	beq ?ExitRoutine               ; Zero? Then no column, so no collision.
	bmi ?ExitRoutine               ; Negative? Then no column, so no collision.
	
	dey              ; adjust column value 1-14 to 0-13
	
	tya              ; Multiply by 4 for index into BRICK_TEST_TABLE
	asl a            ; times 2
	asl a            ; times 4
	tax
	
	ldy BRICK_MASK_TABLE,x ; First entry in record is byte offset for brick

	inx                    ; Next entry in record is a byte of mask data

?LoopCheckBrick
	lda (ZBRICK_BASE),y    ; Read byte from brick line screen memory at offset.
	and BRICK_TEST_TABLE,x ; Mask bits.

	lda (ZBRICK_BASE),y    ; Store result back to brick line in screen memory
	
	iny                    ; Next byte in brick screen memory
	inx                    ; Next entry in the Mask table.
	
	cpx #4                 ; If exceeded record length then comparison is done.
	bne ?LoopCheckBrick
		
?ExitRoutine
	safeRTS ; restore registers and CPU flags, then RTS

	
