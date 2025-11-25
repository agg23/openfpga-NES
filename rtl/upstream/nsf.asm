;----------------------------------
; NSF player for PowerPak
;
; Player rom is at $4100-4FFF (NSF header at $4100)
;
; PowerPak registers:
;
;  5FF0: timer latch LSB
;  5FF1: timer latch MSB
;  5FF2: timer status (Read: bit7=timer wrapped,  Write: clear status)
;  5FF3: Expansion audio control (copy header[0x7B] here)
;  5FF6-5FFF: banking registers (as described in NSF spec)
;
;  Timer details:
;      PowerPak NSF mapper has a 16bit 1MHz counter that counts down from [5FF1:5FF0] to 0.
;      After the counter reaches 0, it's automatically reloaded and timer status bit is set.
;      Clear the status bit by writing to $5FF2.
;
;-----------------------------------


A       = $80
B       = $40
SELECT  = $20
START   = $10
UP      = $08
DOWN    = $04
LEFT    = $02
RIGHT   = $01

HDR_BASE        = $4100
HDR_SONGS       = HDR_BASE+$06
HDR_FIRST       = HDR_BASE+$07
HDR_LOAD        = HDR_BASE+$08
HDR_INIT        = HDR_BASE+$0a
HDR_PLAY        = HDR_BASE+$0c
HDR_TITLE       = HDR_BASE+$0e
HDR_ARTIST      = HDR_BASE+$2e
HDR_COPYRIGHT   = HDR_BASE+$4e
HDR_NTSC_LO     = HDR_BASE+$6E
HDR_NTSC_HI     = HDR_BASE+$6F
HDR_BANK        = HDR_BASE+$70
HDR_PAL_LO      = HDR_BASE+$78
HDR_PAL_HI      = HDR_BASE+$79
HDR_EXP_HW      = HDR_BASE+$7b

STACK_TOP       = $1f4
        CURRENT = $1f4      ;song#
        PLAYING = $1f5      ;nonzero=song is playing
        JOYPAD  = $1f6      ;button state
        JOYD    = $1f7      ;button 0->1
        JOYTMP  = $1f8
        FRAME   = $1f9
        PAL     = $1fa      ;1=PAL detected
        DIVTMP  = $1fb
        STR     = $1fc      ;4 bytes used for printing current song #

; header ------

        db $4E,$45,$53,$1A
        db $01          ;PRG size/16k
        db $00          ;CHR size/8k
        db $00,$00      ;flags,mapper
        db $00,$00,$00,$00,$00,$00,$00,$00

        .org $4000
        .pad HDR_BASE+$80

reset ;-------

        sei
        ldx #<(STACK_TOP-1)
        txs
        stx PLAYING

        lda #$00
        sta $2000               ;nmi off
        sta $2001               ;screen off
        jsr pal_detect

;        ldx #8                  ;load CHR: 128 tiles = $800 bytes
;        ldy #$00
;        sty $2006
;        sty $2006
;        lda #<chr
;        sta 0
;        lda #>chr
;        sta 1
;-       lda (0),y
;        sta $2007
;        iny
;        bne -
;        inc 1
;        dex
;        bpl -
        ldx #3                  ;load CHR: 128 tiles = $800 bytes
        lda #$80
        sta 2
        lda #$c0
        sta 3
        ldy #$00
        sty $2006
        sty $2006
        lda #<chr
        sta 0
----    lda #>chr
        sta 1
-       lda #8
        sta 4        
--      lda (0),y
        beq ++
        cpx #0    ; requires pattern to be 0,other (0x3c),0xff, matches 0,mem2,mem3 for 0x100/2
        bpl ++
        cmp #$ff
        beq +++
        lda 2
        bne ++
+++     lda 3
++      sta $2007
        iny
        dec 4
        bne --
        lda #8   ; requires compressed format that removes every second 8 bytes which were 0s
        sta 4
        lda #0
---     sta $2007
        dec 4
        bne ---
        cpy #0
        bne -
        inc 1
        dex
        bpl -
        ldy #$80 ; requires pattern to be at chr+0x080
        cpx #$ff
        beq ----
        lda 2
        rol
        ror 3
        lsr 2
        bne ----

        lda #$3f                ;set palette
        sta $2006
        lda #$00
        sta $2006
        ldx #8
