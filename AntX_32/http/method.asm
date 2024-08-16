;------------------------------------------------
;	AntX Web Server
;	SYSTEM: HTTP Request
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc HTTPRequest  ;  lpSocketIoData

local Connection  DWORD ?
local AskPath     DWORD ?
local pNetHost    PCHAR ?
;------------------------------------------------
;       * * *  Get Headers
;------------------------------------------------
;   mov ESI, [lpSocketIoData]
;   mov ECX, [CountBytes]

	mov EDX, ESI
	mov [pBuffer], EDX
	mov [CountBytes], ECX

	xor EAX, EAX
	mov [AskPath], EAX

	inc EAX
	mov [Connection], EAX
	jmp jmpFindFirst@Request
;------------------------------------------------
;       * * *  Set Connection
;------------------------------------------------
jmpGetConnect@Request:
	xor EAX, EAX
	mov [Connection], EAX
	jmp jmpFindEnd@Request
;------------------------------------------------
;       * * *  Set Length
;------------------------------------------------
jmpGetLength@Request:
	mov [AskPath], EDI
	jmp jmpFindEnd@Request
;------------------------------------------------
;       * * *  Scan Header
;------------------------------------------------
jmpScanHeader@Request:
	mov EBX, ECX
	mov EDX, EDI
	mov EAX,[EDI]
	cmp  AX, CHR_CRLF
	je jmpEndHeader@Request
;------------------------------------------------
;       * * *  Get Ask Length
;------------------------------------------------
	xor ECX, ECX
	mov  CL, szHeaderConnection - szHeaderLength - 2
	mov ESI, szHeaderLength + 2
	repe cmpsb
	je jmpGetLength@Request
;------------------------------------------------
;       * * *  Get Ask Connection
;------------------------------------------------
	mov  CL, szKeepAlive - szHeaderConnection - 2
	mov ESI, szHeaderConnection + 2
	mov EDI, EDX
	repe cmpsb
	je jmpGetConnect@Request
;------------------------------------------------
;       * * *  Find End Header
;------------------------------------------------
jmpFindEnd@Request:
	mov ECX, EBX

jmpFindFirst@Request:
	mov EDI, EDX
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
	sub [CountBytes], ECX

	mov ESI, [AskPath]
	or  ESI, ESI
	jz jmpGetUrlPath@Request

		mov EAX, [TransferredBytes]
		sub EAX, ECX
		push EAX
		call StrToWord

		pop ECX
		inc EAX
		inc EAX
		add EAX, ECX
		mov ESI, [lpSocketIoData] 
		mov [ESI+PORT_IO_DATA.TotalBytes], EAX
;------------------------------------------------
;       * * *  Set URL FileName
;------------------------------------------------
jmpGetUrlPath@Request:
	mov ESI, [lpSocketIoData] 
	mov EAX, [Connection]
	mov [ESI+PORT_IO_DATA.Connection], AX

	lea EDI, [ESI+PORT_IO_DATA.Path]
	mov EBX, [ESI+PORT_IO_DATA.NetHost]
	mov [pNetHost], EBX

	mov ESI, [EBX+NET_HOST.SiteFolder]
	xor EAX, EAX
	lodsb

	mov ECX, EAX
	rep movsb
;------------------------------------------------
;       * * *  Uniform Resource Locator
;------------------------------------------------
	mov ECX, [CountBytes]
	mov ESI, [pBuffer]

	mov [pBuffer], EDI
	mov EBX, EDI

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
			sub AL, 'A' - '0' - 10

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
		mov EBX, EDI
		jmp jmpSetChar@Request
;------------------------------------------------
;       * * *  DefPage
;------------------------------------------------
jmpGetUrlSize@Request:
	mov [Param], EBX
	mov ESI, EDI
	dec ESI
	lodsb

	cmp AL, '\'
	jne jmpSetUrlSize@Request

		mov EBX, [pNetHost]
		mov ESI, [EBX+NET_HOST.IndexPage]
		xor EAX, EAX
		lodsb
		add ECX, EAX
		jmp jmpScanUrl@Request
;------------------------------------------------
;       * * *  Get URL Size
;------------------------------------------------
jmpSetUrlSize@Request:
	xor EAX, EAX
	mov [EDI], AL

	mov ESI, [lpSocketIoData] 
	mov  AL, 2

	lea EBX, [ESI+PORT_IO_DATA.UrlSize]
	lea ECX, [EBX+EAX]

	mov EAX, EDI
	sub EAX, ECX
	mov [EBX], AX

	cmp AX, MAX_PATH_SIZE
	ja jmpSyntaxError@Request
;------------------------------------------------
;       * * *  Find Access
;------------------------------------------------
	mov ESI, [pBuffer]
	mov ECX, EAX
	mov EAX, '\..\'

jmpScanAccess@Request:
	cmp EAX, [ESI]
	je jmpAccessDenied@Request

	inc ESI
	loop jmpScanAccess@Request
;------------------------------------------------
;       * * *  Get RunProc
;------------------------------------------------
	mov ESI, [Param]
	mov EDX, EDI
	sub EDX, ESI

	mov EDI, szFileName
	mov ECX, EDX
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
	mov EBX, DefRunProcess
	mov ESI, [lpSocketIoData] 
	mov [ESI+PORT_IO_DATA.ExtRunProc], EBX

jmpFindExt@Request:
	add EBX, ASK_EXT_SIZE
	mov ESI, [EBX]
	or  ESI, ESI
	jz jmpExtEnd@Request

		xor EAX, EAX
		lodsb
		mov ECX, EDX
		cmp EAX, ECX 
		jne jmpFindExt@Request

			mov EDI, szFileName
			repe cmpsb
			jne jmpFindExt@Request

				mov ESI, [lpSocketIoData]
				mov [ESI+PORT_IO_DATA.ExtRunProc], EBX
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