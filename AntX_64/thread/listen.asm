;------------------------------------------------
;	AntX Web Server
;	THREAD: Listener + Acceptor
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc ThreadListener   ;   RCX = ThrControl

local TotalSocket    QWORD ?
local ppTablePort    LPVOID ?
local lpListenIoData LPPORT_IO_DATA ?
;------------------------------------------------
	xor RAX, RAX
	inc EAX
	mov [ThreadListenCtrl], EAX
	mov AL,  64
	sub RSP, RAX
;------------------------------------------------
;       * * *  Wait Connection
;------------------------------------------------
jmpWaitConnect@Listener:
	mov RDI, ListenReport.NetHost
	xor RAX, RAX
	stosq
	stosq
	stosq

	mov AL, NET_ERR_SetConnect
	mov [ListenReport.Index], EAX

jmpTimeOut@Listener:
	param 3, 0
	param 5, R8
	param 4, WAIT_LIST_TIMEOUT
	param 2, TabNetEvent
	param 1, [TotalHost]
	call [WSAWaitForMultipleEvents]

	cmp EAX, WAIT_FAILED
	je jmpListenError@Listener

	mov ECX, [ThreadServerCtrl]
	or  ECX, ECX 
	jz jmpEnd@Listener

	cmp EAX, WAIT_TIMEOUT
	je jmpTimeOut@Listener
;------------------------------------------------
;       * * *  Get Host
;------------------------------------------------
	lea RDI, [RAX*8]
	shl RAX, 5
	add RAX, TabNetHost
	mov [ListenReport.NetHost], RAX
;------------------------------------------------
;       * * *  Get NetEvent
;------------------------------------------------
	param 1, [TabListenSocket+RDI]
	mov [ListenReport.Socket], RCX
	param 2, [TabNetEvent+RDI]
	param 3, ListenEvent
	call [WSAEnumNetworkEvents]

	mov DL, NET_ERR_GetConnect
	or EAX, EAX
	jnz jmpReport@Listener
;------------------------------------------------
;       * * *  Ask Socket
;------------------------------------------------
	xor RAX, RAX
	mov  AL, FD_ACCEPT
	test [ListenEvent.lNetworkEvents], EAX
	jz jmpWaitConnect@Listener

		mov EAX, [ListenEvent.iErrorCode + FD_ACCEPT_ERROR]
		or  EAX, EAX
		jnz jmpReportError@Listener
;------------------------------------------------
;       * * *  Accept Connect
;------------------------------------------------
	param 5, RAX
	param 4, RAX
	param 3, SizeOfAddrIn
	param 2, Address
	param 1, [ListenReport.Socket]
	call [WSAAccept]

	mov  DL, NET_ERR_Accept
	cmp RAX, INVALID_SOCKET
	je jmpReport@Listener
;------------------------------------------------
;       * * *  Set Socket + Address (inet_ntoa)
;------------------------------------------------
	mov [ListenReport.Socket], RAX
	xor RAX, RAX
	mov RBX, RAX
	mov RCX, RAX
	mov RDI, RAX
	mov RSI, RAX
	mov ESI, sStrByteScale + 1
	mov EDI, ListenReport.Address + 1
	mov EDX, [Address.sin_addr]
	mov  CL, 4

jmpScanAddres@Listener:
	mov BL, DL 
	mov EAX, [ESI+EBX*4]

	cmp BL, 100
	jb jmpSetDigAddr@Listener
		stosb

jmpSetDigAddr@Listener:
	shr EAX, 8
	cmp BL, 10
	jb jmpEndDigAddr@Listener
		stosb

jmpEndDigAddr@Listener:
	shr EAX, 8
	mov AH, '.'
	stosw
	ror EDX, 8
	loop jmpScanAddres@Listener

	mov RAX, RDI
	dec EAX
	sub RAX, ListenReport.Address + 1
	mov [ListenReport.Address], AL
;------------------------------------------------
;       * * *  Set Timeout
;------------------------------------------------
	call [GetTickCount]
	add RAX, [ServerConfig.MaxTimeOut]
	mov [ListenReport.TimeLimit], RAX
;------------------------------------------------
;       * * *  Memory Port Buffer
;------------------------------------------------
	param 4, PAGE_READWRITE
	param 3, MEM_COMMIT
	param 2, [SocketDataSize]
	param 1, 0
	call [VirtualAlloc]

	mov DL, NET_ERR_SocketMemory
	or RAX, RAX
	jz jmpReport@Listener
;------------------------------------------------
;       * * *  Find Free Socket
;------------------------------------------------
		mov [lpListenIoData], RAX

		mov RDI, [TabSocketIoData]
		mov ECX, MAX_SOCKET
		mov  DL, NET_ERR_FindSocket
		xor RAX, RAX
		repnz scasq
		jnz jmpReport@Listener

			mov [TotalSocket], RCX
			lea RBX, [RDI-8]
			mov [ppTablePort], RBX
			mov qword[ListenReport.Index], RBX
;------------------------------------------------
;       * * *  Create Port
;------------------------------------------------
			param 4, RAX
			param 3, RAX
			param 2, [hPortIOSocket]
			param 1, [ListenReport.Socket]

			call [CreateIoCompletionPort]
			mov DL, NET_ERR_PortSocket
			or EAX, EAX
			jz jmpReport@Listener
;------------------------------------------------
;       * * *  Set SocketPort + Buffer
;------------------------------------------------
	mov RBX, [lpListenIoData]
	lea RDI, [RBX+PORT_IO_DATA.TimeLimit]
	mov RSI, ListenReport
	xor RCX, RCX
	mov  CL, ACCEPT_HEADER_COUNT
	rep movsq

	mov RDI, qword[ListenReport.Index]
	mov [RDI], RBX
	mov RSI, RBX
