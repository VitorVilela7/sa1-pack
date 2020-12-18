@includefrom sa1.asm
pushpc

; MaxTile API:
; 1) Flush Northern OAM ($0328-$03FC), mark them as standard priority.
; - use the SA-1 CPU
; - call with A/X/Y 8-bit. All registers are destroyed.
; - $0328-$03FC's Y position is cleared to #$F0.
;
; Note: called before a new sprite is executed, freeing the region for it.

; 2) Flush Custom OAM range ($0200 - $03FC)
; - use the SA-1 CPU
; - call with A 8-bit, X/Y 16-bit. All registers are destroyed.
; - specify the initial range on X ($0200-$03FC)
; - specify the final range on Y ($0200-$03FC).
; - Y must be greater than X.
; - specify priority on A (#$00 - low, #$01 - normal, #$02 - high, #$03 - max)
;
; Note: This routine is slow and is only recommended to use for keeping compatibility with older structures.
; It's recommended to use MaxTile native methods for faster speed.

; 3) Clear OAM ($0200 - $03FC)
; - use the SA-1 CPU
; - call with A 8-bit, X/Y 16-bit. A is destroyed.
; - $0200-$03FC's Y position is cleared to #$F0.
;
; Note: This routine is called from $7F:8000, invoking the SA-1 CPU.

; MaxTile work memory:
; $40:B000-$40:C7FF.

; MaxTile pointer buffers (highest -> lowest)
; Each group is made of 8 bytes:
; - tile buffer pointer (16-bit): normally pointer + $01FC
; - tile prop buffer pointer (16-bit): normally pointer + $01FC
; - tile buffer initial pointer (16-bit): normally pointer + $7F
; - tile prop initial pointer (16-bit): normally pointer + $7F

; During the tile copy procedure, both tile buffer and prop pointers turn into length.

!maxtile_pointer_max		= $40B5E0		; 8 bytes
!maxtile_pointer_high		= $40B5E8		; 8 bytes
!maxtile_pointer_normal		= $40B5F0		; 8 bytes
!maxtile_pointer_low		= $40B5F8		; 8 bytes

; If no hook is defined, the following pointers are used:
; $40:B600 -> priority #1 prop buffer
; $40:B680 -> priority #2 prop buffer
; $40:B700 -> priority #3 prop buffer
; $40:B780 -> priority #4 prop buffer
; $40:B800 -> priority #1 buffer
; $40:BA00 -> priority #2 buffer
; $40:BC00 -> priority #3 buffer
; $40:BE00 -> priority #4 buffer

ORG $008494
	LDA.B #oam_compress
	STA $3180
	LDA.B #oam_compress>>8
	STA $3181
	LDA.B #oam_compress>>16
	STA $3182
	JMP $1E80

	NOP #34 ; freespace
warnpc $0084C8

; This is one of favorite hijacks that many patches
; likes editing. Because of that, I'll NOP the entire
; routine and put the MVN code at a position that is
; unlikely to get modified.

org $008027
	NOP #13		; If any routine hijack this, things won't blow up.
	; PC is now $00:8034, aligned with the looping LDA #$008D opcode (low hijack probability)
	
	PEA.w $0040
	PLB
	
	JML oam_init_tables	
	NOP
	
oam_transfer_clear_invoker:
	LDA #oam_clear_invoke_end-oam_clear_invoke-1
	LDX #oam_clear_invoke
	LDY #$8000
	MVN $7F, oam_clear_invoke>>16
	PLB
	
	; PC is now $00:804A, aligned with the original code.
warnpc $00804A

; Some routines uses the "RTL" byte as JSL->RTS support byte,
; we can't modify it for safety reasons.

; $00804C:        A9 6B         LDA #$6B                  ;|\"RTL" [6B]
; $00804E:        8F 82 81 7F   STA $7F8182               ;//


; CODE_0086DA:        22 2E 81 7F   JSL.L RAM_7F812E    

org $0086DA
	JSL oam_clear_invoke_special

pullpc

oam_init_tables:
	LDA.w #$B800+$01FC
	STA.w !maxtile_pointer_max+0
	STA.w !maxtile_pointer_max+4
	LDA.w #$BA00+$01FC
	STA.w !maxtile_pointer_high+0
	STA.w !maxtile_pointer_high+4
	LDA.w #$BC00+$01FC
	STA.w !maxtile_pointer_normal+0
	STA.w !maxtile_pointer_normal+4
	LDA.w #$BE00+$01FC
	STA.w !maxtile_pointer_low+0
	STA.w !maxtile_pointer_low+4
	
	LDA.w #$B600+$7F
	STA.w !maxtile_pointer_max+2
	STA.w !maxtile_pointer_max+6
	LDA.w #$B680+$7F
	STA.w !maxtile_pointer_high+2
	STA.w !maxtile_pointer_high+6
	LDA.w #$B700+$7F
	STA.w !maxtile_pointer_normal+2
	STA.w !maxtile_pointer_normal+6
	LDA.w #$B780+$7F
	STA.w !maxtile_pointer_low+2
	STA.w !maxtile_pointer_low+6
	
	; Clear OAM hook
	STZ.w $0110
	
	JML oam_transfer_clear_invoker

