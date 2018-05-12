#pragma rtGlobals=1		// Use modern global access method.

Menu "Macros"
	Submenu "Temperature Control"
		"Check Circuit Wiring", ThermalWiringChecker()
		"I-V Characaterization", IVCharDriver()
		"Thermal Imaging", ThermalImagingDriver()
		"Thermal Lithography", ThermalLithoDriver()
		"Meter Panel", TempContMeterDriver()
	End	
End

Function ThermalWiringChecker()
	CrossPointSetup(-1)
	CheckWiring(0)
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// TEMPERATURE CONTROL METER  ////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function TempContMeterDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F TempContMeterPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	NewDataFolder/O/S root:packages:TemperatureControl:Meter
	
	//Variables declaration
	Variable/G GRcant = 0
	Variable/G GIcant = 0
	Variable/G GPcant = 0
	Variable/G GVtot = 0
	Variable/G GVcant = 0
	Variable/G GrunMeter = 1
	
	// Setting up all the backend wiring:
	SetupVcantAlias()
	forceLateral()
	ThermalPIDSetup()
	setLinearCombo()
	td_wv("output.A",0.5)
		
	// Starting background process here:
	//SetBackground bgThermalMeter()
	//GrunMeter = 1;CtrlBackground period=5,start
	ARBackground("bgThermalMeter",5,"")
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

	// Create the control panel.
	Execute "TempContMeterPanel()"
End


