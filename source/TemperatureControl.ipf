#pragma rtGlobals=1		// Use modern global access method.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////// VERY IMPORTANT - READ THIS FIRST  //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Software requirements:
//----------------------------------------------------
// Igor Pro 6.1 or later
// Asylum Research software version: MFP3D 090909+xxxx or later

// Electrical connections Instructions:
//--------------------------------------------------
// Please make sure to use the voltage follower box specially constructed to work 
// around the impedence matching problem of ARC1 and ARC2 controllers for this
// code to work accurately.
// Electrical circuit: [+] ---  cantilever (Rcant) --- current limiting sense resistor (Rsense) ---- [ground]
// 1. Unplug ALL cables terminating at Input 0, Input 1, Input 2 on the AFM Controller
// 2. Connect the Expansion port (D-Sub 25 pin) to the Voltage follower box 
// 3. Connect Vsense (voltage across Rsense) to the in0 labled on the box NOT on the BNCin0 on the ARC1/ARC2 Controller
// 4. Connect Vtotal to the in1 labled on the box NOT on the BNCin1 on the ARC1/ARC2 Controller
// 5. Connect Vtotal to BNCout0 on the ARC1/ARC2 Controller

// NOTE - Don't set the Rcant setpoint too close to the room temperature resistance of the cantilever.
// This causes the PID control to approach a singularity point. In this case 0V will be applied to the circuit resulting
// in no damage to the cantilever. 

// DISCLAIMER:
// ---------------------------------
// This code is foreign to the existing AFM software. I have worked around many issues painstakingly to ensure
// that this code works as smoothly as possible. In the same manner, care has been takine to ensure that the
// normal AFM operation is not thwarted in any way. Sometimes, when this package is started up but not used actively,
// certain native operations of the AFM software tend to take back certain resources that were allocated for this code.
// This may manifest in the form of malfunctioning temperature control meters, stoppage in the PID controlling the
// cantilever temperature, etc. None of these should damage the cantilever in anyway. To resume normal operation 
// of this code when necessary, use the reinitialize / refresh buttons provided. Typically, clicking on the start button
// is sufficient to bring things back to normal. This code has been tested extensively and its use has so far never
// resulted in any damage to the cantilever or the sample but please be careful when using this code and be mindful
// of the fact that this code is still foreign to the native AFM software.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////// BASICS  ///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 1. Installing the code:
// This is slightly complicated. Contact me for installation.
// Copy this file to C:\Program Files\WaveMetrics\Igor Pro Folder_09_09_09\AsylumResearch\Code3D\UserIncludes

// 2. Accesssing the Heated Cantilever Suite:
// In the top menu bar of the AFM software: UIUC >> Heated Cantilever Suite >>

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////  I-V Characterization  /////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// This package is accessed by clicking on UIUC >> Heated Cantilever Suite >> I-V Characterization

// This package lets you electrically characterize the probe by linearly ramping the voltage being applied
// across the heating cirucit . 

// Rsense (kOhm) ->  The resistance of the sense resistor in kilo ohms
// You can apply at most 10V with this setup so choose your sense resistor that will allow you 
// to access the cantilever temperatures you are interested in. 
// I advise you to pick sense resistors in the range of 1.0 to 5 kilo ohms.
// The value entered here will persist throughout the AFM software.

// V initial (V) ->  Initial voltage to be appled across the circuit (0V <= V initial <10V). 
// Lower ranges of voltage (0-1V) are typically less reliable. 1V should be just fine.

// V final (V) -> Maximum voltage that will be applied across the cirucit (0V < V final <= 10V)
// I advise you to start with something small like 2V and go as high as necessary.

// The specifics of the voltage ramp are specified next:

// Delay (sec)  ->  Time delay in seconds between measurement points. Larger the delay, greater the 
// number of points of data being averaged. Any time greater than 1 sec will not necesarily improve
// the accuracy of the results greatly. Ensure that the delay is at least 250 msec.

// V step (V)  ->  incremental voltage being applied across the circuit between measurement points 

// Show data check box ->   If this is left checked, a table will pop up with the results of the IV characterization

// Once the above parameters are specified, you may click the "start" button. If it does nothing on the first click, click it again.

// In the event that you want to stop the ramp at any time, you can do so by clicking the "Stop" button. 

// Four graphs are updated in real time as each measurement point is acquired. Due to the nature of Igor Pro, 
// the data may appear in an ackward manner because Igor Pro considers (0,0) as a point of measurement even if
// it is a virtual point on the graph. This will disappear and the data will look cleaner once the ramp is completed.

// The four graphs display circuit properties against actual bias applied across the circuit and 
// are as follows in a anti-clockwise direciton:
// 1. Cantilever resistance
// 2. Voltage across the cantilever
// 3. Power supplied to the cantilever
// 4. Current through the cantilever

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////   THERMAL LITHOGRAPHY  /////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// This package is accessed by clicking on UIUC >> Heated Cantilever Suite >> Thermal Lithography

// This window allows you to perform thermal lithograhy with a heated cantilever.
// The lithography lines / patterns drawn either using Microangelo or SmartLitho 
// can be synchronized if appropriate triggers are inserted into Asylum's code
// With the trigger code inserted, this package is capable of switching the cantilever's
// temperature from warm to hot and vice-versa when cantilever is performing lithography.

// R sense (k Ohm) --> The resistance of the sense resistor in kilo ohms
// See notes on the I-V characterization section for more details

// R Normal (k Ohm) -->  This is the cantilever's resistance setpoint to be maintained when
// NOT performing lithography. 

// R Litho (k Ohm) --> This is the cantilever resistance setpoint to be mantained when performing
// lithography

// Note - Due to limitations of Asylum's hardware & software, the above mentioned canilever
// resistance setpoints may not be maintained very accurately (although the precision

// This package also allows slow ramping of cantilver temperature while performing lithography
// 

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////// VERSION LOG  /////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Upcoming changes:
// proportional gain for TF-AFM
// Integral and differential parameters for temperature control
// Use UserCalc channel to provide an ACCURATE Vcant that takes into account any amplification and removes
//                      any inaccuracies associated with the measurements. 
// Allow voltage control from menu. 

// Version 1.9
// Cleaner and safer connection checker
// Allow Temperature Control to work in conjunction with a Linear Amplifier for larger Voltage range
// Replaced Lateral (inaccurate) with UserIn0 (accurate Vsense) display. Now even shows a cautionary message about what exactly is being acquired.

// Version 1.8 (9/17/2011):
// SetPID correction factor now ensures that actual setpoint is close to user specified setpoint.
// Other minor bugfixes

// Version 1.7 (9/16/2011):
// Cleaned up UI
// IV calib - made V final editable not num steps
// IV calib - Now shows table if requested
// More accurate IV calib AND meter panel by reading Vtot as well (DACs are quite inaccurate & I haven't been able to offet the voltage using the doIVPanel)

// Version 1.6:
// Lithography with ramped temperature