-       lda #$0f
        sta $2007
        lda #$30
        sta $2007
        sta $2007
        sta $2007
        dex
        bne -

        lda #$20                ;clear screens
        sta $2006
        lda #$00
        sta $2006
        tax
        ldy #4 ;$10
        lda #$20                ;" "
-       sta $2007
        inx
        bne -
        dey
        bne -

        lda #$20
        sta $2006
        lda #$70
        sta $2006
        lda #$2f               ;"/"
        sta $2007
        lda HDR_SONGS
        jsr deci                
-       lda STR,y               ;print #songs
        sta $2007
        dey
        bpl -

        lda #$20                ;print song infos
        sta $2006
        lda #$42
        sta $2006
        ldy #0
-       lda HDR_TITLE,y
        beq +
        sta $2007
        iny
        cpy #30
        bne -
+
        lda #$20
        sta $2006
        lda #$22
        sta $2006
        ldy #0
-       lda HDR_ARTIST,y
        beq +
        sta $2007
        iny
        cpy #30
        bne -
+
        lda #$20
        sta $2006
        lda #$02
        sta $2006
        ldy #0
-       lda HDR_COPYRIGHT,y
        beq +
        sta $2007
        iny
        cpy #30
        bne -
+
        lda HDR_EXP_HW          ;enable extra audio HW (also PRG write enable for FDS)
        sta $5ff3

        ora #$40			    ;- kevtris - swap VRC6 registers which is how all NSFs use VRC6
        ldx #$55
        stx $3ff2
        ldx #$aa
        stx $3fea			    ;- these two writes enable the chip select mode in the HDNES hardware
        sta $3ffa			    ;- automatic enable setting for HDNES

        jsr timer_init

        lda HDR_FIRST           ;init first song
        sta CURRENT
        jsr init

        lda #%00001010          ;screen on, sprites off
        sta $2001

busywait
        lda $5ff2
        bpl busywait
        sta $5ff2

        inc FRAME
        jsr joyread
        jsr play
        jmp copyapustatus       ;busywait

pal_detect ;-----------------
        lda $2002
-       lda $2002
        bpl -

        ldy #24                 ;eat about 30000 cycles (1 NTSC frame)
        ldx #100
-       dex
        bne -
        dey
        bne -

        lda $2002               ;VBL flag is set if NTSC
        bmi +
        inx
+       stx PAL
        rts

init ;------------------        ;begin CURRENT song
        jsr stopsound

        jsr bank_init

        lda HDR_EXP_HW          ;clear 6000-7fff unless FDS is enabled
        and #4
        bne no_wram_clear
        lda #$60
        sta 1
        lda #0
        sta 0
        tay
-       sta (0),y
        iny
        bne -
        inc 1
        bpl -
   no_wram_clear

        lda #0                  ;clear 0000-07ff
        tax
-       sta $00,x
        sta $200,x              ;(not 100-1ff)
        sta $300,x
        sta $400,x
        sta $500,x
        sta $600,x
        sta $700,x
        inx
        bne -

        lda CURRENT             ;print song#
        jsr deci
        lda #$20        ;<---
-       iny
        sta STR,y
        cpy #3
        bne -
        lda $2002
-       lda $2002
        bpl -
        lda #$20
        sta $2006
        lda #$6d
        sta $2006
        lda STR+2
        sta $2007
        lda STR+1
        sta $2007
        lda STR
        sta $2007

        lda #$00                ;reset scroll
        sta $2006
        sta $2006

        lda PLAYING
        bne +
        rts
+
        ldx CURRENT             ;call INIT w/ A=song#, X=pal
        dex
        txa
        ldx PAL
        jmp (HDR_INIT)

bank_init ;---------------
        lda #0
        ldx #7
-       ora HDR_BANK,x
        dex
        bpl -
        tax
        bne banked_nsf
  not_banked:
        lda HDR_LOAD+1
        lsr
        lsr
        lsr
        lsr
        tax
        ldy #0
-       tya
        sta $5ff0,x
        iny
        inx
        cpx #$10
        bne -
        dey
        sty $5ff7
        dey
        sty $5ff6
        rts
  banked_nsf:
        ldx #7
-       lda HDR_BANK,x
        sta $5ff8,x
        dex
        bpl -
        lda HDR_BANK+6          ;FDS also has banks @ 6000-7FFF
        sta $5ff6
        lda HDR_BANK+7
        sta $5ff7
        rts