Window TempContMeterPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 975,335) as "Temperature Control Meter"
	SetDrawLayer UserBack
	
	ValDisplay vd_Rcant,pos={16,16},size={385,20},title="R cant (k Ohm)", mode=0
	ValDisplay vd_Rcant,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Rcant, fsize=18, value=root:Packages:TemperatureControl:Meter:GRcant
	
	ValDisplay vd_Pcant,pos={39,51},size={362,20},title="P cant (mW)", mode=0
	ValDisplay vd_Pcant,limits={0,20,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Pcant, fsize=18, value=root:Packages:TemperatureControl:Meter:GPcant
	
	ValDisplay vd_Icant,pos={52,88},size={351,20},title="I cant (mA)", mode=0
	ValDisplay vd_Icant,limits={0,1.75,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Icant, fsize=18, value=root:Packages:TemperatureControl:Meter:GIcant
	
	ValDisplay vd_Vcant,pos={58,123},size={346,20},title="V cant (V)", mode=0
	ValDisplay vd_Vcant,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Vcant, fsize=18, value=root:Packages:TemperatureControl:Meter:GVcant//Root:Packages:MFP3D:Meter:Lateral
	
	ValDisplay vd_Vtot,pos={74,157},size={331,20},title="V tot (V)", mode=0
	ValDisplay vd_Vtot,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Vtot, fsize=18, value=root:Packages:TemperatureControl:Meter:GVtot
	//Root:Packages:MFP3D:Meter:ReadMeterRead[%UserIn0][0]+Root:Packages:MFP3D:Meter:Lateral
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={420,66},size={54,83}, barmisc={0,0}

	SetDrawEnv fsize=18
	DrawText 429,37, "PID"
	SetDrawEnv fsize=18
	DrawText 419,63, "Status"
End

Function bgThermalMeter()
		
	String dfSave = GetDataFolder(1)
	
	//WAVE tempWave = Root:Packages:MFP3D:Meter:ReadMeterRead
	//Variable Vsense = tempWave[%UserIn0][0]
	
	//SetDataFolder Root:Packages:MFP3D:Meter
	//NVAR Lateral
	
	//Variable Vcant = Lateral
	
	Variable Vsense = td_RV("UserIn0")

	Variable Vcant = td_RV("Lateral")
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense
	SetDataFolder root:packages:TemperatureControl:Meter
	NVAR gRcant, gPcant, gIcant, gRunMeter, gVtot, gVcant
	
	
	gVtot = (Vsense + Vcant)//*correction 
	// Perhaps, the correction factor needs to be a function too?
	Variable correction = 0.94
	if(gVtot < 0.55)
		correction = 0.8
	elseif(gVtot >= 0.55 && gVtot < 1.1)
		correction = 0.88
	elseif(gVtot >= 1.1 && gVtot < 2.55)
		correction = 0.925
	elseif(gVtot >=2.55 && gVtot < 5.1)
		correction = 0.94
	elseif(gVtot >=5.1)
		correction = 0.951
	endif
	
	gVtot = gVtot * correction// in V (applying the approximate correction factor)
		
	
	gVcant = gVtot - Vsense
	gIcant = Vsense / gRsense // in mA
	gPcant = gVcant * gIcant // in mW
	gRcant = gVcant / gIcant // in kOhms
	
	setLinearCombo()	
	
	SetDataFolder dfSave	
		
	// A return value of 1 stops the background task. a value of 0 keeps it running
	return !gRunMeter					
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// THERMAL IMAGING FUNCTIONS /////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ThermalImagingDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F ThermalImagingPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	
	NewDataFolder/O/S root:packages:TemperatureControl:Imaging
	
	//Variables declaration
	Variable rcant = NumVarOrDefault(":gRcant",3)
	Variable/G gRcant= rcant
	String /G gScanModeNames = "Contact;AC mode"
	Variable/G gScanMode = 1 // Contact, 2 for tapping
	
	ThermalPIDSetup()
	setLinearCombo()
	SetupVcantAlias()
	SetupVcantWindow()
	
	if(wireChecked == 0)
		//Check to make sure cables are properly plugged in:
		CheckWiring(1)
	endif
	
	TempContMeterDriver()
	
	// Create the control panel.
	Execute "ThermalImagingPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End


Window ThermalImagingPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,325) as "Thermal Imaging Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	SetVariable sv_Setpoint,pos={16,49},size={180,18},title="Rcant set point (kOhm)", limits={0,inf,1}
	SetVariable sv_Setpoint,value= root:packages:TemperatureControl:Imaging:gRcant,live= 1
	
	Popupmenu pp_scanmode,pos={16,80},size={135,18},title="Scan Mode"
	Popupmenu pp_scanmode,value= root:packages:TemperatureControl:Imaging:gScanModeNames,live= 1, proc=ScanModeProc
	
	Button but_start,pos={16,112},size={67,20},title="Start PID", proc=ThermalImagingButtonFunc
	Button but_stop,pos={133,112},size={63,20},title="Stop PID", proc=ThermalImagingButtonFunc
		
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={103,115},size={15,15}, bodyWidth=15, barmisc={0,0}
		
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 49,169, "Suhas Somnath, UIUC 2010"
End	

Function ScanModeProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:Imaging
	NVAR gScanMode
	
	switch( pa.eventCode )
		case 2: // mouse up
			gScanMode = pa.popNum
			if (gScanMode == 1)
				MainPopupFunc("ImagingModePopup_0",1,"Contact")
				CrossPointSetup(1)
			else
				MainPopupFunc("ImagingModePopup_0",2,"AC Mode")
				CrossPointSetup(2)
			endif
			setUpVcantWindow()
			break
	endswitch
	
	SetDataFolder dfSave
	
End //LineLength

Function ThermalImagingButtonFunc(ctrlname) : ButtonControl
	String ctrlname
	
	Variable RemInd = FindLast(CtrlName,"_")
	if (RemInd > -1)
		CtrlName = CtrlName[RemInd+1,Strlen(CtrlName)-1]
	else
		print "Error in Button function"
		return -1
	endif
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:Imaging
		
	strswitch (ctrlName)
		case "start":
			startImagingPID()
		break
				
		case "stop":
			StopPID()
		break		
	endswitch
	
	SetDataFolder dfSave
	
End

Function startImagingPID()
			
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense
	SetDataFolder root:packages:TemperatureControl:Imaging
	NVAR gRcant, gScanMode
	
	CrossPointSetup(Gscanmode)
	setLinearCombo()
	//SetupVcantAlias()
	
	SetPID(-1*(1+(gRcant/gRsense))/0.94)
	
	//td_WS("Event.12","once"); 
	td_WV("PIDSLoop.5.Status",1);
	PIDPanelButtonFunc("Read",5)	
End

Function setUpVcantWindow()
	
	// Channel 5:
	Variable popnum = WhichListItem("Lateral", DataTypeFunc(5))
	if(popnum < 0)
		// Potential already being displayed
		// dont bother
		return -1
	endif
	SetDataTypePopupFunc("Channel5DataTypePopup_5",popNum,"Lateral") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel5RealPlanefitPopup_5",4,"Masked Line") // for the live flatten
	SetPlanefitPopupFunc("Channel5SavePlanefitPopup_5",4,"Flatten 0") // for the save flatten
	ShowWhatPopupFunc("Channel5CapturePopup_5",4,"Both")
	
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// THERMAL LITHOGRAPHY ///////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ThermalLithoDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F ThermalLithographyPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	
	NewDataFolder/O/S root:packages:TemperatureControl:Lithography
	
	//Variables declaration
	Variable RLitho = NumVarOrDefault(":gRLitho",4)
	Variable/G gRLitho= RLitho
	Variable RNorm = NumVarOrDefault(":gRNorm",3)
	Variable/G gRNorm= RNorm
	Variable/G gAllowHeating = 0
	
	// Create the control panel.
	Execute "ThermalLithoPanel()"
	
	ThermalPIDSetup()
	
	//Check to make sure cables are properly plugged in:
	if(wireChecked==0)
		CheckWiring(1)
	endif
	
	TempContMeterDriver()	
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End

Window ThermalLithoPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,325) as "Thermal Lithography Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="R Sense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	SetVariable sv_RLitho,pos={16,49},size={180,18},title="R Litho (kOhm)", limits={0,inf,1}
	SetVariable sv_RLitho,value= root:packages:TemperatureControl:Lithography:gRLitho,live= 1
	SetVariable sv_RNorm,pos={16,80},size={180,18},title="R Normal (kOhm)", limits={0,inf,1}
	SetVariable sv_RNorm,value= root:packages:TemperatureControl:Lithography:gRNorm,live= 1
	
	Button but_start,pos={16,110},size={67,20},title="Start PID", proc=ThermalLithoButtonFunc
	Button but_stop,pos={133,110},size={63,20},title="Stop PID", proc=ThermalLithoButtonFunc//, disable=2
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={102,112},size={15,15}, bodyWidth=15, barmisc={0,0}
	
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 49,162, "Suhas Somnath, UIUC 2010"
	
