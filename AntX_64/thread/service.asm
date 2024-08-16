;------------------------------------------------
;	AntX Web Server
;	THREAD: Service + Report + TimeOut
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Set ServiceStatus  * * *
;------------------------------------------------
proc SetService   ;   Param = EDX

	mov RBX, SrvStatus
	mov RDI, RBX
	xor RAX, RAX
	mov RCX, RAX

	mov AL,  SERVICE_WIN32_OWN_PROCESS
	stosd
	mov EAX, EDX
	stosd

	mov RAX, RCX
	mov CL,  SERVICE_STATUS_COUNT - 2
	rep stosd

	cmp EDX, SERVICE_START_PENDING
	je jmpRun@SetService

		mov AL, SERVICE_ACCEPT_STOP + SERVICE_ACCEPT_SHUTDOWN
		mov [SrvStatus.dwControlsAccepted], EAX

jmpRun@SetService:
	cmp EDX, SERVICE_RUNNING
	je jmpSet@SetService

	cmp EDX, SERVICE_STOPPED
	je jmpSet@SetService

		mov [SrvStatus.dwWaitHint], WAIT_SERVICE_HINT
		inc [SrvStatus.dwCheckPoint]

jmpSet@SetService:
	mov AL,  32
	sub RSP, RAX

	param 2, RBX
	param 1, [hStatus]
	call [SetServiceStatus]

	xor RCX, RCX
	mov CL,  32
	add RSP, RCX
	ret
endp
;------------------------------------------------
;       * * *  ServiceHandle  * * *
;------------------------------------------------
proc ServiceHandler   ;   RCX = Control

	cmp ECX, SERVICE_CONTROL_STOP
	je jmpStop@ServiceHandler

	cmp ECX, SERVICE_CONTROL_SHUTDOWN
	jne jmpEnd@ServiceHandler
;------------------------------------------------
;       * * *  Set Status  * * *
;------------------------------------------------
	mov EAX, [lppReportMessages+SYS_MSG_ShutDown*4]
	mov [lppReportMessages+SYS_MSG_Stop*4], EAX

jmpStop@ServiceHandler:
	xor RAX, RAX
	mov AL,  32
	sub RSP, RAX

	mov [SrvStatus.dwCurrentState], SERVICE_STOP_PENDING
	mov [SrvStatus.dwCheckPoint],   WAIT_SERVICE_HINT
	inc [SrvStatus.dwWaitHint]

	param 1, [hStatus]
	param 2, SrvStatus
	call [SetServiceStatus]

	or EAX, EAX
	jnz jmpSet@ServiceHandler

		mov DL, SYS_ERR_StopPending
		call FileReport

jmpSet@ServiceHandler:
	xor RCX, RCX
	mov [ThreadServerCtrl], ECX
	mov CL,  32
	add RSP, RCX

jmpEnd@ServiceHandler:
	ret
endp
;------------------------------------------------
;       * * *  MAIN Process (Services)  * * *
;------------------------------------------------
proc ServiceMain

local Count         QWORD ?   ;   RCX = Count
;local Agv          QWORD ?   ;   RDX = Agv
local PortTimeOut   QWORD ?
local TimeDelay     QWORD ?
local SetListSocket LPVOID ?   ;   LPSOCKET
local lpTimeIoData  LPPORT_IO_DATA ?
;------------------------------------------------
;      * * *  ServiceHandler
;------------------------------------------------
	xor RAX, RAX
	mov AL,  64
	sub RSP, RAX

	mov [SrvStatus.dwCurrentState], SERVICE_START_PENDING
	mov [SrvStatus.dwServiceType],  SERVICE_WIN32_OWN_PROCESS
	mov [SrvStatus.dwWaitHint],     WAIT_SERVICE_HINT
	inc [SrvStatus.dwCheckPoint]

	param 2, ServiceHandler
	param 1, szServiceName
	call [RegisterServiceCtrlHandler]

	mov DL, SYS_ERR_Register
	or EAX, EAX
	jz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Start Service
;------------------------------------------------
	mov [hStatus], RAX
	param 1, RAX
	param 2, SrvStatus
	call [SetServiceStatus]

	mov DL, SYS_ERR_StartPending
	or EAX, EAX
	jz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Set Config Parameters
;------------------------------------------------
	call SetConfigParameters
	or EDX, EDX
	jnz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Start Services