timer_init ;-------------
        lda HDR_NTSC_LO
        ldy HDR_NTSC_HI
        ldx PAL
        beq +
        lda HDR_PAL_LO
        ldy HDR_PAL_HI
+
        cpy #0
        beq fixit
+       cmp #$41
        bne time_ok
        cpy #$1a
        bne time_ok
  fixit
        lda time_lo,x
        ldy time_hi,x
  time_ok
        sta $5ff0
        sty $5ff1
        rts

  time_hi db $41, $4e
  time_lo db $1a, $20

stopsound ;---------------
        lda #$00                ;reset sound regs
        sta $4015
        sta $4008
        lda #$10
        sta $4000
        sta $4004
        sta $400c
        lda #$0f
        sta $4015
        lda #$40
        sta $4017

        lda #$c0                ;FDS reset
        sta $4083
        sta $4080
        sta $4084
        sta $4087
        sta $4089
        lda #$e8
        sta $408a

	    ;-----------------------kevtris start

        lda HDR_EXP_HW
        and #$01
        beq szz0

        lda #$00	;shut up VRC6
        sta $9000
        sta $a000
        sta $b000

szz0
        lda HDR_EXP_HW
        and #$02
        beq szz1
        
        lda #$00	;shut up VRC7
        ldx #$35
sswt    ldy #$10
        stx $9010
        nop
        nop
        nop
        nop
        sta $9030
sswx    dey
        bne sswx
        dex
        bne sswt
        
szz1
        lda HDR_EXP_HW
        and #$08
        beq ssz2
        
        sta $5015	;shut up MMC5

ssz2
        lda HDR_EXP_HW
        and #$10
        beq ssz3
        
        ldx #$80	;shut up N163
        stx $f800	;start from address 0, auto increment
sswq    sta $4800
        dex
        bpl sswq	;clear all RAM
        
ssz3
        lda HDR_EXP_HW
        and #$20
        beq ssz4
        
        ldx #$0f	;shut up 5B
sswz    stx $c000
        sta $e000
        dex
        bpl sswz

ssz4
	    ;-------------------kevtris end

        rts
play ;--------------------
        lda PLAYING
        beq +
        lda #DOWN
        bit JOYPAD
        beq ++
        lda FRAME
        lsr
        bcc +
++      lda #UP
        bit JOYPAD
        beq playhere
        jsr playhere
        jsr playhere
  playhere
        jmp (HDR_PLAY)
+       rts

joyread ;----------------
        lda JOYPAD
        pha
        jsr joyread2
retry   lda JOYPAD
        sta JOYTMP
        jsr joyread2
        lda JOYPAD
        eor JOYTMP
        bne retry

        pla
        eor JOYPAD
        and JOYPAD
        sta JOYD

        asl             ;A
        bcc +
_A          ldx CURRENT
            cpx HDR_SONGS
            bcc ++
            ldx #$00
++          inx
            stx CURRENT
            jmp init
+
        asl             ;B
        bcc +
_B          dec CURRENT
            bne ++
            lda HDR_SONGS
            sta CURRENT
++          jmp init
+
        asl             ;SEL
        bcc +
            ;lda #$00
            ;sta PLAYING
            ;jmp stopsound
            jmp powerpak_bios_reset
+
        asl             ;START
        bcc +
            lda #$01
            sta PLAYING
            jmp init
+
        asl             ;UP
        asl             ;DOWN
        asl             ;LEFT
        bcs _B          
 
        asl             ;RIGHT
        bcs _A
        rts
joyread2 ;----------------
        jmp joyreadpiano
;		nop
;		nop
;        ldx #1
;        stx $4016
;        dex
;        stx $4016
;        ldx #$08
;-       clc
;        lda $4017               ;kevtris - added to read controller 2 so the HDNES menu is still accessable
;        lda $4016
;        ora #$fc
;        adc #3
;        rol JOYPAD
;        dex
;        bne -
;        rts
div10 ;------------------
        ldx #0                  ;in: A=#
        stx DIVTMP                ;out: X=#/10, A=remainder
        cmp #%10100000
        bcc +
        sbc #%10100000
+       rol DIVTMP
        cmp #%01010000
        bcc +
        sbc #%01010000
