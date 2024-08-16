;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Set Config Parameters
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc SetConfigParameters

local SetNetEvent   LPVOID ?    ;   LPWSAEVENT 
local SetListSocket LPVOID ?    ;   LPSOCKET
;------------------------------------------------
;       * * *  Init Params
;------------------------------------------------
	mov EDI, ServerConfig.MaxRecvFileSize
	mov ECX, SERVER_CONFIG_DWORD

jmpSetParam@SetConfigParameters:
	mov EAX, [EDI]
	or  EAX, EAX
	jz jmpNextServer@SetConfigParameters

		push ECX
		push ESI

		inc EAX
		mov ESI, EAX
		call StrToWord

		pop ESI
		pop ECX

jmpNextServer@SetConfigParameters:
	mov [SystemReport.ExitCode], ECX

	mov DL, CFG_ERR_SystemParam
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

	stosd
	loop jmpSetParam@SetConfigParameters
;------------------------------------------------
;       * * *  Delta RecvBuffer
;------------------------------------------------
	mov CX,  PORT_DATA_SIZE
	mov EAX, [ServerConfig.MaxBufferSize]
	shr EAX, 12
	inc EAX
	shl EAX, 12
	add ECX, EAX
	sub EAX, [ServerConfig.MaxRecvSize]

	mov [ServerConfig.MaxRecvBufferSize], EAX
	mov [SocketDataSize], ECX
;------------------------------------------------
;       * * *  Set Seconds TimeOut
;------------------------------------------------
	mov EBX, [ServerConfig.MaxTimeOut]
	mov EAX, 1000   ;   msec
	mul EBX
	mov [ServerConfig.MaxTimeOut], EAX
;------------------------------------------------
;       * * *  Set ListenSocket
;------------------------------------------------
	xor EAX, EAX
	mov  AL, SYS_MSG_Start
	mov [SystemReport.Index], EAX

	mov  DL, CFG_ERR_HostParam
	mov  AL, MAX_NET_HOST
	sub EAX, [TotalHost]
	jz  jmpEnd@SetConfigParameters

	mov [TotalHost], EAX
	inc EAX
	mov [SystemReport.ExitCode], EAX
;------------------------------------------------
;       * * *  Set TotalHosts
;------------------------------------------------
	mov [SystemReport.NetHost], TabNetHost
	mov [SetNetEvent], TabNetEvent
	mov [SetListSocket],   TabListenSocket
	mov [Address.sin_family], AF_INET
;------------------------------------------------
;       * * *  Set IP Address
;------------------------------------------------
jmpListenLoop@SetConfigParameters:
	dec [SystemReport.ExitCode]
	jz jmpSocketPort@SetConfigParameters
;------------------------------------------------
;       * * *  Valid Host
;------------------------------------------------
		mov EBX, [SystemReport.NetHost]
		xor EAX, EAX
		mov ECX, EAX
		mov EDI, EBX
		mov CL,  NET_HOST_PARAM
		mov DL,  CFG_ERR_HostValue
		repnz scasd
		jz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Copy Address
;------------------------------------------------
		mov EDI, SystemReport.Address
		mov EDX, [EBX+NET_HOST.Address]
		mov ESI, EDX
		inc EDX
		mov  CL, [ESI]
		inc ECX
		rep movsb
;------------------------------------------------
;       * * *  Get Address (inet_addr)
;------------------------------------------------
		mov ESI, EDX
		xor ECX, ECX
		mov EDI, ECX
		mov EBX, ECX
		mov  BL, 10

jmpFindAddr@SetConfigParameters:
		xor EDX, EDX

jmpScanAddr@SetConfigParameters:
		lodsb
		cmp AL, '0'
		jb jmpGetAddr@SetConfigParameters

		cmp AL, '9' 
		ja jmpGetAddr@SetConfigParameters

			sub AL, '0'
			mov CL, AL

			mov EAX, EDX
			mul EBX 
			add EAX, ECX
			mov EDX, EAX
			jmp jmpScanAddr@SetConfigParameters

jmpGetAddr@SetConfigParameters:
		or  EDI, EDX
		ror EDI, 8 
		cmp AL, '.'
			je jmpFindAddr@SetConfigParameters
;------------------------------------------------
;       * * *  Get Port : 20480 = htons( 80 )
;------------------------------------------------
		mov [Address.sin_addr], EDI
		mov DX, INTERNET_PORT
		cmp AL, ':'
		jne jmpAddrEnd@SetConfigParameters
			xor EDX, EDX

jmpScanPort@SetConfigParameters:
			lodsb
			cmp AL, '0'
			jb jmpGetPort@SetConfigParameters

			cmp AL, '9' 
			ja jmpGetPort@SetConfigParameters

				sub AL, '0'
				mov CL, AL

				mov EAX, EDX
				mul EBX 
				add EAX, ECX
				mov EDX, EAX
				jmp jmpScanPort@SetConfigParameters

jmpGetPort@SetConfigParameters:
			xchg DH, DL

jmpAddrEnd@SetConfigParameters:
		mov [Address.sin_port], DX
;------------------------------------------------
;       * * *  Socket
;------------------------------------------------
		xor EAX, EAX
		inc EAX
		push EAX
		xor EAX, EAX
		push EAX
		push EAX
		push IPPROTO_TCP
		push SOCK_STREAM
		push AF_INET
		call [WSASocket]

		mov  DL, SYS_ERR_Socket
		cmp EAX, INVALID_SOCKET
		je jmpEnd@SetConfigParameters

		mov EDI, [SetListSocket]
		stosd
		mov [SystemReport.Socket],  EAX
		mov [SetListSocket], EDI
