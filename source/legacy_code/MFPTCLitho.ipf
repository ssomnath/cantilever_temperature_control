#pragma rtGlobals=1		// Use modern global access method.

Menu "Macros"
	"MFP Temperature Controlled Lithography", MFPTCLithoDriver()
End

Function MFPTCLithoDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F MFPTCLithoPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:MFPTCLitho
	
	//Variables declaration
	Variable rsense = NumVarOrDefault(":gRsense",0.89)
	Variable/G gRsense= rsense
	Variable RLitho = NumVarOrDefault(":gRLitho",4)
	Variable/G gRLitho= RLitho
	Variable RNorm = NumVarOrDefault(":gRNorm",3)
	Variable/G gRNorm= RNorm
	
	MFPTCLithoSetup()
	
	//Check to make sure cables are properly plugged in:
	DoAlert 1,"Do you want me to check if all electrical connections\nhave correctly been wired?\n(Strongly Recommended)"
	if(V_flag==1)
		// Yes clicked
		CheckWiring()
	endif
	
	// Create the control panel.
	Execute "MFPTCLithoPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// MFP TC Litho PANEL ////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// This is the function renders the window and all widgets within for MFP TC Litho Panel
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Window MFPTCLithoPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,325) as "MFP TC Litho"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="R Sense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:MFPTCLitho:gRsense,live= 1
	SetVariable sv_RLitho,pos={16,49},size={180,18},title="R Litho (kOhm)", limits={0,inf,1}
	SetVariable sv_RLitho,value= root:packages:MFPTCLitho:gRLitho,live= 1
	SetVariable sv_RNorm,pos={16,80},size={180,18},title="R Normal (kOhm)", limits={0,inf,1}
	SetVariable sv_RNorm,value= root:packages:MFPTCLitho:gRNorm,live= 1
	
	Button but_start,pos={16,110},size={67,20},title="Start PID", proc=MFPTCLithoButtonFunc
	Button but_stop,pos={133,110},size={63,20},title="Stop PID", proc=MFPTCLithoButtonFunc//, disable=2
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={102,112},size={15,15}, bodyWidth=15, barmisc={0,0}
	
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 49,162, "Suhas Somnath, UIUC 2010"
	
End	

Function MFPTCLithoButtonFunc(ctrlname) : ButtonControl
	String ctrlname
	
	Variable RemInd = FindLast(CtrlName,"_")
	if (RemInd > -1)
		CtrlName = CtrlName[RemInd+1,Strlen(CtrlName)-1]
	else
		print "Error in Button function"
		return -1
	endif
			
	strswitch (ctrlName)

		case "start":
			//ModifyControl but_start, disable=2, title="Running..."
			//ModifyControl but_stop, disable=0
			startPID()
		break
		
		case "stop":
			//ModifyControl but_stop, disable=2
			//ModifyControl but_start, disable=0, title="Start PID"
			StopPID()
		break
			
	endswitch
		
End


Function startPID()
			
	SetHeat(0)
	PIDPanelButtonFunc("Read",5)	
		
End

Function StopPID()
	// Writing -1 is the only way to reset / modify a loop
	// would be nice to automatically shut off the heating 
	// once all lines have been written / litho is completed
	td_WV("PIDSLoop.5.Status",-1);
	PIDPanelButtonFunc("Read",5)	
	//Safety Cutoff
	td_WV("Output.A",0.5)
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

// Automatically sets the temperature of the tip
// based on the supplied mode:
// 0 ~ Normal (low heating)
// 1 ~ Litho / Full heating
Function SetHeat(mode)
	Variable mode
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFPTCLitho
	
	NVAR gRsense, gRNorm, gRLitho

	// 1 - Stop PID (so that mode can be changed)
	td_WV("PIDSLoop.5.Status",-1);
	
	// 2 - set correct PGain value
	if(mode)
		//Litho mode
		SetPID(-1*(1+(gRLitho/gRsense)))
	else
		// Normal mode
		SetPID(-1*(1+(gRNorm/gRsense)))
	endif
	
	// 3 - start PID
	td_WV("PIDSLoop.5.Status",1);
	
	SetDataFolder dfSave
	
End

function MFPTCLithoSetup()
	
	// 1. set up the CONSTANT / standard PIDS parameters with status = 0
	// 3. set the out channel to something positive (eg - +0.5V)
	// 2. crosspoint panel set up
	
	// 1. PIDS set up:
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFPTCLitho
	
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
	

	// 2. Set up crosspoint connections:
	// Choose this to be DC scan mode:
	XPTPopupFunc("LoadXPTPopup",7,"Litho")
	
	//Reading Vsense (later gets converted to Vcant)
	//td_WS("Crosspoint.InA","BNCIn0")
	WireXpt("InAPopup","BNCIn0")
		
	//Setting up the output channel:
	//td_WS("Crosspoint.BNCOut0","")
	WireXpt("BNCOut0Popup","OutA")
	//XPTBoxFunc("XPTLock10Box_0",1)
	
	//Commiting all changes:
	ARCheckFunc("DontChangeXPTCheck",1)
	XptButtonFunc("WriteXPT")
	 // seems to annul all the changes made so far if I used td_WS
	
	// 3. Positive voltage out of Output channel:
	td_WV("Output.A",0.5)
	
	SetDataFolder DfSave
	
end

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