// Version 1.5:
// Realtime Lithography & Imaging setpoint updating
// Refresh button on meter panel restarting everthing. Now restarting Bg fun only.
// Stopping the PID now does NOT unlock the autochange XPT. 

// Version 1.4:
// Cleaned up IV calibration UI
// IV calibration now running as a backgroung process (takes 1/10 as many data points though)

//Version 1.3
// Added a refresh button to meter panel
// Misc changes
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Notes to self:
// ARGetImagingMode - in Temp1.ipf
//Use this to check if thermal code exists.
//DataFolderExists("root:packages:TemperatureControl" )

Menu "UIUC"
	Submenu "Heated Cantilever Suite v. 1.9"
		"Connections Checker", CircuitCheckDriver()
		"I-V Characaterization", IVCharDriver()
		"Thermal Imaging", ThermalImagingDriver()
		"Thermal Lithography", ThermalLithoDriver()
		"Meter Panel", TempContMeterDriver()
	End	
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// CONNECTIONS CHECKER /////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function CircuitCheckDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F CircuitCheckPanel
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
	Variable Amplifier = NumVarOrDefault(":gAmplifier",1)
	Variable/G gAmplifier= Amplifier
	
	NewDataFolder/O/S root:packages:TemperatureControl:CircuitChecker
	Variable rCant = NumVarOrDefault(":gRcant",NaN)
	Variable/G gRcant= rcant
	Variable rCantExp = NumVarOrDefault(":gRcantExp",3)
	Variable/G gRcantExp= rcantExp
	Variable manualCheck = NumVarOrDefault(":gManualCheck",NaN)
	Variable/G gManualCheck= manualCheck
	Variable OpA = NumVarOrDefault(":gOpA",NaN)
	Variable/G gOpA= OpA
	Variable IpA = NumVarOrDefault(":gIpA",NaN)
	Variable/G gIpA= IpA
	Variable vHeating = NumVarOrDefault(":gvHeating",NaN)
	Variable/G gvHeating= vHeating
		
	// Create the control panel.
	Execute "CircuitCheckPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End


Window CircuitCheckPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,495) as "Heated Cantilever Circuit Check"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	
	SetVariable sv_Amplification,pos={16,52},size={180,18},title="Amplifier", limits={1,10,.01}
	SetVariable sv_Amplification,value= root:packages:TemperatureControl:gAmplifier,live= 1
	
	SetVariable sv_RcantExp,pos={16,86},size={180,20},title="Expected R cant"
	SetVariable sv_RcantExp, value=root:Packages:TemperatureControl:CircuitChecker:gRcantExp
	
	ValDisplay vd_Rcant,pos={16,120},size={180,20},title="R cant (k Ohm)"
	ValDisplay vd_Rcant, value=root:Packages:TemperatureControl:CircuitChecker:gRcant
	
	Checkbox chk_AllowManual, pos = {16, 151}, size={10,10}, title="Manual Controls", proc=ManualCircuitCheck
	Checkbox chk_AllowManual, live=1,value=root:packages:TemperatureControl:CircuitChecker:gManualCheck
	
	ValDisplay sv_Outpt,pos={45,211},size={154,18},title="Output.A (V)", limits={0,10,1}
	ValDisplay sv_Outpt,live= 1,disable=1,value=root:packages:TemperatureControl:CircuitChecker:gOpA
	
	SetVariable vd_Vtot1,pos={45,177},size={154,20},title="V heating (V)", disable=1
	SetVariable vd_Vtot1, value=root:Packages:TemperatureControl:CircuitChecker:gVheating
	
	ValDisplay vd_Sens,pos={45,245},size={154,20},title="Input.A (V)", live= 1,disable=1
	ValDisplay vd_Sens, value=root:Packages:TemperatureControl:CircuitChecker:gIpA
	
	Button but_Check,pos={12,278},size={192,35},title="Check Circuit", proc=CheckWiring
		
	SetDrawEnv fstyle= 1 
	SetDrawEnv fsize= 14
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 16,345, "Suhas Somnath, UIUC 2010"
		
End	

