INCLUDE "hardware.inc"

/*
	Sprites- $FE00-$FE9F
	Sprite 1: right channel, bottom/left on screen, $FE00-$FE03
	Sprite 2: left channel, top/right on screen, $FE04-$FE07
	Sprite Y: LY+16
	Each channel is 64 pixels tall -> 128 total pixels -> 11 pixels from screen, 
	10 pixels from each other, added to 8 
	(right: x=18 to x=81, middle: x=82 to x=91, left: x=92 to x=155)
	right middle: x=50, left middle: x=124

	Enable OAM interrupts (rSTAT = %xx1xxxxx), wait manually for hblank
*/

left_sample equ $80
left_pulse equ $81
left_mv equ $82
right_sample equ $83
right_pulse equ $84
right_mv equ $85
spr_y equ $86
amp_lut equ $06
sprite_lut equ $09

SECTION "STAT interrupt", ROM0[$48]
	jp playSample

SECTION "Sample playback", ROM0[$300]
playSample:
	xor a
	ld d, $2f
	ld e, a
	sla h
	adc c
	ld c, a
	ld [de], a
	ld a, e
	adc b
	inc d
	ld [de], a
	set 7, h
	srl h
	;bank change with no conditional jumps
	;inefficient though
	
	jr z, displaySample
	ld h, $2f
	inc bc
	ld [hl], c
	inc h
	ld [hl], b
	ld h, $40
	jr loadSample
displaySample:
	ldh a, [rLY]
	add 17
	push hl
	ldh [spr_y], a
	ld hl, $FE00
	ld [hli], a
	ld d, sprite_lut
	ld a, [left_sample]
	ld e, a
	ld a, [de]
	ld [hl], a
	ld l, $05
	inc d
	ld a, [right_sample]
	ld [hld], a
	ldh a, [spr_y]
	ld [hl], a
	pop hl
    ; the amplitude lookup table is 512 bytes,
    ; 2 bytes per amplitude, one for each parameter
loadSample:
    ld d, amp_lut
    ld a, [hli]
    ldh [left_sample], a
	ld e, a
	ld a, [de]
	ldh [rNR12], a
	inc d
	ld a, [de]
	and $f0
	ldh [left_mv], a
	dec d
    ld a, [hli]
    ldh [right_sample], a
	ld e, a
	ld a, [de]
	ldh [rNR22], a
	inc d
	ld a, [de]
	and $0f
	ld d, a
	ldh a, [left_mv]
	or d
	ld d, a
	ld a, $80
	ldh [rNR50], a
	ldh [rNR24], a
	ldh [rNR14], a
	ld a, d
	ldh [rNR50], a
sampleEnd:
	reti
waitLine:
	jr waitLine

SECTION "Header", ROM0[$100]

EntryPoint:
	di
	jp Start

REPT $150 - $104
	db 0
ENDR

SECTION "Game code", ROM0[$150]

Start:
	di	
	ld a, $01
	ldh [rKEY1], a
	stop
	nop
	xor a
	ldh [rNR52], a
	cpl
	ldh [rNR52], a

waitVblank:
	ldh a, [rLY]
	cp 145
	jr nz, waitVblank

	xor a
	ldh [rLCDC], a
	ld a, $08
	ldh [rSTAT], a

	ld a, 1
	ld [$FE02], a
	ld a, 2
	ld [$FE06], a

	ld a, $FF
	ldh [rBGP], a
	xor a
	ldh [rOBP0], a
	ldh [rOBP1], a

	ld a, $80
	ld hl, $8010
	ld [hli], a
	ld [hli], a
	xor a
	ld c, 14
zeroTile1:
	ld [hli], a
	dec c
	jr nz, zeroTile1
	ld a, $80
	ld [hli], a
	ld [hli], a
	xor a
	ld c, 14
zeroTile2:
	ld [hli], a
	jr nz, zeroTile2

	ld hl, $8000
	xor a
	ld c, 16
zeroTile:
	ld [hli], a
	dec c
	jr nz, zeroTile

	ld hl, $9800
	ld bc, $0400
mapBG:
	ld [hli], a
	dec bc
	ld a, c
	and a
	jr nz, mapBG
	ld a, b
	and a
	jr nz, mapBG

	ld a, %10010011
	ldh [rLCDC], a

	ld hl, $4000
	ld bc, $0001
	ld sp, $cfff

	ld a, $e0
	ldh [rNR13], a
	ldh [rNR23], a

	ld a, $c0
	ldh [rNR11], a
	ldh [rNR21], a

	ld a, $0f
	ldh [rNR12], a
	ldh [rNR22], a

	ld a, $87
	ldh [rDIV], a
	ldh [rNR14], a

stallPulse1:
	ldh a, [rDIV]
	cp 9
	jr nz, stallPulse1

	xor a
	ldh [rNR13], a

	ld a, $80
	ldh [rNR14], a

	ld a, $87
	ldh [rDIV], a
	ldh [rNR24], a

stallPulse2:
	ldh a, [rDIV]
	cp 9
	jr nz, stallPulse2

	xor a
	ldh [rNR23], a

	ld a, $80
	ldh [rNR24], a
	ldh [rNR14], a

	ld a, $12
	ldh [rNR51], a
	ld a, $77
	ldh [rNR50], a
	ld a, %00000010
	ldh [rIE], a
	ei
	jp waitLine

SECTION "Amplitude LUT", ROM0[$600]
	INCBIN "amp_lut.bin"

SECTION "Sprite LUT", ROM0[$900]
	INCBIN "sprite_lut.bin"