;------------------------------------------------
;	AntX Web Server
;	MAIN: Init Resource
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;section '.code' code readable executable
;------------------------------------------------
;   * * *  Includes System Modules
;------------------------------------------------
include 'proc\string.asm'
include 'proc\report.asm'
include 'proc\config.asm'

include 'http\header.asm'
include 'http\method.asm'

include 'thread\service.asm'
include 'thread\listen.asm'
include 'thread\route.asm'
include 'thread\process.asm'
;------------------------------------------------
;   * * *  Import Library Procedures * * *
;------------------------------------------------
section '.idata' import data readable writeable

DD 0,0,0,  RVA szKernel32,	RVA LibraryKernel32
DD 0,0,0,  RVA szWinSocket2,	RVA LibraryWinSocket2
DD 0,0,0,  RVA szAdvAPI32,	RVA LibraryAdvAPI32
DD 0,0,0,0,0
;------------------------------------------------
;   * * *  Import Table Kernel32 * * *
;------------------------------------------------
LibraryKernel32:

GetLastError			DD RVA szGetLastError
VirtualAlloc			DD RVA szVirtualAlloc
VirtualFree			DD RVA szVirtualFree
GetTickCount			DD RVA szGetTickCount
GetLocalTime			DD RVA szGetLocalTime
GetSystemTime			DD RVA szGetSystemTime 
GetCommandLine			DD RVA szGetCommandLine
CreateIoCompletionPort		DD RVA szCreateIoCompletionPort
GetQueuedCompletionStatus	DD RVA szGetQueuedCompletionStatus
PostQueuedCompletionStatus	DD RVA szPostQueuedCompletionStatus
SetHandleInformation		DD RVA szSetHandleInformation
CloseHandle			DD RVA szCloseHandle
Sleep				DD RVA szSleep
CreateEvent			DD RVA szCreateEvent
SetEvent			DD RVA szSetEvent
CreateThread			DD RVA szCreateThread
ExitThread			DD RVA szExitThread
CreateProcess			DD RVA szCreateProcess
ExitProcess			DD RVA szExitProcess
GetExitCodeProcess		DD RVA szGetExitCodeProcess
WaitForMultipleObjects		DD RVA szWaitForMultipleObjects
TerminateProcess		DD RVA szTerminateProcess
CreatePipe			DD RVA szCreatePipe
CreateFile			DD RVA szCreateFile
GetFileType			DD RVA szGetFileType
GetFileSizeEx			DD RVA szGetFileSizeEx
ReadFile			DD RVA szReadFile
WriteFile			DD RVA szWriteFile
EndTableKernel32		DD NULL
;------------------------------------------------
;   * * *  Import Table WinSocket2 * * *
;------------------------------------------------
LibraryWinSocket2:

setsockopt			DD RVA szSetSockOpt
bind				DD RVA szBinding
listen				DD RVA szListen
shutdown			DD RVA szShutdown
closesocket			DD RVA szCloseSocket
WSAStartup			DD RVA szWSAStartup
WSAGetLastError			DD RVA szWSAGetLastError
WSACreateEvent			DD RVA szWSACreateEvent
WSAEnumNetworkEvents		DD RVA szWSAEnumNetworkEvents
WSAWaitForMultipleEvents	DD RVA szWSAWaitForMultipleEvents
WSAEventSelect			DD RVA szWSAEventSelect
WSACloseEvent			DD RVA szWSACloseEvent
WSASocket			DD RVA szWSASocket
WSAAccept			DD RVA szWSAAccept
WSASend				DD RVA szWSASend
WSARecv				DD RVA szWSARecv
WSACleanup			DD RVA szWSACleanup
EndTableWinSocket2		DD NULL
;------------------------------------------------
;   * * *  Import Table AdvAPI32 * * *
;------------------------------------------------
LibraryAdvAPI32:

SetServiceStatus		DD RVA szSetServiceStatus
RegisterServiceCtrlHandler	DD RVA szRegisterServiceCtrlHandler
StartServiceCtrlDispatcher	DD RVA szStartServiceCtrlDispatcher
EndTableAdvAPI32		DD NULL
;------------------------------------------------
;   * * *  Init Service Dispacher  * * *
;------------------------------------------------
ServiceTable			DD szServiceName, ServiceMain, NULL, NULL
SizeOfAddrIn			DD SOCKADDR_IN_SIZE
;------------------------------------------------
;       * * *  WinAPI ProcNames
;------------------------------------------------
szKernel32			DB 'KERNEL32.DLL',0
szAdvAPI32			DB 'ADVAPI32.DLL',0
szWinSocket2			DB 'WS2_32.DLL',0
szServiceName			DB 'AntXServer',0