+       rol DIVTMP
        cmp #%00101000
        bcc +
        sbc #%00101000
+       rol DIVTMP
        cmp #%00010100
        bcc +
        sbc #%00010100
+       rol DIVTMP
        cmp #%00001010
        bcc +
        sbc #%00001010
+       rol DIVTMP
        ldx DIVTMP
        rts
deci ;-------------------       ;in: A=#
        ldy #$ff                ;out: A,X=?  Y=strlen-1
-       jsr div10
        iny
        sta STR,y
        txa
        bne -
        rts

powerpak_bios_reset ;---------
        lda #$00                ;screen off
        sta $2000
        sta $2001
        jsr stopsound
        ldx #(resetcode_end - resetcode - 1)
-       lda resetcode,x
        sta $0,x
        dex
        bpl -
        jmp 0

    resetcode
        lda #1
        sta $4207
        jmp ($fffc)
    resetcode_end

;------------------------
chr     .bin "font_cmp.bin"         ;ascii chr set compressed

notesLow
		db $F1,$7F,$13,$AD,$4D,$F3,$9D,$4C,$00,$B8,$74,$34
		db $F8,$BF,$89,$56,$26,$F9,$CE,$A6,$80,$5C,$3A,$1A
		db $FB,$DF,$C4,$AB,$93,$7C,$67,$52,$3F,$2D,$1C,$0C
		db $FD,$EF,$E1,$D5,$C9,$BD,$B3,$A9,$9F,$96,$8E,$86
		db $7E,$77,$70,$6A,$64,$5E,$59,$54,$4F,$4B,$46,$42
		db $3F,$3B,$38,$34,$31,$2F,$2C,$29,$27,$25,$23,$21
		db $1F,$1D,$1B,$1A,$18,$17,$15,$14,$00,$00,$00,$00
notesHigh
		db $07,$07,$07,$06,$06,$05,$05,$05,$05,$04,$04,$04
		db $03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02
		db $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
		; can cut off here and do a compare (>= use $00) instead to save space
		db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
 
MIDI_BUFF    = $4030 ; 4030-403f
MIDI_READ    = $402f
MIDI_START   = $402e
MIDI_NEXT    = $402d
MIDI_RECENT  = $402c
APU_STATUSC  = $402b ; Copy of last write to $4015
MMC5_STATUSC = $402a ; Copy of last write to $5015
LOOKUP_HI_R  = $4029 ; Read - Based on 402a - change?
LOOKUP_LOW_R = $4028 ; Read - Based on 402a - change?
MIDI_PATCH   = $4027
MIDI_NOTE2   = $4026 ; keep in order 2,1 separate by 4
MIDI_NOTE3   = $4025
AVAILABLE    = $4024
FDS_ENABLE   = $4023 ; Don't use this
MIDI_NOTE1   = $4022
MIDI_TMP2    = $4021
MIDI_TMP     = $4020
 
joyreadpiano		
        ldx #1
		stx $4016
		dex
		nop
		nop
		nop
		stx $4016
		stx MIDI_READ
		stx MIDI_READ
		lda $4016
		ror a
		bcs readmidi
		jmp joy2read
readmidi
		;nop ; /needed on real hw?
		;nop ; /needed on real hw?
		ldx #8
readmidibit
		lda $4016
		ror a
		rol MIDI_READ
		dex
		bne readmidibit
		lda MIDI_READ
		eor #$ff
		sta MIDI_READ

		ldx MIDI_NEXT
		sta MIDI_BUFF,x
		inx
		txa             ; these txa, and #0F, tax could be replaced with simple stx MIDI_NEXT (ie inc MIDI_NEXT) if buffer was 256 bytes
		and #$0F
		tax
		sta MIDI_NEXT

		ldx MIDI_START
		lda MIDI_BUFF,x
		cmp #$ff
		bne checkF
		jmp doReset
checkF
		and #$f0
		cmp #$f0
		bne checkC
testNext
		inx
		txa
		and #$0F
		tax
		cpx MIDI_NEXT
		bne contF
		jmp doneTest
contF
		lda MIDI_BUFF,x
		and #$80
		bne testNext
		jmp doNext
checkC
		cmp #$c0
		bne check8B
		inx
		txa
		and #$0F
		tax
		cpx MIDI_NEXT
		bne doPatch
		jmp doneTest
