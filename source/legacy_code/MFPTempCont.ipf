#pragma rtGlobals=1		// Use modern global access method.

Menu "Macros"
	"MFP Temperature Control", MFPTempContDriver()
End

Function MFPTempContDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F MFPTempContPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:MFPTempCont
	
	//Variables declaration
	Variable rsense = NumVarOrDefault(":gRsense",0.89)
	Variable/G gRsense= rsense
	Variable rcant = NumVarOrDefault(":gRcant",3)
	Variable/G gRcant= rcant
	String /G gScanModeNames = "Contact;AC mode"
	Variable/G gScanMode = 1 // Contact, 2 for tapping
	
	mfpTempContSetup()
	
	//Check to make sure cables are properly plugged in:
	DoAlert 1,"Do you want me to check if all electrical connections\nhave correctly been wired?\n(Strongly Recommended)"
	if(V_flag==1)
		// Yes clicked
		CheckWiring()
	endif
	
	// Create the control panel.
	Execute "MFPTempContPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// MFP Temp Cont Demo PANEL ////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// This is the function renders the window and all widgets within for MFP Temp Cont Demo panel
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Window MFPTempContPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,325) as "MFP Temp Cont Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:MFPTempCont:gRsense,live= 1
	SetVariable sv_Setpoint,pos={16,49},size={180,18},title="Rcant set point (kOhm)", limits={0,inf,1}
	SetVariable sv_Setpoint,value= root:packages:MFPTempCont:gRcant,live= 1
	
	Popupmenu pp_scanmode,pos={16,80},size={135,18},title="Scan Mode"
	Popupmenu pp_scanmode,value= root:packages:MFPTempCont:gScanModeNames,live= 1, proc=ScanProc
	
	Button but_start,pos={16,112},size={67,20},title="Start PID", proc=MFPTempContButtonFunc
	//Button but_refresh,pos={16,112},size={130,22},title="Show Vout Vs Vsense", proc=MFPTempContButtonFunc
	Button but_stop,pos={133,112},size={63,20},title="Stop PID", proc=MFPTempContButtonFunc//, disable=2
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={103,115},size={15,15}, bodyWidth=15, barmisc={0,0}
	
	//SetDrawEnv linefgc= (17408,17408, 17408), linethick= 1.5, pos={164,112}
	
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 49,169, "Suhas Somnath, UIUC 2010"
	
End	

Function ScanProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFPTempCont
	NVAR gScanMode
	
	switch( pa.eventCode )
		case 2: // mouse up
			gScanMode = pa.popNum
			if (gScanMode == 1)
				MainPopupFunc("ImagingModePopup_0",1,"Contact")
			else
				MainPopupFunc("ImagingModePopup_0",2,"AC Mode")
			endif
			break
	endswitch
	
	SetDataFolder dfSave
	
End //LineLength

Function MFPTempContButtonFunc(ctrlname) : ButtonControl
	String ctrlname
	
	Variable RemInd = FindLast(CtrlName,"_")
	if (RemInd > -1)
		CtrlName = CtrlName[RemInd+1,Strlen(CtrlName)-1]
	else
		print "Error in Button function"
		return -1
	endif
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFPTempCont
		
	strswitch (ctrlName)

		case "start":
			//ModifyControl but_start, disable=2, title="Running..."
			//ModifyControl but_stop, disable=0
			
			startPID()
		break
		
		case "refresh":
			if(!exists("Vsens"))
				Make/O/N=1e5 Vsens, Vout
				td_xsetinwavepair(0,"12,12","Input.A",Vsens,"Output.A",Vout,"Vsens+=0; Vout+=0",5)
			endif
			RefreshGraphs()
		break
		
		case "stop":
			//ModifyControl but_stop, disable=2
			//ModifyControl but_start, disable=0, title="Start PID"
			StopDemo()
		break
			
	endswitch
	
	
	SetDataFolder dfSave
	
End

Function RefreshGraphs()
	
	// Forcing reacquisition of data
	td_WS("Event.12","once"); 
	
	DoWindow Graph0
	if (V_Flag != 0)
		KillWindow Graph0
	endif
	
	Wave Vout, Vsens
	
	display/K=1 Vsens, Vout
	ModifyGraph rgb(Vout)=(0,0,0)
	
End


Function startPID()
			
	NVAR gRsense, gRcant, gScanMode
	CrossPointSetup(Gscanmode)
	SetPID(-1*(1+(gRcant/gRsense)))
	//td_WV("PIDSLoop.5.Pgain",pgain);
	td_WS("Event.12","once"); 
	td_WV("PIDSLoop.5.Status",1);
	PIDPanelButtonFunc("Read",5)	
End

Function StopDemo()
	// Writing -1 is the only way to reset / modify a loop
	td_WV("PIDSLoop.5.Status",-1);
	//Safety Cutoff
	td_WV("Output.A",0.5)
	PIDPanelButtonFunc("Read",5)
End

Function SetPID(pgain)
	Variable pgain
	Wave/T parms
	// only modify Pgain and status
	parms[6] = num2str(pgain)
	parms[13] = "0"
	// but still have to rewrite the group to controller
	td_WG("PIDSLoop.5",parms)
	
