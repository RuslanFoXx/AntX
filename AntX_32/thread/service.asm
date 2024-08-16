;------------------------------------------------
;	AntX Web Server
;	THREAD: Service + Report + TimeOut
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Set ServiceStatus  * * *
;------------------------------------------------
proc SetService

	mov EBX, SrvStatus
	mov EDI, EBX
	mov EAX, SERVICE_WIN32_OWN_PROCESS
	stosd
	mov EAX, EDX
	stosd

	mov ECX, SERVICE_STATUS_COUNT-2
	xor EAX, EAX
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
	push EBX
	push [hStatus]
	call [SetServiceStatus]
	ret
endp
;------------------------------------------------
;       * * *  ServiceHandle  * * *
;------------------------------------------------
proc ServiceHandler Control

	mov EAX, [Control]
	cmp EAX, SERVICE_CONTROL_STOP
	je jmpStop@ServiceHandler

	cmp EAX, SERVICE_CONTROL_SHUTDOWN
	jne jmpEnd@ServiceHandler
;------------------------------------------------
;       * * *  Set Status  * * *
;------------------------------------------------
	mov EAX, [lppReportMessages+SYS_MSG_ShutDown*4]
	mov [lppReportMessages+SYS_MSG_Stop*4], EAX  

jmpStop@ServiceHandler:
	mov [SrvStatus.dwCurrentState], SERVICE_STOP_PENDING
	mov [SrvStatus.dwCheckPoint],   WAIT_SERVICE_HINT
	inc [SrvStatus.dwWaitHint]

	push SrvStatus
	push [hStatus]
	call [SetServiceStatus]

	or EAX, EAX
	jnz jmpSet@ServiceHandler

		mov  DL, SYS_ERR_StopPending
		call FileReport

jmpSet@ServiceHandler:
	xor EAX, EAX
	mov [ThreadServerCtrl], EAX

jmpEnd@ServiceHandler:
	ret
endp
;------------------------------------------------
;       * * *  MAIN Process (Service)  * * *
;------------------------------------------------
proc ServiceMain Count, Agv

local PortTimeOut  DWORD ?
local TimeDelay    DWORD ?
local lpTimeIoData LPPORT_IO_DATA ?
;------------------------------------------------
;      * * *  ServiceHandler
;------------------------------------------------
	mov [SrvStatus.dwCurrentState], SERVICE_START_PENDING
	mov [SrvStatus.dwServiceType],  SERVICE_WIN32_OWN_PROCESS
	mov [SrvStatus.dwWaitHint],     WAIT_SERVICE_HINT
	inc [SrvStatus.dwCheckPoint]

	push ServiceHandler
	push szServiceName
	call [RegisterServiceCtrlHandler]

	mov DL, SYS_ERR_Register
	or EAX, EAX
	jz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Start Service
;------------------------------------------------
	mov [hStatus], EAX
	push SrvStatus
	push EAX  ;  [hStatus]
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
;       * * *  Running Services
;------------------------------------------------
	xor EAX, EAX
	mov [SrvStatus.dwCheckPoint], EAX
	mov [SrvStatus.dwWaitHint],   EAX
	mov [SrvStatus.dwCurrentState],     SERVICE_RUNNING
	mov [SrvStatus.dwControlsAccepted], SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_SHUTDOWN

	push SrvStatus
	push [hStatus]
	call [SetServiceStatus]
	mov   DL, SYS_ERR_Start

	or EAX, EAX
	jz jmpServiceError@ServiceMain
;------------------------------------------------
;       * * *  Get All Reports
;------------------------------------------------
	mov EDI, SystemReport
	xor EAX, EAX
	mov ECX, EAX
	mov  CL, 3 * REPORT_INFO_COUNT
	rep stosd

	mov [TimeDelay], EAX
	inc EAX
	mov [ThreadServerCtrl], EAX
