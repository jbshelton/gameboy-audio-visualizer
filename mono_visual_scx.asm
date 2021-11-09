INCLUDE "hardware.inc"

amp_lut equ $03
lyc_lut equ $05

SECTION "STAT interrupt", ROM0[$48]
playSample:
	push bc
	ld d, amp_lut
	ld b, $0f
	ld a, [hli]
	ld e, a
	ld a, [de]
	ldh [rSCX], a
	ld a, e
	or b
	ldh [rNR12], a
	ld a, e
	and b
	ld e, a
	swap e
	or e
	ld e, a
	
	ld a, $80
	ldh [rNR50], a
	ldh [rNR14], a
	ld a, e
	ldh [rNR50], a
	pop bc
	;loading takes 18 m cycles

	bit 7, h
	jr z, nopLY
	ld h, $2f
	inc bc
	ld [hl], c
	inc h
	ld [hl], b
	ld h, $40
	jr prepLY
nopLY:
REPT 13
	nop
ENDR
	;bank change takes 18 m cycles
prepLY:
	ld d, lyc_lut
	ldh a, [rLYC]
	ld e, a
	ld a, [de]
	ldh [rLYC], a
	;LYC takes 11 m cycles
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
	ldh [rLYC], a
	ld a, $40
	ldh [rSTAT], a
	ldh [rSCY], a
	ld a, 8
	ldh [rSCX], a

	ld a, $FC
	ldh [rBGP], a
	; BG map: 2nd and 12th columns of tiles is $7F repeating,
	; otherwise tiles are $FF
	ld c, 16
	ld a, $7F
	ld de, $8010
loadVizTile:
	ld [de], a
	inc e
	dec c
	jr nz, loadVizTile
	xor a
	cpl
	ld c, 16
	ld e, $00
zeroTile0:
	ld [de], a
	inc e
	dec c
	jr nz, zeroTile0

	ld hl, BGMap
	ld de, $9800
	ld bc, BGMapEnd-BGMap
copyBG:
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, copyBG
	dec b
	jr nz, copyBG

	ld a, %10010001
	ldh [rLCDC], a

	ld hl, $4000
	ld bc, $0001
	ld de, $0000
	ld sp, $cfff

	ld a, $e0
	ldh [rNR13], a

	ld a, $c0
	ldh [rNR11], a

	ld a, $0f
	ldh [rNR12], a

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

	ld a, $11
	ldh [rNR51], a
	ld a, $77
	ldh [rNR50], a
	ld a, %00000010
	ldh [rIE], a
	ei
	jp waitLine

SECTION "Amplitude LUT", ROM0[$300]
	INCBIN "scx_lut_mono.bin"

SECTION "LYC LUT", ROM0[$500]
	INCBIN "lyc_lut.bin"

SECTION "BG data", ROM0[$900]
BGMap:
REPT 32
	db $01
	REPT 31
		db $00
	ENDR
ENDR
BGMapEnd: