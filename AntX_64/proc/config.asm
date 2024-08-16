;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Set Config Parameters
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc SetConfigParameters

local SetNetEvent   LPVOID ?    ;   LPWSAEVENT 
;local SetListSocket LPVOID ?    ;   LPSOCKET
;------------------------------------------------
	xor RAX, RAX
	mov RDI, RAX
	mov R14, RAX
	mov AL,  64
	sub RSP, RAX
;------------------------------------------------
;       * * *  Init Params
;------------------------------------------------
	mov EDI,  ServerConfig.MaxRecvFileSize
	mov R14b, SERVER_CONFIG_DWORD

jmpSetParam@SetConfigParameters:
	mov RAX, [RDI]
	or  RAX, RAX
	jz jmpNextServer@SetConfigParameters

		mov R15, RDI
		inc RAX
		mov RSI, RAX
		call StrToWord

jmpNextServer@SetConfigParameters:
	mov [SystemReport.ExitCode], R14d

	mov DL, CFG_ERR_SystemParam
	or RAX, RAX
	jz jmpEnd@SetConfigParameters

		mov RDI, R15
		stosq
		dec R14
		jnz jmpSetParam@SetConfigParameters
;------------------------------------------------
;       * * *  Delta RecvBuffer
;------------------------------------------------
	mov R14w, PORT_DATA_SIZE
	mov RAX, [ServerConfig.MaxBufferSize]
	shr RAX, 12
	inc RAX
	shl RAX, 12
	add R14, RAX
	sub RAX, [ServerConfig.MaxRecvSize]

	mov [ServerConfig.MaxRecvBufferSize], RAX
	mov [SocketDataSize], R14
;------------------------------------------------
;       * * *  Set Seconds TimeOut
;------------------------------------------------
	mov RBX, [ServerConfig.MaxTimeOut]
	xor RAX, RAX
	mov  AX, 1000
	mul EBX
	mov [ServerConfig.MaxTimeOut], RAX
;------------------------------------------------
;       * * *  Set ListenSocket
;------------------------------------------------
	xor RAX, RAX
	mov  AL, SYS_MSG_Start
	mov [SystemReport.Index], EAX

	mov  DL, CFG_ERR_HostParam
	mov  AL, MAX_NET_HOST
	sub RAX, [TotalHost]
	jz jmpEnd@SetConfigParameters

	mov [TotalHost], RAX
	inc EAX
	mov [SystemReport.ExitCode], EAX
;------------------------------------------------
;       * * *  Set TotalHosts
;------------------------------------------------
	mov [SystemReport.NetHost], TabNetHost
	mov [SetNetEvent], TabNetEvent
	mov [SetListSocket], TabListenSocket
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
		mov RBX, [SystemReport.NetHost]
		xor RAX, RAX
		mov RCX, RAX
		mov RDI, RBX
		mov  CL, NET_HOST_PARAM
		mov  DL, CFG_ERR_HostValue
		repnz scasd
		jz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Copy Address
;------------------------------------------------
		mov RDX, RAX
		mov EDI, SystemReport.Address
		mov EDX, [RBX+NET_HOST.Address]
		mov RSI, RDX
		inc RDX
		mov CL, [RSI]
		inc ECX
		rep movsb
;------------------------------------------------
;       * * *  Get Address (inet_addr)
;------------------------------------------------
		mov RSI, RDX
		xor RCX, RCX
		mov RDI, RCX
		mov RBX, RCX
		mov  BL, 10
		mov R8b, '0'
		mov R9b, '9'

jmpFindAddr@SetConfigParameters:
		xor RDX, RDX

jmpScanAddr@SetConfigParameters:
		lodsb
		cmp AL, R8b
		jb jmpGetAddr@SetConfigParameters

		cmp AL, R9b 
		ja jmpGetAddr@SetConfigParameters

			sub AL, R8b
			mov CL, AL

			mov EAX, EDX
			mul RBX 
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
			xor RDX, RDX

jmpScanPort@SetConfigParameters:
			lodsb
			cmp AL, R8b
			jb jmpGetPort@SetConfigParameters

			cmp AL, R9b 
			ja jmpGetPort@SetConfigParameters

				sub AL, R8b
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
		xor RAX, RAX
		param 4, RAX
		param 5, RAX
		inc RAX
		param 6, RAX
		param 3, IPPROTO_TCP
		param 2, SOCK_STREAM
		param 1, AF_INET
		call [WSASocket]

		mov  DL, SYS_ERR_Socket
		cmp EAX, INVALID_SOCKET
		je jmpEnd@SetConfigParameters

		mov RDI, [SetListSocket]
		stosq
		mov [SystemReport.Socket],  RAX
		mov [SetListSocket], RDI
;------------------------------------------------
;       * * *  Option SocketPort
;------------------------------------------------
		param 1, RAX
		param 5, 8
		param 4, SetOptionPort
		param 3, SO_REUSEADDR
		param 2, SOL_SOCKET
		call [setsockopt]

		mov DL, SYS_ERR_Option
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Binding
;------------------------------------------------
		param 3, 0
		mov R8b, SOCKADDR_IN_SIZE
		param 2, Address
		param 1, [SystemReport.Socket]
		call [bind]

		mov DL, SYS_ERR_Binding
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  Listen
;------------------------------------------------
		param 2, [ServerConfig.MaxConnections]
		param 1, [SystemReport.Socket]
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
		mov RDI, [SetNetEvent]
		stosq
		mov [SetNetEvent], RDI

		param 2, RAX
		param 3, FD_ACCEPT+FD_CLOSE
		param 1, [SystemReport.Socket]
		call [WSAEventSelect]

		mov DL, SYS_ERR_SetEvent
		or EAX, EAX
		jnz jmpEnd@SetConfigParameters
