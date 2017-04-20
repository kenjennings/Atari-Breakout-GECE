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
; Github: https://github.com/kenjennings/Breakout-GECE-for-Atari
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
	; However, giving the player a page 0 pointer to a color
	; table and having the VBI decide which to use simplified
	; this logic considerably.
  	
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
	

	

	
DLI_2
	pha
	txa
	pha
	tya
	pha

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
	
	
	
	
	
DLI_3
	pha
	txa
	pha
	tya
	pha
	
	; Magic here
	
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
	
	
	
	
				
	