Function ManualCircuitCheck(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			String dfSave = GetDataFolder(1)
			SetDataFolder root:packages:TemperatureControl:CircuitChecker
			NVAR gManualCheck
			gManualCheck = cba.checked
			SetDataFolder dfSave
			if(gManualCheck)
				ModifyControl sv_Outpt, disable=!gManualCheck
				ModifyControl vd_Vtot1, disable=!gManualCheck
				ModifyControl vd_Sens, disable=!gManualCheck
			else
				ModifyControl sv_Outpt, disable=1
				ModifyControl vd_Vtot1, disable=1
				ModifyControl vd_Sens, disable=1
			endif
			break
	endswitch

	return 0
End

Function CheckWiring(ctrlname) : ButtonControl
	String ctrlName;
	
	CrossPointSetup(-1)

	// In A must increase if Out A is increased.
	// Will try two values (eg 2V and 5V) to see if BNC cables have been
	// correctly set up.
	
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense, gAmplifier, gWireChecked
	
	SetDataFolder root:packages:TemperatureControl:CircuitChecker
	NVAR gRcant, gIpA, gOpA, gVHeating, gManualCheck, gRcantExp
	
	if(gManualCheck)
		gOpA = gVHeating;
	else
		gOpA = 1;
	endif
	
	gOpA = gOpA / gAmplifier;
	td_WV("Output.A",gOpA);
		
	gIpA = 0;
	gOpA = 0;
	Variable count = 0;
	Variable t0 = ticks
	do
		gIpA = gIpA + td_RV("Input.A");
		gOpA = gOpA + td_RV("Input.B");
		count = count+1;
	while ((ticks - t0)/60 < 1)
		
	gIpA = gIpA/count;
	gOpA = gOpA/count;
	gRcant = (gAmplifier*gOpA - gIpA)/(gIpA/gRsense);
		
	SetIdleVoltage()
	//print num2str(abs(gRcant/gRcantExp)-1)
	if(abs(gRcant/gRcantExp)-1 < 0.1) // Must be within 10% of expected value
		gWireChecked = 1;
		DoAlert 0,"Connections OK"
	else
		DoAlert 0,"Cantilever improperly connected!\nConnect Vtotal to controller front panel \n2. Connect Vsense and Vtotal to the Voltage Connector box not the front panel of the controller. \n3. Use expansion cable to connect controller to Voltage Follwer circuit box"
	endif
	
	SetDataFolder dfSave
			
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
	
	Variable Amplifier = NumVarOrDefault(":gAmplifier",1)
	Variable/G gAmplifier= Amplifier
		
	NewDataFolder/O/S root:packages:TemperatureControl:Meter
	
	//Variables declaration
	Variable/G gRcant = 0
	Variable/G gIcant = 0
	Variable/G gPcant = 0
	Variable/G gVtot = 0
	Variable/G gVcant = 0;
	Variable/G gRunMeter = 1
	Variable/G gVoltClip = 0;
			
	ReInitializeThermalMeterPanel("")
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

	// Create the control panel.
	Execute "TempContMeterPanel()"
End

Function RestartThermalMeterPanel(ctrlname) : ButtonControl
	String ctrlname

	ARBackground("bgThermalMeter",10,"")
End

Function ReInitializeThermalMeterPanel(ctrlname) : ButtonControl
	String ctrlname

	// Setting up all the backend wiring:
	SetupVcantAlias()
	//forceLateral()
	ThermalPIDSetup()
	setLinearCombo()
	SetIdleVoltage()
		
	// Starting background process here:
	RestartThermalMeterPanel("")
	
End

Function DisconnectOutput(ctrlname) : ButtonControl
	String ctrlname

	// Set DAC Output to 0
	td_WV("Output.A",0);
	
	// Reset the Output BNC 
	//XPTBoxFunc(XPTLock10Box_0,1)
	WireXpt("BNCOut0Popup","Ground")	
	XptButtonFunc("WriteXPT")
	
	// Don't want to turn on and off the meter itself. Doesn't restart properly with Refresh
	// String dfSave = GetDataFolder(1)
	// SetDataFolder root:packages:TemperatureControl:Meter
	// NVAR gRunMeter
	// gRunMeter = 0; // Meter need not run.
	// SetDataFolder dfSave;
	
	// All this work is undone simply by closing and reopening the MeterPanel
	// Need to add a status bit for whether the heating was turned off manually
	
	
End



Function SetIdleVoltage()
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gAmplifier
	
	Variable idleVoltage = 0.5;
	
	td_wv("output.A",idleVoltage/gAmplifier);
	
	SetDataFolder dfSave
End



Window TempContMeterPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 1035,335) as "Temperature Control Meter"
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
	ValDisplay vd_Vcant, fsize=18, value=root:Packages:TemperatureControl:Meter:GVcant
	
	ValDisplay vd_Vtot,pos={74,157},size={331,20},title="V tot (V)", mode=0
	ValDisplay vd_Vtot,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Vtot, fsize=18, value=root:Packages:TemperatureControl:Meter:GVtot
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={523,17},size={19,19}, barmisc={0,0}
	
	ValDisplay vd_VoltClipLED, value=root:Packages:TemperatureControl:Meter:gVoltClip
	ValDisplay vd_VoltClipLED, mode=2, limits={0,1,0}, lowColor= (0,65280,0), zeroColor= (0,65280,0)
	ValDisplay vd_VoltClipLED, highColor= (65280,0,0), pos={523,158},size={19,19}, barmisc={0,0}
	
	ValDisplay vd_MeterStatusLED, value=root:Packages:TemperatureControl:Meter:gRunMeter
	ValDisplay vd_MeterStatusLED, mode=2, limits={0,1,0}, highColor= (0,65280,0), zeroColor= (65280,0,0)
	ValDisplay vd_MeterStatusLED, lowColor= (65280,0,0), pos={523,43},size={19,19}, barmisc={0,0}

	SetDrawEnv fsize=18
	DrawText 428,36, "PID Status"
	SetDrawEnv fsize=18
	DrawText 426,178, "Vtot Status"
	SetDrawEnv fsize=18
	DrawText 412,63, "Meter Status"
	
	Button but_refresh,pos={450,96},size={59,27},title="Refresh", proc=RestartThermalMeterPanel
	Button but_reinit,pos={440,66},size={79,27},title="Reinitialize", proc=ReinitializeThermalMeterPanel
	Button but_PowOff,pos={410,126},size={138,27},title="Disconnect Cantilever", proc=DisconnectOutput

End

Function bgThermalMeter()
		
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense, gAmplifier
	SetDataFolder root:packages:TemperatureControl:Meter
	NVAR gRcant, gPcant, gIcant, gRunMeter, gVtot, gVcant, gVoltClip
	
	Variable Vsense = td_RV("Input.A") //td_RV("Input.A")
	
	gVtot = td_RV("Input.B"); // NOT using lateral here
	
	//Variable Vsense = td_RV("UserIn0") //td_RV("Input.A")
	
	//gVtot = td_RV("UserIn1"); // NOT using lateral here
	
	if(gVtot > 9.7) // DAC can only output up to 9.7 V
		gVoltClip = 1;
	else
		gVoltClip = 0;
	endif
	
	gVtot = gVtot * gAmplifier;
	
	gVcant = gVtot - Vsense
	gIcant = Vsense / gRsense // in mA
	gPcant = gVcant * gIcant // in mW
	gRcant = gVcant / gIcant // in kOhms
	
	SetDataFolder dfSave	
		
	// A return value of 1 stops the background task. a value of 0 keeps it running
	return !gRunMeter					
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// THERMAL IMAGING FUNCTIONS /////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ThermalImagingDriver()
	
	String dfSave = GetDataFolder(1)
	
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
		
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	Variable Amplifier = NumVarOrDefault(":gAmplifier",1)
	Variable/G gAmplifier= Amplifier
	
	if(wireChecked == 0)
		//Check to make sure cables are properly plugged in:
		DoAlert 0, "Your electrical connections have not been checked.\n Please verify them using: \nUIUC >> Heated Cantilever Suite >> Connection Checker"
		CircuitCheckDriver()
		//return
	endif
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F ThermalImagingPanel
	if (V_Flag != 0)
		return 0
	endif
		
	NewDataFolder/O/S root:packages:TemperatureControl:Imaging
	
	//Variables declaration
	Variable rcant = NumVarOrDefault(":gRcant",3)
	Variable/G gRcant= rcant
	//This will form the setpoint for z - height
	Variable vcant = NumVarOrDefault(":gVcant",3)
	Variable/G gVcant= vcant
	String /G gScanModeNames = "Contact;AC mode"//;Thermal"
	Variable/G gScanMode = 1 // Contact, 2 for tapping, 3 for thermal
	String /G gZfeedbackChannel = "Input.A" //"Lateral"
			
	ThermalPIDSetup()
	setLinearCombo()
	SetupVcantAlias()
	SetupVcantWindow()
	
	TempContMeterDriver()
	
	// Create the control panel.
	Execute "ThermalImagingPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End


Window ThermalImagingPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,390) as "Thermal Imaging Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	SetVariable sv_RcantSetpoint,pos={16,50},size={180,18},title="Rcant set point (kOhm)", limits={0,inf,1}
	SetVariable sv_RcantSetpoint,value= root:packages:TemperatureControl:Imaging:gRcant,live= 1, proc= UpdateRcant
	
	Popupmenu pp_scanmode,pos={16,81},size={135,18},title="Scan Mode",live= 1, proc=ScanModeProc
	Popupmenu pp_scanmode,value= root:packages:TemperatureControl:Imaging:gScanModeNames
	
	SetVariable sv_VcantSetpoint,pos={16,116},size={180,18},title="Vsense setpoint (V)", limits={0,inf,.01}
	SetVariable sv_VcantSetpoint,value= root:packages:TemperatureControl:Imaging:gVcant,live= 1//,disable=2
	SetVariable sv_VcantSetpoint,proc=UpdateThermalSetpoint, disable=2
	
	Button but_start,pos={17,183},size={65,26},title="Start PID", proc=StartImagingPID
	Button but_stop,pos={131,183},size={65,26},title="Stop PID", proc=StopImagingPID
	
	SetVariable sv_Amplification,pos={16,147},size={180,18},title="Amplifier", limits={1,10,.01}
	SetVariable sv_Amplification,value= root:packages:TemperatureControl:gAmplifier,live= 1
		
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={94,186},size={20,20}, bodyWidth=20, barmisc={0,0}
		
	SetDrawEnv fstyle= 1 
	SetDrawEnv fsize= 14
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 14,239, "Suhas Somnath, UIUC 2010"
		
