;------------------------------------------------
;	AntX Web Server
;	SYSTEM: HTTP Request
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc HTTPRequest  ;  lpSocketIoData

;   R9  = Connection
;   R10 = Length 
;   R11 = CountBytes
;   R12 = Url
;   R13 = Method
;   R15 = lpSocketIoData
;   R14 = CountBytes
;   RCX = CountBytes - MethodSize
;------------------------------------------------
	xor R9,  R9
	mov R10, R9
	mov RDI, R9
	inc R9d

	mov RDX, RSI
	mov R11, RCX
	mov R12, RDX
	jmp jmpFindFirst@Request
;------------------------------------------------
;       * * *  Set Connection
;------------------------------------------------
jmpGetConnect@Request:
	xor R9d, R9d
	jmp jmpFindEnd@Request
;------------------------------------------------
;       * * *  Set Length
;------------------------------------------------
jmpGetLength@Request:
	mov R10, RDI
	jmp jmpFindEnd@Request
;------------------------------------------------
;       * * *  Scan Header
;------------------------------------------------
jmpScanHeader@Request:
	mov RBX, RCX
	mov RDX, RDI
	mov EAX,[RDI]
	cmp AX, CHR_CRLF
	je jmpEndHeader@Request
;------------------------------------------------
;       * * *  Get Ask Length
;------------------------------------------------
	xor RCX, RCX
	mov RSI, RCX
	mov  CL, szHeaderConnection - szHeaderLength - 2
	mov ESI, szHeaderLength + 2
	repe cmpsb
	je jmpGetLength@Request
;------------------------------------------------
;       * * *  Get Ask Connection
;------------------------------------------------
	mov  CL, szKeepAlive - szHeaderConnection - 2
	mov ESI, szHeaderConnection + 2
	mov RDI, RDX
	repe cmpsb
	je jmpGetConnect@Request
;------------------------------------------------
;       * * *  Find End Header
;------------------------------------------------
jmpFindEnd@Request:
	mov RCX, RBX

jmpFindFirst@Request:
	mov RDI, RDX
	mov  AL, CHR_LF
	repne scasb
	je jmpScanHeader@Request

		mov DL, SRV_ERR_Header
		mov BL, HTTP_400_BAD_REQUEST
		ret
;------------------------------------------------
;       * * *  Get Ask End
;------------------------------------------------
jmpEndHeader@Request:
	mov [R15+PORT_IO_DATA.Connection], R9w
	sub R11, RCX

	or R10, R10
	jz jmpGetUrlPath@Request

		mov RSI, R10
	    sub R14, RCX
		call StrToWord

		inc RAX
		inc RAX
		add RAX, R14
		mov [R15+PORT_IO_DATA.TotalBytes], RAX
;------------------------------------------------
;       * * *  Uniform Resource Locator
;------------------------------------------------
;   R10 = UrlPath
;   R12 = Ask
;   R13 = Method
;   R14 = NetHost
;   R15 = lpSocketIoData
;------------------------------------------------
jmpGetUrlPath@Request:
	xor RAX, RAX
	mov RSI, RAX
	mov R14, [R15+PORT_IO_DATA.NetHost]
	mov ESI, [R14+NET_HOST.SiteFolder]
	lodsb

	lea RDI, [R15+PORT_IO_DATA.UrlSize]
	mov R10, RDI
	stosw

	mov RCX, RAX
	rep movsb
;------------------------------------------------
;       * * *  Set URL FileName
;------------------------------------------------
	mov RSI, R12
	mov RCX, R11

	mov R11, RDI
	mov R12, RDI

jmpScanUrl@Request:
	lodsb
	mov DL, ' '
	cmp AL, DL
	jbe jmpGetUrlSize@Request

		cmp AL, '?'
		je jmpGetUrlSize@Request

		cmp AL, '/'
		je jmpGetFolder@Request

		cmp AL, '.'
		je jmpGetExt@Request

		cmp AL, '%'
		je jmpGetHex@Request

		cmp AL, '+'
		jne jmpSetChar@Request
			mov AL, DL
;------------------------------------------------
;       * * *  Set CharChange
;------------------------------------------------
jmpSetChar@Request:
		stosb
		loop jmpScanUrl@Request

		mov DL, SRV_ERR_Url
		mov BL, HTTP_400_BAD_REQUEST
		ret