End

Function ThermalLithoButtonFunc(ctrlname) : ButtonControl
	String ctrlname
	
	Variable RemInd = FindLast(CtrlName,"_")
	if (RemInd > -1)
		CtrlName = CtrlName[RemInd+1,Strlen(CtrlName)-1]
	else
		print "Error in Button function"
		return -1
	endif
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:Lithography
	
	NVAR gAllowHeating
			
	strswitch (ctrlName)

		case "start":
			//ModifyControl but_start, disable=2, title="Running..."
			//ModifyControl but_stop, disable=0
			gAllowHeating=1
			SetDataFolder dfSave
			startLithoPID()
			setLinearCombo()
		break
		
		case "stop":
			//ModifyControl but_stop, disable=2
			//ModifyControl but_start, disable=0, title="Start PID"
			gAllowHeating=0
			SetDataFolder dfSave
			StopPID()
			setLinearCombo()
		break
			
	endswitch
		
End

Function startLithoPID()
	
	CrossPointSetup(3)	
	SetHeat(0)
	PIDPanelButtonFunc("Read",5)	
		
End

// Automatically sets the temperature of the tip
// based on the supplied mode:
// 0 ~ Normal (low heating)
// 1 ~ Litho / Full heating
Function SetHeat(mode)
	Variable mode
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl
	
	NVAR gRsense
	
	SetDataFolder root:packages:TemperatureControl:Lithography
	
	NVAR gRNorm, gRLitho, gAllowHeating
	
	if(!gAllowHeating)
		SetDataFolder dfSave
		return 0
	endif

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


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// IV CHARACTERIZATION //////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function IVCharDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F IVCharPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	
	NewDataFolder/O/S root:packages:TemperatureControl:IVChar
	
	//Variables declaration
	Variable Vinitial = NumVarOrDefault(":gVinitial",1)
	Variable/G gVinitial= Vinitial
	Variable Vfinal = NumVarOrDefault(":gVfinal",1)
	Variable/G gVfinal= Vfinal
	Variable Vstep = NumVarOrDefault(":gVstep",1)
	Variable/G gVstep= Vstep
	Variable numsteps = NumVarOrDefault(":gnumsteps",1)
	Variable/G gnumsteps= numsteps
	Variable delay = NumVarOrDefault(":gdelay",1)
	Variable/G gDelay= delay
	Variable/G gAbort = 0
	Variable/G gProgress = 0
	
	Make/O/N=(2) Vtotalwave
	Make/O/N=(2) Vsensewave
	Make/O/N=(2) Vcantwave
	Make/O/N=(2) Rcantwave
	Make/O/N=(2) Pcantwave
	Make/O/N=(2) Icantwave
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave
	
	CrossPointSetup(-1)	

	//Check to make sure cables are properly plugged in:
	if(wireChecked == 0)
		CheckWiring(1)
	endif
	
	// Create the control panel.
	Execute "IVCharPanel()"
	