; This code is uploaded to $7F:8000.
oam_clear_invoke:
	LDA.b #oam_start_frame
	STA $3180
	LDA.b #oam_start_frame>>8
	STA $3181
	LDA.b #oam_start_frame>>16
	STA $3182
	
	LDA #$80
	STA $2200
	
-	LDA $3189
	BEQ -
	
	STZ $3189
	RTL
.end

oam_clear_invoke_special:
	LDA.b #oam_start_frame_special
	STA $3180
	LDA.b #oam_start_frame_special>>8
	STA $3181
	LDA.b #oam_start_frame_special>>16
	STA $3182
	JSR $1E80
	RTL

oam_start_frame:
	JSR oam_clear
	
.reset_tables
	PHB
	LDA #$40
	PHA
	PLB
	
	REP #$20
	LDA.w !maxtile_pointer_max+4
	STA.w !maxtile_pointer_max+0
	LDA.w !maxtile_pointer_high+4
	STA.w !maxtile_pointer_high+0
	LDA.w !maxtile_pointer_normal+4
	STA.w !maxtile_pointer_normal+0
	LDA.w !maxtile_pointer_low+4
	STA.w !maxtile_pointer_low+0

	LDA.w !maxtile_pointer_max+6
	STA.w !maxtile_pointer_max+2
	LDA.w !maxtile_pointer_high+6
	STA.w !maxtile_pointer_high+2
	LDA.w !maxtile_pointer_normal+6
	STA.w !maxtile_pointer_normal+2
	LDA.w !maxtile_pointer_low+6
	STA.w !maxtile_pointer_low+2
	SEP #$20
	
	PLB
	RTL
	
oam_start_frame_special:
	JSR oam_clear_special
	JMP oam_start_frame_reset_tables

macro oam_reset_y()
	STA.b $01+!x
	!x #= !x+4
endmacro

; Clear $6200-$63FC, as fast as possible;

oam_clear:
	PHD
	PEA.w .block-1
	PEA.w $6300
	PEA.w $6200
	PLD
	
	LDA.b #$F0
.block
	!x = 0
	rep 36 : %oam_reset_y()
.boss
	rep 28 : %oam_reset_y()
	PLD
	RTS
	
oam_clear_special:
	PHD
	PEA.w $6300
	PLD
	LDA.b #$F0
	JMP oam_clear_boss

oam_compress:
print pc

	; Flush the rest of OAM.
	LDA #$05 ; Map $40:A000-$40:BFFF to $6000-$7FFF
	STA $318F
	STA $2225
	
	PHB
	LDA #$40
	PHA
	PLB
	JSR oam_flush_southern
	JSR oam_flush_player
	JSR oam_flush_northern
    JSR oam_flush_lakitu
	PLB
	
	STZ $318F ; Map $40:0000-$40:1FFF to $6000-$7FFF
	STZ $2225
	
	; Copy MaxTile buffers to $0200-$03FC...
	JSR do_the_copy
	

	PHB
	LDA #$00
	PHA
	PLB
	
	REP #$20
	LDA $6110
	BEQ .return
	STA $00
	LDY $6112
	STY $02
	STZ $6110
	SEP #$20
	PHK
	PEA.w .return-1
	JML [$3000]
.return	
	SEP #$30
	
	LDY #$1E
-	LDX $8475,Y
	LDA $6423,X
	ASL
	ASL
	ORA $6422,X
	ASL
	ASL
	ORA $6421,X
	ASL
	ASL
	ORA $6420,X
	STA $6400,Y
	LDA $6427,X
	ASL
	ASL
	ORA $6426,X
	ASL
	ASL
	ORA $6425,X
	ASL
	ASL
	ORA $6424,X
	STA $6401,Y
	DEY
	DEY
	BPL -
	
	PLB
	RTL
	
; MaxTile pointer buffers (highest -> lowest)
; Each group is made of 8 bytes:
; - tile buffer pointer (16-bit): normally pointer + $01FC
; - tile prop buffer pointer (16-bit): normally pointer + $01FC
; - tile buffer initial pointer (16-bit): normally pointer + $7F
; - tile prop initial pointer (16-bit): normally pointer + $7F

macro copy_priority(pointer, offset)
	LDA.w $0000+<pointer>
	BMI ?abort
	LDX.w $0004+<pointer>
	INX #<offset>
	MVP $40,$40