End	

Function ScanModeProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:Imaging
	NVAR gScanMode
	
	switch( pa.eventCode )
		case 2: // mouse up
			gScanMode = pa.popNum
			if (gScanMode == 2)
				MainPopupFunc("ImagingModePopup_0",2,"AC Mode")
				CrossPointSetup(2)
			else
				// Both other modes of scanning are contact based.
				MainPopupFunc("ImagingModePopup_0",1,"Contact")
				CrossPointSetup(1)
			endif
			if (gScanMode == 3)
				ThermalzPIDSetup()
				td_WV("PIDSLoop.2.Status",1)
				// if and when engaging:
				// Check if heated. Only if heated -> engage
				// Otherwise setpoint will not be met. full 150V will be applied -> breaking the cantilever
				//Thermal feedback - enable Vcant setpoint
				ModifyControl sv_VcantSetpoint, disable=0
			else
				ModifyControl sv_VcantSetpoint, disable=2
			endif
			setUpVcantWindow()
			break
	endswitch
	
	SetDataFolder dfSave
	
End //ScanModeProc

function ThermalzPIDSetup()
	
	// This function is pretty much useless. Temp1.ipf >> ARGetImagingMode
	// will overwrite all this. Make changes there. 
		
	String dfSave = GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:Imaging
	NVAR gVcant
	SVAR gZfeedbackChannel
	
	// part a) -> intial standard set up	
	Make/O/T parms
	td_RG("PIDSLoop.2",parms)
	parms[0] = gZfeedbackChannel // Input Channel
	parms[1] = "Height" // Output channel
	parms[2] = "No" // Dynamic Setpoint
	parms[3] = num2str(gVcant)// Setpoint
	parms[4] = "0" // Setpoint offset
	parms[5] = "0" // DGain
	parms[6] = "50" // P gain
	parms[7] = "0" // I Gain
	parms[8] = "0" // S Gain
	parms[9] = "-10" // Input Min
	parms[10] = "150" // Output Max
	parms[11] = "Always" // Start Event
	parms[12] = "Never" // Stop Event
	parms[13] = "-1"
	td_WG("PIDSLoop.2",parms)

	//Setting the status = 0 is equivalent to clicking the write button
	//PIDPanelButtonFunc("Write",5)
	PIDPanelButtonFunc("Read",2)
			
	SetDataFolder DfSave
	
end

