#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#MaxThreadsPerHotkey 2 
#SingleInstance Force
DetectHiddenWindows, off


;消息("重载···")

TopRightClick(){
	; 消息("切换窗口，置底！")
	send ^!{Esc} 
	; ActPrvWindow(0)
}

Acc_Init() {
	Static	h
	If Not	h
		h:=DllCall("LoadLibrary","Str","oleacc","Ptr")
}
Acc_Query(Acc) { ; thanks Lexikos - www.autohotkey.com/forum/viewtopic.php?t=81731&p=509530#509530
	try return ComObj(9, ComObjQuery(Acc,"{618736e0-3c3d-11cf-810c-00aa00389b71}"), 1)
}
Acc_Error(p="") {
	static setting:=0
	return p=""?setting:setting:=p
}
Acc_GetStateText(nState)
{
	nSize := DllCall("oleacc\GetStateText", "Uint", nState, "Ptr", 0, "Uint", 0)
	VarSetCapacity(sState, (A_IsUnicode?2:1)*nSize)
	DllCall("oleacc\GetStateText", "Uint", nState, "str", sState, "Uint", nSize+1)
	Return	sState
}
Acc_Children(Acc) {
	if ComObjType(Acc,"Name") != "IAccessible"
		ErrorLevel := "Invalid IAccessible Object"
	else {
		Acc_Init(), cChildren:=Acc.accChildCount, Children:=[]
		if DllCall("oleacc\AccessibleChildren", "Ptr",ComObjValue(Acc), "Int",0, "Int",cChildren, "Ptr",VarSetCapacity(varChildren,cChildren*(8+2*A_PtrSize),0)*0+&varChildren, "Int*",cChildren)=0 {
			Loop %cChildren%
				i:=(A_Index-1)*(A_PtrSize*2+8)+8, child:=NumGet(varChildren,i), Children.Insert(NumGet(varChildren,i-8)=9?Acc_Query(child):child), NumGet(varChildren,i-8)=9?ObjRelease(child):
			return Children.MaxIndex()?Children:
		} else
			ErrorLevel := "AccessibleChildren DllCall Failed"
	}
	if Acc_Error()
		throw Exception(ErrorLevel,-1)
}
Acc_Location(Acc, ChildId=0, byref Position="") { ; adapted from Sean's code
	try Acc.accLocation(ComObj(0x4003,&x:=0), ComObj(0x4003,&y:=0), ComObj(0x4003,&w:=0), ComObj(0x4003,&h:=0), ChildId)
	catch
		return
	Position := "x" NumGet(x,0,"int") " y" NumGet(y,0,"int") " w" NumGet(w,0,"int") " h" NumGet(h,0,"int")
	return	{x:NumGet(x,0,"int"), y:NumGet(y,0,"int"), w:NumGet(w,0,"int"), h:NumGet(h,0,"int")}
}
Acc_State(Acc, ChildId=0) {
	try return ComObjType(Acc,"Name")="IAccessible"?Acc_GetStateText(Acc.accState(ChildId)):"invalid object"
}
Acc_ObjectFromWindow(hWnd, idObject = -4)
{
	Acc_Init()
	If	DllCall("oleacc\AccessibleObjectFromWindow", "Ptr", hWnd, "UInt", idObject&=0xFFFFFFFF, "Ptr", -VarSetCapacity(IID,16)+NumPut(idObject==0xFFFFFFF0?0x46000000000000C0:0x719B3800AA000C81,NumPut(idObject==0xFFFFFFF0?0x0000000000020400:0x11CF3C3D618736E0,IID,"Int64"),"Int64"), "Ptr*", pacc)=0
	Return	ComObjEnwrap(9,pacc,1)
}

global accToolBar
global hToolBar

Loop {
	ControlGetText, Text, MSTaskListWClass%A_Index%, ahk_class Shell_TrayWnd
	If (ErrorLevel) {
		ExitApp
	}
	If (Text = "Running Applications") {
		ControlGet, hwnd, hwnd,, MSTaskListWClass%A_Index%, ahk_class Shell_TrayWnd
		hToolBar := hwnd
		accToolBar := Acc_ObjectFromWindow(hwnd)
		Break
	}
	; MsgBox, 4, , %Text%`n`nContinue?
	; IfMsgBox, NO, break
}

; For Each, Child In Acc_Children(accToolBar) {
; 	If (Acc_Location(accToolBar, child).w) {
; 		Try
; 		{
; 			t .= (Acc_State(accToolBar, child)="has Popup"? "--> ":"  ") accToolBar.accName(child) "`n"
; 			name := accToolBar.accName(child)
; 			FoundPos := InStr(name, "-" , false,  -1)
; 			if (FoundPos>0)
; 			{
; 				name :=  SubStr(name, 1, FoundPos - 2)
; 				;t .= name "`n"
; 				WinGet, id, list, %name%
; 				Loop, %id%
; 				{
; 					this_id := id%A_Index%
; 				}
; 			}
; 		}
; 	}
; }

; https://www.autohotkey.com/boards/viewtopic.php?t=94563
; MsgBox % t

TaskbarHotFrame()

loop 
{	
	WinGet, wid, ID, A
	WinWaitNotActive, ahk_id %wid%
	TaskbarHotFrame()
	; 消息("clipboard", "w550")
}

TaskbarHotFrame(){
	;return
	WinGetTitle, title, A
	title .= " - "
	For Each, Child In Acc_Children(accToolBar) {
		Try
		{
			loca := Acc_Location(accToolBar, child)
			If (loca.w) {
				name := accToolBar.accName(child)
				FoundPos := InStr(name, title , false,  -1)
				if (FoundPos=1)
				{
					;消息(loca.x " " loca.y " " loca.w " " loca.h)
					WinGet, wid, ID , ahk_class ptHotFrame
					WinGetPos, x, y, w, h, ahk_id hToolBar
					PostMessage, 0x401, x,y, , ahk_id %wid%
					PostMessage, 0x402, loca.x,loca.y, , ahk_id %wid%
					PostMessage, 0x403, loca.w,loca.h, , ahk_id %wid%
					PostMessage, 0x404, 0,0, , ahk_id %wid%
				}
			}
		}
	}
}

消息(Message,Width := "w150",Timeout := "-500", Title := "")  
{
	Progress, %Width% b1 zh0 fs18, %Message%,,%Title%,
			settimer, killAlert,%Timeout%
}

killAlert:
progress,off
return