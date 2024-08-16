;------------------------------------------------
;	AntX Web Server
;	MAIN: Main + Config + Start
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
format PE64 CONSOLE
include 'server.inc'
section '.code' code readable executable

	xor RAX, RAX
	mov RCX, RAX
	mov RDI, RAX
	mov CL,  56
	sub RSP, RCX

	mov EDI, ThreadServerCtrl
	mov CX,  STACK_FRAME_CLEAR
	rep stosq

	inc EAX    
	mov [SetOptionPort], RAX
;------------------------------------------------
;   * * *  Set Digital Scale
;------------------------------------------------
	mov EDI, sStrByteScale
	mov  CX, MAX_INT_SCALE
	mov  DX, '00'
	mov EBX, EDX

jmpSetScale@Main:
	cmp DH, '9'
	jbe jmpSet10@Main
		mov DH, '0'
		inc DL

jmpSet10@Main:
		cmp DL, '9'
		jbe jmpSet100@Main
			mov DL, '0'
			inc BH

jmpSet100@Main:
	mov EAX, EBX
	stosw

	mov EAX, EDX
	stosw

	inc DH
	loop jmpSetScale@Main
;------------------------------------------------
;   * * *  Get CommandLine
;------------------------------------------------
	call [GetCommandLine]
	or RAX, RAX
	jz jmpError@Main

		mov R10, RAX
		mov RSI, RAX
		xor RDX, RDX
		mov RBX, RDX
;       mov RDI, RDX
		mov AL, [RSI]
		cmp AL, '"'
		je jmpSetEnd@Main

		cmp AL, "'"
		jne jmpGetPath@Main

jmpSetEnd@Main:
			mov DL, AL
			inc RSI

jmpGetPath@Main:
		mov EDI, szReportName
		mov R10, RSI
		mov [lppReportMessages], EDI

jmpCopyPath@Main:
		lodsb
		stosb
		cmp AL, '.'
		jne jmpNextPath@Main

			mov RBX, RSI
			mov RCX, RDI

jmpNextPath@Main:
		cmp AL, DL
		jne jmpCopyPath@Main

jmpPathEnd@Main:
		mov DL, SYS_ERR_CommandLine
		or RBX, RBX
		jz jmpError@Main

	mov dword[RCX], EXT_LOG
	mov dword[RBX], EXT_INI
;------------------------------------------------
;   * * *  OpenConfig
;------------------------------------------------
	param 4, 0
	param 7, R9
	param 6, FILE_ATTRIBUTE_READONLY
	param 5, OPEN_EXISTING
	param 3, FILE_SHARE_READ 
	param 2, GENERIC_READ 
	param 1, R10
	call [CreateFile]

	xor RDX, RDX
	cmp RAX, INVALID_HANDLE_VALUE
		je jmpError@Main

		mov [hFile], RAX
		param 1, RAX
		xor RAX, RAX
		param 5, RAX
		param 4, CountBytes
		param 3, CONFIG_BUFFER_SIZE
		param 2, _DataBuffer_
		call [ReadFile]

		mov RCX, [hFile]
		call [CloseHandle]

		xor RDX, RDX
		mov RCX, [CountBytes]
		or  ECX, ECX
		jz jmpError@Main
;------------------------------------------------
;   * * *  Get Config Strings
;------------------------------------------------
	mov RDI, _DataBuffer_
	mov RSI, TabConfig
	xor RDX, RDX
	mov R8,  RDX
	mov DX,  MAX_CONFIG_COUNT
	mov R8b, 4

jmpTextScan@Main:
	mov [RSI], EDI
	add RSI, R8

jmpTextSkip@Main:
	mov AL, CHR_LF
	repne scasb
	jne jmpTextEnd@Main
	jECXz jmpTextEnd@Main

	dec EDX
	jnz jmpTextScan@Main

jmpTextEnd@Main:
	xor EAX, EAX
	mov [RSI], EAX
;------------------------------------------------
;   * * *  Init Table HTTP Tags
;------------------------------------------------
;   xor ECX, ECX
	mov  CL, RESPONT_HEADER_COUNT
	mov EDI, lppTagRespont
	mov EAX, szTagOk
	rep stosd
;------------------------------------------------
;   * * *  Find KeyWord
;------------------------------------------------
;	R10 = TabNetHost
;	R11 = TabRunProcess 
;   R12 = GetRunProcess
;	R15 = TabConfig
;	RSI = Param
;------------------------------------------------
	mov CL,  MAX_RUN_PROC
	mov R13, RCX
	mov CL,  MAX_NET_HOST
	mov R14, RCX
	mov R10, TabNetHost
	mov R11, TabRunProcess
	mov R15, TabConfig
	mov R12, R11
	mov [DefRunProcess.Type], szHeaderTextHtml

jmpFindConfig@Main:
	mov RSI, R15
	xor RAX, RAX
	lodsd
	or  EAX, EAX
	jz jmpScanEnd@Main

		mov R15, RSI
		mov RBX, RAX
		cmp byte[RBX], '#'
		je jmpFindConfig@Main