;------------------------------------------------
;       * * *  Get ProcessReport
;------------------------------------------------
jmpMainLoop@ServiceMain:
	xor EAX, EAX
	mov [lpFileReport], EAX

	mov ECX, [SystemReport.Index]
	jECXz jmpGetSocketReport@ServiceMain

		mov EAX, SystemReport
		call WriteReport

		xor EAX, EAX
		mov [SystemReport.Index], EAX
;------------------------------------------------
;       * * *  Get RouterReport
;------------------------------------------------
jmpGetSocketReport@ServiceMain:
	mov ECX, [RouterReport.Index]
	jECXz jmpGetListenReport@ServiceMain

		mov EAX, RouterReport
		call WriteReport

		xor EAX, EAX
		mov [RouterReport.Index], EAX
;------------------------------------------------
;       * * *  Get ListenReport
;------------------------------------------------
jmpGetListenReport@ServiceMain:
	mov EAX, [GetListenReport]
	cmp EAX, [SetListenReport]
	je jmpGetRouteReport@ServiceMain

		call WriteReport

		lea EAX, [ESI+REPORT_INFO_SIZE]
		cmp EAX, [MaxListenReport]
		jb jmpSetListenReport@ServiceMain
			mov EAX, [TabListenReport]

jmpSetListenReport@ServiceMain:
		mov [GetListenReport], EAX
;------------------------------------------------
;       * * *  Get RouteReport
;------------------------------------------------
jmpGetRouteReport@ServiceMain:
	mov EAX, [GetRouteReport]
	cmp EAX, [SetRouteReport]
	je jmpControlStop@ServiceMain

		call WriteReport

		lea EAX, [ESI+REPORT_INFO_PATH_SIZE]
		cmp EAX, [MaxRouteReport]
		jb jmpSetRouteReport@ServiceMain
			mov EAX, [TabRouteReport]

jmpSetRouteReport@ServiceMain:
		mov [GetRouteReport], EAX
;------------------------------------------------
;       * * *  System Stoped
;------------------------------------------------
jmpControlStop@ServiceMain:
	mov EAX, [lpFileReport]
	or  EAX, EAX
	jnz jmpTimeOut@ServiceMain

		cmp EAX, [ThreadServerCtrl]
		je jmpServiceStop@ServiceMain
;------------------------------------------------
;       * * *  Wait
;------------------------------------------------
		mov ECX, [hFileReport]
		jECXz jmpSleep@ServiceMain

			push ECX
			call [CloseHandle]

			xor EAX, EAX
			mov [hFileReport], EAX

jmpSleep@ServiceMain:
		push WAIT_POST_TIMEOUT
		call [Sleep]
;------------------------------------------------
;       * * *  Scan TimeOut
;------------------------------------------------
jmpTimeOut@ServiceMain:
	call [GetTickCount]
	cmp EAX, [TimeDelay]
	jb jmpMainLoop@ServiceMain

		mov [PortTimeOut], EAX
		add EAX, [ServerConfig.MaxTimeOut]
		mov [TimeDelay], EAX
;------------------------------------------------
;       * * *  Find Free Socket
;------------------------------------------------
	mov EDI, [TabSocketIoData]
	mov ECX, [ServerConfig.MaxConnections]

jmpFindPort@ServiceMain:
	xor EAX, EAX
	repz scasd
	jz jmpMainLoop@ServiceMain

		mov EBX, [EDI-4]
		mov [lpTimeIoData], EBX

		mov EAX, [EBX+PORT_IO_DATA.TimeLimit]
		cmp EAX, [PortTimeOut]
		ja jmpFindPort@ServiceMain

			mov  DX, [EBX+PORT_IO_DATA.Connection]
			xor EAX, EAX
			mov [EBX+PORT_IO_DATA.Connection], AX
			cmp [EBX+PORT_IO_DATA.Route], AX
			jne jmpFindPort@ServiceMain
