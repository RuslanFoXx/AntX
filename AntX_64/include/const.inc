;------------------------------------------------
;	AntX Web Server
;	RESURSE: Define KeyWord Constants
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  HTTP Request Method  * * *
;------------------------------------------------
HTTP_200_OK				equ   0
HTTP_201_CREATE			equ   4
HTTP_400_BAD_REQUEST	equ   8
HTTP_403_FORBIDDEN		equ  12
HTTP_404_NOT_FOUND		equ  16
HTTP_405_ALLOWED		equ   ?
HTTP_500_INTERNAL		equ  20
HTTP_501_NOT_IMPLEMENT	equ  24
HTTP_503_BUSY			equ  28
;------------------------------------------------
;       * * *  Config Mode Params
;------------------------------------------------
CFG_PARAM_ENUM			equ   31		; SERVER_CONFIG_PARAM + RESPONT_HEADER_COUNT + ASK_EXT_PARAM +NET_HOST_PARAM

CFG_INDEX_PROCESS		equ   84		; SERVER_CONFIG_PARAM + RESPONT_HEADER_COUNT ( 12 + 8 )
CFG_INDEX_HOST			equ  108		; CFG_INDEX_PROCESS + ASK_EXT_PARAM ( 20 + 6 )

CFG_OFFSET_PROCESS		equ   84		; CFG_INDEX_PROCESS ( 80 )
CFG_OFFSET_HOST			equ  140		; CFG_INDEX_HOST + NET_HOST_SIZE ( 108 + 32 )
;------------------------------------------------
;       * * *  Define Constant KeyWords  * * *
;------------------------------------------------
HEADER_HTTP				equ 050545448h  ; HTTP-заголовок.
HEADER_HTTP_VER			equ 0312E312Fh  ; HTTP-версия.
HEADER_HTTP_VER64		equ 0312E312F50545448h  ;   HTTP/1.1-версия.
CONTENT_ID				equ 3D444952h   ; 'RID='.

ASK_EMPTY				equ       002h  ; Пустая строка "/"
CHR_CR					equ        0Dh  ; Пустая строка в заголовке: "\r"
CHR_LF					equ        0Ah  ; Пустая строка в заголовке: "\n"
END_CRLF				equ  0A0D0A0Dh  ; Пустая строка в заголовке: "\r\n\r\n"
CHR_CRLF				equ      0A0Dh  ; Пустая строка в заголовке: "\r\n"

EXT_LOG					equ 000676F6Ch  ; "log"
EXT_INI					equ 000696E69h  ; "ini"
EXT_HTML				equ 0006D7468h  ; "htm"

INS_TMP					equ 0706D742Eh  ; ".tmp"

SET_CASE_UP				equ       0DFh  ; C AND 223
SET_CASE_DOWN			equ       020h  ; c OR  32

KEY_CASE_UP				equ 0DFDFDFDFh  ; 'A-Z' AND 223
KEY_CASE_DOWN			equ 020202020h  ; 'a-z' OR  32
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------