;------------------------------------------------
;   * * *  Get ConfigParam
;------------------------------------------------
	mov RDI, RBX
	xor RCX, RCX
	mov  CL, MAX_PARAM_LENGTH
	mov  AL, '='
	repne scasb
	jne jmpErrorParam@Main

		mov RDX, RBX
		inc RBX
		mov R8,  RDI
		sub R8,  RBX
		mov RSI, RDI
		mov AL,  ' '

jmpFindParam@Main:
	scasb
	jbe jmpFindParam@Main

		mov RAX, RDI
		dec RAX
		sub RAX, RSI
		jz jmpSetParam@Main

			dec RSI
			mov [RSI],AL

			dec RDI
			xor EAX, EAX
			mov [RDI],AL

			mov RAX, RSI

jmpSetParam@Main:
	mov R9, RAX
;------------------------------------------------
;   * * *  Find KeyParam
;------------------------------------------------
	mov ESI, sServerConfigParam
	xor RCX, RCX
	mov RBX, RCX

jmpFindKey@Main:
	inc EBX
	add ESI, ECX
	xor EAX, EAX
	lodsb
	mov ECX, EAX
	jECXz jmpReport@Main

		cmp EAX, R8d
		jne jmpFindKey@Main

			mov EDI, EDX
			repe cmpsb
			jne jmpFindKey@Main
;------------------------------------------------
;   * * *  Select Table
;------------------------------------------------
			shl EBX, 2
			cmp BL, CFG_INDEX_HOST
			je jmpHost@Main
			ja jmpSetHost@Main

			cmp BL, CFG_INDEX_PROCESS
			je jmpAsk@Main
			ja jmpSetAsk@Main

			mov [ServerConfig+EBX*2], R9
			jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set Report
;------------------------------------------------
jmpReport@Main:
	mov AX, [RDX]
	mov RBX, RCX
	sub AX,'00'
	mov BL, AH
	mov CL, 10
	mul CL
	add BL, AL
	cmp BL, REPORT_MESSAGE_COUNT-1
	ja jmpErrorParam@Main

	mov [lppReportMessages+EBX*4], R9d
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set ExtAsk
;------------------------------------------------
jmpAsk@Main:
	mov R12d, ErrRunProcess
	or  R9d, R9d
	jz jmpFindConfig@Main

	mov R12d, DefRunProcess
	mov AX, [R9]
	cmp AH, '*'
	je jmpFindConfig@Main

	dec R13d
	jz jmpErrorParam@Main

		mov RSI, R12
		mov RDI, R11
		mov R12, R11
		mov  CL, ASK_EXT_COUNT
		rep movsd

		mov R11, RDI

jmpSetAsk@Main:
	mov [R12d+EBX-CFG_OFFSET_PROCESS], R9d
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set Host
;------------------------------------------------
jmpHost@Main:
	dec R14d
	jz jmpErrorParam@Main

		mov  CL, NET_HOST_SIZE
		add R10, RCX

jmpSetHost@Main:
	mov [R10d+EBX-CFG_OFFSET_HOST], R9d
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Config Error
;------------------------------------------------
jmpErrorParam@Main:
	mov [lppReportMessages], R9d
	mov RAX, R15
	sub EAX, TabConfig
	shr EAX, 2
	mov [SystemReport.ExitCode], EAX

	xor EDX, EDX
	jmp jmpError@Main
;------------------------------------------------
;       * * *  Set Report FileName
;------------------------------------------------
jmpScanEnd@Main:
	mov [TotalHost], R14
	mov [TotalProcess], R13

	mov  DL,  CFG_ERR_SystemParam
	mov RSI, [ServerConfig.lpReportPath]
	or  RSI, RSI
	jz jmpError@Main

		mov EDI, szReportName
		xor EAX, EAX
		lodsb
		inc EAX
		mov ECX, EAX
		rep movsb
;------------------------------------------------
;       * * *  Startup WSAver=2.2
;------------------------------------------------
	xor RCX, RCX
	mov  CX, SET_WSA_VER
	param 2, WSockVer
	call [WSAStartup]

	mov DL, SYS_ERR_WSAversion
	or EAX, EAX
	jnz jmpError@Main
;------------------------------------------------
;   * * *  Start Server
;------------------------------------------------
	param 1, ServiceTable
	call [StartServiceCtrlDispatcher]

	or EAX, EAX
	jnz jmpEnd@Main
		mov DL, SYS_ERR_Dispatcher
;------------------------------------------------
;   * * *  Server Error
;------------------------------------------------
jmpError@Main:
	call FileReport
;------------------------------------------------
;   * * *  Stop Server
;------------------------------------------------
jmpEnd@Main:
	mov  DL, SYS_MSG_Stop
	call FileReport

	param 1, 0
	call [ExitProcess]
;------------------------------------------------
include 'resource.asm'
;------------------------------------------------
;   * * *   END  * * *
;------------------------------------------------