End

function mfpTempContSetup()
	
	// 1. set up the CONSTANT / standard PIDS parameters with status = 0
	// 2. set up detrend to calculate Vcant into InA
	
	// 1. PIDS set up:
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFPTempCont
	
	// part a) -> intial standard set up	
	Make/O/T parms
	td_RG("PIDSLoop.5",parms)
	parms[0] = "Input.A" // Input Channel
	parms[1] = "Output.A" // Output channel
	parms[2] = "No" // Dynamic Setpoint
	parms[3] = "0" // Setpoint
	parms[4] = "0" // Setpoint offset
	parms[5] = "0" // DGain
	parms[6] = "-4" // P gain (~3 kOhm)
	parms[7] = "0" // I Gain
	parms[8] = "0" // S Gain
	parms[9] = "0" // Input Min
	parms[10] = "10" // Output Max
	td_WS("Event.13","once")
	parms[11] = "13" // Start Event
	parms[12] = "Never" // Stop Event
	parms[13] = "0"
	td_WG("PIDSLoop.5",parms)

	//Setting the status = 0 is equivalent to clicking the write button
	//PIDPanelButtonFunc("Write",5)
	PIDPanelButtonFunc("Read",5)
		
	// 4.  Setting up the detrend:
	// This will overwrite the input.A channel as the difference between the unaltered Input.A and the output.A.
	//Make/N=(2)/O SplitterWave;
	//SplitterWave={0,1}
	//td_SetDetrend("output.A", SplitterWave, "input.A")
	
	SetDataFolder DfSave
	
end

Function CrossPointSetup(scanmode)
	Variable Scanmode

	if (ScanMode == 1)
		// Contact mode:
		XPTPopupFunc("LoadXPTPopup",4,"DCScan")
	else 
		// AC mode:
		XPTPopupFunc("LoadXPTPopup",2,"ACScan")
	endif
		
	//Reading Vsense (later gets converted to Vcant)
	//td_WS("Crosspoint.InA","BNCIn0")
	WireXpt("InAPopup","BNCIn0")
	
	//Reading second channel - Vtotal
	//td_WS("Crosspoint.InB","BNCIn1")
	WireXpt("InBPopup","BNCIn1")
	
	//Setting up the output channel:
	//td_WS("Crosspoint.BNCOut0","")
	WireXpt("BNCOut0Popup","OutA")
	//XPTBoxFunc("XPTLock10Box_0",1)
	
	//Commiting all changes:
	ARCheckFunc("DontChangeXPTCheck",1)
	XptButtonFunc("WriteXPT")
	 // seems to annul all the changes made so far if I used td_WS
	
	//Positive voltage out of Output channel:
	td_WV("Output.A",0.5)
End

Function CheckWiring()
	// This will be executed AFTER the PID has been set up
	// In A must increase if Out A is increased.
	// Will try two values (eg 2V and 5V) to see if BNC cables have been
	// correctly set up.
	
	td_WV("Output.A",2)
		
	// wait for a second or so
	Variable t0 = ticks
	do
	while ((ticks - t0)/60 < 0.25)
	
	Variable in1 = td_RV("Input.A")
	
	td_WV("Output.A",5)
		
	// wait for a second or so
	t0 = ticks
	do
	while ((ticks - t0)/60 < 0.25)
	
	Variable in2 = td_RV("Input.A")
	
	// Almost shut off the voltage supply
	
	td_WV("Output.A",0.5)
	
	//print "in1 = " + num2str(in1) + ", in2 = " + num2str(in2)
	
	if(in2 > (in1+0.15) && in1 > 0.1)
		DoAlert 0,"Connections ok!"
	else
		DoAlert 0,"Cantilever improperly connected!\nPlease make sure to wire:\n1. Input0 to sense voltage\n2. Output0 to total voltage"
	endif

End

Function WireXpt(whichpopup,channel)
	String whichpopup, channel
	
	execute("XPTPopupFunc(\"" + whichpopup + "\",WhichListItem(\""+ channel +"\",Root:Packages:MFP3D:XPT:XPTInputList,\";\",0,0)+1,\""+ channel +"\")")

End

Function PIDPanelButtonFunc(action, loop)
	String action
	Variable loop
	
	if(loop > 5 || loop < 0)
		print "PIDPanelButtonFunc - Invalid loop number!"
		return -1
	endif
	
	Variable type = 0
	type += abs(cmpstr(action,"read"))
	type += abs(cmpstr(action,"write"))
	type += abs(cmpstr(action,"start"))
	type += abs(cmpstr(action,"stop"))
	if(type != 3)
		print "PIDPanelButtonFunc - Invalid action argument!"
		return -1
	endif
	
	Struct WMButtonAction InfoStruct
	InfoStruct.CtrlName = action+"PIDSLoop"+num2str(loop)
	InfoStruct.EventMod = 1
	InfoStruct.EventCode = 2
	PIDSLoopButtonFunc(InfoStruct)
End