End


Window IVCharPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 1300,700) as "Heated Cantilever I-V Characterization Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={132,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	
	SetVariable sv_Vinitial,pos={188,20},size={112,18},title="V initial (V)", limits={0,10,1}, proc=IVSetVarProc
	SetVariable sv_Vinitial,value= root:packages:TemperatureControl:IVChar:gVinitial,live= 1
	
	SetVariable sv_Vstep,pos={336,20},size={105,18},title="V step (V)", limits={0,10,1}, proc=IVSetVarProc
	SetVariable sv_Vstep,value= root:packages:TemperatureControl:IVChar:gVstep,live= 1
	
	SetVariable sv_steps,pos={42,57},size={105,18},title="Num steps", limits={1,inf,1}, proc=IVSetVarProc
	SetVariable sv_steps,value= root:packages:TemperatureControl:IVChar:gNumSteps,live= 1
	
	ValDisplay vd_VFinal,pos={353,57},size={84,20},title="V Final"
	ValDisplay vd_VFinal,value= root:packages:TemperatureControl:IVChar:gVFinal,live= 1
	
	SetVariable sv_tDelay,pos={185,57},size={120,18},title="Delay (sec)", limits={0,inf,1}
	SetVariable sv_tDelay,value= root:packages:TemperatureControl:IVChar:gDelay,live= 1
	
	Button but_start,pos={468,18},size={80,25},title="Start", proc=StartIVChar
	Button but_stop,pos={468,50},size={80,25},title="Stop", proc=StopIVChar
	
	ValDisplay vd_Progress,pos={566,30},size={214,20},title="Progress", mode=0, live=1
	ValDisplay vd_Progress,limits={0,100,0},barmisc={0,40},highColor= (0,43520,65280)
	ValDisplay vd_Progress, fsize=18, value=root:Packages:TemperatureControl:IVChar:GProgress
	
	String dfSave= GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:IVChar
	
	Display/W=(21,85,397,292) /HOST=# VcantWave, vs VTotalWave
	ModifyGraph frameStyle=5
	Label bottom "V total (V)"
	Label left "V cant (V)"
	RenameWindow #,G0
	SetActiveSubwindow ##
	
	Display/W=(410,85,790,292) /HOST=# RcantWave, vs VTotalWave
	ModifyGraph frameStyle=5
	Label bottom "V total (V)"
	Label left "R cant (k Ohms)"
	RenameWindow #,G1
	SetActiveSubwindow ##
	
	Display/W=(21,305,397,505) /HOST=# PcantWave, vs VTotalWave
	ModifyGraph frameStyle=5
	Label bottom "V total (V)"
	Label left "P cant (mW)"
	RenameWindow #,G2
	SetActiveSubwindow ##
	
	Display/W=(410,305,790,505) /HOST=# IcantWave, vs VTotalWave
	ModifyGraph frameStyle=5
	Label bottom "V total (V)"
	Label left "I Cant (mA)"
	RenameWindow #,G3
	SetActiveSubwindow ##
	
	SetDataFolder dfSave		
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 624,535, "Suhas Somnath, UIUC 2010"
End	
	
Function IVSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			
			String dfSave = GetDataFolder(1)
	
			SetDataFolder root:Packages:TemperatureControl:IVChar
			
			NVAR gVinitial, gVstep, gNumSteps, gVFinal
			
			if(gVinitial + gVstep * gNumSteps > 10)
				gNumSteps = floor((10-gVinitial)/gVstep)
				
			endif
			gVFinal = gVinitial + gVStep * gNumSteps
			SetDataFolder dfSave
			break
	endswitch

	return 0
End

Function StopIVChar(ctrlname) : ButtonControl
	String ctrlname
	
	String dfSave = GetDataFolder(1)
		
	SetDataFolder root:Packages:TemperatureControl:IVChar
	NVAR gAbort
	
	gAbort = 1
	
	SetDataFolder dfSave
	
End