;------------------------------------------------
;       * * *  MaxSocket Limit
;------------------------------------------------
	mov RAX, [ServerConfig.MaxConnections]
	cmp RAX, [TotalSocket]
	jb jmpRecvHeader@Listener

		mov [RSI+PORT_IO_DATA.ExtRunProc], ErrRunProcess
		xor RCX, RCX
		mov  BL, HTTP_503_BUSY
		call CreateHttpHeader
;------------------------------------------------
;       * * *  Sending (close)
;------------------------------------------------
		mov RAX, [RSI+PORT_IO_DATA.CountBytes]
		mov [RSI+PORT_IO_DATA.WSABuffer.len], RAX
		mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

		param 3, 0
		param 7, R8
		param 6, RSI
		param 5, R8
		inc R8
		param 4, TransBytes
		lea RDX, [RSI+PORT_IO_DATA.WSABuffer]
		param 1, [ListenReport.Socket]
		call [WSASend]

		mov DL, NET_MSG_ConnectLimit
		or EAX, EAX
		jz jmpReport@Listener

			call [WSAGetLastError]
			mov DL,  NET_MSG_ConnectLimit
			cmp EAX, ERROR_IO_PENDING
			je jmpReport@Listener

				mov DL, NET_ERR_SendListen
				jmp jmpReport@Listener
;------------------------------------------------
;       * * *  Accept To Buffer
;------------------------------------------------
jmpRecvHeader@Listener:
	lea RAX, [RSI+PORT_IO_DATA.Buffer]
	mov [RSI+PORT_IO_DATA.WSABuffer.buf], RAX

	mov RAX, [ServerConfig.MaxHeadSize]
	mov [ESI+PORT_IO_DATA.WSABuffer.len], RAX

	param 7, RCX
	param 6, RSI
	param 5, TransFlag
	param 4, TransBytes
	inc RCX
	param 3, RCX
	lea RDX, [RSI+PORT_IO_DATA.WSABuffer]
	param 1, [ListenReport.Socket]
	call [WSARecv]

	or EAX, EAX
	jz jmpConnected@Listener

		call [WSAGetLastError]
		mov DL,  NET_ERR_RecvHeader
		cmp EAX, ERROR_IO_PENDING
		jne jmpReport@Listener
;------------------------------------------------
;       * * *  Post ListReport
;------------------------------------------------
jmpConnected@Listener:
	mov DL, SRV_MSG_Connected

jmpReport@Listener:
	mov [ListenReport.Index], EDX
	call [WSAGetLastError]
;------------------------------------------------
;       * * *  Post ListenError
;------------------------------------------------
jmpReportError@Listener:
	mov [ListenReport.Error], EAX

	mov RDI, [SetListenReport]
	lea RDX, [RDI+REPORT_INFO_SIZE]
	cmp RDX, [MaxListenReport]
	jb jmpSetReport@Listener
		mov RDX, [TabListenReport]
;------------------------------------------------
;       * * *  Create Report
;------------------------------------------------
jmpSetReport@Listener:
	cmp RDX, [GetListenReport]
	je jmpError@Listener

		mov RSI, ListenReport.Index
		xor RCX, RCX
		mov CL,  ACCEPT_HEADER_REPORT
		rep movsq
		mov [SetListenReport], RDX
;------------------------------------------------
;       * * *  Error ListReport
;------------------------------------------------
jmpError@Listener:
	mov EAX, [ListenReport.Index]
	cmp  AL, NET_ERR_WaitConnect
	jae jmpWaitConnect@Listener

	cmp  AL, NET_ERR_SocketMemory
	jbe jmpSocketClose@Listener

	cmp  AL, NET_ERR_PortSocket
	jbe jmpMeroryFree@Listener
;------------------------------------------------
;       * * *  Port Free
;------------------------------------------------
	mov RDI, [ppTablePort]
	xor RAX, RAX
	mov [RDI], RAX
;------------------------------------------------
;       * * *  Merory Free
;------------------------------------------------
jmpMeroryFree@Listener:
	param 1, [lpListenIoData]
	param 2, 0
	param 3, MEM_RELEASE
	call [VirtualFree]
;------------------------------------------------
;       * * *  Close Socket
;------------------------------------------------
jmpSocketClose@Listener:
	param 1, [ListenReport.Socket]
	call [closesocket]
	jmp jmpWaitConnect@Listener
;------------------------------------------------
;       * * *  ListenEvent Error
;------------------------------------------------
jmpListenError@Listener:
	call [WSAGetLastError]
	mov  [SystemReport.Error], EAX
	mov  [SystemReport.Index], NET_ERR_WaitConnect
;------------------------------------------------
;       * * *  Close ListenEvent
;------------------------------------------------
jmpEnd@Listener:
	mov RSI, TabNetEvent
	mov RAX, [TotalHost]
	mov [SetOptionPort], RAX

jmpFreeEvent@Listener:
	lodsq
	mov [lpListenIoData], RSI
	param 1, RAX
	call [WSACloseEvent]

	mov RSI, [lpListenIoData]
	dec [SetOptionPort]
	jnz jmpFreeEvent@Listener
;------------------------------------------------
;       * * *  Close ListenSocket
;------------------------------------------------
	mov RSI, TabListenSocket

jmpFreeSocket@Listener:
	lodsq
	mov [lpListenIoData], RSI

	param 1, RAX
	call [closesocket]

	mov RSI, [lpListenIoData]
	dec [TotalHost]
	jnz jmpFreeSocket@Listener
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
	xor RAX, RAX
	param 1, RAX
	mov [ThreadListenCtrl], EAX
	mov AL,  64
	add RSP, RAX
	call [ExitThread]
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------