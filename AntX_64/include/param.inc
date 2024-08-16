;------------------------------------------------
;	AntX Web Server
;	RESURSE: Set Parameters Macros
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Macros Param of Call
;------------------------------------------------
macro param n, expr{

	if n in <0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16>
	if n eq 0
		if expr eq 0
			xor RAX, RAX
		else
			mov RAX, expr
		end if
	else if n eq 1
		if expr eq 0
			xor RCX, RCX
		else
			mov RCX, expr
		end if
	else if n eq 2
		if expr eq 0
			xor RDX, RDX
		else
			mov RDX, expr
		end if
	else if n eq 3
		if expr eq 0
			xor R8, R8
		else
			mov R8, expr
		end if
	else if n eq 4
		if expr eq 0
			xor R9, R9
		else
			mov R9, expr
		end if
	else
		mov qword [RSP+(n*8-8)], expr
	end if
	else
		display "parameter " #`n# " is not valid."
		param n, expr
  end if			}
;------------------------------------------------
;       * * *   END  * * *
;------------------------------------------------