Function StartIVChar(ctrlname) : ButtonControl
	String ctrlname
	
	ModifyControl but_start, disable=2, title="Running..."
	
	// Forcing the crosspoints to stay again:
	CrossPointSetup(-1)
	
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:Packages:TemperatureControl
	NVAR gRsense
	
	SetDataFolder root:Packages:TemperatureControl:IVChar
	NVAR gVinitial, gVstep, gNumSteps, gDelay, gAbort, gProgress
	
	Variable vinitial = gVinitial
	Variable Vstep = gVstep
	Variable numsteps = gNumsteps
	Variable delay =gDelay	* 60 // per sec
	Variable rsense = gRsense
	
	Wave Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
	Redimension/N=(NumSteps+1) Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
	
	gProgress = 0
	
	Variable i=0;
	for(i=0; i<= NumSteps; i+=1)
	
		if(gAbort)
			gAbort = 0
			break
		endif
	
		td_WV("Output.A",Vinitial + i*Vstep)
		Variable Vssum = 0
		Variable count = 0
		Variable t0 = ticks
		do
			Vssum += td_RV("Input.A")
			count += 1
		while(ticks-t0<Delay)
		
		gProgress = (i/NumSteps)*100
		print "iteration #" + num2str(i) + " now complete"
		
		// Calculate the varialbes now:
		VtotalWave[i] = Vinitial + i*Vstep
		VsenseWave[i] = Vssum / count
		VcantWave[i] =  VTotalWave[i] - VsenseWave[i]
		IcantWave[i] =VsenseWave[i] / rsense // in mA
		RcantWave[i] = VcantWave[i] / IcantWave[i]
		PcantWave[i] = VcantWave[i] * IcantWave[i]
		
	endfor
	
	Edit/K=1 VTotalWave,VsenseWave,VCantWave,RCantWave,PCantWave,ICantWave
	
	SetDataFolder dfSave
	
	td_WV("Output.A",0.5)
	
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// GENERAL FUNCTIONS ///////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function SetPID(pgain)
	Variable pgain
	SetDataFolder root:packages:TemperatureControl
	Wave/T parms
	// only modify Pgain and status
	parms[6] = num2str(pgain)
	parms[13] = "0"
	// but still have to rewrite the group to controller
	td_WG("PIDSLoop.5",parms)
	
End

Function StopPID()
	// Writing -1 is the only way to reset / modify a loop
	td_WV("PIDSLoop.5.Status",-1);
	//Safety Cutoff
	td_WV("Output.A",0.5)
	PIDPanelButtonFunc("Read",5)
	// If the user doesn't want to do anything with the thermal panel
	// this should not affect future actions:
	ARCheckFunc("DontChangeXPTCheck",0)
End

Function SetupVcantAlias()

	// Hacking the Asylum panels to automatically shove in an Alias:
	// To do this manually: Programming >> XOPTables >> Aliases >> User tab
	// Edit/K=0 UserAlias.ld

	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:MFP3D:Hardware
	// Potential goes in #18
	//For some reason it keeps showing up as NaN despite giving good data for the topography.
	// So I switched to Lateral. 
	// Also easier to do the meter with a non NAN channel for Vcant
	Wave/T UserAlias
	Redimension/N=1 UserAlias
	UserAlias[0] = "LinearCombo.Output"
	SetDimLabel 0, 0, 'Lateral', UserAlias
	Wave/T AllAlias
	AllAlias[22] = "LinearCombo.Output"
	
	WriteAllAliases()
	
	SetDataFolder DfSave
	
End

Function setLinearCombo()
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl
	
	Make/N=(2)/O coeffWave
	coeffWave = {0,-1}
	td_SetLinearCombo("Input.A", coeffWave, "Output.A")
			
	SetDataFolder DfSave
End

function ThermalPIDSetup()
	
	// 1. set up the CONSTANT / standard PIDS parameters with status = 0
	// 2. Wire Crosspoint panel temporarily
	
	// 1. PIDS set up:
	
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl
	
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
	
	// 2. Dont make the Auto Change XPT
	 CrossPointSetup(-1)
			
	SetDataFolder DfSave
	
end