;------------------------------------------------
;       * * *  Post Close
;------------------------------------------------
		or DX, DX
		jnz jmpFindPort@ServiceMain

			push EDI
			push ECX        

			lea ESI, [EBX+PORT_IO_DATA.NetHost]
			mov EDI, TimeOutReport.NetHost
			mov ECX, REPORT_INFO_PORT
			rep movsd
;------------------------------------------------
;       * * *  Post Shutdown
;------------------------------------------------
			push SD_BOTH
			push [EBX+PORT_IO_DATA.Socket]
			call [shutdown]
			mov DL, SRV_MSG_TimeOut
			or EAX, EAX
			jz jmpReport@ServiceMain
;------------------------------------------------
;       * * *  Post Kill
;------------------------------------------------
				mov ESI, [lpTimeIoData]
				mov EDI, [ESI+PORT_IO_DATA.TablePort]
				xor EAX, EAX
				mov [EDI], EAX

				push MEM_RELEASE
				push EAX
				push ESI
				call [VirtualFree]

				mov DL, SYS_ERR_TimeShutDown
;------------------------------------------------
;       * * *  Report Close
;------------------------------------------------
jmpReport@ServiceMain:
			mov [TimeOutReport.Index], EDX
			call [WSAGetLastError]
			mov [TimeOutReport.Error], EAX

			mov EAX, TimeOutReport
			call WriteReport

			pop ECX
			pop EDI
			jmp jmpMainLoop@ServiceMain
;------------------------------------------------
;       * * *  Server Stoped
;------------------------------------------------
jmpServiceError@ServiceMain:
	call FileReport
;------------------------------------------------
;       * * *  Server Stoped
;------------------------------------------------
jmpServiceStop@ServiceMain:
	push WORK_EXIT_TIMEOUT
	call [Sleep]

	mov EAX, [ThreadListenCtrl]
	or  EAX, [ThreadProcessCtrl]
	or  EAX, [ThreadSocketCtrl]
	jnz jmpServiceStop@ServiceMain
;------------------------------------------------
;       * * *  Close All ListSockets
;------------------------------------------------
	mov EDI, [TabSocketIoData]
	or  EDI, EDI
	jz jmpPortClose@ServiceMain
		mov ECX, [ServerConfig.MaxConnections]

jmpScanSocket@ServiceMain:
		xor EAX, EAX
		repz scasd
		jz jmpPortClose@ServiceMain
			mov ESI, [EDI-4]
			mov [lpTimeIoData], ESI
			push ECX
			push EDI
			push MEM_RELEASE
			xor EAX, EAX
			push EAX
			push ESI
			push [ESI+PORT_IO_DATA.Socket]

			mov ECX, [ESI+PORT_IO_DATA.hFile]
			jECXz jmpFreeMemory@ServiceMain

				push ECX
				call [CloseHandle]

jmpFreeMemory@ServiceMain:
			call [closesocket]
			call [VirtualFree]

			pop EDI
			pop ECX
			jmp jmpScanSocket@ServiceMain
;------------------------------------------------
;       * * *  Port Close
;------------------------------------------------
jmpPortClose@ServiceMain:
	push [hPortIOSocket]
	call [CloseHandle]
	call [WSACleanup]
;------------------------------------------------
;       * * *  Free ReportBuffer
;------------------------------------------------
	push MEM_RELEASE
	xor EAX, EAX
	push EAX
	push [TabSocketIoData]
	call [VirtualFree]
;------------------------------------------------
;       * * *  Service Stoped
;------------------------------------------------
	xor EAX, EAX
	mov [SrvStatus.dwControlsAccepted], EAX
	mov [SrvStatus.dwWaitHint], EAX
	inc EAX
	mov [SrvStatus.dwCurrentState], EAX

	push SrvStatus
	push [hStatus]
	call [SetServiceStatus]

	or EAX, EAX
	jnz jmpEnd@ServiceMain

		mov  DL, SYS_ERR_Stop
		call FileReport
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
jmpEnd@ServiceMain:
	xor EAX, EAX
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------