;------------------------------------------------
;       * * *  Set HexChar
;------------------------------------------------
jmpGetHex@Request:
		lodsb
		cmp AL, '0'
		jb jmpSetChar@Request

		cmp AL, 'A'
		ja jmpSetChar@Request

		cmp AL, '9'
		jbe jmpSetHex1@Request
			sub AL, 'A' - '0' - 10

jmpSetHex1@Request:
		sub AL, '0'
		mov DL, AL

		dec ECX
		lodsb

		cmp AL, '0'
		jb jmpSetChar@Request

		cmp AL, 'A'
		ja jmpSetChar@Request

		cmp AL, '9'
		jbe jmpSetHex2@Request
			sub AL, 'A' - '0' + 10

jmpSetHex2@Request:
		sub AL, '0'
		shr AL, 4
		or  AL, DL
		jmp jmpSetChar@Request
;------------------------------------------------
;       * * *  Set Path
;------------------------------------------------
jmpGetFolder@Request:
		mov AL, '\'

jmpGetExt@Request:
		mov R12, RDI
		jmp jmpSetChar@Request
;------------------------------------------------
;       * * *  DefPage
;------------------------------------------------
jmpGetUrlSize@Request:
	mov RSI, RDI
	dec RSI
	lodsb
	cmp AL, '\'
	jne jmpSetUrlSize@Request

		xor RAX, RAX
		mov RSI, RAX
		mov ESI, [R14+NET_HOST.IndexPage]
		lodsb
		add ECX, EAX
		jmp jmpScanUrl@Request
;------------------------------------------------
;       * * *  Get URL Size
;------------------------------------------------
jmpSetUrlSize@Request:
	xor RAX, RAX
	mov [RDI], AL

	mov RAX, RDI
	sub RAX, R10
	sub  AX, 2
	mov [R10], AX

;	mov DL, SRV_ERR_PathSize
	cmp AX, MAX_PATH_SIZE
	ja jmpSyntaxError@Request
;------------------------------------------------
;       * * *  Find Access
;------------------------------------------------
	mov RSI, R11
	mov RCX, RAX
	mov EAX, '\..\'

jmpScanAccess@Request:
	cmp EAX, [RSI]
	je jmpAccessDenied@Request

	inc RSI
	loop jmpScanAccess@Request
;------------------------------------------------
;       * * *  Get RunProc
;------------------------------------------------
;   R8  = ASK_EXT_SIZE
;   R9  = Len
;   R11 = Url
;   R12 = Ask
;   R13 = Method
;   R15 = lpSocketIoData
;   RDX = ExtSize

	mov R9,  RDI
	sub R9,  R12

	mov RDI, szFileName
	mov RSI, R12
	mov R12, RDI
	mov RCX, R9
	mov  BL, SET_CASE_DOWN

jmpScanExt@Request:
	lodsb
	cmp AL, 'A'
	jb jmpNextExt@Request

	cmp AL, 'Z'
	ja jmpNextExt@Request
		or AL, BL
jmpNextExt@Request:
	stosb
	loop jmpScanExt@Request
;------------------------------------------------
;       * * *  Find TableExt
;------------------------------------------------
	mov RBX, DefRunProcess
	mov [R15+PORT_IO_DATA.ExtRunProc], RBX
	mov RSI, RCX
	mov R8,  RCX
	mov R8b, ASK_EXT_SIZE

jmpFindExt@Request:
	add RBX, R8
	mov ESI,[RBX]
	or  ESI, ESI
	jz jmpExtEnd@Request

		xor RAX, RAX
		lodsb
		mov ECX, R9d
		cmp EAX, ECX 
		jne jmpFindExt@Request

			mov RDI, R12
			repe cmpsb
			jne jmpFindExt@Request

				mov [R15+PORT_IO_DATA.ExtRunProc], RBX
jmpExtEnd@Request:
	xor EDX, EDX
	ret
;------------------------------------------------
;       * * *  Syntax Error
;------------------------------------------------
jmpSyntaxError@Request:
	mov DL, SRV_ERR_PathSize
	mov BL, HTTP_400_BAD_REQUEST
	ret
;------------------------------------------------
;       * * *  Access Denied
;------------------------------------------------
jmpAccessDenied@Request:
	mov DL, SRV_MSG_OpenAccess
	mov BL, HTTP_403_FORBIDDEN
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------