Function CrossPointSetup(scanmode)
	Variable Scanmode

	if (ScanMode == 1)
		// Contact mode:
		XPTPopupFunc("LoadXPTPopup",4,"DCScan")
	elseif(ScanMode == 2)
		// AC mode:
		XPTPopupFunc("LoadXPTPopup",2,"ACScan")
	elseif(ScanMode == 3)
		// AC mode:
		XPTPopupFunc("LoadXPTPopup",7,"Litho")	
	endif
		
	//Reading Vsense (later gets converted to Vcant)
	//td_WS("Crosspoint.InA","BNCIn0")
	WireXpt("InAPopup","BNCIn0")
	
	//Reading second channel - Vtotal
	//td_WS("Crosspoint.InB","BNCIn1")
	// Not required any more. Automatically calculating this stuff in "Lateral"
	//WireXpt("InBPopup","BNCIn1")
	
	//Setting up the output channel:
	//td_WS("Crosspoint.BNCOut0","")
	WireXpt("BNCOut0Popup","OutA")
	//XPTBoxFunc("XPTLock10Box_0",1)
	
	//Commiting all changes:
	if(ScanMode != -1)
		ARCheckFunc("DontChangeXPTCheck",1)
	endif
	XptButtonFunc("WriteXPT")
	 // seems to annul all the changes made so far if I used td_WS
	
	//Positive voltage out of Output channel:
	td_WV("Output.A",0.5)
End

Function CheckWiring(displayDialog)
	Variable displayDialog
	// This will be executed AFTER the PID has been set up
	// In A must increase if Out A is increased.
	// Will try two values (eg 2V and 5V) to see if BNC cables have been
	// correctly set up.
	if(displayDialog)
		DoAlert 1,"Do you want me to check if all electrical connections\nhave correctly been wired?\n(Strongly Recommended)"
		if(V_flag!=1)
			// No or cancel clicked
			return -1
		endif
	endif
	
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
		
		// Commit this check to memory:
		String dfSave = GetDataFolder(1)
		NewDataFolder/O/S root:packages:TemperatureControl
		Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
		Variable/G gWireChecked = 1
		SetDataFolder dfSave
		
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

Function forceLateral()
	MeterPopupFunc("LateralPopup",3,"On")
	MeterPanelSetup("MeterSetupDone")
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// DISCARDED FUNCTIONS ///////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

// No need to use this anymore. 
// See SetUpVcantWindow
Function setUpImagingWindows()
	// Setting the viewing / acquiring channels:
	// Channels 3,4 will acquire Vsense and Vtotal for the sake of Vcant (channel 5)
	
	// Channel 5:
	Variable popnum = WhichListItem("Vcant", DataTypeFunc(5))
	if(popnum < 0)
		SetUpUserCalc()
	endif
	if(popnum < 0)
		DoAlert 0, "Error! \n The function - 'Vcant' was not found in UserCalculated.ipf"
		return -1
	endif
	SetDataTypePopupFunc("Channel5DataTypePopup_5",popNum,"Vcant") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel5RealPlanefitPopup_5",4,"Masked Line") // for the live flatten
	SetPlanefitPopupFunc("Channel5SavePlanefitPopup_5",4,"Flatten 0") // for the save flatten
	ShowWhatPopupFunc("Channel5CapturePopup_5",4,"Both")
	
	// Would be very nice If there would be some way to avoid having to waste two channels like this:
	
	// Channel 4:
	popnum = WhichListItem("UserIn1", DataTypeFunc(4))
	SetDataTypePopupFunc("Channel4DataTypePopup_4",popNum,"UserIn1") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel4RealPlanefitPopup_4",1,"None") // for the live flatten
	SetPlanefitPopupFunc("Channel4SavePlanefitPopup_4",1,"None") // for the save flatten
	//ShowWhatPopupFunc("Channel4CapturePopup_4",1,"None") // We dont want to display this channel
	ShowWhatPopupFunc("Channel4ShowWhatPopup_4",1,"None") // We dont want to display this channel
	
	// Channel 3:
	popnum = WhichListItem("UserIn0", DataTypeFunc(3))
	SetDataTypePopupFunc("Channel3DataTypePopup_3",popNum,"UserIn0") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel3RealPlanefitPopup_3",1,"None") // for the live flatten
	SetPlanefitPopupFunc("Channel3SavePlanefitPopup_3",1,"None") // for the save flatten
	//ShowWhatPopupFunc("Channel3CapturePopup_3",1,"None") // We dont want to display this channel
	ShowWhatPopupFunc("Channel3ShowWhatPopup_3",1,"None") // We dont want to display this channel
	
End

//No Need for this anymore:
// See SetupVcantWindow
Function SetUpUserCalc()
	// This is assuming that the function Vcant exists in the UserCalc ipf:
	Variable popnum = WhichListItem("Vcant", GetUserCalculatedFuncList())
	ChannelPopFunc("UserCalcFuncPop_0",PopNum+1,"Vcant") 

	// Setting the name / label for the channel: 
	UserChannelNameFunc("UserCalcName_0",NaN,"Vcant","GlobalStrings[%UserCalcName][%Value]")
End