szGetLastError			DB 0,0, 'GetLastError',0
szVirtualAlloc			DB 0,0, 'VirtualAlloc',0
szVirtualFree			DB 0,0, 'VirtualFree',0
szGetTickCount			DB 0,0, 'GetTickCount',0
szGetLocalTime			DB 0,0, 'GetLocalTime',0
szGetSystemTime			DB 0,0, 'GetSystemTime',0
szGetCommandLine		DB 0,0, 'GetCommandLineA',0
szCreateIoCompletionPort	DB 0,0, 'CreateIoCompletionPort',0
szGetQueuedCompletionStatus	DB 0,0, 'GetQueuedCompletionStatus',0
szPostQueuedCompletionStatus	DB 0,0, 'PostQueuedCompletionStatus',0
szSetHandleInformation		DB 0,0, 'SetHandleInformation',0
szCloseHandle			DB 0,0, 'CloseHandle',0
szSleep				DB 0,0, 'Sleep',0
szCreateEvent			DB 0,0, 'CreateEventA',0
szSetEvent			DB 0,0, 'SetEvent',0
szCreateThread			DB 0,0, 'CreateThread',0
szExitThread			DB 0,0, 'ExitThread',0
szCreateProcess			DB 0,0, 'CreateProcessA',0
szExitProcess			DB 0,0, 'ExitProcess',0
szGetExitCodeProcess		DB 0,0, 'GetExitCodeProcess',0
szWaitForMultipleObjects	DB 0,0, 'WaitForMultipleObjects',0
szTerminateProcess		DB 0,0, 'TerminateProcess',0
szCreatePipe			DB 0,0, 'CreatePipe',0
szCreateFile			DB 0,0, 'CreateFileA',0
szGetFileType			DB 0,0, 'GetFileType',0
szGetFileSizeEx			DB 0,0, 'GetFileSizeEx',0
szReadFile			DB 0,0, 'ReadFile',0
szWriteFile			DB 0,0, 'WriteFile',0

szSetSockOpt			DB 0,0, 'setsockopt',0
szBinding			DB 0,0, 'bind',0
szListen			DB 0,0, 'listen',0
szShutdown			DB 0,0, 'shutdown',0
szCloseSocket			DB 0,0, 'closesocket',0
szWSAStartup			DB 0,0, 'WSAStartup',0
szWSAGetLastError		DB 0,0, 'WSAGetLastError',0
szWSACreateEvent		DB 0,0, 'WSACreateEvent',0
szWSAEnumNetworkEvents		DB 0,0, 'WSAEnumNetworkEvents',0
szWSAWaitForMultipleEvents	DB 0,0, 'WSAWaitForMultipleEvents',0
szWSAEventSelect		DB 0,0, 'WSAEventSelect',0
szWSACloseEvent			DB 0,0, 'WSACloseEvent',0
szWSASocket			DB 0,0, 'WSASocketA',0
szWSAAccept			DB 0,0, 'WSAAccept',0
szWSASend			DB 0,0, 'WSASend',0
szWSARecv			DB 0,0, 'WSARecv',0
szWSACleanup			DB 0,0, 'WSACleanup',0

szSetServiceStatus		DB 0,0, 'SetServiceStatus',0
szRegisterServiceCtrlHandler	DB 0,0, 'RegisterServiceCtrlHandlerA',0
szStartServiceCtrlDispatcher	DB 0,0, 'StartServiceCtrlDispatcherA',0
;------------------------------------------------
;   * * *  Init Server Headers  * * *
;------------------------------------------------
szHeaderServer			DB 13,10, 'Server: AntX/1.75 x32'
szVersionServer			DB 13,10, 'Date: '
szHeaderType			DB ' GMT'
				DB 13,10, 'Content-Type: '
szHeaderDisposition		DB 13,10, 'Content-Disposition: '
szHeaderLength			DB 13,10, 'Content-Length: '
szHeaderConnection		DB 13,10, 'Connection: '
szClose				DB 'close'
szKeepAlive			DB 'keep-alive'
szKeepAliveEnd:
;------------------------------------------------
;   * * *  Init Const Strings  * * *
;------------------------------------------------
szTagOk				DB  2, 'Ok'
szHeaderTextHtml		DB  9, 'text/html'
;------------------------------------------------
;   * * *  ConfigParamWords
;------------------------------------------------
sWeekDateHeader			DB 'Sun,Mon,Tue,Wed,Thu,Fri,Sat,'
sMonthDateHeader		DB 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec '
sServerConfigParam		DB 4,'File',5,'Stack',7,'Connect',7,'Process',4,'Time',6,'Buffer',6, 'Header',4,'Recv',4,'Send',4,'Pipe',4,'Temp',6,'Report'
sGetHttpMethod			DB 3,'200',3,'201',3,'400',3,'403',3,'404',3,'500',3,'501',3,'503'
sRunningExtParam		DB 3,'Ask',4,'Type',11,'Disposition',3,'Dir',3,'Run',3,'Cmd'
sHostPathParam			DB 4,'Host',7,'Address',4,'Site',4,'Code',4,'Page',0,0
sHexScaleChar			DB '0123456789ABCDEF'
;------------------------------------------------
;       * * *  Init Server Params  * * *
;------------------------------------------------
section '.data' data readable writeable

