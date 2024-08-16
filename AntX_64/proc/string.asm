;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Strings
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  INT To String  * * *
;------------------------------------------------
proc IntToStr

;   mov RDI, pBuffer
;   mov RCX, Value

jmpSet@IntToStr:
	xor RBX, RBX
	mov R8b, '0'
	mov BL,  10
	mov RAX, RCX

jmpScan@IntToStr:
	inc RDI
	xor RDX, RDX
	div RBX
	or  RAX, RAX
	jnz jmpScan@IntToStr

	mov RSI, RDI
	mov RAX, RCX

jmpDiv@IntToStr:
	dec RDI
	xor RDX, RDX
	div RBX

	add DL, R8b
	mov [RDI], DL

	or  RAX, RAX
	jnz jmpDiv@IntToStr

	mov RDI, RSI 
	xor RCX, RCX
	ret
endp
;------------------------------------------------
;       * * *  HEX To String  * * *
;------------------------------------------------
proc HexToStr

;   mov RDI,  pBuffer
;   mov RDX,  Value
	mov RSI,  sHexScaleChar
	xor RCX,  RCX
	mov RBX,  RCX
	mov CL,   16
	mov R8b,  0Fh

jmpScan@HexToStr:
	rol RDX, 4
	mov BL,  DL
	and BL,  R8b
	mov AL, [RSI+RBX]
	stosb
	loop jmpScan@HexToStr
	ret
endp
;------------------------------------------------
;       * * *  String To DWORD  * * *
;------------------------------------------------
proc StrToWord

;   mov RSI, pBuffer
	xor RDX, RDX
	mov R8b, '0'
	mov R9b, '9'

	or RSI, RSI
	jz jmpEnd@StrToWord

	mov RCX, RDX
	mov RBX, RDX
	mov BL,  10

jmpScan@StrToWord:
	lodsb
	cmp AL, R8b
	jb jmpEnd@StrToWord

	cmp AL, R9b
	ja jmpEnd@StrToWord

	sub AL, R8b
	mov CL, AL

	mov RAX, RDX
	mul RBX 
	add RAX, RCX
	mov RDX, RAX
	jmp jmpScan@StrToWord

jmpEnd@StrToWord:
	mov RAX, RDX
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------