;------------------------------------------------
;       * * *  Option SocketPort
;------------------------------------------------
		xor EDX, EDX
		mov  DL, SO_REUSEADDR
		push EDX
		push SetOptionPort
		push EDX
		push SOL_SOCKET
		push EAX
		call [setsockopt]

		mov DL, SYS_ERR_Option
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Binding
;------------------------------------------------
		push SOCKADDR_IN_SIZE
		push Address
		push [SystemReport.Socket]
		call [bind]

		mov DL, SYS_ERR_Binding
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Listen
;------------------------------------------------
		push [ServerConfig.MaxConnections]
		push [SystemReport.Socket]
		call [listen]

		mov DL, SYS_ERR_Listen
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  SocketEvent
;------------------------------------------------
		call [WSACreateEvent]
		mov DL, SYS_ERR_NetEvent
		or EAX, EAX
		jz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  ListenEvent
;------------------------------------------------
		mov EDI, [SetNetEvent]
		stosd
		mov [SetNetEvent], EDI

		push FD_ACCEPT+FD_CLOSE
		push EAX
		push [SystemReport.Socket]
		call [WSAEventSelect]

		mov DL, SYS_ERR_SetEvent
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  ListenReport
;------------------------------------------------
		mov EAX, SystemReport
		call WriteReport

		add [SystemReport.NetHost], NET_HOST_SIZE
		jmp jmpListenLoop@SetConfigParameters
;------------------------------------------------
;       * * *  Socket Port
;------------------------------------------------
jmpSocketPort@SetConfigParameters:
	xor EAX, EAX
	push EAX
	push EAX
	push EAX
	dec EAX
	push EAX
	call [CreateIoCompletionPort]

	mov DL, SYS_ERR_SocketPort
	or EAX, EAX
	jz jmpEnd@SetConfigParameters
		mov [hPortIOSocket], EAX
;------------------------------------------------
;       * * * Set TabRunRroc
;------------------------------------------------
	xor EBX, EBX
	mov EDI, EBX
	inc EBX
	mov ECX, MAX_RUN_PROC+2
	sub ECX, [TotalProcess]
	mov ESI, ErrRunProcess.RunPath

jmpLoopRun@SetConfigParameters:
	lodsd
	mov EDX, EAX
	lodsd
	or  EAX, EDX
	jz jmpNextRunProc@SetConfigParameters

		mov  EDI,  EBX
		mov [ESI], EBX 

jmpNextRunProc@SetConfigParameters:
	add ESI, ASK_EXT_SIZE-8
	loop jmpLoopRun@SetConfigParameters
;------------------------------------------------
;       * * *  Set Max RunProcess
;------------------------------------------------
	mov [ThreadProcessCtrl], EDI
	or EDI, EDI
	jz jmpSetMaxProc@SetConfigParameters

		mov ECX, [ServerConfig.MaxRunning]
		shl ECX, 3

jmpSetMaxProc@SetConfigParameters:
	mov [MaxQueuedProcess], ECX
;------------------------------------------------
;       * * *  Set Report Buffers
;------------------------------------------------
	mov EBX, [ServerConfig.MaxReportStack]
	xor EAX, EAX
	mov  AL, REPORT_INFO_SIZE
	mul EBX
	mov [TabRouteReport], EAX

	add ECX, EAX
	shl EBX, 10
	add EAX, EBX
	mov [TabQueuedProcess], EAX

	add EAX, MAX_SOCKET * 4
	add EAX, ECX
;------------------------------------------------
;       * * *  Get ReportBuffers
;------------------------------------------------
	push PAGE_READWRITE
	push MEM_COMMIT
	push EAX
	xor EAX, EAX
	push EAX
	call [VirtualAlloc]

	mov DL, SYS_ERR_TableBuffer
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

		mov EDI, GetMemoryBuffer
		stosd
		add EAX, MAX_SOCKET * 4
		stosd
		stosd
		stosd
		add EAX, [EDI]
		stosd
		stosd
		stosd
		add EAX, [EDI]
		stosd
;------------------------------------------------
;       * * *  Init Process
;------------------------------------------------
	mov ECX, [ThreadProcessCtrl]
	jECXz jmpThreadRouter@SetConfigParameters

		stosd
		stosd
		add [EDI], EAX
;------------------------------------------------
;       * * *  ProcessEvent
;------------------------------------------------
		xor EAX, EAX
		push EAX
		push EAX
		push EAX
		push EAX
		call [CreateEvent]

		mov DL, SYS_ERR_NetEvent
		or EAX, EAX
		jz jmpEnd@SetConfigParameters

			mov [RunProcessEvent], EAX
;------------------------------------------------
;       * * *  Thread Process
;------------------------------------------------
		xor EAX, EAX
		push EAX
		push EAX
		push EAX
		push ThreadProcessor
		push EAX
		push EAX
		call [CreateThread]

		mov DL, SYS_ERR_ThreadProcess
		or EAX, EAX
		jz jmpEnd@SetConfigParameters

			push EAX
			call [CloseHandle]
;------------------------------------------------
;       * * *  Thread Socket
;------------------------------------------------
jmpThreadRouter@SetConfigParameters:
	xor EAX, EAX
	push EAX
	push EAX
	push EAX
	push ThreadRouter
	push EAX
	push EAX
	call [CreateThread]

	mov DL, SYS_ERR_ThreadRouter
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

		push EAX
		call [CloseHandle]
;------------------------------------------------
;       * * *  Thread Listen
;------------------------------------------------
	xor EAX, EAX
	push EAX
	push EAX
	push EAX
	push ThreadListener
	push EAX
	push EAX
	call [CreateThread]

	mov DL, SYS_ERR_ThreadListen
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

		push EAX
		call [CloseHandle]

	xor EDX, EDX
;------------------------------------------------
;       * * *  End Proc  * * *
;------------------------------------------------
jmpEnd@SetConfigParameters:
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------