;------------------------------------------------
	xor EAX, EAX
	mov [SrvStatus.dwCheckPoint], EAX
	mov [SrvStatus.dwWaitHint],   EAX
	mov [SrvStatus.dwCurrentState],     SERVICE_RUNNING
	mov [SrvStatus.dwControlsAccepted], SERVICE_ACCEPT_STOP + SERVICE_ACCEPT_SHUTDOWN

	param 1, [hStatus]
	param 2, SrvStatus
	call [SetServiceStatus]

	mov DL, SYS_ERR_Start
	or EAX, EAX
	jz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Get All Reports
;------------------------------------------------
	xor RAX, RAX
	mov RCX, RAX
	mov RDI, SystemReport
	mov  CL, 3 * REPORT_INFO_COUNT
	rep stosq

	mov [TimeDelay], RAX
	inc RAX
	mov [ThreadServerCtrl], EAX
;------------------------------------------------
;       * * *  Get ProcessReport
;------------------------------------------------
jmpMainLoop@ServiceMain:
	xor RAX, RAX
	mov [lpFileReport], RAX

	mov ECX, [SystemReport.Index]
	jECXz jmpGetSocketReport@ServiceMain

		mov RAX, SystemReport
		call WriteReport

		xor EAX, EAX
		mov [SystemReport.Index], EAX
;------------------------------------------------
;       * * *  Get RouterReport
;------------------------------------------------
jmpGetSocketReport@ServiceMain:
	mov ECX, [RouterReport.Index]
	jECXz jmpGetListenReport@ServiceMain

		mov RAX, RouterReport
		call WriteReport

		xor EAX, EAX
		mov [RouterReport.Index], EAX
;------------------------------------------------
;       * * *  Get ListenReport
;------------------------------------------------
jmpGetListenReport@ServiceMain:
	mov RAX, [GetListenReport]
	cmp RAX, [SetListenReport]
	je jmpGetRouteReport@ServiceMain

		call WriteReport

		lea RAX, [RSI+REPORT_INFO_SIZE]
		cmp RAX, [MaxListenReport]
		jb jmpSetListenReport@ServiceMain
			mov RAX, [TabListenReport]

jmpSetListenReport@ServiceMain:
		mov [GetListenReport], RAX
;------------------------------------------------
;       * * *  Get RouteReport
;------------------------------------------------
jmpGetRouteReport@ServiceMain:
	mov RAX, [GetRouteReport]
	cmp RAX, [SetRouteReport]
	je jmpControlStop@ServiceMain

		call WriteReport

		lea RAX, [RSI+REPORT_INFO_PATH_SIZE]
		cmp RAX, [MaxRouteReport]
		jb jmpSetRouteReport@ServiceMain
			mov RAX, [TabRouteReport]

jmpSetRouteReport@ServiceMain:
		mov [GetRouteReport], RAX
;------------------------------------------------
;       * * *  System Stoped
;------------------------------------------------
jmpControlStop@ServiceMain:
	mov RAX, [lpFileReport]
	or  RAX, RAX
	jnz jmpTimeOut@ServiceMain

		cmp EAX, [ThreadServerCtrl]
		je jmpServiceStop@ServiceMain
;------------------------------------------------
;       * * *  Wait
;------------------------------------------------
		mov RCX, [hFileReport]
		jRCXz jmpSleep@ServiceMain

			call [CloseHandle]

			xor RAX, RAX
			mov [hFileReport], RAX

jmpSleep@ServiceMain:
		param 1, WAIT_POST_TIMEOUT
		call [Sleep]
;------------------------------------------------
;       * * *  Scan TimeOut
;------------------------------------------------
jmpTimeOut@ServiceMain:
	call [GetTickCount]
	cmp RAX, [TimeDelay]
	jb jmpMainLoop@ServiceMain

		mov [PortTimeOut], RAX
		add RAX, [ServerConfig.MaxTimeOut]
		mov [TimeDelay], RAX
;------------------------------------------------
;       * * *  Find Free Socket
;------------------------------------------------
	mov RDI, [TabSocketIoData]
	mov RCX, [ServerConfig.MaxConnections]

jmpFindPort@ServiceMain:
	xor RAX, RAX
	repz scasq
	jz jmpMainLoop@ServiceMain

		mov RBX, [RDI-8]
		mov [lpTimeIoData], RBX

		mov RAX, [RBX+PORT_IO_DATA.TimeLimit]
		cmp RAX, [PortTimeOut]
		ja jmpFindPort@ServiceMain

			mov DX, [RBX+PORT_IO_DATA.Connection]
			xor RAX, RAX
			mov [EBX+PORT_IO_DATA.Connection], AX
			cmp [EBX+PORT_IO_DATA.Route], AX
			jne jmpFindPort@ServiceMain