Function UpdateThermalSetpoint(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval

			String dfSave = GetDataFolder(1)
			SetDataFolder root:packages:TemperatureControl:Imaging
			NVAR gVcant, gScanMode
			SVAR gZfeedbackChannel
			// Do all this only if scan mode is Thermal
			if (gScanMode == 3 && td_RV("PIDSLoop.2.Status") > 0)
				Make/O/T parms
				td_RG("PIDSLoop.2",parms)
				// Don't assume that PIDS has been setup appropriately.
				// Read the PID 2 input channel
				if(cmpstr(parms[0],gZfeedbackChannel) == 0)
					// PIDS on thermal feedback - go ahead and update PIDS
					Variable errcode = td_WV("PIDSLoop.2.Setpoint",gVcant);
					if(errcode == 1117)
						print "Error: PID Loop not running"
					endif
				endif
			endif
			SetDataFolder dfSave
			break
	endswitch

	return 0
End


Function StopImagingPID(ctrlname) : ButtonControl
	String ctrlname
	StopPID()
End

Function UpdateRcant(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			
			String dfSave = GetDataFolder(1)
			
			SetDataFolder root:Packages:TemperatureControl
			NVAR gRsense
			SetDataFolder root:Packages:TemperatureControl:Imaging
			NVAR gRcant
			gRcant = dval;
					
			// Completely update PID ONLY if already running
			if(td_RV("PIDSLoop.5.Status")==1)
				//print "PID running. Therefore I am updating"
				SetPID(-1*(1+(gRcant/gRsense)))
				td_WV("PIDSLoop.5.Status",1);
			endif
					
			SetDataFolder dfSave
			break
	endswitch

	return 0
End

Function startImagingPID(ctrlname) : ButtonControl
	String ctrlname
	
	String dfSave = GetDataFolder(1)		
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense
	SetDataFolder root:packages:TemperatureControl:Imaging
	NVAR gRcant, gScanMode
	
	CrossPointSetup(Gscanmode)
	setLinearCombo()
	//SetupVcantAlias()
	
	SetPID(-1*(1+(gRcant/gRsense)))
	SetDataFolder dfSave
	
	//td_WS("Event.12","once"); 
	td_WV("PIDSLoop.5.Status",1);
	PIDPanelButtonFunc("Read",5)	
End

// This is just Vsense being displayed on the screen. User takes full responsibility of calculating the actual Vcant
// with the appropriate signal manipulation. Will try to replace this with a UserCalc channel <-- Lot more work
Function setUpVcantWindow()

	Variable chanIndx = 1;
	Variable freeChan = 6;
	for(chanIndx =1; chanIndx<6; chanIndx=chanIndx+1)
		if( WhichListItem("UserIn0", DataTypeFunc(chanindx))==0)
			//print "it is channel number " + num2str(chanindx)
			break;
		elseif( WhichListItem("Off", DataTypeFunc(chanindx))==0)
			//print "Channel #" + num2str(chanindx) + " was Off"
			freeChan = min(freeChan, chanIndx)
		endif
	Endfor
	// Case 1 - UserIn0 already present. chanIndx already set. Don't do anything now
	
	if(chanIndx > 5)
		// Case 2 - Userin0 NOT already present but empty channel available
		if(freeChan < 5)
			chanIndx = freeChan
		else
		// Case 3 - Userin0 NOT present and all channels taken. FORCE last channel with message (Unlikely)
			chanIndx = 5;
			DoAlert 0,"No empty channels found\nOverriding Channel 5 to display Vsense"
		endif
	endif
	
	DoAlert 0,"CAUTION:\nVsense will be displayed to you\n It is your responsibility to calculate Vcant\nMake a note of all necessary parameters"

	// By now, a channel has been decided for Usein0. Just configure it.
	Variable popnum = WhichListItem("UserIn0", DataTypeFunc(5))
	
	SetDataTypePopupFunc("Channel" + num2str(chanIndx) + "DataTypePopup_" + num2str(chanIndx) ,popNum,"UserIn0") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel" + num2str(chanIndx) + "RealPlanefitPopup_" + num2str(chanIndx),4,"Masked Line") // for the live flatten
	SetPlanefitPopupFunc("Channel" + num2str(chanIndx) + "SavePlanefitPopup_" + num2str(chanIndx),1,"None") // for the save flatten
	ShowWhatPopupFunc("Channel" + num2str(chanIndx) + "CapturePopup_" + num2str(chanIndx),4,"Both")
	SetChannelColorMap("Channel" + num2str(chanIndx) + "1ColorMapPopup_" + num2str(chanIndx),29,"VioletOrangeYellow")

End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// THERMAL LITHOGRAPHY ///////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ThermalLithoDriver()
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	Variable Amplifier = NumVarOrDefault(":gAmplifier",1)
	Variable/G gAmplifier= Amplifier
	
	//Check to make sure cables are properly plugged in:
	if(wireChecked==0)
		DoAlert 0, "Your electrical connections have not been checked.\n Please verify them using: \nUIUC >> Heated Cantilever Suite >> Connection Checker"		
		CircuitCheckDriver()
		//return;
	endif
		
	// If the panel is already created, just bring it to the front.
	DoWindow/F ThermalLithographyPanel
	if (V_Flag != 0)
		return 0
	endif
	
	NewDataFolder/O/S root:packages:TemperatureControl:Lithography
	
	//Variables declaration
	Variable RLitho = NumVarOrDefault(":gRLitho",4)
	Variable/G gRLitho= RLitho
	Variable doRamp = NumVarOrDefault(":gDoRamp",0)
	Variable/G gDoRamp= doRamp
	Variable Rstep = NumVarOrDefault(":gRstep",0.1)
	Variable/G gRstep= Rstep
	Variable tStep = NumVarOrDefault(":gtStep",1)
	Variable/G gtStep= tStep
	Variable Rmax = NumVarOrDefault(":gRmax",6)
	Variable/G gRmax= Rmax
	Variable/G gRampStartTick= 0
	Variable/G gCurrentSetpoint = 0;
	Variable RNorm = NumVarOrDefault(":gRNorm",3)
	Variable/G gRNorm= RNorm
	Variable/G gAllowHeating = 0
	Variable/G gRunRampBGfun = 0;
	// -1 - unheated, 0 - warm / normal mode, 1 - litho / imaging (fully heated)
	Variable HeatingState = NumVarOrDefault(":gHeatingState",-1)
	Variable/G gHeatingState= HeatingState
	
	// Create the control panel.
	Execute "ThermalLithoPanel()"
	
	ThermalPIDSetup()
	
	TempContMeterDriver()	
	
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End

Window ThermalLithoPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 700,515) as "Thermal Lithography Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={180,18},title="R Sense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	SetVariable sv_RNorm,pos={16,49},size={180,18},title="R Normal (kOhm)", limits={0,inf,1}, proc=UpdateNormSetpt
	SetVariable sv_RNorm,value= root:packages:TemperatureControl:Lithography:gRNorm,live= 1
	SetVariable sv_RLitho,pos={16,80},size={180,18},title="R Litho (kOhm)", limits={0,inf,1}, proc=UpdateLithoSetpt
	SetVariable sv_RLitho,value= root:packages:TemperatureControl:Lithography:gRLitho,live= 1
	
	// Ramp parameters:
	Checkbox chk_AllowRamping, pos = {23, 115}, size={10,10}, title="Ramp Temperature", proc=AllowRampedHeating
	Checkbox chk_AllowRamping, live=1,value=root:packages:TemperatureControl:Lithography:gDoRamp
	SetVariable sv_Rstep,pos={55,145},size={142,18},title="R step (kOhm)", limits={0,inf,1}
	SetVariable sv_Rstep,live= 1,disable=2,value=root:packages:TemperatureControl:Lithography:gRstep
	SetVariable sv_tstep,pos={55,178},size={142,18},title="t step (sec)", limits={0,inf,1}
	SetVariable sv_tstep,live= 1,disable=2, value=root:packages:TemperatureControl:Lithography:gtStep
	SetVariable sv_Rmax,pos={55,213},size={142,18},title="R max (kOhm)", limits={0,inf,1}
	SetVariable sv_Rmax,live= 1,disable=2, value=root:packages:TemperatureControl:Lithography:gRmax
	
	SetVariable sv_Amplification,pos={16,251},size={180,18},title="Amplifier", limits={1,10,.01}
	SetVariable sv_Amplification,value= root:packages:TemperatureControl:gAmplifier,live= 1
	
	Button but_start,pos={16,287},size={75,28},title="Start PID", proc=ThermalLithoButtonFunc,live= 1
	Button but_stop,pos={131,287},size={75,28},title="Stop PID", proc=ThermalLithoButtonFunc,live= 1//, disable=2
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={101,290},size={20,20}, bodyWidth=20, barmisc={0,0}
	
	SetDrawEnv fstyle= 1
	SetDrawEnv fsize= 14
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 18,351, "Suhas Somnath, UIUC 2010"
	
End

Function AllowRampedHeating(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			String dfSave = GetDataFolder(1)
			SetDataFolder root:packages:TemperatureControl:Lithography
			NVAR gDoRamp
			gDoRamp = cba.checked
			if(gDoRamp)
				ModifyControl sv_Rstep, disable=!gDoRamp
				ModifyControl sv_tstep, disable=!gDoRamp
				ModifyControl sv_Rmax, disable=!gDoRamp
			else
				ModifyControl sv_Rstep, disable=2
				ModifyControl sv_tstep, disable=2
				ModifyControl sv_Rmax, disable=2
			endif
			break
	endswitch

	return 0
End

Function UpdateLithoSetpt(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			String dfSave = GetDataFolder(1)
			SetDataFolder root:packages:TemperatureControl:Lithography
			NVAR gRLitho, gHeatingState
			gRLitho = sva.dval
			if(gHeatingState == 1)
				// Real-time updating of setpoint
				SetHeat(1);
			endif
			SetDataFolder dfSave;
			break
	endswitch

	return 0
End

Function UpdateNormSetpt(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			String dfSave = GetDataFolder(1)
			SetDataFolder root:packages:TemperatureControl:Lithography
			NVAR gRNorm, gHeatingState
			gRNorm = sva.dval
			if(gHeatingState == 0)
				// Real-time updating of setpoint
				SetHeat(0);
			endif
			SetDataFolder dfSave;
			break
	endswitch

	return 0
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
	
	NVAR gAllowHeating, gDoRamp, gRunRampBGfun
			
	strswitch (ctrlName)

		case "start":
			//ModifyControl but_start, disable=2, title="Running..."
			//ModifyControl but_stop, disable=0
			gAllowHeating=1
			SetDataFolder dfSave
			startLithoPID()
			setLinearCombo()
			
			if(gDoRamp)
				// Start ramp monitoring background function
				//print "starting ramp monitor"
				gRunRampBGfun = 1;
				ARBackground("bgRampMonitor",100,"")
			endif
			
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
	//setLinearCombo()	
	SetHeat(0)
	PIDPanelButtonFunc("Read",5)	
		
End

Function bgRampMonitor()

	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gRsense
	SetDataFolder root:packages:TemperatureControl:Lithography
	NVAR gRstep, gtStep, gRmax, gRampStartTick, gCurrentSetpoint, gRLitho, gRunRampBGfun, gHeatingState
	
	
	if(gHeatingState>0)
	// Calculate expected setpoint:
	
		Variable iter = ceil((ticks - gRampStartTick)/(gtStep*60))
		Variable expSetpt = min(gRmax,  gRLitho + iter * gRstep)
	
		// Case 1: Same iteration - don't change Pgain
		
		if(expSetpt > gCurrentSetpoint)
			
			// Case 2: next iteration - change Pgain.
			gCurrentSetpoint = expSetpt
			SetPID(-1*(1+(gCurrentSetpoint/gRsense)))
			td_WV("PIDSLoop.5.Status",1);
		endif
	elseif(gHeatingState<0)
		// Heating has stopped.
		gRunRampBGfun=0;
	endif
	
	SetDataFolder dfSave
	
	// When will this bg end?
	return !gRunRampBGfun;
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
	
	NVAR gRNorm, gRLitho, gAllowHeating, gHeatingState, gRampStartTick, gDoRamp, gCurrentSetpoint
	
	if(!gAllowHeating)
		SetDataFolder dfSave
		return 0
	endif

	// 1 - Stop PID (so that mode can be changed)
	//td_WV("PIDSLoop.5.Status",-1);
	
	// 2 - set correct PGain value
	gHeatingState = mode;
	if(mode)
		//Litho mode
		
		SetPID(-1*(1+(gRLitho/gRsense)))
		
		if(gDoRamp)
			gRampStartTick = ticks;
			gCurrentSetpoint = gRLitho;
		endif
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
		
	String dfSave = GetDataFolder(1)
	
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TemperatureControl
	
	Variable rsense = NumVarOrDefault(":gRsense",0.98)
	Variable/G gRsense= rsense
	Variable wireChecked = NumVarOrDefault(":gWireChecked",0)
	Variable/G gWireChecked = wireChecked
	Variable Amplifier = NumVarOrDefault(":gAmplifier",1)
	Variable/G gAmplifier= Amplifier
	
	//Check to make sure cables are properly plugged in:
	if(wireChecked == 0)
		DoAlert 0, "Your electrical connections have not been checked.\n Please verify them using: \nUIUC >> Heated Cantilever Suite >> Connection Checker"		
		CircuitCheckDriver()
		//return;
	endif
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F IVCharPanel
	if (V_Flag != 0)
		return 0
	endif
	
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
	Variable showTable = NumVarOrDefault(":gshowTable",1)
	Variable/G gshowTable= showTable
	Variable/G gProgress = 0
	Variable/G gClippedRead=0
	Variable/G gAbortIV = 1
	
	Make/O/N=(2) Vtotalwave
	Make/O/N=(2) Vsensewave
	Make/O/N=(2) Vcantwave
	Make/O/N=(2) Rcantwave
	Make/O/N=(2) Pcantwave
	Make/O/N=(2) Icantwave
	//Reset the datafolder to the root / previous folder
	
	SetDataFolder dfSave
	
	CrossPointSetup(-1)	
	
	// Create the control panel.
	Execute "IVCharPanel()"
	
End


Window IVCharPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 1300,700) as "Heated Cantilever I-V Characterization Panel"
	SetDrawLayer UserBack
		
	SetVariable sv_Rsense,pos={16,20},size={152,18},title="Rsense (kOhm)", limits={0,inf,1}
	SetVariable sv_Rsense,value= root:packages:TemperatureControl:gRsense,live= 1
	
	SetVariable sv_Vinitial,pos={200,20},size={112,18},title="V initial (V)", limits={0,10,1}, proc=IVSetVarProc
	SetVariable sv_Vinitial,value= root:packages:TemperatureControl:IVChar:gVinitial,live= 1
	
	SetVariable sv_Vstep,pos={336,57},size={105,18},title="V step (V)", limits={0,10,1}, proc=IVSetVarProc
	SetVariable sv_Vstep,value= root:packages:TemperatureControl:IVChar:gVstep,live= 1
	
	ValDisplay sv_steps,pos={52,57},size={115,18},title="Num steps"
	ValDisplay sv_steps,value= root:packages:TemperatureControl:IVChar:gNumSteps,live= 1
	
	SetVariable vd_VFinal,pos={332,20},size={109,20},title="V Final (V)", proc=IVSetVarProc, limits={0,inf,1}
	SetVariable vd_VFinal,value= root:packages:TemperatureControl:IVChar:gVFinal,live= 1
	
	SetVariable sv_tDelay,pos={192,57},size={120,18},title="Delay (sec)", limits={0,inf,1}
	SetVariable sv_tDelay,value= root:packages:TemperatureControl:IVChar:gDelay,live= 1
	
	Button but_start,pos={465,18},size={67,25},title="Start", proc=StartIVChar2
	Button but_stop,pos={465,50},size={67,25},title="Stop", proc=StopIVChar
	
	SetVariable sv_Amplification,pos={555,51},size={115,18},title="Amplifier", limits={1,10,.01}
	SetVariable sv_Amplification,value= root:packages:TemperatureControl:gAmplifier,live= 1
	
	ValDisplay vd_Progress,pos={554,23},size={236,20},title="Progress", mode=0, live=1
	ValDisplay vd_Progress,limits={0,100,0},barmisc={0,40},highColor= (0,43520,65280)
	ValDisplay vd_Progress, fsize=14, value=root:Packages:TemperatureControl:IVChar:GProgress
	
	Checkbox chk_ShowData, pos = {708, 51}, size={10,10}, title="Show Data", proc=ShowDataChkFun
	Checkbox chk_ShowData, live=1, value=root:Packages:TemperatureControl:IVChar:gshowTable
	
	String dfSave= GetDataFolder(1)
	SetDataFolder root:packages:TemperatureControl:IVChar
	
	Display/W=(21,85,397,292) /HOST=# VcantWave, vs VTotalWave
	ModifyGraph frameStyle=5, mode=4, msize=3,marker=19, lStyle=7; // marker: kind of point, mode:=3display only points, 0 = lines between points
	Label bottom "\Z13V total (V)"
	Label left "\Z13V cant (V)"
	RenameWindow #,G0
	SetActiveSubwindow ##
	
	Display/W=(410,85,790,292) /HOST=# RcantWave, vs VTotalWave
	ModifyGraph frameStyle=5, mode=4, msize=3,marker=19, lStyle=7;
	Label bottom "\Z13V total (V)"
	Label left "\Z13R cant (k Ohms)"
	RenameWindow #,G1
	SetActiveSubwindow ##
	
	Display/W=(21,305,397,505) /HOST=# PcantWave, vs VTotalWave
	ModifyGraph frameStyle=5, mode=4, msize=3,marker=19, lStyle=7;
	Label bottom "\Z13V total (V)"
	Label left "\Z13P cant (mW)"
	RenameWindow #,G2
	SetActiveSubwindow ##
	
	Display/W=(410,305,790,505) /HOST=# IcantWave, vs VTotalWave
	ModifyGraph frameStyle=5, mode=4, msize=3,marker=19, lStyle=7;
	Label bottom "\Z13V total (V)"
	Label left "\Z13I Cant (mA)"
	RenameWindow #,G3
	SetActiveSubwindow ##
	
	SetDataFolder dfSave		
	SetDrawEnv fstyle= 1 
	SetDrawEnv textrgb= (0,0,65280)
	DrawText 624,535, "\Z13Suhas Somnath, UIUC 2010"
End	

Function ShowDataChkFun(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			String dfSave = GetDataFolder(1)
			SetDataFolder root:Packages:TemperatureControl:IVChar
			NVAR gShowTable
			gShowTable = cba.checked
			SetDataFolder dfSave
			break
	endswitch

	return 0
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
			
			gNumSteps = floor((gVFinal - gVInitial)/gVstep);		
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
	NVAR gAbortIV
	
	// stop background function here.
	gAbortIV = 1

	ModifyControl but_start, disable=0, title="Start"
	
	SetDataFolder dfSave
	
End

Function StartIVChar2(ctrlname) : ButtonControl
	String ctrlname
	
	ModifyControl but_start, disable=2, title="Running..."
	
	// Forcing the crosspoints to stay again:
	CrossPointSetup(-1)
	
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:Packages:TemperatureControl:IVChar
	
	Variable/G gIteration = 0
	Variable/G gIterStartTick = 0
	Variable/G gVsenseTotal = 0
	Variable/G gVtotTotal = 0
	Variable/G gNumMeasurements = 0
	Variable/G gClippedRead = 0
	
	NVAR gNumsteps
	
	Wave Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
	Redimension/N=0 Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
	Redimension/N=(gNumSteps+1) Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
	
	// Starting background process here:
	ARBackground("bgIVFun",100,"")
	
	SetDataFolder dfSave

End

Function bgIVFun()

	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:packages:TemperatureControl
	NVAR gAmplifier
	
	SetDataFolder root:Packages:TemperatureControl:IVChar
	NVAR gAbortIV, gClippedRead
	
	if(gAbortIV || gClippedRead)
		SetidleVoltage()
		SetDataFolder dfSave
		ModifyControl but_start, disable=0, title="Start"
		gAbortIV = 0;
		if(gClippedRead)
			print "came here"
			DoAlert 0,"I-V aborted: Either UserIn0 or UserIn1 exceeded 10 V\nCheck your circuit / I-V parameters"
		endif
		return 1;
	endif
	
	// Case 1: Very first run of IV
	NVAR gIterStartTick
	if(gIterStartTick == 0)
		NVAR gVinitial, gVstep
		td_WV("Output.A",(gVinitial + 0*gVstep)/gAmplifier)
		gIterStartTick = ticks
		SetDataFolder dfSave
		//print("very first IV")
		return 0;
	endif
	
	if(gIterStartTick > 0)
	
		NVAR gIteration, gVsenseTotal, gNumMeasurements, gDelay, gVtotTotal
		//print "Time till next iteration: " + num2str(gIterStartTick+(gDelay* 60) - ticks)
		if(ticks < (gIterStartTick+(gDelay* 60)))
		
			// Case 2: Same iteration 
			// take another measurement
			gVsenseTotal += td_RV("Input.A")
			gVtotTotal += td_RV("Input.B")*gAmplifier // Measuring before amplification (obviously)
			gNumMeasurements += 1
			SetDataFolder dfSave
			//print("Grabbing more data")
			return 0;
		else
			
			NVAR gProgress, gNumSteps, gVinitial, gVstep
			Wave Vtotalwave, VsenseWave, VcantWave, RcantWave, PcantWave, IcantWave
		
			// Case 3: Completed iteration 
			
			// a. calculate & store necessary vals for previous iter	
			SetDataFolder root:Packages:TemperatureControl
			NVAR gRsense
			SetDataFolder root:Packages:TemperatureControl:IVChar
			
			//print "Took " + num2str(gNumMeasurements) + " measurements"
		
			gVtotTotal = gVtotTotal / gNumMeasurements
			gVsenseTotal = gVsenseTotal / gNumMeasurements
			
			VtotalWave[gIteration] = gVtotTotal
			VsenseWave[gIteration] = gVsenseTotal
			IcantWave[gIteration] =gVsenseTotal / gRsense // in mA
			
			/////////////////////////////////// ORIGINAL CALCULATION /////////////////////////////////////////////
			VcantWave[gIteration] =  gVtotTotal - gVsenseTotal
			RcantWave[gIteration] = VcantWave[gIteration] / IcantWave[gIteration]
			PcantWave[gIteration] = VcantWave[gIteration] * IcantWave[gIteration]
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			
			
			/////////////////////////////////// HIGH RS CALCULATION /////////////////////////////////////////////
			//Variable Rtot = gVtotTotal/IcantWave[gIteration];
			//print "Rtot = " + num2str(Rtot)
			
			//Variable RsMain = 47.35; // (kOhms) Enter manually here for now.
			//RcantWave[gIteration] = Rtot - (RsMain + gRsense);
			//VcantWave[gIteration] =  RcantWave[gIteration] * IcantWave[gIteration]
			//PcantWave[gIteration] = VcantWave[gIteration] * IcantWave[gIteration]
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			
			
			
			// Raise flag if any of the ADCs was saturated
			gVtotTotal = gVtotTotal/gAmplifier
			if(gVtotTotal >= 9.8 || gVsenseTotal > 9.8)
				gClippedRead = 1;
			endif
			
			// b. advance iteration & progress		
			gNumMeasurements = 0;
			gVsenseTotal = 0;
			gVtotTotal = 0;
			gIteration = gIteration+1
			gProgress = min(100,floor((gIteration/gNumSteps)*100))
			//print "iteration #" + num2str(gIteration) + " now complete"
			
			// c. Start next iteration OR stop
			
			if(gIteration <= gNumsteps)
			
				// start next iteration
				td_WV("Output.A",(gVinitial + gIteration*gVstep)/gAmplifier)
				gIterStartTick = ticks
				SetDataFolder dfSave
				//print("moving to next iteration")
				return 0;
				
			else
			
				// stop IV calibration
				//gIterStartTick = 0
				NVAR gShowTable
				SetDataFolder dfSave
				
				SetidleVoltage()

				//print("IV calibration complete")
				if(gShowTable)
					//print "Displaying Table"
					Edit/K=1 VTotalWave,VsenseWave,VCantWave,RCantWave,PCantWave,ICantWave
				endif
				ModifyControl but_start, disable=0, title="Start"
				return 1;
				
			endif
		endif
	endif
	
	print "IV calib should not be coming here. Aborting"
	return 1; // DONT keep background function alive

End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// GENERAL FUNCTIONS ///////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function SetPID(pgain)
	Variable pgain
	
	// Version 1.8 and beyond: Rcant setpoint corrected here:
	
	
	// Pgain = 1 + RcBAD / Rs
	pgain = pgain-1;
	// pgain is now RcBAD / Rs
	pgain = pgain*(1/0.975)
	// pgain is now RcGOOD / Rs
	pgain = 1+ pgain;
	
	String dfSave = GetDataFolder(1)

	SetDataFolder root:packages:TemperatureControl
	Wave/T parms
	NVAR gAmplifier
	 
	pgain = pgain/gAmplifier;
	
	// only modify Pgain and status
	parms[6] = num2str(pgain)
	parms[13] = "0"
	// but still have to rewrite the group to controller
	td_WG("PIDSLoop.5",parms)
	SetDataFolder dfSave
	
End

Function StopPID()
	// Writing -1 is the only way to reset / modify a loop
	td_WV("PIDSLoop.5.Status",-1);
	// If the user doesn't want to do anything with the thermal panel
	// this should not affect future actions:
	//ARCheckFunc("DontChangeXPTCheck",0)
	
	if(DataFolderExists("root:packages:TemperatureControl:Lithography" ))
		String dfSave = GetDataFolder(1)
		SetDataFolder root:packages:TemperatureControl:Lithography
		NVAR gHeatingState, gAllowHeating
	
		gHeatingState = -1
		//gRunRampBGfun = 0;
		gAllowHeating=0;
		SetDataFolder dfSave
	endif
	
	//Safety Cutoff
	SetidleVoltage()
	PIDPanelButtonFunc("Read",5)
	
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
	// coeffWave = {b,a}
	// z = y + ax+b
	// z = Output.A + -1*Input.A
	// z = Vtotal - Vsense
	// Make it:
	// z = Amplifier*Vtotal - Vsense
	// Closest is the inverse: z = Vsense + (-gAmplifier)*Vtotal
	// Vtotal isn't even that accurate. Why bother? Just rely on Input.0 and scale carefully.
	
	// Use SetDetrend before combo
	td_SetLinearCombo("Input.A", coeffWave, "Input.B")
			
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
	
	// Used in IV calibration and Meter - we read V total using an additional channel
	// for increased accuracy. MFP DACs are quite inaccurate
	WireXpt("InBPopup","BNCIn1");
	
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
	SetidleVoltage()
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

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// DISCARDED FUNCTIONS ///////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function CheckWiringOLD(displayDialog)
	Variable displayDialog
	// This will be executed AFTER the PID has been set up
	// In A must increase if Out A is increased.
	// Will try two values (eg 2V and 5V) to see if BNC cables have been
	// correctly set up.
	if(displayDialog)
		DoAlert 1,"Do you want me to check if all electrical connections have correctly been wired?\t\t(Strongly Recommended)\nThis check will apply 2*amplification volts, so select NO if you have an amplifier connected or if the cantilever / sense resistances are large"
		//DoAlert 0,"1. Connect Vtotal to controller front panel \n2. Connect Vsense to the Voltage Connector box not the front panel of the controller. \n3. Use expansion cable to connect controller to Voltage Follwer circuit box"
		if(V_flag!=1)
			// No or cancel clicked
			return -1
		endif
	endif
	
	td_WV("Output.A",1)
		
	// wait for a second or so
	Variable t0 = ticks
	do
	while ((ticks - t0)/60 < 0.25)
	
	Variable in1 = td_RV("Input.A")
	
	// Don't want to output too much -> 
	// If an amplifier is being used 
	td_WV("Output.A",2)
		
	// wait for a second or so
	t0 = ticks
	do
	while ((ticks - t0)/60 < 0.25)
	
	Variable in2 = td_RV("Input.A")
	
	// Almost shut off the voltage supply
	
	SetidleVoltage()
	
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
		DoAlert 0,"Cantilever improperly connected!\nConnect Vtotal to controller front panel \n2. Connect Vsense and Vtotal to the Voltage Connector box not the front panel of the controller. \n3. Use expansion cable to connect controller to Voltage Follwer circuit box"
	endif
	
	
End

// This method still works but it causes Igor to freeze while measurements take place
// IV calibration cannot be stopped. Nothing else may be performed
// This does average ~ 160 samples per represented data point -> lower noise.
Function StartIVChar(ctrlname) : ButtonControl
	String ctrlname
	
	ModifyControl but_start, disable=2, title="Running..."
	
	// Forcing the crosspoints to stay again:
	CrossPointSetup(-1)
	
	String dfSave = GetDataFolder(1)
	
	SetDataFolder root:Packages:TemperatureControl
	NVAR gRsense
	
	SetDataFolder root:Packages:TemperatureControl:IVChar
	NVAR gVinitial, gVstep, gNumSteps, gDelay, gProgress
	
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
	
		td_WV("Output.A",Vinitial + i*Vstep)
		Variable Vssum = 0
		Variable count = 0
		Variable t0 = ticks
		do
			Vssum += td_RV("Input.A")
			count += 1
		while(ticks-t0<Delay)
		
		gProgress = (i/NumSteps)*100
		//print "iteration #" + num2str(count) + " now complete"
		
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
	
	ModifyControl but_start, disable=0, title="Start"
	
	SetidleVoltage()
	
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


//No Need for this anymore:
// See SetupVcantWindow
Function SetUpUserCalc()
	// This is assuming that the function Vcant exists in the UserCalc ipf:
	Variable popnum = WhichListItem("Vcant", GetUserCalculatedFuncList())
	ChannelPopFunc("UserCalcFuncPop_0",PopNum+1,"Vcant") 

	// Setting the name / label for the channel: 
	UserChannelNameFunc("UserCalcName_0",NaN,"Vcant","GlobalStrings[%UserCalcName][%Value]")
End

// Ideally, one would assume that Output.A was accurate when getting Vtotal. However, it is way too inaccurate
// to make precise quantitative measurements. On the other hand the ADCs on UserIn-s are sufficiently
// accurate. It is therefore recommended to use UserIn0 instead of using 
Function setUpVcantWindowWRONG()
	
	// Channel 5:
	Variable popnum = WhichListItem("Lateral", DataTypeFunc(5))
	if(popnum < 0)
		// Lateral already being displayed
		// dont bother
		return -1
	endif
	SetDataTypePopupFunc("Channel5DataTypePopup_5",popNum,"Lateral") // sets the channel acquired into the graph:
	SetPlanefitPopupFunc("Channel5RealPlanefitPopup_5",4,"Masked Line") // for the live flatten
	SetPlanefitPopupFunc("Channel5SavePlanefitPopup_5",4,"Flatten 0") // for the save flatten
	ShowWhatPopupFunc("Channel5CapturePopup_5",4,"Both")
	SetChannelColorMap("Channel51ColorMapPopup_5",29,"VioletOrangeYellow")
	
End

Function forceLateral()
	MeterPopupFunc("LateralPopup",3,"On")
	MeterPanelSetup("MeterSetupDone")
End