sStrByteScale			DD MAX_INT_SCALE dup(?)
ServerTime			SYSTEMTIME ?
LocalTime			SYSTEMTIME ?

Method				DWORD ?
TotalHost			DWORD ?
TotalProcess			DWORD ?

GetNetHost			LPNET_HOST ?
SetRunProc			LPASK_EXT ?
GetRunProc			LPASK_EXT ?
pBuffer				PCHAR ?
pFind				PCHAR ?
;------------------------------------------------
;       * * *  Init Service DataSection
;------------------------------------------------
ThreadServerCtrl		DWORD ?
ThreadSocketCtrl		DWORD ?
ThreadListenCtrl		DWORD ?
ThreadProcessCtrl		DWORD ?

hFileReport			HANDLE ?
hPortIOSocket			HANDLE ?
hStatus				SERVICE_STATUS_HANDLE ?

SrvStatus			SERVICE_STATUS ?
dSecurity			SECURITY_ATTRIBUTES ?
Address				sockaddr_in ?
;------------------------------------------------
;       * * *  Init Config DataSection
;------------------------------------------------
SocketDataSize			DWORD ?
ServerResurseId			DWORD ?
SetOptionPort			DWORD ?
CountProcess			DWORD ?
Param				DWORD ?
PostBytes			DWORD ?
PipeBytes			DWORD ?
TotalBytes			DWORD ?
CountBytes			DWORD ?
TransBytes			DWORD ?
TransFlag			DWORD ?

ServerConfig			SERVER_CONFIG ?
lppTagRespont			RESPONT_HEADER ?
lppReportMessages 		DD REPORT_MESSAGE_COUNT dup(?)
;------------------------------------------------
;       * * *  Init Table Buffer
;------------------------------------------------
GetMemoryBuffer:
TabSocketIoData			LPPORT_IO_DATA ?

TabListenReport			LPREPORT_INFO ?
GetListenReport			LPREPORT_INFO ?
SetListenReport			LPREPORT_INFO ?
MaxListenReport:

TabRouteReport			LPREPORT_INFO ?
GetRouteReport			LPREPORT_INFO ?
SetRouteReport			LPREPORT_INFO ?
MaxRouteReport:

TabQueuedProcess		LPPORT_IO_DATA ?
GetQueuedProcess		LPPORT_IO_DATA ?
SetQueuedProcess		LPPORT_IO_DATA ?
MaxQueuedProcess		LPPORT_IO_DATA ?
;------------------------------------------------
;       * * *  Init Report DataSection
;------------------------------------------------
lpFileReport			LPREPORT_INFO ?

ListenReport			ACCEPT_HEADER ?
RouterHeader			REPORT_HEADER ?

SystemReport			REPORT_INFO ?
RouterReport			REPORT_INFO ?
TimeOutReport			REPORT_INFO ?
;------------------------------------------------
;       * * *  Init Router DataSection
;------------------------------------------------
lpPortIoCompletion		LPVOID ?
lpSocketIoData			LPPORT_IO_DATA ?
TransferredBytes		DWORD ?
;------------------------------------------------
;       * * *  Init Listener DataSection
;------------------------------------------------
WSockVer			WSADATA ?
ListenEvent			WSANETWORKEVENTS ?

TabListenSocket	SOCKET		MAX_NET_HOST dup(?)
TabNetEvent			WSAEVENT MAX_NET_HOST dup(?)
TabNetHost			DB NET_HOST_SIZE * MAX_NET_HOST dup(?)
;------------------------------------------------
;       * * *  Init Process DataSection
;------------------------------------------------
hInPipe				HANDLE ?
hOutPipe			HANDLE ?

StartRunInfo			STARTUPINFO ?
ProcRunInfo			PROCESS_INFORMATION ?

ErrRunProcess			ASK_EXT ?
DefRunProcess			ASK_EXT ?
TabRunProcess			DB ASK_EXT_SIZE * MAX_RUN_PROC dup(?)

RunProcessSocket		LPPORT_IO_DATA MAXIMUM_WAIT_OBJECTS dup(?)
RunProcessEvent			HANDLE MAXIMUM_WAIT_OBJECTS dup(?)
;------------------------------------------------
;       * * *  Init Buffers
;------------------------------------------------
TabConfig:
szProcPath			DB MAX_PATH_SIZE dup(?)
szProcDir			DB MAX_PATH_SIZE dup(?)
szCmdPath			DB MAX_PATH_SIZE dup(?)

szFileName			DB MAX_PATH_SIZE dup(?)
szMoveName			DB MAX_PATH_SIZE dup(?)
;------------------------------------------------
;       * * *  Strings Buffer
;------------------------------------------------
szReportName			DB MAX_PATH_SIZE dup(?)
_DataBuffer_			DB CONFIG_BUFFER_SIZE dup(?)
szTextReport			DB REPORT_BUFFER_SIZE dup(?)
;------------------------------------------------
;   * * *   END  * * *
;------------------------------------------------