;------------------------------------------------
;       * * *  ListenReport
;------------------------------------------------
		param 0, SystemReport
		call WriteReport

		add [SystemReport.NetHost], NET_HOST_SIZE
		jmp jmpListenLoop@SetConfigParameters
;------------------------------------------------
;       * * *  Socket Port
;------------------------------------------------
jmpSocketPort@SetConfigParameters:
	param 1, 0
	param 2, RCX
	param 3, RCX
	param 4, RCX
	dec RCX
	call [CreateIoCompletionPort]

	mov DL, SYS_ERR_SocketPort
	or EAX, EAX
	jz jmpEnd@SetConfigParameters
		mov [hPortIOSocket], RAX
;------------------------------------------------
;       * * * Set TabRunRroc
;------------------------------------------------
	xor RCX, RCX
	mov RBX, RCX
	mov R9,  RCX
	mov R8,  RCX
	mov R8b, ASK_EXT_SIZE-8
	inc RBX

	mov  CX, MAX_RUN_PROC+2
	sub RCX, [TotalProcess]
	mov RSI, ErrRunProcess.RunPath

jmpLoopRun@SetConfigParameters:
	lodsd
	mov RDX, RAX
	lodsd
	or  RAX, RDX
	jz jmpNextRunProc@SetConfigParameters

		mov  R9d,  EBX
		mov [RSI], EBX 

jmpNextRunProc@SetConfigParameters:
	add RSI, R8
	loop jmpLoopRun@SetConfigParameters
;------------------------------------------------
;       * * *  Set Max RunProcess
;------------------------------------------------
	mov [ThreadProcessCtrl], R9d
	or R9, R9
	jz jmpSetMaxProc@SetConfigParameters

		mov RCX, [ServerConfig.MaxRunning]
		shl ECX, 3

jmpSetMaxProc@SetConfigParameters:
	mov [MaxQueuedProcess], RCX
;------------------------------------------------
;       * * *  Set Report Buffers
;------------------------------------------------
	mov RBX, [ServerConfig.MaxReportStack]
	xor RAX, RAX
	mov  AL, REPORT_INFO_SIZE
	mul EBX
	mov [TabRouteReport], RAX

	add ECX, EAX
	shl EBX, 10
	add EAX, EBX
	mov [TabQueuedProcess], RAX

	add EAX, MAX_SOCKET * 8
	add EAX, ECX
	mov RDX, RAX
;------------------------------------------------
;       * * *  Get ReportBuffers
;------------------------------------------------
	param 4, PAGE_READWRITE
	param 3, MEM_COMMIT
	param 1, 0
	call [VirtualAlloc]

	mov DL, SYS_ERR_TableBuffer
	or RAX, RAX
	jz jmpEnd@SetConfigParameters

		mov RDI, GetMemoryBuffer
		stosq
		add RAX, MAX_SOCKET * 8
		stosq
		stosq
		stosq
		add RAX, [RDI]
		stosq
		stosq
		stosq
		add RAX, [RDI]
		stosq
;------------------------------------------------
;       * * *  Init Process
;------------------------------------------------
	mov ECX, [ThreadProcessCtrl]
	jECXz jmpThreadRouter@SetConfigParameters

		stosq
		stosq
		add [RDI], RAX
;------------------------------------------------
;       * * *  ProcessEvent
;------------------------------------------------
		param 1, 0
		param 2, RCX  ;  0
		param 3, RCX  ;  0
		param 4, RCX  ;  0
		call [CreateEvent]

		mov DL, SYS_ERR_NetEvent
		or EAX, EAX
		jz jmpEnd@SetConfigParameters

			mov [RunProcessEvent], RAX
;------------------------------------------------
;       * * *  Thread Process
;------------------------------------------------
		param 1, 0
		param 6, RCX
		param 5, RCX
		param 4, RCX
		param 3, ThreadProcessor
		param 2, RCX
		call [CreateThread]

		mov DL, SYS_ERR_ThreadProcess
		or EAX, EAX
		jz jmpEnd@SetConfigParameters

			param 1, RAX
			call [CloseHandle]
;------------------------------------------------
;       * * *  Thread Socket
;------------------------------------------------
jmpThreadRouter@SetConfigParameters:
	param 1, 0
	param 6, RCX
	param 5, RCX
	param 4, RCX
	param 3, ThreadRouter
	param 2, RCX
	call [CreateThread]

	mov DL, SYS_ERR_ThreadRouter
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

		param 1, RAX
		call [CloseHandle]
;------------------------------------------------
;       * * *  Thread Listen
;------------------------------------------------
	param 1, 0
	param 6, RCX
	param 5, RCX
	param 4, RCX
	param 3, ThreadListener
	param 2, RCX
	call [CreateThread]

	mov DL, SYS_ERR_ThreadListen
	or EAX, EAX
	jz jmpEnd@SetConfigParameters

		param 1, RAX
		call [CloseHandle]

	xor RDX, RDX
;------------------------------------------------
;       * * *  End Proc  * * *
;------------------------------------------------
jmpEnd@SetConfigParameters:
	xor RAX, RAX
	mov AL,  64
	add RSP, RAX
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------