doPatch
		lda MIDI_BUFF,x
		sta MIDI_PATCH
		jmp doNext
check8B
		inx
		inx
		inx
		txa
		and #$0F
		tax
		cpx MIDI_NEXT
		beq noteComplete
		jmp doneTest
noteComplete
		ldx MIDI_START
		lda MIDI_BUFF,x
		and #$e0
		cmp #$80
		beq doNote
		jmp doNext
doNote
		ldx MIDI_START
		inx
		txa
		and #$0F
		tax
		lda MIDI_BUFF,x
		sta MIDI_TMP   ; note
		tay
		inx
		txa
		and #$0F
		tax
		lda MIDI_BUFF,x
		sta MIDI_TMP2  ; vol
		tya
		cmp #$71
		bmi noteOkLow
		jmp doNext
noteOkLow
		cmp #$21
		bpl noteOkHigh
		jmp doNext
noteOkHigh
		lda MIDI_PATCH
		cmp #$40
		bcs jNoteTri
		and #$04
		bne noTri
		tya
		cmp #$39       ; split at A3
		bpl noTri
jNoteTri
		jmp noteTri
noTri
		tya
		cmp MIDI_NOTE1
		bne testPulse2
		lda #$00
		jmp doPulse
testPulse2
		cmp MIDI_NOTE2
		bne useRecent
		lda #$04
		jmp doPulse
useRecent
		lda MIDI_TMP2 ; /vol
		bne swapRecent
		jmp doNext
swapRecent
		lda MIDI_RECENT
		eor #04
doPulse
		tax
		tya
		sta MIDI_NOTE1,x
		sec
		sbc #$21
		tay
		lda MIDI_PATCH
		and #$08
		bne noteM5
		lda notesLow,y
		sta $4002,x
		lda notesHigh,y
		ora #$08
		sta $4003,x
		jmp getVol
noteM5
		lda notesLow,y
		sta $5002,x
		lda notesHigh,y
		ora #$08
		sta $5003,x
getVol
		lda MIDI_TMP2 ; /vol
		cmp #$78
		bpl setPulsVol
		clc
		adc #$07
setPulsVol
		ror
		ror
		ror
		and #$0f
		tay
		ora #$30
		sta MIDI_TMP
		lda MIDI_PATCH
		ror
		ror
		ror
		and #$c0
		ora MIDI_TMP
		sta MIDI_TMP
		lda MIDI_PATCH
		and #$08
		bne volM5
		lda MIDI_TMP
		sta $4000,x
		lda #$00
		sta $4001,x
		lda APU_STATUSC
		ora #$03
		sta $4015
		jmp upRecent
volM5
		lda MIDI_TMP
		sta $5000,x
		lda #$00
		sta $5001,x
		lda MMC5_STATUSC
		ora #$03
		sta $5015
upRecent
		tya
		bne setRecent
		txa
		eor #$04
		tax
setRecent
		stx MIDI_RECENT
		jmp doNext
noteTri
		tya
		cmp MIDI_NOTE3
		beq doTri
		lda MIDI_TMP2
		beq doNext
		tya
doTri
		sta MIDI_NOTE3
		ldy #$3F
		cpy MIDI_PATCH
		bcc normOct
		;sec ; Must be set already if here
		sbc #$09 ; (Up one octave)
		jmp setTri
normOct
		sec
		sbc #$15 ; correct
setTri
		tay
		lda notesLow,y
		sta $400a
		lda notesHigh,y
		ora #$f8
		sta $400b
		lda MIDI_TMP2
		beq triOff
		lda #$ff
		bne triSet
triOff
		lda #$80
triSet
		sta $4008
		lda APU_STATUSC
		ora #$04
		sta $4015
doNext
		lda MIDI_NEXT
		sta MIDI_START
doneTest
doReset

joy2read		
        ldx #$08
-       clc
        lda $4017
        ora #$fc
        adc #3
        rol JOYPAD
        dex
        bne -
        rts
		
        .pad $4fed
copyapustatus		
        lda $4015
		sta APU_STATUSC
        lda $5015
		sta MMC5_STATUSC
		jmp busywait

        .pad $4ffc              ;powerpak bios jumps to (4FFC)
        .dw reset               ;vectors are NOT mapped to $Fxxx, IRQ/NMI must be disabled.

        .align $4000