;------------------------------------------------
;       * * *  Post Close
;------------------------------------------------
		or DX, DX
		jnz jmpFindPort@ServiceMain

			mov [SetListSocket], RDI
			mov [Count], RCX

			lea RSI, [RBX+PORT_IO_DATA.NetHost]
			mov RDI, TimeOutReport.NetHost
			mov RCX, REPORT_INFO_PORT
			rep movsq
;------------------------------------------------
;       * * *  Post Shutdown
;------------------------------------------------
			mov CL,  SD_BOTH
			param 2, RCX
			param 1, [RBX+PORT_IO_DATA.Socket]
			call [shutdown]

			mov DL, SRV_MSG_TimeOut
			or EAX, EAX
			jz jmpReport@ServiceMain
;------------------------------------------------
;       * * *  Post Kill
;------------------------------------------------
				mov RSI, [lpTimeIoData]
				mov RDI, [RSI+PORT_IO_DATA.TablePort]
				xor RAX, RAX
				mov [RDI], RAX

				param 1, RSI
				param 2, RAX
				param 3, MEM_RELEASE
				call [VirtualFree]

				mov DL, SYS_ERR_TimeShutDown
;------------------------------------------------
;       * * *  Report Close
;------------------------------------------------
jmpReport@ServiceMain:
			mov [TimeOutReport.Index], EDX
			call [WSAGetLastError]
			mov [TimeOutReport.Error], EAX

			mov RAX, TimeOutReport
			call WriteReport

			mov RDI, [SetListSocket]
			mov RCX, [Count]
			jmp jmpFindPort@ServiceMain
;------------------------------------------------
;       * * *  Server Stoped
;------------------------------------------------
jmpServiceError@ServiceMain:
	call FileReport
;------------------------------------------------
;       * * *  Server Stoped
;------------------------------------------------
jmpServiceStop@ServiceMain:
	xor RCX, RCX
	mov  CX, WORK_EXIT_TIMEOUT
	call [Sleep]

	mov EAX, [ThreadListenCtrl]
	or  EAX, [ThreadProcessCtrl]
	or  EAX, [ThreadSocketCtrl]
	jnz jmpServiceStop@ServiceMain
;------------------------------------------------
;       * * *  Close All PortSockets
;------------------------------------------------
	mov RDI, [TabSocketIoData]
	or  RDI, RDI 
	jz jmpPortClose@ServiceMain
		mov RCX, [ServerConfig.MaxConnections]

jmpScanSocket@ServiceMain:
		xor RAX, RAX
		repz scasq
		jz jmpPortClose@ServiceMain

			mov [ServerConfig.MaxConnections], RCX
			mov [SetListSocket], RDI

			mov RBX, [RDI-8]
			mov [lpTimeIoData], RBX
			mov [TimeDelay], RCX

			param 1, [RBX+PORT_IO_DATA.hFile]
			jRCXz jmpFreeMemory@ServiceMain

				call [CloseHandle]

jmpFreeMemory@ServiceMain:
			mov RSI, [lpTimeIoData]
			param 1, [RSI+PORT_IO_DATA.Socket]
			call [closesocket]

			param 1, [lpTimeIoData]
			param 2, 0
			param 3, MEM_RELEASE
			call [VirtualFree]

			mov RDI, [SetListSocket]
			mov RCX, [TimeDelay]
			jmp jmpScanSocket@ServiceMain
;------------------------------------------------
;       * * *  Port Close
;------------------------------------------------
jmpPortClose@ServiceMain:
	param 1, [hPortIOSocket]
	call [CloseHandle]
	call [WSACleanup]
;------------------------------------------------
;       * * *  Free ReportBuffer
;------------------------------------------------
	param 1, [TabSocketIoData]
	param 2, 0
	param 3, MEM_RELEASE
	call [VirtualFree]
;------------------------------------------------
;       * * *  Service Stoped
;------------------------------------------------
	xor EAX, EAX
	mov [SrvStatus.dwControlsAccepted], EAX
	mov [SrvStatus.dwWaitHint], EAX
	inc EAX
	mov [SrvStatus.dwCurrentState], EAX

	param 1, [hStatus]
	param 2, SrvStatus
	call [SetServiceStatus]

	or EAX, EAX
	jnz jmpEnd@ServiceMain

		mov  DL, SYS_ERR_Stop
		call FileReport
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
jmpEnd@ServiceMain:
	xor RCX, RCX
	mov CL,  64
	add RSP, RCX
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------