?abort:
endmacro

macro restrict_buffer(pointer)
	LDA.w $0004+<pointer>
	SEC
	SBC.w $0000+<pointer>
	CMP $00
	BCC ?all_ok
	CLC
	LDA $00
?all_ok:
	DEC ; You can optimize by using CLC/SBC, but because the comparison is unsigned it will screw up with FFFF value.
	STA.w $0000+<pointer>
	EOR #$FFFF
	ADC $00
	STA $00
endmacro

do_the_copy:
	PHB
	LDA #$40
	PHA
	PLB
	REP #$30
	
	LDA #$0200
	STA $00
	%restrict_buffer(!maxtile_pointer_max)
	%restrict_buffer(!maxtile_pointer_high)
	%restrict_buffer(!maxtile_pointer_normal)
	%restrict_buffer(!maxtile_pointer_low)
	
	LDA #$0080
	STA $00
	%restrict_buffer(2+!maxtile_pointer_max)
	%restrict_buffer(2+!maxtile_pointer_high)
	%restrict_buffer(2+!maxtile_pointer_normal)
	%restrict_buffer(2+!maxtile_pointer_low)

	LDY #$03FF
	%copy_priority(!maxtile_pointer_low, 3)
	%copy_priority(!maxtile_pointer_normal, 3)
	%copy_priority(!maxtile_pointer_high, 3)
	%copy_priority(!maxtile_pointer_max, 3)
	
	LDY #$049F
	%copy_priority(2+!maxtile_pointer_low, 0)
	%copy_priority(2+!maxtile_pointer_normal, 0)
	%copy_priority(2+!maxtile_pointer_high, 0)
	%copy_priority(2+!maxtile_pointer_max, 0)
	
	SEP #$30
	PLB
	RTS

macro oam_check_slot(slot)
	CMP.w $0201+(<slot>*4)
	BEQ ?skip
	
	LDY.w $0200+(<slot>*4)
	STY.b $00,x
	LDY.w $0202+(<slot>*4)
	STY.b $02,x
	STA.w $0201+(<slot>*4)
	
	LDA.w $0420+<slot>
	STA.b ($00)
	
	DEC.b $00
	DEX #4
	
	LDA.b #$F0
?skip:
endmacro

macro oam_flush_buffer(priority, first, last)
	REP #$31
	LDA.w <priority>+2
	STA $00
	LDA.w <priority>
	ADC.w #-$A000+$6000
	TAX
	SEP #$20
	
	LDA #$F0

	!x = <last>
	
	while !x >= <first>
		%oam_check_slot(!x)
		!x #= !x-1
	endif
	
	REP #$21
	TXA
	ADC.w #$A000-$6000
	STA.w <priority>
	LDA $00
	STA.w <priority>+2
	SEP #$30
endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MaxTile pointer buffers (highest -> lowest)
; Each group is made of 8 bytes:
; - tile buffer pointer (16-bit)
; - tile prop buffer pointer (16-bit)
; - tile buffer initial pointer (16-bit)
; - tile prop initial pointer (16-bit)

; During the tile copy procedure, both tile buffer and prop pointers turn into length.

;!maxtile_pointer_max		= $40B000		; 8 bytes
;!maxtile_pointer_high		= $40B008		; 8 bytes
;!maxtile_pointer_normal		= $40B010		; 8 bytes
;!maxtile_pointer_low		= $40B018		; 8 bytes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

nmstl_mockup_flush:
	LDA #$05 ; Map $40:A000-$40:BFFF to $6000-$7FFF
	STA $318F
	STA $2225
	
	PHB
	LDA #$40
	PHA
	PLB
	PHX
	JSR oam_flush_northern
	PLX
	PLB
	
	STZ $318F ; Restore normal mapping
	STZ $2225
	RTL

; Priority: standard.
; Flush $0328 is 74th OAM tile (0 based).
; $03F8 and $03FC are lakitu cloud tiles.
oam_flush_northern:
	%oam_flush_buffer(!maxtile_pointer_normal, 74, 127-2)
	RTS

; Priority: maximum.
; Flush $0200-$02FC
oam_flush_southern:
	%oam_flush_buffer(!maxtile_pointer_max, 0, 63)
	RTS

; Priority: high.
; Flush $0300-$0324 (player) + $0328-$032C (yoshi)
; $0330-$0334 are likelly trashed (yoshi clone tiles).
oam_flush_player:
	%oam_flush_buffer(!maxtile_pointer_high, 63, 73+2)
	RTS
    
; Priority: low
; Flush $03F8 and $03FC
oam_flush_lakitu:
    %oam_flush_buffer(!maxtile_pointer_low, 126, 127)
    RTS

	
