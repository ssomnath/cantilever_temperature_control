#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=ScanMaster

Constant FreqStopEvent = 7


function DoScanFunc(ctrlName)			//the scanning function
	string ctrlName

	PostARMacro(CtrlName,NaN,"","")
	SwapMacroMode(1)
	Execute/P/Q/Z "SwapMacroMode(-1)"
	if (GV("DoThermal"))								//turn thermal off if it is on
		DoThermalFunc("StopThermalButton_1")
	endif
	String CtrlNameOrg = CtrlName						//massage the name to remove everything but the command
	Variable RemIndex = FindLast(CtrlName,"_")
	if (RemIndex > -1)
		CtrlName = CtrlName[0,RemIndex-1]
	endif
	RemIndex = FindLast(CtrlName,"Button")
	if (RemIndex > -1)
		CtrlName = CtrlName[0,RemIndex-1]
	endif
	PV("ElectricTune",0)
	if (!stringmatch(ctrlName,"ClearImage"))		//unless we are clearing the image
		UpdateDelaySetvars()							//we need to unhighlite the delayed setvars
	endif
	
	Variable DoBias = StringMatch(CtrlName,"*BiasScan")	//bias scan button is evidently weird 
	if (DoBias)
		CtrlName = CtrlName[0,Strlen(CtrlName)-9]+CtrlName[Strlen(CtrlName)-4,Strlen(CtrlName)-1]
	endif
	PV("IsScanBias",DoBias)				//setting this means it will do a bias scan
	
	Wave FMVW = $cFMVW

//	KillBackground
	string SavedDataFolder = GetDataFolder(1)
	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList 
	String errorStr = ""		//keep track of any td errors
	Variable FMapStatus, SaveForce
	Struct ARImagingModeStruct ImagingModeParms
	ARGetImagingMode(ImagingModeParms)
	variable ImagingMode = ImagingModeParms.ImagingMode
	variable i, stop
	string FMOKList = GetFMOKList()
	
	String ChannelList = GTS("DataTypeSum")
	Variable IsFreq = (WhichListItem("Frequency",ChannelList,";",0,0) >= 0)	//is frequency or potential turned on?
	Variable IsPot = (WhichListItem("Potential",ChannelList,";",0,0) >= 0)
	strswitch (ctrlName)

		case "StopScan":			//stop everything, now
		case "StopScan":			//withdraw from the force panel
		case "StopEngage":	//same thing except from the meter panel
			////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			////////////////////////// start of code addition by Suhas //////////////////////////////////////////////////
			
			// Stop PIS loop #5
			Struct WMButtonAction InfoStruct
			InfoStruct.CtrlName = "stopPIDSLoop5"
			InfoStruct.EventMod = 1
			InfoStruct.EventCode = 2
			PIDSLoopButtonFunc(InfoStruct)
			
			// cut off voltage supply to circuit.
			td_wv("Output.A",0.5)
			
			ArrayInterfacer("print \"DAQmx Scan Stopped at ScanMaster\"");
			ArrayInterfacer("fDAQmx_ScanStop(\"Dev1\");");
			
			//////////////////////////////// end of code addition by Suhas /////////////////////////////////////////////
			////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			BackgroundInfo
			If (V_flag)				//kill background if running
				KillBackground
			endif
			
			wave MeterStatus = root:Packages:MFP3D:Meter:MeterStatus
			variable meterRun0 = MeterStatus[%Run][0]
			MeterStatus[%EngageOn][0] = 0				//we don't want to be engaging
			SetLowNoise(0)
			ARManageRunning("Scan;Engage;FMap;",0)		//at this point, we are not scanning, We are not engaged, and not force moding.
			//This switch must deal with which PISloops to turn off.
			errorStr += num2str(td_StopOutWaveBank(-1))+","			//stop all of the banks
			ClearEvents()
			if (WhichListItem("AR_Stop",GetRTStackInfo(0),";",0,0) < 0)

				If (ImagingMode == 2)		// Hard to read - IF (Tip Protect = Off) || ((Tip Protect = On) && (Loops Behaving))
					if ((!FMVW[%TipProtectOn][0]) || (FMVW[%TipProtectOn][0] && (td_ReadValue("Dissipation")<FMVW[%DissipationSetpointVolts][%Low] && (!FrequencyLimitCheck(td_ReadValue("Frequency")))))) // If we are in FM Mode and the loops are behaving then leave them running
						AR_Stop(OKList=FMOKList)
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="outputXLoop"))+","		// Kill all loops except Frequency and Drive FB
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="outputYLoop"))+","
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="HeightLoop"))+","
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="PotentialLoop"))+","
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="DwellLoop"))+","
						ErrorStr += num2str(ir_StopPISLoop(NaN,LoopName="outputZLoop"))+","
					else
						AR_Stop()												//this fixes all of the various buttons
						ErrorStr += num2str(ir_StopPISLoop(-1))+","		//Kill all the loops & update the status of the FM loops
					endif
				else
					ErrorStr += num2str(ir_StopPISLoop(-1))+","
					AR_Stop()
				endif
			else
				ErrorStr += num2str(ir_StopPISLoop(-1))+","
				AR_Stop()
			endif
//			UpdateMeterStatus(1)

			errorStr += IR_StopInWaveBank(-1)
			//Don't stop all PIS loop here, they have already been turned off in the above if statements.
			CheckYourZ(1)				//this sets variables that could be on because of scanning to 0
			errorStr += num2str(td_WriteString("CTFC.EventEnable","Never"))+","			//reset more things to 0
			errorStr += num2str(td_WriteString("ScanEngine.XDestination","Output.Dummy"))+","				//turn the scan engine off
			errorStr += num2str(td_WriteString("ScanEngine.YDestination","Output.Dummy"))+","
			errorStr += num2str(td_WriteString("OutWave0StatusCallback",""))+","
			FMapStatus = GV("FMapStatus")
			PV("ScanStatus;FMapStatus;FMapPaused;",0)
			PV("DelayUpdate",GV("DelayUpdate") & 1)					//delay update is no longer active as we have stopped scanning
			if (FMapStatus)							//we might need to save a FMap
				SaveForce = GV("FMapSave")
				if (SaveForce & 5)
					UpdateForceList()
				endif
				Wave FDVW = root:Packages:MFP3D:Main:Variables:ForceDispVariablesWave
				if ((SaveForce) || ((Sum(FDVW,FindDimLabel(FDVW,0,"FMapUseFunc0"),FindDimLabel(FDVW,0,"FMapUseFunc"+num2str(cMaxFMapImageChannels-1)))) && (FDVW[%FMapAutoName][0])))
					PV("FMapBaseSuffix",GV("FMapBaseSuffix")+1)		//we saved a FMap so update the suffix
				endif
				if (GV("ShowXYSpot"))			//if Show XY spot is on
					ShowXYSpotFunc("ShowXYSpotCheck_2",1)	//then display it again, it was turned off for scanning
				endif
			endif

//			errorStr += num2str(td_WriteString("Event.0","Once")						//trigger the ramp
			// Cypher.Output.Z not currently wave driveable
			if (StringMatch(td_ReadString("ZDACSource"),"External"))			//is this cypher?
				Stop = 100
				Variable CurrentHeight = td_ReadValue("Height")
				for (i = 0; i < stop; i += 1)
					ir_writeValue("Cypher.Output.Z",-CurrentHeight/(stop-1)*i+CurrentHeight)		//loop to withdraw Z manually
				endfor
				DoScanStopCallback(CtrlNameOrg)
			else
				td_SetRamp(2,"Output.Z",80,0,"",0,0,"",0,0,"DoScanStopCallback(\""+CtrlNameOrg+"\")")	//withdraw Z
			endif
			
			if (!GV("DontChangeXPT"))
				LoadXPTState(ImagingModeParms.XPTString+"Meter")		//change back the XPT if that is okay
			endif

//			DoWindow/K MeterPanel
//			if (V_flag)
//				MakeMeterPanel()
//			endif
//			if (meterRun0 == 0)
//				StopMeter("")		//but turn the meter on if it was on before
//			else
			UpdateMeterStatus(0)	//I'm pretty sure that this function does everything in this entire block
//				StartMeter("")
//			endif

			//UpdateAllControls("LastScan_0","Do Scan","DoScan_0","",DropEnd=1)
			GhostMainPanel()				//ghost all of the panels
			GhostForceMapPanel()
			GhostNapPanel()
			GhostFMPanel()
			GhostTunePanel()
			GhostARDoIVPanel()
			TuneBoxFunc("TuneFeedbackBox_3",0)
			
			UpdateAllControls("StopEngageButton",cEngageButtonTitle,"SimpleEngageButton","SimpleEngageMe",DropEnd=2)		//meter panel doesn't have ghost function
			UpdateAllControls("MeterSetup","","","",Disable=0)
			ARReportError(errorStr)			//errors?
			ClearEvents()						//clean up everything else
			SetDisable(0)
			DisableButtons(1)
			CheckSaveStatus()
			ImageTimeRemaining(NaN,"")

//			SetDataFolder(SavedDataFolder)     //the data folder has not been set yet
			return 0									//we are through

		case "UpScan":								//these are the same as DoScan, but a direction is chosen
		case "DownScan":
			errorStr += num2str(td_StopOutWaveBank(-1))+","		//stop the current action
			errorStr += IR_StopInWaveBank(-1)
			if (stringmatch(ctrlName,"DownScan"))			//set the scandown variable
				PV("ScanDown",1)
			else
				PV("ScanDown",0)
			endif
			if ((ImagingMode != 2) && (IsPot || IsFreq))
				errorStr += num2str(ir_StopPISLoop(NaN,LoopName="FrequencyLoop"))+","		//if a frequency feedback loop is running not in FM mode, turn the loop off and reset the frequency
				errorStr += num2str(ir_WriteValue("DDSFrequencyOffset0",0))+","
			endif

		case "DoScan":				//we want to scan
			ARManageRunning("Scan",0)		//spoof the scan, since this chould be running already
			ARManageRunning("Engage",0)		//If they clicked on simple engage, then that is all right as well.
			AR_Stop(OKList=FMOKList)
			ARManageRunning("Scan",1)		//scan is back baby.
			td_ReadString("Temperature@Head")		//do this early so the later reading is more accurate
			td_ReadString("Temperature@Scanner")

			ClearEvents()
			errorStr += num2str(td_WriteString("ScanEngine.XDestination","Output.Dummy"))+","				//turn the scan engine off
			errorStr += num2str(td_WriteString("ScanEngine.YDestination","Output.Dummy"))+","
			CheckYourZ(1)
			
			PV("ScanStatus",1)			//we are scanning now
			UpdateAllControls("LastScan_0","Moving","","")
			UpdateAllControls("MeterSetup","","","",Disable=2)
			ErrorStr += SetLowNoise(1)


			wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
			Wave OMVW = root:Packages:MFP3D:Main:Variables:oldMVW
			CheckLithoWave(MVW[%FastScanSize][0]-OMVW[%FastScanSize][0],MVW[%SlowScanSize][0]-OMVW[%SlowScanSize][0])
			Duplicate/O MVW root:Packages:MFP3D:Main:Variables:OldMVW
			RealScanParmFunc("ALL","Copy")
			PV("ParmChange;",0)		//changing the parms matters starting now
			PV("DelayUpdate",GV("DelayUpdate") & 1)		//clear this

			GhostMainPanel()			//ghost the panels
			GhostNapPanel()
			GhostFMPanel()
			GhostTunePanel()
			GhostARDoIVPanel()
			DisableButtons(0)
			SetDisable(2)
			break

		case "LastScan":
			//DoAlert 1, "Do you want to withdraw after this scan?"		//this needs a way to be turned off by preferences
			
			variable noWithdraw
			wave PrefsWave = $GetDF("Prefs")+"PrefsWave"				//this wave is saved for each user
			variable warnWithdraw = PrefsWave[%NoWarnBit] & 2^13		//see what the initial settings are
			if (GetKeyState(0) & 2^1)										//is the Alt key held down
				SafePVByLabel(PrefsWave,(SafeGVByLabel(PrefsWave,"NoWarnBit") & ~2^13),"NoWarnBit")		//clear the noWarn bit so the dialog will come up
			endif
//				SafePVByLabel(PrefsWave,(SafeGVByLabel(PrefsWave,"NoWarnBit") & 2^14),"ARDoalertAction")		//move bit 14 which is the no withdraw/withdraw setting to the action bit
//			endif
			noWithdraw = ARDoAlert("Do you want to withdraw after this scan?",13,1)			//put up a dialog or automatically set the action
			PV("LastScanWithdraw",!noWithdraw)// v_flag == 1)										//set the withdraw variable
//			if (noWithdraw)														//set the default action
//				SafePVByLabel(PrefsWave,(SafeGVByLabel(PrefsWave,"NoWarnBit") | 2^14),"NoWarnBit")
//			else
//				SafePVByLabel(PrefsWave,(SafeGVByLabel(PrefsWave,"NoWarnBit") & ~2^14),"NoWarnBit")
//			endif
			if (!warnWithdraw)									//if the no warn was not set
				if (PrefsWave[%NoWarnBit] & 2^13)				//but now it is
					DoAlert 0, "To change the Last Scan settings click the button while holding the Alt key"	//put up a message about how to change the default
				endif												//you do not get this option if the no warn was set and the dialog brought up with the Alt key
			endif
			
			UpdateAllControls("LastScan_0","Waiting...","","")
			PV("LastScan",1)						//this is the last scan
			GhostMainPanel()
			GhostNapPanel()
			GhostFMPanel()
			
//			SetDataFolder(SavedDataFolder)     //the data folder has not been set yet
			return 0

		case "ClearImage":						//we want the images NaN so the scaling works on new parts, but for speed reasons we now use 0
			SetDataFolder root:Packages:MFP3D:Main:		//it all happens in here
			string ListWave = WaveList("*Image*",";","")	//grab all of the image waves
			stop = ItemsInList(ListWave)
			for (i = 0;i < stop;i += 1)						//loop through the list
				wave temp = $StringFromList(i,ListWave)
				FastOp temp = 0									//set them to 0, NaN really slows down displaying images
			endfor
			SetDataFolder(SavedDataFolder)
//			PV("ParmChange",1)			//this no longer counts as a parm change
			CheckSaveStatus()
			if (GV("RealArgyleReal"))		//if argyle is the RT window, then we need to reset the line counter
				//to get those to update.
				ResetLineCounter()
			endif
			
//			SetDataFolder(SavedDataFolder)     //the data folder has not been set yet
			return 0						//we're through

		case "ContinueScan":										//the function was called but not by a button

			if (GV("LastScan"))						//check to see if we should do more
				BackgroundInfo							//check the background
				If (V_flag)
					KillBackground						//kill background if needed
				endif
	
				//stop the out waves
				errorStr += num2str(td_StopOutWaveBank(-1))+","
				//stop the inwaves
				errorStr += IR_stopinwavebank(-1)
				//turn the scan engine off
				errorStr += num2str(td_WriteString("ScanEngine.XDestination","Output.Dummmy"))+","
				errorStr += num2str(td_WriteString("ScanEngine.YDestination","Output.Dummy"))+","
				//UpdateAllControls("LastScan_0","Do Scan","DoScan_0","")

				UpdateAllControls("MeterSetup","","","",Disable=0)
				Beep
				wave MeterStatus = root:Packages:MFP3D:Meter:MeterStatus
//				variable meterRun1 = MeterStatus[%Run][0]
				ErrorStr += SetLowNoise(0)

				PV("ScanStatus",0)
				GhostMainPanel()
				GhostNapPanel()
				GhostFMPanel()
				GhostTunePanel()
				GhostARDoIVPanel()
				DisableButtons(1)
				ARRestoreDBState()
				//let things know we are only engaged now.
				ARManageRunning("Engage",1)
				ARManageRunning("Scan",0)
//				if (MeterRun1)
//					StartMeter("")
//				endif
				UpdateMeterStatus(0)					//this should replace the other meter code
				if (GV("LastScanWithdraw"))			//withdraw if this is set
					DoScanFunc("StopScan")
				endif
				ARCallbackFunc("ImageDone")

//				SetDataFolder(SavedDataFolder)     //the data folder has not been set yet
				return -1
	
			else

				KeepScanningFunc()
//				SetDataFolder(SavedDataFolder)     //the data folder has not been set yet
				return 0

			endif
			break
			
		default:					//something called this function with an unknown name
			DoAlert 0, "Something called "+GetFuncName()+" with an invalid CtrlName."
			return 1
			
	endswitch
	
	DoWindow MasterChannelPanel	//scanning without displaying the data doesn't make any sense
	if (!v_flag)
		DoWindow Channel1Panel		//but they might have individual panels open
		if (!v_flag)					//but if they don't have #1 assume the worst
			MakePanel("MasterChannel")
		endif
	endif
	
	SetDataFolder root:Packages:MFP3D:Main:		//it all happens in here
	
	variable scanPoints = GV("ScanPoints")		//grab all the happy variables
	variable scanRate = GV("ScanRate")
	variable scanSpeed = GV("ScanSpeed")
	variable scanLines = GV("ScanLines")
	variable scanAngle = GV("ScanAngle")
	variable scanSize = GV("ScanSize")
	variable scanRatio = GV("SlowRatio")/GV("FastRatio")
	variable xOffset = GV("XOffset")
	variable yOffset = GV("YOffset")
	variable xLVDTSens = GV("XLVDTSens")
	variable yLVDTSens = GV("YLVDTSens")
	variable xPiezoSens = GV("XPiezoSens")
	variable yPiezoSens = GV("YPiezoSens")
	variable xScanDirection = GV("XScanDirection")
	variable yScanDirection = GV("YScanDirection")
	variable scanMode = GV("ScanMode")
	variable xOffsetVolts, yOffsetVolts, xGain, yGain, xLVDTOffset, yLVDTOffset

	if (scanMode == 0)				//closed loop is the default
		xOffsetVolts = xOffset/abs(xLVDTSens)
		yOffsetVolts = yOffset/abs(yLVDTSens)
		xGain = scanSize/(abs(xLVDTSens)*.8*20)
		yGain = scanSize/(abs(yLVDTSens)*.8*20)
		xLVDTOffset = GV("XLVDTOffset")
		yLVDTOffset = GV("YLVDTOffset")
	else								//open loop
		xOffsetVolts = xOffset/xPiezoSens*xScanDirection
		yOffsetVolts = yOffset/yPiezoSens*yScanDirection
		xGain = -scanSize/(xPiezoSens*.8*160)
		yGain = -scanSize/(yPiezoSens*.8*160)
		xLVDTOffset = 0
		yLVDTOffset = 0
	endif
	
	variable scanDown = mod(GV("ScanDown"),2)		//the second bit of ScanDown has nap info
	variable aDCgain = GV("ADCgain")
	variable driveAmplitude = GV("DriveAmplitude")
	variable driveFrequency = GV("DriveFrequency")
	variable/G DriftTime
	Variable napMode = GV("NapMode")
	SVAR LogFile
	LogFile = "Log File:Start\r"			//start the logfile
	PV("OldScanSize",td_ReadValue("$OutputXLoop.SetpointGain")*5e-9)							//record the current scansize and offsets
	PV("OldYOffset",YOffset)
	PV("OldXOffset",XOffset)
	
//	UpdateAllControls("StopEngageButton",cEngageButtonTitle,"SimpleEngageButton","SimpleEngageMe") //moved to later
	
	variable decimation = round(cMasterSampleRate/(scanRate*scanPoints*2.5))		//calculate the decimation which has to be an integer
	variable interpolation

//	if (0)//(NapMode) && (scanMode == 0) && (scanLines > 512))		//scanLines <= 800
//		MakeScanEngineWaves(scanDown,IsNap=NapMode)				//this makes the ortho scan waves		//these are the old single scan waves, no longer used
//		interpolation = decimation*scanPoints/256						//calculate the interpolation
	if (!scanMode && ((scanLines <= 256) || (!napMode && (scanLines <= 800))))		//closed loop, less than 800 lines, or 256 lines or less if nap mode
		MakeDoubleScanEngineWaves(scanDown,IsNap=NapMode)				//this makes the ortho scan waves
		interpolation = decimation*scanPoints/256						//calculate the interpolation
	elseif (scanMode)										//closed loop raster waves
		MakeScanEngineRasterWaves(ScanDown,scanMode)				//this makes waves the raster way		//everything else, doubled even though not in function name
		interpolation = round(1e5/(scanRate*640))						//calculate the interpolation
	else														//open loop raster waves
		MakeScanEngineRasterWaves(ScanDown,scanMode)				//this makes waves the raster way		//everything else, doubled even though not in function name
		interpolation = round(1e5/(scanRate*8))						//calculate the interpolation
	endif
	
	wave FastWave, SlowWave, SlowWaveBackup					//the waves that it makes

Make/O/N=(ScanLines) TimeWave						//makes a wave to check the timing of ReadUpdateGraph
TimeWave = NaN
	//Set bandwidth on all inputs to 1/3 of the pixel frequency. Actually, bandwidths are not decided yet.
//	variable bandwidth= 2/3*scanRate*scanPoints		//this has never been used
//	errorStr += num2str(ir_WriteValue("Input.FastGain",aDCgain)				//this is now used for both modes
	errorStr += num2str(ARSetFastGain(ADCGain))+","		//Don't use the ImagingModeParms.ADCGain
	//we want the value entered in the control

	SetScanBandwidth()					//this sets the bandwidth to the numbers on the filter panel
	if (!GV("DontChangeXPT"))
		LoadXPTState(ImagingModeParms.XPTString+"Scan")		//update the XPT, this calls UpdateMeterStatus
	else
		UpdateMeterStatus(0)		//low noise changed.
	endif
	
	UpdateAllControls("SimpleEngageButton",cWithdrawButtonTitle,"StopEngageButton","DoScanFunc",DropEnd=2)
	variable currentTime = DateTime
	DriftTime = currentTime		//set the start of the scan time

	//************************************
	//New way.
	//ErrorStr += InitZFeedback0(2,"Always")			//sets up and starts the Z feedback (and FM loops)
	ErrorStr += InitZFeedback(ImagingModeParms)

	//************************************
	errorStr += num2str(td_WriteString("Event.1","Clear"))+","		//just to be sure.  Right now the engage does not leave event 1 on, but lets make sure for the future.
	
	
	
	
	errorStr += num2str(ir_StopPISLoop(NaN,LoopName="outputXLoop"))+","	//if anything, turn it off
	errorStr += num2str(ir_StopPISLoop(NaN,LoopName="outputYLoop"))+","
//	Variable NapTest = ((napMode == 1) || (napMode == 3))
	
	
	if (scanMode == 0)		//closed loop
		
		Struct ARFeedbackStruct FB
		ARGetFeedbackParms(FB,"outputX")
		FB.PGain = 0
		FB.SGain = 0
		IR_WritePIDSloop(FB)
	
		ARGetFeedbackParms(FB,"outputY")
		FB.PGain = 0
		FB.SGain = 0
		IR_WritePIDSloop(FB)
	
	endif

	if (GV("SlowScanEnabled") == 0)		//slow scan is turned off
		variable tempVar = td_ReadValue("Output.ScanSlow")	//where is the slow output?
		FastOp SlowWave = (tempVar)			//set the slow wave to its current value
	endif

	string callbackStr					//make the callback string
	callbackStr = "OutAndTrigger("+num2str(decimation)+","+num2str(interpolation)+","+num2str(ScanDown)+","+num2str(ScanLines)+")"

	if (scanRatio > 1)			//calculate the affect of non square scans
		FastWave /= scanRatio
		PV("FastScanSize",scanSize/scanRatio)
		PV("SlowScanSize",scanSize)
	else
		SlowWave *= scanRatio
		PV("FastScanSize",scanSize)
		PV("SlowScanSize",scanSize*scanRatio)
	endif

	variable xStart, yStart
	if (scanMode == 0)			//closed loop, calculate where we want to start
		xStart = (FastWave[0]*xGain*20)*cos(scanAngle*pi/180)+(SlowWave[0]*xGain*20)*sin(scanAngle*pi/180)+xOffsetVolts+xLVDTOffset
		yStart = -(FastWave[0]*yGain*20)*sin(scanAngle*pi/180)+(SlowWave[0]*yGain*20)*cos(scanAngle*pi/180)+yOffsetVolts+yLVDTOffset
	else				//open loop
		if (GV("SlowScanEnabled"))
			FastOp SlowWave = -1*SlowWave		//the signs are reversed for open loop
		endif
		FastOp FastWave = -1*FastWave
		FastOp SlowWaveBackup = -1*SlowWaveBackup		//calculate where open loop want to start
		xStart = (FastWave[0]*xGain*160)*cos(scanAngle*pi/180)+(SlowWave[0]*xGain*160)*sin(scanAngle*pi/180)+xOffsetVolts+70
		yStart = -(FastWave[0]*yGain*160)*sin(scanAngle*pi/180)+(SlowWave[0]*yGain*160)*cos(scanAngle*pi/180)+yOffsetVolts+70
	endif
	if (scanMode == 0)	//ramp to either the open or closed loop starting point and then call OutAandTrigger
		errorStr += num2str(td_SetRamp(10,"$outputXLoop.Setpoint",2,xStart,"$outputYLoop.Setpoint",2,yStart,"",0,0,callbackStr))+","
	else
		errorStr += num2str(td_SetRamp(10,"Output.X",20,xStart,"Output.Y",20,yStart,"",0,0,callbackStr))+","  //bipolar controllers need the same velocity, since at the Igor level, the bipolar controller only has -10 to +150 volts.
	endif
	
	ARReportError(errorStr)

	SetDataFolder SavedDataFolder
	return(0)

end //DoScanFunc

///////////////////////////////////////////////////////////////////////////////
// Start modification - Suhas
Function ArrayInterfacer(message)
	String message
	
	DoWindow/F ArrayScanPanel
	if(V_flag != 0)
		execute(message)
	endif
	
End
// End of Modification by Suhas
//////////////////////////////////////////////////////////////////////////////

function OutAndTrigger(decimation,interpolation,ScanDown,ScanLines)		//This actually sets up the scan. The XY should be in the right place.
	variable decimation, interpolation, ScanDown, ScanLines

	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main:		//it all happens in here

	variable scanAngle = GV("ScanAngle")			//get all of the variables
	variable scanSize = GV("ScanSize")
	variable xOffset = GV("XOffset")
	variable yOffset = GV("YOffset")
	variable xLVDTSens = GV("XLVDTSens")
	variable yLVDTSens = GV("YLVDTSens")
	variable xPiezoSens = GV("XPiezoSens")
	variable yPiezoSens = GV("YPiezoSens")
	variable xScanDirection = GV("XScanDirection")
	variable yScanDirection = GV("YScanDirection")

	variable dontChangeXPT = GV("DontChangeXPT")
	Struct ARImagingModeStruct ImagingModeParms			//set up a structure
	ARGetImagingMode(ImagingModeParms)					//fill it with goodness
	variable scanMode = GV("ScanMode")
	Variable DFRTOn = GV("DFRTOn")
	variable xGain, yGain, xScanOffset, yScanOffset
	
	PV("SaveImageCount",0)			//reset the save image count
	
	if (scanMode == 0)			//closed loop

		xGain = scanSize/(abs(xLVDTSens)*.8*20)		//these are scan engine gains
		yGain = scanSize/(abs(yLVDTSens)*.8*20)
		xScanOffset = GV("XLVDTOffset")/20+(xOffset/(abs(xLVDTSens)*20))
		yScanOffset = GV("YLVDTOffset")/20+(yOffset/(abs(yLVDTSens)*20))
		
	else							//open loop

		xGain = scanSize/(xPiezoSens*.8*160)
		yGain = scanSize/(yPiezoSens*.8*160)
		xScanOffset = -((xOffset/xPiezoSens)/160)*xScanDirection
		yScanOffset = -((yOffset/yPiezoSens)/160)*yScanDirection

	endif
	
	variable xPgain = xLVDTSens*10^GV("XPGain")		//multiplying by the sensitivity takes care of some gain issues,
	variable xIgain = xLVDTSens*10^GV("XIGain")			//but more importantly makes sure the sign is correct
	variable yPgain = yLVDTSens*10^GV("YPGain")
	variable yIgain = yLVDTSens*10^GV("YIGain")
	variable xSgain = xLVDTSens*10^GV("XSGain")
	variable ySgain = yLVDTSens*10^GV("YSGain")
	wave FastWave, SlowWave, SlowWaveBackup
	variable napMode = GV("NapMode")
	string triggerStr = "5"					//triggering off of event 5 is what turns nap mode on
	if ((napMode == 2) || (napMode == 0))		//napmode 2 is just two interleaved scans without lifting on the second pass
		triggerStr = "0"
	endif
	variable napOn = napMode > 0			//when napOn is 1 then the waves and everything are twice as big
	
	String errorStr = ""														//this accumulates any errors from td functions
	errorStr += num2str(ir_WriteValue("ScanEngine.XGain",xGain))+","	//set up the scan engine			//checkme vvvv
	errorStr += num2str(ir_WriteValue("ScanEngine.YGain",yGain))+","
	errorStr += num2str(ir_WriteValue("ScanEngine.XOffset",xScanOffset))+","
	errorStr += num2str(ir_WriteValue("ScanEngine.YOffset",yScanOffset))+","
	errorStr += num2str(ir_WriteValue("output.ScanFast",FastWave[0]))+","
	errorStr += num2str(ir_WriteValue("output.ScanSlow",SlowWave[0]))+","
	errorStr += num2str(ir_WriteValue("ScanEngine.Sin",sin(scanAngle*pi/180)))+","
	errorStr += num2str(ir_WriteValue("ScanEngine.Cos",cos(scanAngle*pi/180)))+","
	
	if (scanMode == 0)			//closed loop

		errorStr += num2str(td_WriteString("ScanEngine.XDestination","$outputXLoop.Setpoint"))+","	//set the setpoint
		errorStr += num2str(td_WriteString("ScanEngine.YDestination","$outputYLoop.Setpoint"))+","
					//these gains were not set before, just integral
		errorStr += num2str(ir_WriteValue("$OutputXLoop.PGain",xPGain))+","
		errorStr += num2str(ir_WriteValue("$OutputXLoop.SGain",xSGain))+","
		errorStr += num2str(ir_WriteValue("$OutputYLoop.PGain",yPGain))+","
		errorStr += num2str(ir_WriteValue("$OutputYLoop.SGain",ySGain))+","
	else																							//open loop
		errorStr += num2str(td_WriteString("ScanEngine.XDestination","Output.X"))+","	//hook up the outputs
		errorStr += num2str(td_WriteString("ScanEngine.YDestination","Output.Y"))+","
	endif
		
	//stop before setting the out waves
	errorStr += num2str(td_StopOutWaveBank(-1))+","
	errorStr += num2str(td_WriteString("Event.5","Clear"))+","		//this might be set if Nap mode was running before
			//these drive the X & Y stages
			
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////// BEGIN CODE MODIFICATION BY SUHAS ////////////////////////////////////////
	
	// This is being used to supply a trigger channel for delineating the start and end of the trace and retrace.
	// It is the user's responsibility to connect Output.C to a BNC out channel
	
	Variable numpts = Dimsize(FastWave,0)/2.5;
	Make/O/N=(Dimsize(Fastwave,0)) SuhasWave;
	Variable indx=0;
	for(indx=0;indx<numpts*(1/8);indx=indx+1)
		SuhasWave[indx] = 2.2
	endfor
	for(indx=numpts*(1/8);indx<numpts*(9/8);indx=indx+1)
		SuhasWave[indx] = 4.2
	endfor
	for(indx=numpts*(9/8);indx<numpts*(11/8);indx=indx+1)
		SuhasWave[indx] = 6.2
	endfor
	for(indx=numpts*(11/8);indx<numpts*(19/8);indx=indx+1)
		SuhasWave[indx] = 8.2
	endfor
	for(indx=numpts*(19/8);indx<numpts*(20/8);indx=indx+1)
		SuhasWave[indx] = 2.2
	endfor
	
	// Original Line:
	//errorStr += num2str(td_xSetOutWave(0,triggerStr+",2","Output.ScanFast",FastWave,Decimation))+","	//set up the fast wave
	
	errorStr += num2str(td_xSetOutWavePair(0,triggerStr+",2","Output.ScanFast",FastWave,"Output.C",SuhasWave,Decimation))+","	//set up the fast wave
	
	///////////////////////////// END CODE MODIFICATION BY SUHAS ////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	if (GV("DisplayLVDTTraces"))											//if we are displaying LVDT traces, set that up here
		if (GV("ScanMode"))
			errorStr += num2str(td_WriteString("OutWave0StatusCallback","CheckOpenXYFunc()"))+","			//closed loop
		else
			errorStr += num2str(td_WriteString("OutWave0StatusCallback","CheckXYFunc()"))+","		//open loop
		endif
	else
		errorStr += num2str(td_WriteString("OutWave0StatusCallback","CheckSaveFunc()"))+","			//this now always runs, both CheckXY functions call this
	endif
	
	if (GV("ScanMode"))

		if (napMode)
			errorStr += num2str(td_xSetOutWave(1,triggerStr+",2","Output.ScanSlow",SlowWave,-Interpolation*256*2.5*2))+","
//			errorStr += num2str(td_xSetOutWavePair(1,triggerStr+",2","Output.ScanSlow",SlowWave,"Output.Dummy",SlowWaveBackup,-Interpolation*256*2.5*2))+","
			PV("Interpolate",-Interpolation*256*2.5*2)
		else

				//these no longer have to be set up as a pair to get the update to work so Slow Scan disabled works
//			errorStr += num2str(td_xSetOutWavePair(1,"0,2","ScanSlow%Output",SlowWave,"Dummy%Output",SlowWaveBackup,-Interpolation*256*2.5))+","
			errorStr += num2str(td_xSetOutWave(1,"0,2","Output.ScanSlow",SlowWave,-Interpolation*256*2.5))+","
			PV("Interpolate",-Interpolation*256*2.5)
		endif

	else

				//these no longer have to be set up as a pair to get the update to work so Slow Scan disabled works
//		errorStr += num2str(td_xSetOutWavePair(1,triggerStr+",2","ScanSlow%Output",SlowWave,"Dummy%Output",SlowWaveBackup,-Interpolation*8))+","
		errorStr += num2str(td_xSetOutWave(1,triggerStr+",2","Output.ScanSlow",SlowWave,-Interpolation*8))+","
		PV("Interpolate",-Interpolation*8)

	endif

	if (NapMode & 1)
		errorStr += num2str(td_xSetOutWave(2,triggerStr+","+triggerStr,"Height",NapWave,Decimation))+","		//we need this for true napmode or stupid nap mode
	endif

	if (GV("IsScanBias"))				//this means that we are going to write an image during the scan
//		UpdateAllXPT("BNCOut0","OutA")			//hook up BNC Out 0
		if (PrepareImageWrite(GV("ScanPoints"),GV("ScanLines"),scanDown))		//this gets the image ready
			DoScanFunc("StopScan")					//if there were issues then stop the scan
			return 1
		endif
		//errorStr += num2str(td_xSetOutWavePair(2,triggerStr+",2","TipBias",ImageDrive,"Output.Dummy",ImageDrive,Decimation))+","
		errorStr += num2str(td_xSetOutWave(2,triggerStr+",2","TipBias",ImageDrive,Decimation))+","
		errorStr += num2str(td_WriteString("OutWave0StatusCallback","UpdateImageWrite("+num2str(GV("ScanPoints"))+","+num2str(GV("ScanLines"))+","+num2str(decimation)+","+num2str(scanDown)+","+num2str(GV("LithoBiasOff"))+",0)"))+","
		errorStr += num2str(td_WriteString("OutWave2StatusCallback","UpdateImageWrite("+num2str(GV("ScanPoints"))+","+num2str(GV("ScanLines"))+","+num2str(decimation)+","+num2str(scanDown)+","+num2str(GV("LithoBiasOff"))+",1)"))+","
		DoScanFunc("LastBiasScan_0")				//this makes sure it only does one
	else							//we aren't doing a bias write scan, so reset everything
//		if (GV("HVPFMHolder"))
//			UpdateAllXPT("BNCOut0","DDS")
//		else
//			UpdateAllXPT("BNCOut0","Ground")
//		endif
		errorStr += num2str(td_WriteString("OutWave2StatusCallback",""))+","
	endif

	//stop before setting the in waves
	errorStr += IR_StopInWaveBank(-1)
	AdjustScanWaves()				//this makes sure all of the input, image and scope waves are the right size

	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeLIst		//the list of data channels
	SVAR MICL = root:Packages:MFP3D:Main:Variables:MasterInChannelLIst		//the list of in channels, which have different names
	variable dataTypeSum = GV("DataTypeSum")	//grab DataTypeSum, which is a bit total of the needed channels
	Variable AllDataTypeSum = DataTypeSum		//keep a copy, we pull out the special Channel from DataTypeSum
	string chanSpecialStr, waveSpecialStr
	variable specialNum = GV("Channel1DataType")
	
	waveSpecialStr = StringFromList(specialNum,MDTL)			//grab the channel set to be 32 bits
	chanSpecialStr = StringFromList(specialNum,MICL)
	waveSpecialStr = FindUserName(waveSpecialStr,"Name")+"Wave"
//	if (stringmatch(chanSpecialStr,"DDSFrequencyOffset0"))
//		chanSpecialStr = "Freq%DDS"
//	endif

	String ChannelList = GTS("DataTypeSum")
	Variable IsFreq = (WhichListItem("Frequency",ChannelList,";",0,0) >= 0)	//is frequency or potential turned on?
	Variable IsPot = (WhichListItem("Potential",ChannelList,";",0,0) >= 0)
	Variable IsCurrent = (WhichListItem("Current",ChannelList,";",0,0) >= 0)
	if (IsFreq)		//capturing frequency

		wave/T DynamicAlias = $GetDF("Alias")+"DynamicAlias"
		if (stringmatch(waveSpecialStr,"FrequencyWave"))			//if frequency is captured in 32 bits
			DynamicAlias[%Frequency][0] = "$DDSFrequency0"//td_ReadString("Alias:DDSFrequency0")//"Lockin.0.Freq"				//then setup the PIS loop so it drives Frequency
		else
			DynamicAlias[%Frequency][0] = "$DDSFrequencyOffset0"//td_ReadString("Alias:DDSFrequencyOffset0")//"Lockin.0.FreqOffset"		//otherwise drive the offset with the PIS loop
		endif
		WriteAllAliases()				//we adjusted aliases

	endif

	ErrorStr += IR_XSetInWave(2,triggerStr+",2",chanSpecialStr,$waveSpecialStr,"SaveImageFunc(100)",Decimation)	//set the 32 bit channel
	dataTypeSum -= 2^(specialNum-1)
	
	string chan1Str = "", chan2Str = "", chan3Str = "", chan4Str = ""
	string wave1Str = "", wave2Str = "", wave3Str = "", wave4Str = ""
	variable i, chanTotal = 0, inCount = 0, ADCError = 0
	ADCError += ADCcheck(chanSpecialStr,waveSpecialStr,chanTotal,inCount)
	chanTotal = 0
	
	for (i = 0;i < ItemsInList(MDTL);i += 1)		//go through the whole list, 0 is off

		if ((2^i) & DataTypeSum)
			if (stringmatch(StringFromList(i+1,MICL),"None"))
				continue
			endif
			chanTotal += 1								//we are using one more channel
			
			
			switch (chanTotal)							//set up the channels one by one

				case 1:
					chan1Str = StringFromList(i+1,MICL)				//the name of the input channel
					wave1Str = StringFromList(i+1,MDTL)				//the name of the input wave
					break

				case 2:
					chan2Str = StringFromList(i+1,MICL)
					wave2Str = StringFromList(i+1,MDTL)
					break

				case 3:
					chan3Str = StringFromList(i+1,MICL)
					wave3Str = StringFromList(i+1,MDTL)
					break

				case 4:
					chan4Str = StringFromList(i+1,MICL)
					wave4Str = StringFromList(i+1,MDTL)
					break

			endswitch
		endif
	endfor											//when this is through chanTotal is the total number of channels

//	wave/T checkXPT = root:Packages:MFP3D:XPT:Originals:ACScan
	if (IsPot && (napMode & 1))
//
		//Potential feedback
		ElectricBoxFunc("PotentialGainOnBox",2)
//		UpdateXPT("ACScan","BNCOut0","OutC")
//		UpdateXPT("ACScan","PogoOut","OutC")
//
//	elseif (stringmatch(checkXPT[%BNCOut0][0],"OutC"))			//Undo the potential case.
//
//		UpdateXPT("ACScan","BNCOut0","Ground")
//		UpdateXPT("ACScan","PogoOut","Ground")
//		
	endif

	if (!dontChangeXPT)				//if we can adjust the XPT
		wave MeterStatus = root:Packages:MFP3D:Meter:MeterStatus
		variable meterRun = MeterStatus[%Run][0]

		//AdjustScanXPT()//waveSpecialStr,wave1Str,wave2Str,wave3Str,wave4Str,ImagingModeParms.ImagingMode)		//adjust the XPT to match the desired channels
		LoadXPTState(ImagingModeParms.XPTString+"Scan")				//and load it

	endif

	if (stringMatch(chan1Str+chan2Str+chan3Str+chan4Str,"*Stop*"))		//I don't think that chan#Str can be set to stop anymore	
		return 1
	endif
	if (ADCError)			//stop things if there are not enough ADCs to collect all of the channels
		DoAlert 0,"You have asked for too many ADCs to collect your data.\rPlease turn a channel off, or select a different channel that does not need an ADC\rand restart the scan."
		DoScanFunc("StopScan_0")
		return(0)
	endif


	if (IsFreq)		//capturing frequency
	
	
		Struct ARFeedbackStruct FB
		ARGetFeedbackParms(FB,"Frequency")
		FB.PGain = 0
		FB.SGain = 0


		if (DFRTOn && ImagingModeParms.ImagingMode == 3)		//setting up DFRT happens elsewhere
		elseif (((napMode == 0) || (napMode == 2)) && (ImagingModeParms.imagingMode != 2))		//not doing real nap mode but capturing frequency
			errorStr += num2str(ir_WriteValue("DDSFrequencyOffset0",0))+","		//set the offset to 0
			ErrorStr += 	IR_WritePIDSloop(FB)

		elseif (ImagingModeParms.imagingMode != 2)				//FM mode gets setup elsewhere

//			errorStr += num2str(ir_WriteValue("$FrequencyLoop.Status",0))+","				//checkme
			errorStr += num2str(ir_WriteValue("DDSFrequencyOffset0",0))+","		//set the offset to 0
			FB.StartEvent = "1"
			FB.StopEvent = num2str(FreqStopEvent)
			ErrorStr += 	IR_WritePIDSloop(FB)
		endif
	endif


	//This should be handled by WriteBias when the crosspoint is loaded up.
//	if (IsCurrent)			//if we are looking at current
//		errorStr += num2str(ir_WriteValue("SurfaceBias",GV("BiasVoltage")+GV("SurfaceBiasOffset")))+","		//hook up the bias //checkme
//	endif

	
	//JB Counter%Input hack
	//we need to force Counter%Input on bank 1
	//so if it is slotted to be on Bank0 (< 2 other channels selected), switch things around.
	String ChanList = Chan1Str+";"+Chan2Str+";"+Chan3Str+";"+Chan4Str+";"
	Variable FirstBank = 0
	Variable SecondBank = 1
	Variable CountIndex = WhichListItem("Count",ChanList,";",0,0)
	if ((CountIndex >= 0) && (CountIndex < 2))
		SwapVars(FirstBank,SecondBank)
	endif
	//End JB Counter Hack		

	if (GV("DisplayLVDTTraces"))				//when this is on the XY LVDT traces are captured
		chanTotal = Limit(chanTotal,0,2)		//this uses the last bank so only 2 other channels are available
		
		//this is now the same for open or closed loop
		ErrorStr += IR_XSetInWavePair(SecondBank,triggerStr+",Always","XSensor",XLVDT,"YSensor",YLVDT,"",Decimation)

		Wave XLVDT, XRes, YRes, DisplayXDrive, DisplayYDrive, DisplayXLVDT, DisplayYLVDT						//XLVDT gets scaled when it is set as an output wave
		CopyScales/P XLVDT XRes, YRes, DisplayXDrive, DisplayYDrive, DisplayXLVDT, DisplayYLVDT		//copy the scale from XLVDT to the rest
		
	endif

	wave1Str = FindUserName(wave1Str,"Name")+"Wave"			//these might have different names if they are user waves
	wave2Str = FindUserName(wave2Str,"Name")+"Wave"
	wave3Str = FindUserName(wave3Str,"Name")+"Wave"
	wave4Str = FindUserName(wave4Str,"Name")+"Wave"

	switch (chanTotal)						//set up the waves according to how many there are

		case 1:
			ErrorStr += IR_XSetInWave(FirstBank,triggerStr+",2",chan1Str,$wave1Str,"",Decimation)
			break

		case 2:
			ErrorStr += IR_XSetInWavePair(FirstBank,triggerStr+",2",chan1Str,$wave1Str,chan2Str,$wave2Str,"",Decimation)
			break

		case 3:
			ErrorStr += IR_XSetInWavePair(FirstBank,triggerStr+",2",chan1Str,$wave1Str,chan2Str,$wave2Str,"",Decimation)
			ErrorStr += IR_XSetInWave(SecondBank,triggerStr+",2",chan3Str,$wave3Str,"",Decimation)
			break

		case 4:
			ErrorStr += IR_XSetInWavePair(FirstBank,triggerStr+",2",chan1Str,$wave1Str,chan2Str,$wave2Str,"",Decimation)
			ErrorStr += IR_XSetInWavePair(SecondBank,triggerStr+",2",chan3Str,$wave3Str,chan4Str,$wave4Str,"",Decimation)
			break
		
	endswitch

	BackgroundInfo
	if (V_flag)
		KillBackground			//kill any active background task
	endif

	PV("StartHeadTemp",td_ReadValue("Temperature@Head"))			//capture the temps for the note
	PV("StartScannerTemp",td_ReadValue("Temperature@Scanner"))
	wave/Z DegreesWave = root:Packages:MFP3D:Heater:DegreesWave		//if this wave exists
	if (WaveExists(DegreesWave))
		PV("StartBioHeaterTemp",DegreesWave[td_ReadValue("CurrentValue@Heater")])		//get the temp of the bioheater
	endif
 	if (ScanDown)					//the call function is different if we are going up or down
		variable/G LineCount = ScanLines-1//*(1+(napMode > 0))-1			//if down then the LineCount is maxed
		SetBackground UpdateRealGraph(1)
	else
		variable/G LineCount = 0		//start at 0
		SetBackground UpdateRealGraph(0)
 	endif
 	errorStr += num2str(td_WriteString("Event.4","Clear"))+","
	CtrlBackground start,period=6,noBurst=1				//start the background at 10 hz

 	AdjustSwapParms()				//adjust the swap parms
 	PV("UpdateCounter",0)
 	PV("StartLineCount",td_ReadValue("LinenumOutWave0"))
 	
	if (Exists("UserOutAndTrigger"))		//call the user function if it exists
		FuncRef DoNothing UserFunc=$"UserOutAndTrigger"
		UserFunc()
	endif	
 	
 	
  	errorStr += num2str(td_WriteString("Event.2","Set"))+","			//this means that waves that repeat keep running
	errorStr += num2str(td_WriteString("Event.0","Clear"))+","		//set everything going
 	if (napMode == 3)
	 	errorStr += num2str(td_WriteString("Event.6","Set"))+","		//6 means that we are in snap mode
 	else
	 	errorStr += num2str(td_WriteString("Event.6","Clear"))+","	//no 6 means normal nap mode
	endif
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/// Modification by Suhas for Array Scan
	// Warning: This requires the arrayscan to be called at all times
	// Make this run only if the corresponding function is compiled
	// Make this trigger a variable function. So that functions may be modified
	ArrayInterfacer("StartDataAcquisition()");
	//TwoChannelScan()
	/// End of modification by Suhas
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	if (napMode)
		errorStr += num2str(td_WriteString("Event."+triggerStr,"Set"))+","		//set everything going
	else
		errorStr += num2str(td_WriteString("Event.0","Once"))+","		//set everything going
		errorStr += Num2str(td_WriteString("Event.1","Once"))+","		//This is for the feedback loops, that might depend on ParmSwapper to turn on.
	endif
	
	
	
	UpdateAllControls("LastScan_0",StringFromList(GV("LastScan"),"Last Scan;Waiting...;",";"),"","")
	UpdateAllControls("MeterSetup","","","",Disable=2)
	SetDisable(0)

	ARCallbackFunc("ImageGo")

	ARReportError(errorStr)
	
//	Variable LastMacroMode = GV("LastARMacroMode")
//	if (LastMacroMode)
//		SwapMacroMode(0)
//		if (LastMacroMode & 1)
//			PostARMacro("",nan,"","")		//just leave it empty, it will call the next step.
//		endif
//	endif
	
	SetDataFolder SavedDataFolder
	return(0)
end //OutAndTrigger

function FakeScanSetup()				//this tries to duplicate the XPT setup, it is called by a button on the crosspoint panel

	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main:		//it all happens in here
	
	
	Struct ARImagingModeStruct ImagingModeParms
	ARGetImagingMode(ImagingModeParms)
	
	variable napMode = GV("NapMode")
	variable napOn = napMode > 0

//	AdjustScanWaves()				//this makes sure all of the input, image and scope waves are the right size

	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList		//the list of data channels
	SVAR MICL = root:Packages:MFP3D:Main:Variables:MasterInChannelList		//the list of in channels, which have different names
	variable dataTypeSum = GV("DataTypeSum")	//grab DataTypeSum, which is a bit total of the needed channels
	Variable AllDataTypeSum = DataTypeSum		//keep a copy, we pull out the special Channel from DataTypeSum
	string chanSpecialStr, waveSpecialStr
	variable specialNum = GV("Channel1DataType")
	
	waveSpecialStr = StringFromList(specialNum,MDTL)
	chanSpecialStr = StringFromList(specialNum,MICL)
	waveSpecialStr = FindUserName(waveSpecialStr,"Name")+"Wave"
	dataTypeSum -= 2^(specialNum-1)
	
	string chan1Str = "", chan2Str = "", chan3Str = "", chan4Str = ""
	string wave1Str = "", wave2Str = "", wave3Str = "", wave4Str = ""
	variable i, chanTotal = 0, inCount = 0, ADCError = 0

	ADCError += ADCcheck(chanSpecialStr,waveSpecialStr,chanTotal,inCount)
	chanTotal = 0
	
	for (i = 0;i < ItemsInList(MDTL);i += 1)		//go through the whole list, 0 is off

		if ((2^i) & DataTypeSum)
			if (stringmatch(StringFromList(i+1,MICL),"None"))
				continue
			endif
			chanTotal += 1								//we are using one more channel
			
			
			switch (chanTotal)							//set up the channels one by one

				case 1:
					chan1Str = StringFromList(i+1,MICL)				//the name of the input channel
					wave1Str = StringFromList(i+1,MDTL)				//the name of the input wave
					ADCError += ADCcheck(chan1Str,wave1Str,chanTotal,inCount)
					break

				case 2:
					chan2Str = StringFromList(i+1,MICL)
					wave2Str = StringFromList(i+1,MDTL)
					ADCError += ADCcheck(chan2Str,wave2Str,chanTotal,inCount)
					break

				case 3:
					chan3Str = StringFromList(i+1,MICL)
					wave3Str = StringFromList(i+1,MDTL)
					ADCError += ADCcheck(chan3Str,wave3Str,chanTotal,inCount)
					break

				case 4:
					chan4Str = StringFromList(i+1,MICL)
					wave4Str = StringFromList(i+1,MDTL)
					ADCError += ADCcheck(chan4Str,wave4Str,chanTotal,inCount)
					break

			endswitch
		endif
	endfor											//when this is through chanTotal is the total number of channels
	if (ADCError)
		DoAlert 0,"You have asked for too many ADCs to collect your data.\rPlease turn a channel off, or select a different channel that does not need an ADC\rand restart the scan."
		DoScanFunc("StopScan_0")
		return(0)
	endif

//	if ((2^(WhichListItem("Deflection",MDTL,";",0,0)-1) & DataTypeSum) && (inCount < 2))
//		Switch (ImagingModeParms.ImagingMode)
//			case 1:		//AC
//			case 2:		//FM
//				if (stringmatch(wave1Str,"Deflection"))
//					chan1Str = "B%Input"
//				elseif (stringmatch(wave2Str,"Deflection"))
//					chan2Str = "B%Input"
//				elseif (stringmatch(wave3Str,"Deflection"))
//					chan3Str = "B%Input"
//				else
//					chan4Str = "B%Input"
//				endif
//				inCount += 1
//				break
//		endswitch
//		
//	endif
	
//	wave/T checkXPT = root:Packages:MFP3D:XPT:Originals:ACScan
//	if ((WhichListItem("Potential",GTS("DataTypeSum"),";",0,0) >= 0) && ((napMode == 1) || (napMode == 3)))
//		UpdateXPT("ACScan","BNCOut0","OutC")
//		UpdateXPT("ACScan","PogoOut","OutC")
//	elseif (stringmatch(checkXPT[%BNCOut0][0],"OutC"))			//undo the potential change above.
//		UpdateXPT("ACScan","BNCOut0","Ground")
//		UpdateXPT("ACScan","PogoOut","Ground")
//		
//	endif

	if (!GV("DontChangeXPT"))
		wave MeterStatus = root:Packages:MFP3D:Meter:MeterStatus
		variable meterRun = MeterStatus[%Run][0]

		//AdjustScanXPT()//waveSpecialStr,wave1Str,wave2Str,wave3Str,wave4Str,ImagingModeParms.imagingMode)
		LoadXPTState(ImagingModeParms.XPTString+"Scan")
	endif

 	AdjustSwapParms()

	SetDataFolder SavedDataFolder

end //FakeScanSetup

function/S FindUserName(chanStr,whichStr)		//this returns the current user name for the user channels
	string chanStr, whichStr						//whichStr is either Name, Ab, or Force

	wave/T GSW = root:Packages:MFP3D:Main:Strings:GlobalStrings
	variable index
//	string inStr = chanStr[0,6]
//	string calcStr = chanStr[0,7]


	//the chanStr[0,Strlen("UserInX")-1]
	//is so you can pass it UserIn0Volts and UserIn0 and get similar results.
	//Force plots were failing for graphs of UserIn0Volts.
	
	String ReducedChannelStr = ""
	if (StrinGmatch(ChanStr,"User*"))
		if (StringMatch(ChanStr,"UserIn*"))
			ReducedChannelStr = ChanStr[0,Strlen("UserInX")-1]
		elseif (StringMatch(ChanStr,"UserCalc*"))
			ReducedChannelStr = ChanStr[0,strlen("UserCalc")-1]
		endif
	endif
	

	if (Strlen(ReducedChannelStr) && strlen(GSW[%$ReducedChannelStr+"Name"]))	//if there is something in the Global Strings wave
		return GSW[%$ReducedChannelStr+whichStr]											//then it has been renamed, so return that name
	else													//otherwise return the stock name
		strswitch (whichStr)
			case "Name":
				return chanStr
	
			case "Ab":
				index = WhichListItem(chanStr,ARFullChannelNames,";",0,0)
				return StringFromList(index,ARShortChannelNames)
	
			case "Force":
				index = WhichListItem(chanStr,ARFullChannelNames,";",0,0)
				return StringFromList(index,ARForceChannelNames)

		endswitch
		
	endif
	
end //FindUserNames



function ClearEvents()				//clears all of the events

	variable i
	for (i = 0;i <= 14;i += 1)
		td_WriteString("Event"+num2str(i),"Clear")
	endfor

end //ClearEvents

									//obselete, no longer used
//function MakeAmpWave(AmpWave)			//makes a wave for drive amplitude for both normal and nap scans
//	wave AmpWave
//
//	variable normAmp = GV("DriveAmplitude")
//	variable napAmp = GV("NapDriveAmplitude")
//
//	FastOp AmpWave = (normAmp)
//
//	if (GV("NapParms") & 1)
//		AmpWave = ((mod(p,160) > 79) * napAmp)+((mod(p,160) <= 79)*normAmp)
//	endif
//	
//end //MakeAmpWave

function MakeNapWave()			//make the wave that raises the tip during the nap scans

	variable napHeightVolts = -GV("NapHeight")/GV("ZPiezoSens")
	variable realScanPoints = GV("ScanPoints")*2.5
	variable napStartHeightVolts = -GV("NapStartHeight")/GV("ZPiezoSens")
	variable roundLength = GV("ScanPoints")*3/32
	Make/O/N=(realScanPoints) NapWave
	NapWave = napHeightVolts+70
	
	if (napStartHeightVolts)					//only do the start height if there is something in there
		Napwave[0,roundLength] = p*napStartHeightVolts/roundLength+70
		NapWave[roundLength+1,roundLength*2] = napStartHeightVolts-(p-roundLength)/roundLength*(napStartHeightVolts-napHeightVolts)+70
		NapWave[realScanPoints-roundLength,realScanPoints-1] = (realScanPoints-p-1)*napHeightVolts/roundLength+70
	else
		Napwave[0,roundLength] = p*napHeightVolts/roundLength+70
		NapWave[realScanPoints-roundLength,realScanPoints-1] = (realScanPoints-p-1)*napHeightVolts/roundLength+70
	endif
	
end //MakeNapWave

function SlowScanFunc(on)
	variable on
	
	wave SlowWave = root:Packages:MFP3D:Main:SlowWave
	wave SlowWaveBackup = root:Packages:MFP3D:Main:SlowWaveBackup
	variable staticVar, moveVar, factor = 160
	if (GV("ScanMode"))
		factor = 2
	endif
	variable point = (factor/2)*(td_ReadValue("LinenumOutWave0")+2)
	
	if (on)
		staticVar = SlowWave[point]
		moveVar = SlowWaveBackup[point+factor]
		SlowWave[point,point+factor] = staticVar+(moveVar-staticVar)*(p-point)/factor
		SlowWave[point+factor,] = SlowWaveBackup
		PV("DelayUpdate",GV("DelayUpdate") | 4)
	else
		staticVar = td_ReadValue("output.ScanSlow")
		FastOp SlowWave = (staticVar)
	endif

	UpdateLog("SlowScanEnabled",on)
	String errorStr = ""
	variable interpolateVar = GV("Interpolate")
//	if (GV("ScanLines") > 800 || GV("ScanMode"))
//		interpolateVar *= 8
//	endif
	
	
	errorStr += num2str(td_xSetOutWave(1,"update,2","output.ScanSlow",root:Packages:MFP3D:Main:SlowWave,GV("Interpolate")))+","
	ARReportError(errorStr)
	
	
end //SlowScanFunc

function MakeRamp(Bank,Channel,Start,Finish,Speed,Gain,rampInterp)	//This makes a ramp and sets up the out wave on the specified channel and bank
	string Channel
	variable Bank, Start, Finish, Speed, Gain, &rampInterp		//rampInterp is passed by reference so the interpolation gets back to the calling function
	String ErrorStr = ""

	variable distance = Finish-Start							//calculate the distance
	variable timeVar = limit(abs(distance*Gain/Speed),0,10)	//calculate the time with a limit of 10 seconds
	rampInterp = round(timeVar*cMasterSampleRate/256)						//calculate the interpolation for a 256 point wave
	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main
	
	Make/O/N=(256) RampWave										//make the wave
	RampWave = Start+(distance*p/(255))						//make the ramp
	ErrorStr = num2str(td_xSetOutWave(Bank,"0",Channel,RampWave,-rampInterp)) + ","	//set up the wave, the negative interpolation means use linear interpolation
//	variable ErrorStr += num2str(td_XSetOutWave(Bank,"User0",Channel,RampWave,-rampInterp)) + ","		//set up the wave, the negative interpolation means use linear interpolation
//	Variable ErrorStr += num2str(td_XSetOutWave(Bank,"Event.0","Setpoint%PISLoop4",RampWave,-RampInterp)) + ","
	
	SetDataFolder SavedDataFolder
	if ((abs(distance*Gain) < .001) || (rampInterp == 0))		//if either of these is true we don't have to ramp. The .01 is volts
		return 0
	else
		return 1	
	endif
	
	ARReportError(ErrorStr)
end //MakeRamp

//function MakeScanWaves(down)			//makes scan waves with any rotation
//	variable down
//	
//	variable ScanPoints = 8	//GV("ScanPoints")		//this is locked at 16 by low level wave size limitations
//	variable ScanRate = GV("ScanRate")
//	variable ScanLines = GV("ScanLines")
//	variable ScanAngle = GV("ScanAngle")
//	variable XLVDTSens = GV("XLVDTSens")
//	variable YLVDTSens = GV("YLVDTSens")
//	
//	variable stop = ScanPoints*(ScanLines+2)*2.5+1  		//The out wave now ends in the middle of the cap, it is actually longer than the
////	variable stop=ScanPoints*ScanLines*2.5+1-(ScanPoints/4)	//in waves. Since we restart between every scan, it isn't a problem
//	variable XDriveOffset = GV("XDriveOffset")
//	variable YDriveOffset = GV("YDriveOffset")
//
//	Make/O/N=(stop) XWave, YWave//, colorWave		//Make the waves. The color wave is just for different colors on trace and retrace for display
//
//	variable i, value
//	if (down)				//down and up are opposite
//		for (i = 0;i <= stop;i += 1)		//these numbers are no longer weird as that the experimental X & YDriveOffset didn't work
//			value = FastScan(i-2)		//This is the fast scan value. The proportion of the Fast vs Slow in X and Y is calculated from the angle
//			XWave[stop-i] = cos(ScanAngle*Pi/180)*value+sin(ScanAngle*pi/180)*(i-ScanPoints/8)/(ScanLines*ScanPoints*2.5-ScanPoints/4)
//			YWave[stop-i] = -sin(ScanAngle*Pi/180)*value+cos(ScanAngle*pi/180)*(i-ScanPoints/8)/(ScanLines*ScanPoints*2.5-ScanPoints/4)
//		endfor									//The first part is the fast scan. The rest is the slow scan which is calculated here
//	else
//		for (i = 0;i < stop;i += 1)
//			value = FastScan(i+1)
//			XWave[i] = cos(ScanAngle*Pi/180)*value+sin(ScanAngle*pi/180)*(i-ScanPoints/8+1)/(ScanLines*ScanPoints*2.5-ScanPoints/4)
//			YWave[i] = -sin(ScanAngle*Pi/180)*value+cos(ScanAngle*pi/180)*(i-ScanPoints/8+1)/(ScanLines*ScanPoints*2.5-ScanPoints/4)
//		endfor
//	endif
//	
//	XWave -= cos(ScanAngle*Pi/180)/2+(1+2/ScanLines)*sin(ScanAngle*Pi/180)/2			//center the XWave
//	YWave -= -sin(ScanAngle*Pi/180)/2+(1+2/ScanLines)*cos(ScanAngle*Pi/180)/2		//center the YWave
//	
//	//The waves now have a size of 1 (except for caps) centered around 0. The rest of the commands scale them
//	
//	FastOp XWave = (5e-9/XLVDTSens)*Xwave
//	FastOp Ywave = (5e-9/YLVDTSens)*YWave
//	
//end //MakeScanWaves
//
//function newMakeScanWaves(down)			//makes scan waves with any rotation
//	variable down
//	
//	variable ScanPoints = 32	//GV("ScanPoints")		//this is locked at 16 by low level wave size limitations
//	variable ScanRate = GV("ScanRate")
//	variable ScanLines = GV("ScanLines")
//	variable ScanAngle = GV("ScanAngle")
//	variable XLVDTSens = GV("XLVDTSens")
//	variable YLVDTSens = GV("YLVDTSens")
//	
//	variable stop = ScanPoints*(ScanLines+2)*2.5+1  		//The out wave now ends in the middle of the cap, it is actually longer than the
////	variable stop=ScanPoints*ScanLines*2.5+1-(ScanPoints/4)	//in waves. Since we restart between every scan, it isn't a problem
//	variable XDriveOffset = GV("XDriveOffset")
//	variable YDriveOffset = GV("YDriveOffset")
//
//	Make/O/N=(stop) XWave, YWave//, colorWave		//Make the waves. The color wave is just for different colors on trace and retrace for display
//
//	variable i, value, slowValue
//	if (down)				//down and up are opposite
//		for (i = 0;i <= stop;i += 1)		//these numbers are no longer weird as that the experimental X & YDriveOffset didn't work
//			value = newFastScan(i+38)		//This is the fast scan value. The proportion of the Fast vs Slow in X and Y is calculated from the angle
//			slowValue = newSlowScan(i-2,ScanPoints,ScanLines)
//			XWave[stop-i] = cos(ScanAngle*Pi/180)*value+sin(ScanAngle*pi/180)*slowValue
//			YWave[stop-i] = -sin(ScanAngle*Pi/180)*value+cos(ScanAngle*pi/180)*slowValue
//		endfor									//The first part is the fast scan. The rest is the slow scan which is calculated here
//	else
//		for (i = 0;i < stop;i += 1)
//			value = newFastScan(i+1)
//			slowValue = newSlowScan(i+1,ScanPoints,ScanLines)
//			XWave[i] = cos(ScanAngle*Pi/180)*value+sin(ScanAngle*pi/180)*slowValue
//			YWave[i] = -sin(ScanAngle*Pi/180)*value+cos(ScanAngle*pi/180)*slowValue
//		endfor
//	endif
//	
//	XWave -= cos(ScanAngle*Pi/180)/2+sin(ScanAngle*Pi/180)/2			//center the XWave
//	YWave -= -sin(ScanAngle*Pi/180)/2+cos(ScanAngle*Pi/180)/2		//center the YWave
//	
//	//The waves now have a size of 1 (except for caps) centered around 0. The rest of the commands scale them
//	
//	FastOp XWave = (5e-9/XLVDTSens)*Xwave
//	FastOp Ywave = (5e-9/YLVDTSens)*YWave
//	
//end //newMakeScanWaves

function MakeDoubleScanEngineWaves(down,[IsNap])			//makes scan waves without rotation, since the scan engine does that
	variable down
	Variable IsNap
	
	if (ParamIsDefault(IsNap))				//assume we are not doing nap
		IsNap = 0
	endif
	
	variable scanPoints = 256	//GV("ScanPoints")		//this is locked at 16 by low level wave size limitations
	variable realScanPoints = GV("ScanPoints")*2.5
	variable scanLines = GV("ScanLines")
	variable stop = 160*scanLines
	Variable SlowScale = 0.8
	if (IsNap)
		Stop *= 2
		SlowScale = .8
	endif
	variable shortStop
	if (stop < 86000)
		shortStop = stop
	else
		shortStop = 80*512
	endif
	
	Make/O/N=(stop) FullSlowWave														
	Make/O/N=(shortstop) SlowWave, SlowWaveBackup			//Make the waves. AmpWave removed
	Make/O/N=(realScanPoints) FastWave
	
	if (isNap)
//		if (down)				//down and up are opposite
//			SlowWaveBackup = ContinuousNapSlowScan(stop-p-2,scanPoints,ScanLines)
//		else
			FullSlowWave = ContinuousNapSlowScan(p,scanPoints,scanLines)
//		endif
	else
		FullSlowWave = ContinuousSlowScan(p+1,scanLines)
	endif
		
	FastWave = newesterFastScan(p,realScanPoints)

	
	FastOp FastWave = .8*FastWave-.4
	FastOp FullSlowWave = (SlowScale)*FullSlowWave-.4
	if (down)
		SlowWaveBackup = -FullSlowWave
	else
		SlowWaveBackup = FullSlowWave
	endif
//	FastOp SlowWaveBackup = (SlowScale*GV("YScanDirection"))*SlowWaveBackup-.4
	FastOp SlowWave = SlowWaveBackup
	//The waves now have a size of .8 (except for caps) centered around 0.
	if (IsNap)
		MakeNapWave()
//		MakeAmpWave(AmpWave)
//		MakeVoltWave(VoltWave)
	endif

end //MakeDoubleScanEngineWaves

//function MakeScanEngineWaves(down,[IsNap])			//makes scan waves without rotation, since the scan engine does that
//	variable down
//	Variable IsNap
//	
//	if (ParamIsDefault(IsNap))				//assume we are not doing nap
//		IsNap = 0
//	endif
//	
//	variable scanPoints = 256	//GV("ScanPoints")		//this is locked at 16 by low level wave size limitations
//	variable realScanPoints = GV("ScanPoints")*2.5
//	variable scanLines = GV("ScanLines")
//	variable stop = 80*scanLines*2
//	Variable SlowScale = 0.8
//	if (IsNap)
//		Stop *= 2
//		SlowScale = .8
//	endif
//	variable shortStop
//	if (stop < 86000)
//		shortStop = stop/2
//	else
//		shortStop = 80*512
//	endif
//	
//	Make/O/N=(stop) FullSlowWave														
//	Make/O/N=(shortstop) SlowWave, SlowWaveBackup			//Make the waves. Ampwave removed
//	Make/O/N=(realScanPoints) FastWave
//	
//	if (isNap)
//		if (down)				//down and up are opposite
//			SlowWaveBackup = napSlowScan(stop-p-2,scanPoints,ScanLines)
//		else
//			SlowWaveBackup = napSlowScan(p+1,scanPoints,scanLines)
//		endif
//	else
//		FullSlowWave = ContinuousSlowScan(p+1,scanLines)
//	endif
//		
//	FastWave = newesterFastScan(p,realScanPoints)
//
//	
//	FastOp FastWave = (.8*GV("XScanDirection"))*FastWave-(.4*GV("XScanDirection"))
//	FastOp FullSlowWave = (SlowScale*GV("YScanDirection"))*FullSlowWave-(.4*GV("YScanDirection"))
//	if (down)
//		SlowWaveBackup = FullSlowWave[stop/2+p]
//	else
//		SlowWaveBackup = FullSlowWave[p]
//	endif
////	FastOp SlowWaveBackup = (SlowScale*GV("YScanDirection"))*SlowWaveBackup-.4
//	FastOp SlowWave = SlowWaveBackup
//	//The waves now have a size of .8 (except for caps) centered around 0.
//	if (IsNap)
//		MakeNapWave()
////		MakeAmpWave(AmpWave)
////		MakeVoltWave(VoltWave)
//	endif
//
//end //MakeScanEngineWaves

function MakeScanEngineRasterWaves(down,scanMode)			//makes scan waves with any rotation
	variable down, scanMode
	
	variable scanPoints = GV("ScanPoints")*2.5
	variable scanLines = GV("ScanLines")

	if (GV("NapMode"))
		scanLines *= 2
		MakeNapWave()
//		MakeAmpWave(AmpWave)
//		MakeVoltWave(VoltWave)
	endif
	
	variable stop = ScanLines  		//The out wave now ends in the middle of the cap, it is actually longer than the
//	variable stop=(scanLines+2)*2.5+1-(1/4)	//in waves. Since we restart between every scan, it isn't a problem

//20081203 Jason C made some changes here to make the slow scan wave a V rather than a ramp
//	Make/O/N=(stop) SlowWave, SlowWaveBackup//, AmpWave				//Make the waves.
	Make/O/N=(2*stop) SlowWave, SlowWaveBackup//, AmpWave				//Make the waves.

	Make/O/N=(scanPoints) FastWave

	FastWave = newesterFastScan(p,scanPoints)
//	if (down)				//down and up are opposite
//		SlowWaveBackup = (stop-p)/(stop)
//	else
//		SlowWaveBackup = (p)/(stop)
//	endif

	if (!down)
		SlowWaveBackup[0,stop-1] = (p)/stop
		SlowWaveBackup[stop,] = (2*stop-p)/stop
	else
		SlowWaveBackup[0,stop-1] = (stop-p)/stop
		SlowWaveBackup[stop,] = (p-stop)/stop
	endif
	//The waves now have a size of .8 (except for caps) centered around 0.

	if (scanMode)
		FastOp FastWave = (.8*GV("XScanDirection"))*FastWave-(.4*GV("XScanDirection"))
		FastOp SlowWaveBackup = (.8*GV("YScanDirection"))*SlowWaveBackup-(.4*GV("YScanDirection"))
	else
		FastOp FastWave = .8*FastWave-.4
		FastOp SlowWaveBackup = .8*SlowWaveBackup-.4
	endif
	FastOp SlowWave = SlowWaveBackup

	
end //MakeScanEngineRasterWaves


function newesterFastScan(var,total)		//Makes the fast scan with symmetric caps, 80 points total with 4 points in each cap.
	variable var, total
	
	variable amp = 2*2/(8*2*pi)		//the size of the cap
	variable v1 = mod(var,total/2)			//where on each ramp
	variable v2 = mod(var,total)			//where overall
	variable factor = total/640

	if (v2 < (32*factor))
		return sin((v1-32*factor)/(64*factor)*pi)*amp		//the second cap

	elseif (v2 < (288*factor))
		return ((v1-32*factor)/(256*factor))				//the first slope

	elseif (v2 < (352*factor))
		return 1+sin((v2-32*factor)/(64*factor)*pi)*amp		//the first cap

	elseif (v2 < (608*factor))
		return 1-((v1-32*factor)/(256*factor))			//the second slope

	else
		return -sin((v1-288*factor)/(64*factor)*pi)*amp		//the second cap

	endif

end //newesterFastScan

function FastScan(var)		//Makes the fast scan with symmetric caps, 20 points total with 1 point in each cap.
	variable var
	
	variable Amp = 2*2/(8*2*pi)		//the size of the cap
	variable V1 = mod(var,10)			//where on each ramp
	variable V2 = mod(var,20)			//where overall

	if (V2 < 1)
		return sin((V1-1)/2*pi)*Amp			//the second half of the starting cap
	elseif (V2 < (9))
		return (V1-1)/8							//the first slope
	elseif ((V2 >= 9) && (V2 < 11))
		return 1+sin((V2-9)/2*pi)*Amp			//the second cap
	elseif ((V2 >= 11) && (V2 < 19))
		return 1-(V1-1)/8						//the second slope
	elseif (V2 >= (19))
		return sin((V1+1)/2*pi)*Amp			//the first part of the first cap
	endif

end //FastScan

function SlowScan(var,scanPoints,scanLines)
	variable var, scanPoints, scanLines
	
	return (var-10*2-1)/((scanLines-2)*8*2.5-scanPoints/32)

end //SlowScan

function newSlowScan(var,scanPoints,scanLines)
	variable var, scanPoints, scanLines
	
	variable v1 = mod(var+4,40)
	variable line = (var+4-v1)/40-1
	
	if (v1 < 0)
		return -2/((scanLines*2)-1)
	elseif (v1 < 7)
		return (line-1.5)/(scanLines*2-1)+sin((v1-3.5)/3.5*pi/2)/(scanLines*4-1)
	elseif ((7 <= v1) && (v1 < 40))
		return (line-1)/(scanLines*2-1)
	endif
	
end //newSlowScan

function ContinuousSlowScan(var,scanLines)		//this function is only for 80 point scans
	variable var, scanLines
	
	variable v1 = mod(var+4,40)
	variable line = (var+4-v1)/40+1
	variable up = 1
	if ((line > (scanLines*2+1)) && (line < (scanLines*4)))
		line = (scanLines*2+2)-mod(line,scanLines*2)
		up = -1
	elseif (var <= 2)
		up = -1
	elseif (line >= (scanLines*4))
		line = 2+scanLines*4-line
		up = -1
	endif
	variable wrapLine = 0
	
	if (v1 < 0)
		return -2/((scanLines*2)-1)
	elseif (v1 < 7)
		return (line-1-up/2)/(scanLines*2-1)+up*sin((v1-3.5)/3.5*pi/2)/(scanLines*4-1)
	elseif ((7 <= v1) && (v1 < 40))
		return (line-1)/(scanLines*2-1)
	endif
	
end //ContinuousSlowScan

function ContinuousNapSlowScan(var,scanPoints,scanLines)
	variable var, scanPoints, scanLines
	
	variable v1 = mod(var+4,160)
	variable line = (var+4-v1)/160
	
	if (line == (scanLines*2))
		return 0
	elseif (line >= scanLines)
		line = mod(line,scanLines)
		
		if ((v1 < 7) && (line == 0))
			return 1-((line)/(scanLines-1))
		elseif (v1 < 7)
			return 1-((line-.5)/(scanLines-1)+sin((v1-3.5)/3.5*pi/2)/(scanLines*2-1))
		elseif ((7 <= v1) && (v1 < 320))
			return 1-((line)/(scanLines-1))
		endif
	else
		if ((v1 < 7) && (line == 0))
			return (line)/(scanLines-1)
		elseif (v1 < 7)
			return (line-.5)/(scanLines-1)+sin((v1-3.5)/3.5*pi/2)/(scanLines*2-1)
		elseif ((7 <= v1) && (v1 < 320))
			return (line)/(scanLines-1)
		endif
	endif	
end //newSlowScan

function napSlowScan(var,scanPoints,scanLines)
	variable var, scanPoints, scanLines
/////////////////////////////////////////////////////////////////////////////////////	
	variable v1 = mod(var+4,160)
	variable line = (var+4-v1)/160-1
////////////////////////////////////////////////////////////////////////////////////	
	if (v1 < 0)
		return -2/((scanLines*2)-1)
	elseif (v1 < 7)
////////////////////////////////////////////////////////////////////////////////////
		return (line-1.5)/(scanLines*2-1)+sin((v1-3.5)/3.5*pi/2)/(scanLines*4-1)
	elseif ((7 <= v1) && (v1 < 160))
		return (line-1)/(scanLines*2-1)
	endif
///////////////////////////////////////////////////////////////////////////////////////	
end //newSlowScan

Function ZoomZoom(IsNice,[infoStr])		//this zooms in real time
	Variable IsNice
	string infoStr

	if (ParamIsDefault(infoStr))
		infoStr = ""
	endif
	
	Wave RVW = $GetDF("Variables")+"RealVariablesWave"
	Variable SlowSize, FastSize, YOffset, XOffset, ScanAngle, Current, Error, NewSize
	String DataFolder, ImageName, NoteStr
	Variable Layer, Range, Center
	String GraphStr = WinName(0,1)		//we only deal with graphs.  Not layouts
	
//	if (
	
	variable V_Right, V_Left, V_top, V_Bottom
	if (strlen(infoStr))
		graphStr = StringByKey("Window",infoStr,":",";")
		V_Right = str2num(StringFromList(0,StringByKey("center",infoStr,":",";"),","))+str2num(StringFromList(0,StringByKey("extents",infoStr,":",";"),","))/2
		V_Left = str2num(StringFromList(0,StringByKey("center",infoStr,":",";"),","))-str2num(StringFromList(0,StringByKey("extents",infoStr,":",";"),","))/2
		V_Top = str2num(StringFromList(1,StringByKey("center",infoStr,":",";"),","))+str2num(StringFromList(1,StringByKey("extents",infoStr,":",";"),","))/2
		V_Bottom = str2num(StringFromList(1,StringByKey("center",infoStr,":",";"),","))-str2num(StringFromList(1,StringByKey("extents",infoStr,":",";"),","))/2
	else
		if ((IsAxesReversed(GraphStr,"Left") < 0) || (IsAxesReversed(GraphStr,"Bottom") < 0))
			if ((!stringmatch(graphStr,"Channel*")) && (!stringmatch(graphStr,"TuneGraph")))
				DoAlert 0, GetFuncName()+" only works on Real time, Offline images, Tunes and Thermals."	//check to make sure that it is a real time graph
				return 1
			endif
		endif
		if (stringmatch(GraphStr,"TuneGraph"))
			GetMarquee/K/W=$GraphStr Amp,Bottom			//special, because the tune doesn't have a left axis
		else
			GetMarquee/K/W=$GraphStr Left,Bottom			//this gets the marquee coordinates
		endif
	endif
	
	String WhichStr
	
//	String GraphStr = S_MarqueeWin
	
	if (StringMatch(GraphStr,"Channel*"))		//RT image

		SlowSize = RVW[%SlowScanSize][0]		//grab the current values
		FastSize = RVW[%FastScanSize][0]
		YOffset = RVW[%YOffset][0]
		XOffset = RVW[%XOffset][0]
		ScanAngle = RVW[%ScanAngle][0]*pi/180 //convert to radians
		error = 0

	elseif (StringMatch(GraphStr,cOfflineBaseName+"*"))		//offline image
		if (ARDoAlert("This will zoom the current scan. Do you want to do that?",3,1))
			return 1
		endif
		
		GetGraphData(GraphStr,DataFolder,ImageName,Layer)
		Wave Image = $DataFolder+ImageName
		NoteStr = Note(Image)
		SlowSize = NumberByKey("SlowScanSize",NoteStr,":","\r")
		FastSize = NumberByKey("FastScanSize",NoteStr,":","\r")
		XOffset = NumberByKey("XOffset",NoteStr,":","\r")
		YOffset = NumberByKey("YOffset",NoteStr,":","\r")
		ScanAngle = NumberByKey("ScanAngle",NoteStr,":","\r")*pi/180 //convert to radians
	elseif ((StringMatch(GraphStr,"TuneGraph")) || (StringMatch(GraphStr,"ThermalGraph")))		//Tune and thermal
		Range = abs(V_Right-V_Left)
		Center = Min(V_Right,V_Left)+Range/2
		WhichStr = ""
		if (GV("WhichACMode"))
			WhichStr = "1"
		endif
		if (StringMatch(GraphStr,"TuneGraph"))
			MainSetVarFunc("DriveFrequency"+WhichStr+"SetVar_1",Center,"",":Variables:MasterVariablesWave[%DriveFrequency"+WhichStr+"][0]")
			MainSetVarFunc("SweepWidth"+WhichStr+"SetVar_1",Range,"",":Variables:MasterVariablesWave[%SweepWidth"+WhichStr+"][0]")
			if ((GV("FitWidth") > Range) && !Strlen(WhichStr))
				ThermalSetVarFunc("FitWidthSetVar_1",Range,"","Variables:ThermalVariablesWave[%FitWidth][0]")
			endif
			//Do anouther tune.
			if (!GV("DoCantTune"))
				CantTuneFunc("DoTuneOnce"+WhichStr+"_3")
			endif
		else		//thermal
			//MainSetVarFunc("DriveFrequency"+WhichStr+"SetVar_1",Center,"",":Variables:MasterVariablesWave[%DriveFrequency"+WhichStr+"][0]")
			ThermalSetVarFunc("ThermalCenterSetVar_1",Center,"",":Variables:ThermalVariablesWave[%ThermalCenter]")
			ThermalSetVarFunc("ThermalWidthSetVar_1",Range,"",":Variables:MasterVariablesWave[%ThermalWidth][0]")
			if (GV("FitWidth") > Range)
				ThermalSetVarFunc("FitWidthSetVar_1",Range,"","Variables:ThermalVariablesWave[%FitWidth][0]")
			endif
			//Make sure we are in zoom mode....
			MainBoxFunc("ThermalZoomBox_1",1)
		endif
		return(0)
	else
		DoAlert 0, GetFuncName()+" only works on Real time and Offline images, Tunes and Thermals."	//check to make sure that it is a real time graph
		return 1
	endif
	NewSize = Max(abs(V_left-V_right),abs(V_top-V_bottom))
	if (NewSize == 0)
		DoAlert 0,"Error trapped!\rZero scan size detected!\rHow did you do that?"
		return(1)
	endif
	
	variable angleScanDirection = 1
	if (GV("ScanMode"))
		angleScanDirection = GV("XScanDirection")*GV("YScanDirection")
	endif
	
	
	//recalculate the offset, the ScanSize/2 is the midpoint of the graph, the trig takes care of the scan angle affects
	XOffset += (sin(ScanAngle*angleScanDirection)*((V_top+V_bottom)/2-SlowSize/2))+(cos(ScanAngle*angleScanDirection)*((V_left+V_right)/2-FastSize/2))
	YOffset += (cos(ScanAngle*angleScanDirection)*((V_top+V_bottom)/2-SlowSize/2))-(sin(ScanAngle*angleScanDirection)*((V_left+V_right)/2-FastSize/2))
	PV("ZoomXOffset",XOffset)
	PV("ZoomYOffset",YOffset)
	
//	if (abs(V_left-V_right) > abs(V_top-V_bottom))			//look for the big side
//		newSize = abs(V_left-V_right)
//	else
//		newSize = abs(V_top-V_bottom)
//	endif
	if (IsNice == 1)
		NewSize = ARNiceRound(NewSize,Max(FastSize,SlowSize))
	elseif (IsNice == 2)
		ARGetEditSize(NewSize,YOffset,XOffset,current,GraphStr)
		return 0
	endif

	MidZoom(newSize)
	
end //ZoomZoom
	
function MidZoom(newSize)
	variable newSize

	variable current
	current = GV("DelayUpdate")
	if (!(current & 1))
		PV("DelayUpdate",2)
	elseif (current == 1)
		current = 5
	endif
	
	MainSetVarFunc("ScanSizeSetVar_0",newSize,"",":Variables:MasterVariablesWave[%ScanSize]")
	MainSetVarFunc("YOffsetSetVar_0",GV("ZoomYOffset"),"",":Variables:MasterVariablesWave[%YOffset]")		//this actually changes the offset
	MainSetVarFunc("XOffsetSetVar_0",GV("ZoomXOffset"),"",":Variables:MasterVariablesWave[%XOffset]")

	if (GV("ScanStatus") && !(current & 1))
		SetDisable(2)
		td_SetRamp(5,"XGain%ScanEngine",0,newSize/abs(GV("XLVDTSens"))/(.8*20),"YGain%ScanEngine",0,newSize/abs(GV("YLVDTSens"))/(.8*20),"",0,0,"FinishZoom()")	
		RealScanParmFunc("ScanSize;FastScanSize;SlowScanSize;","Copy")
		PV("ScanStateChanged",1)							//things have changed
	endif	
	PV("DelayUpdate",current)
end //ZoomZoom

function ARGetEditSize(newSize,yOffset,xOffset,current,graphStr)
	variable newSize, yOffset, xOffset, current
	string graphStr
	
	
	PV("ZoomSize",newSize)
	UpdateUnits("ZoomSize",newSize)
	PVH("ZoomSize",GV("ScanSize"))
	
	variable screenRes = 72/ScreenResolution
	variable/G root:Packages:MFP3D:Main:Variables:ZoomSize
	Variable V_Left, V_Top, V_Right, V_Bottom
	if (WinType(GraphStr) == 13)
		ARGL_GetWindow(GraphStr,V_Left,V_Top,V_Right,V_Bottom)
	else
		GetWindow $graphStr, wsize
	endif
	NewPanel/K=1/N=EditPanel as "What Size?"
	SetWindow EditPanel, hook=EditPanelHook
	MoveWindow/W=EditPanel V_Left+120*screenRes,V_Top+120*ScreenRes,V_Left+330*screenRes,V_Top+220*screenRes
	MakeSetVar("EditPanel","","ZoomSize","","ARSetVarFunc","",60,20,120,70,0,12,0)
	MakeButton("EditPanel","DoEditZoom","Do It",50,20,40,50,"EditZoomFunc",0)
	MakeButton("EditPanel","CancelEditZoom","Cancel",50,20,120,50,"EditZoomFunc",0)
	
end //ARGetEditSize

function EditZoomFunc(ctrlName)
	string ctrlName
	
	if (stringmatch(ctrlName,"DoEditZoom"))
		MidZoom(GV("ZoomSize"))
		DoWindow/K EditPanel
	else
		DoWindow/K EditPanel
	endif
	
	
end //EditZoomFunc

function EditPanelHook(infoStr)
	string infoStr
	
	if (stringmatch(StringByKey("Event",infoStr),"deactivate"))
		DoWindow/K EditPanel
	endif

end //EditPanelHook

function FinishZoom()
	
	SetOffset(3,GV("XOffset"),GV("YOffset"))
	
end //FinishZoom


//Function ZoomOffset() : GraphMarquee		//this just offsets in real time
//
//	variable ScanSize = GV("ScanSize")		//grab the current values
//	variable YOffset = GV("YOffset")
//	variable XOffset = GV("XOffset")
////	variable ScanAngle = GV("ScanAngle")*pi/180 //convert to radians
//	Wave OldMVW = root:packages:MFP3D:Main:Variables:OldMVW
//	Variable ScanAngle = OldMVW[%ScanAngle][0]*pi/180
//	
//
//	GetMarquee/K Left,Bottom					//this gets the marquee coordinates
//	if (stringmatch(S_marqueeWin,"*Channel*") == 0)	//S_marqueeWin is generated by GetMarquee
//		DoAlert 0, "This only works on Real time images"	//check to make sure that it is a real time graph
//		return 1
//	endif
//
//	//recalculate the offset, the ScanSize/2 is the midpoint of the graph, the trig takes care of the scan angle affects
//	XOffset += (sin(ScanAngle)*((V_top+V_bottom)/2-ScanSize/2))+(cos(ScanAngle)*((V_left+V_right)/2-ScanSize/2))
//	YOffset += (cos(ScanAngle)*((V_top+V_bottom)/2-ScanSize/2))-(sin(ScanAngle)*((V_left+V_right)/2-ScanSize/2))
//	MainSetVarFunc("YOffsetSetVar_0",YOffset,"","")		//this actually changes the offset
//	MainSetVarFunc("XOffsetSetVar_0",XOffset,"","")
////	PV("ScanStateChanged",1)							//things have changed
//	
//end //ZoomOffset



Function FixScale(IsNice,[DoAll,infoStr])		//this fixes the scale of the realtime image
	Variable IsNice
	Variable DoAll
	string infoStr

	if (ParamIsDefault(DoAll))
		DoAll = 0
	endif

	Variable Good = 1
	if (ParamIsDefault(infoStr))
		infoStr = ""
		GetAxis/Q Left
		Good *= !V_flag			//if not there, !V_flag=0, so Good = 0
		GetAxis/Q Bottom
		Good *= !V_flag			//if not there, !V_flag=0, so Good = 0
	endif
	
	String GraphStr = "", GraphList = ""
	Variable RealTime = 1

	variable V_Right, V_Left, V_top, V_Bottom
	if (strlen(infoStr))

		graphStr = StringByKey("window",infoStr,":",";")
		V_Right = str2num(StringFromList(0,StringByKey("center",infoStr,":",";"),","))+str2num(StringFromList(0,StringByKey("extents",infoStr,":",";"),","))/2
		V_Left = str2num(StringFromList(0,StringByKey("center",infoStr,":",";"),","))-str2num(StringFromList(0,StringByKey("extents",infoStr,":",";"),","))/2
		V_Top = str2num(StringFromList(1,StringByKey("center",infoStr,":",";"),","))+str2num(StringFromList(1,StringByKey("extents",infoStr,":",";"),","))/2
		V_Bottom = str2num(StringFromList(1,StringByKey("center",infoStr,":",";"),","))-str2num(StringFromList(1,StringByKey("extents",infoStr,":",";"),","))/2

	elseif (Good)
		GetMarquee/K Left,Bottom					//this gets the marquee coordinates
		GraphStr = S_marqueeWin
		//Display has to be checked first, because you can have Channel in the base name
		if (StringMatch(GraphStr,cOfflineBaseName+"*") == 1)
			RealTime = 0
		elseif (stringmatch(GraphStr,"*Channel*") == 1)	//GraphStr is generated by GetMarquee
			RealTime = 1
		else
			Good = 0			//this means it is no good.
		endif
	endif
	
	if (!Good)
		DoAlert 0, "This only works on Real time and OffLine images"	//check to make sure that it is a real time graph
		return 1
	endif

	DoAll *= RealTime		//only doAll for realtime	
	if (DoAll)
		GraphList = WinList("Channel*Image*",";","WIN:4097")
	else
		GraphList = GraphStr+";"
	endif
	
	Variable A, nop = ItemsInList(GraphList,";")
	for (A = 0;A < nop;A += 1)
		GraphStr = StringFromList(A,GraphList,";")
		FixScaleSubFunc(GraphStr,V_Left,V_Right,V_Top,V_Bottom,IsNice)
	endfor

end //FixScale


Function FixScaleSubFunc(GraphStr,Left,Right,Top,Bottom,IsNice)
	String GraphStr
	Variable Left, Right, Top, Bottom
	Variable IsNice

	Variable Good = IsWindow(GraphStr)
	if (!Good)
		return(1)
	endif

	Variable RealTime = StringMatch(GraphStr,"Channel*")

	variable scale, xDelta, yDelta, Offset

	if (wintype(GraphStr) == 13)
		Wave/Z Image = $argl_ReadString(graphStr,"wave")
	else
		wave/Z Image = ImageNameToWaveRef(GraphStr,StringFromList(0,ImageNameList(GraphStr,";")))
	endif
	if (!WaveExists(Image))
		DoAlert 0, "Something went wrong with this scaling. Sorry"
		return 1
	endif
	if ((DimSize(Image,0) <= 2) || (DimSize(Image,1) <= 2))
		return(0)
		//<edit> <Edit> <EDIT> nap image open when <EDIT!!!!EDIT!!EDIT!!EDIT!()*&#%> nap mode turned off.
	endif
	
	Left -= DimOffset(Image,0)
	Right -= DimOffset(Image,0)
	Top -= DimOffset(Image,1)
	Bottom -= DimOffset(Image,1)
	
	xDelta = DimDelta(Image,0)
	yDelta = DimDelta(Image,1)
	left = max(round(Left/xDelta),0)
	right = max(round(Right/xDelta),0)
	top = max(round(Top/yDelta),0)
	bottom = max(round(Bottom/yDelta),0)
	
	
	if ((top-bottom == 0) || (Right - Left == 0))
		DoAlert 0, "This only works on Real time and OffLine <bold> IMAGES </bold>"	//check to make sure that it is a real time graph
		return 1
	endif		
	
	String Info
	Variable Layer

	if (DimSize(Image,2) > 1)
		if (WinType(GraphStr) == 13)		//argyle
			Layer = ARGl_ReadValue(GraphStr,"Layer")
		else
			Info = ImageInfo(GraphStr,NameOfWave(Image),0)
			Layer = NumberByKey("plane",Info,"=",";")
		endif
		ImageStats/M=1/G={left,right,bottom,top}/P=(Layer) Image
	else
		ImageStats/M=1/G={left,right,bottom,top} Image
	endif


	Scale = 2*min(abs(V_max-V_avg),abs(V_avg-V_min))
//	if ((V_max-V_avg) > (V_avg-V_min))
//		scale = 2*(V_avg-v_min)
//	else
//		scale = 2*(V_max-V_avg)
//	endif
	Offset = V_Avg
	if (IsNice)
		Scale = ARNiceRound(Scale,V_Max-V_Min)
		Offset = ARNiceRound(Offset,V_Max-V_Min)
	endif
	
	//Channel1Image1		//Channel 1 Surface Retrace
	//Channel2Image2		//Channel 2, Nap Trace
	
	If (RealTime == 1)
		string chanStr = GraphStr[Strlen("Channel")]
		Variable ChanNum = str2num(ChanStr)
		Variable IsRetrace = GetEndNum(GraphStr)
		Variable IsNap = IsRetrace > 1
		if (IsNap)
			IsRetrace -= 2
		endif
		Struct ARRTImageInfo InfoStruct
		InfoStruct.ChannelNum = ChanNum
		InfoStruct.IsNap = IsNap
		ARGetChannelInfo(InfoStruct)
		String DataTypeStr = InfoStruct.DataType
		
		if (IsRetrace == 1)			
			if (!StringMatch(InfoStruct.LiveDisplay,"Both"))
				IsRetrace -= 1
			endif
		endif
		String DirStr = num2str(IsRetrace+1)
		
		if (IsNap)
			DataSetVarFunc("NapChannel"+chanStr+DirStr+"DataScaleSetVar_"+chanStr,scale,"",":NapChannelVariablesWave[%Nap"+DataTypeStr+DirStr+"DataScale]")
			DataSetVarFunc("NapChannel"+chanStr+DirStr+"DataOffsetSetVar_"+chanStr,Offset,"",":NapChannelVariablesWave[%Nap"+DataTypeStr+DirStr+"DataOffset]")
		else
			DataSetVarFunc("Channel"+chanStr+DirStr+"DataScaleSetVar_"+chanStr,scale,"",":ChannelVariablesWave[%"+DataTypeStr+DirStr+"DataScale]")
			DataSetVarFunc("Channel"+chanStr+DirStr+"DataOffsetSetVar_"+chanStr,Offset,"",":ChannelVariablesWave[%"+DataTypeStr+DirStr+"DataOffset]")
		endif
	else		//OffLine
		RangeandOffsetSetVar("RangeSetVar",scale,"","")
		RangeandOffsetSetVar("OffsetSetVar",Offset,"","")
	endif
	
end //FixScaleSubFunc



Function ShiftOffset(Xpos,Ypos)
	Variable Xpos, YPos
	//Takes the Existing X and Y offsets, and shifts them by Xpos and Ypos
	
	
	Variable DoX = !(!XPos)
	Variable DoY = !(!YPos)
	DoX = 1
	DoY = 1

	Wave OldMVW = root:packages:MFP3D:Main:Variables:OldMVW
	Wave MVW = root:packages:MFP3D:Main:Variables:MasterVariablesWave
	Wave RVW = root:packages:MFP3D:Main:Variables:RealVariablesWave
	variable xScanDirection = GV("XScanDirection")
	variable yScanDirection = GV("YScanDirection")
//	Variable/C RotValues = RotateWave(Ypos,Xpos,OldMVW[%ScanAngle][%value])
	variable scanAngleDirection = 1
	if (GV("ScanMode"))
		scanAngleDirection = xScanDirection*yScanDirection
	endif
	
	Variable/C RotValues = RotateWave(Ypos,Xpos,GrabAngle(td_ReadValue("ScanEngine.sin"),td_ReadValue("ScanEngine.cos"))*scanAngleDirection)
	Ypos = Real(RotValues)
	Xpos = Imag(RotValues)
	Variable ScanMode = RVW[%ScanMode][0]
	Variable XOffset, YOffset
	
	if (ScanMode)
		Xoffset = ((-td_ReadValue("ScanEngine.XOffset"))*MVW[%XPiezoSens][0]*160)*xScanDirection
		Yoffset = ((-td_ReadValue("ScanEngine.YOffset"))*MVW[%YPiezoSens][0]*160)*yScanDirection
	else
		Xoffset = ((td_ReadValue("ScanEngine.XOffset")-GV("xLVDTOffset")/20)*abs(GV("XLVDTSens"))*20)
		Yoffset = ((td_ReadValue("ScanEngine.YOffset")-GV("yLVDTOffset")/20)*abs(GV("YLVDTSens"))*20)
	endif
	
	Variable ZeroThresh = 1e-1		//less than this we call 0
	if (abs(XPos) < ZeroThresh*MVW[%Xoffset][%MinUnits])
		XPos = 0
	endif
	if (abs(YPos) < ZeroThresh*MVW[%Yoffset][%MinUnits])
		YPos = 0
	endif
	Xoffset += Xpos//*GV("XScanDirection")
	Yoffset += YPos//*GV("YScanDirection")
	
	
	Variable Delay = GV("DelayUpdate")
	
	
	if ((Delay & 2) && !(Delay & 1))
		SetOffset(3,Xoffset,Yoffset)
		PV("ParmChange",1+(2 & GV("ParmChange")))
		CheckSaveStatus()
	endif
	
//	PV("DelayUpdate",2)
	if (DoX)
		PVU("XOffset",1)
		MainSetVarFunc("XOffsetSetVar_0",Xoffset,"",":MasterVariablesWave[%Xoffset]")
	endif
	if (DoY)
		PVU("YOffset",1)
		MainSetVarFunc("YOffsetSetVar_0",Yoffset,"",":MasterVariablesWave[%Yoffset]")
	endif
	//don't need to set PV("ScanStateChanged",3)???
	//
End //ShiftOffset

function GrabAngle(sinInput,cosInput)
	variable sinInput, cosInput
	
	if (asin(sinInput) < 0)
		return 360-acos(cosInput)/(pi/180)
	else
		return acos(cosInput)/(pi/180)
	endif

end //GrabAngle

function SaveImageFunc(saveImageCount)		//function saves images to disk
	variable saveImageCount

//NVAR LineCount = root:Packages:MFP3D:Main:LineCount
//print LineCount
	Wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	Wave RVW = root:Packages:MFP3D:Main:Variables:RealVariablesWave
	Wave OVW = root:Packages:MFP3D:Main:Variables:ARDoIVVariablesWave
	Wave/T RVD = root:Packages:MFP3D:Main:Variables:RealVariablesDescription
	variable scanDown = MVW[%ScanDown][0]+2*(RVW[%NapMode] >= 1)
	Variable SavePartial = (ScanDown & 4) > 0
	Variable IsNap = (ScanDown & 2) > 0
	variable scanMode = MVW[%ScanMode][0]
	variable scanLines = RVW[%ScanLines][0]
	variable napScanLines = scanLines
	Variable ImagingMode = MVW[%ImagingMode][0]
	ScanDown = ScanDown & 1
	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
	string errorStr = ""
	variable doTop = mod(saveImageCount,2)+(saveImageCount == 100)

	string thirtyTwoStr = FindUserName(StringFromList(RealScanParmFunc("Channel1DataType","Value"),MDTL),"Name")
	Wave TestWave = $"root:Packages:MFP3D:Main:"+thirtyTwoStr+"Wave"
	variable inputRatio = scanLines/DimSize(TestWave,1)*(1+isNap)
	if ((saveImageCount > 99) && (inputRatio > 1))
		if (inputRatio*2 > (MVW[%SaveImageCount][0]+1))
//print LineCount
			return 0	
		endif
	endif
//print "run"
	String ChannelList = GTS("DataTypeSum")
	Variable IsFreq = (WhichListItem("Frequency",ChannelList,";",0,0) >= 0)	//is frequency or potential turned on?
	Variable IsPot = (WhichListItem("Potential",ChannelList,";",0,0) >= 0)
	if ((saveImageCount > 99) && ((MVW[%LastScan][0] == 1) || (MVW[%DelayUpdate][0] & 4)))
//		IR_StopInWaveBank(1)
		if (IsNap)
			errorStr += num2str(td_WriteString("Event.5","Clear"))+","
		else
			errorStr += num2str(td_WriteString("Event.2","Clear"))+","
		endif
		
//************		
		if (ImagingMode != 2 && (IsPot || IsFreq))
			//Copied from DoScanFunc
			errorStr += num2str(ir_StopPISLoop(NaN,LoopName="FrequencyLoop"))+","		//if a frequency feedback loop is running not in FM mode, turn the loop off and reset the frequency
			errorStr += num2str(ir_WriteValue("DDSFrequencyOffset0",0))+","
		endif
//************

		td_ReadString("Temperature@Head")				//this is so the later reading is more accurate
		td_ReadString("Temperature@Scanner")
			
		PV("LastImage",1)
		ClearEvents()
		PV("UpdateCounter",-1)
		UpdateRealGraph(ScanDown)
		SetDisable(0)
	elseif (saveImageCount > 99)
	
		td_ReadString("Temperature@Head")				//this is so the later reading is more accurate
		td_ReadString("Temperature@Scanner")

	endif

	Variable LastMacroMode = GV("LastARMacroMode")

	variable doScan = !SavePartial
	
variable startTimer = StopMSTimer(-2)		
	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main:
	
	NVAR VerDate = root:Packages:MFP3D:Main:Variables:VerDate
	SVAR BaseName = root:Packages:MFP3D:Main:Variables:BaseName
	SVAR LogFile = root:Packages:MFP3D:Main:LogFile
	Wave OldMVW = root:Packages:MFP3D:Main:Variables:OldMVW
	Wave FMVW = $cFMVW
	Wave AllAlias = root:packages:MFP3D:Hardware:AllAlias
	Wave NapVW = root:Packages:MFP3D:Main:Variables:NapVariablesWave
	Wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
	Wave NCVW = root:Packages:MFP3D:Main:Variables:NapChannelVariablesWave
	Wave TVW = root:Packages:MFP3D:Main:Variables:ThermalVariablesWave
	Wave UserParmWave = root:Packages:MFP3D:Main:Variables:UserVariablesWave
	Wave FilterVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave
	Wave/T CVWD = root:Packages:MFP3D:Main:Variables:ChannelVariablesDescription
	SVAR/Z ImageNote = root:Packages:MFP3D:Main:Variables:ImageNote
	SVAR/Z TipSerialNumber = root:Packages:MFP3D:Main:Variables:TipSerialNumber
	Wave/T GlobalStrings = $GetDF("Strings")+"GlobalStrings"

	Wave XPTwave = root:Packages:MFP3D:XPT:XPTLoad
	wave TestImage = $"root:Packages:MFP3D:Main:"+thirtyTwoStr+"Image0"
	
	variable sum0, sum1, sum2, sum3, chanTotal, napChanTotal, tempSum
	string numStr, waveStr, dataTypeStr, userDataTypeStr
	
	variable scanPoints = .4*DimSize(TestWave,0)		//get the scan points and lines from the actual waves
	variable scale = 1
	variable offset = 0
	variable imageOffset = 0
	variable scanTotal = 0
	variable scanSign = 1
	variable driftCount = GV("DriftCount")
	variable calcDrift = (1 & GV("DriftBits"))
	variable displayRange
	variable saveImageLines = MVW[%SaveImageLines][0]
	if (isNap && (scanLines >= 512))
		saveImageLines = 128
	endif
	
	variable start, finish

	if (scanDown)
		if (saveImageCount > 99)
			start = 0
			finish = saveImageLines-1
		else
			finish = scanLines-1-(saveImageCount*saveImageLines)
			start = finish-(saveImageLines-1)
		endif
	else
		if (saveImageCount > 99)
			finish = scanLines-1
			start = finish-(saveImageLines-1)
		else
			start = saveImageCount*saveImageLines
			finish = start+saveImageLines-1
		endif
	endif
//print "start "+num2str(start)
//print "finish " +num2str(finish)
	Struct ARRTImageInfo InfoStruct
	Variable ChannelNum
	
//	WaveStats/Q/M=1 TestWave
//	if (V_numNans)
//		scanLines = td_WhereNow(TestWave,0)
//	endif
	
	scanLines -= mod(scanLines,2)
	if (scanLines < 8)
		return 1
	endif

	if (ScanDown)													//things are opposite for scandown
		scanTotal = mod(scanLines-1,512)+1
		if (scanTotal == 512)
			scanTotal *= 64
		endif
		scanSign = -1
	endif
	if (IsNap)
		napscanLines = scanLines/2
	endif
	
	CalculateDataTypeSum(sum0,sum1,chanTotal,0)							//this returns data type sums for both trace and retrace
	if (IsNap)
		CalculateDataTypeSum(sum2,sum3,napChanTotal,1)							//this returns data type sums for both trace and retrace
	else
		sum2 = 0
		sum3 = 0
		napChanTotal = 0
	endif
	
	wave UniqueWave, LineWave, LineMask, Mask, W_coef, PrevLine, PrevHist, Corr, LayerWave, FlattenParms
	variable slope
	string offsetList, slopeList

	if (!doScan)
		Make/O/N=(scanPoints,scanLines,chanTotal+napChanTotal) PartialWave
		wave UniqueWave = PartialWave
		Redimension/N=(scanPoints,scanLines) Mask
	endif

	String ChannelNumList = num2str(GV("channel1DataType"))+","
	ChannelNumList += num2str(GV("channel2DataType"))+","
	ChannelNumList += num2str(GV("channel3DataType"))+","
	ChannelNumList += num2str(GV("channel4DataType"))+","
	ChannelNumList += num2str(GV("channel5DataType"))+","
	String NoteStr = ""

	if (saveImageCount > 99)
		Note/K UniqueWave												//kill the note
		
		NoteStr += GetWaveParms(RVW)
		NoteStr = ReplaceStringByKey("32 bit channel",NoteStr,thirtyTwoStr,":","\r",0)
		NoteStr = ReplaceStringByKey("ImagingMode",NoteStr,RVD[%ImagingMode][%Title],":","\r",0)
		NoteStr = ReplaceStringByKey("ScanMode",NoteStr,RVD[%ScanMode][%Title],":","\r",0)
		NoteStr = ReplaceStringByKey("NapMode",NoteStr,RVD[%NapMode][%Title],":","\r",0)
		NoteStr += "Real Parms: End"+"\r"
		NoteStr += "Initial Parms: Start"+"\r"
		NoteStr += GetWaveParms(OldMVW)							//this puts the master variable wave parms in the note
		NoteStr += GetwaveParms(NapVW)
		NoteStr += GetWaveParms(CVW)							//this puts the channel variable wave parms in the note
		NoteStr += GetWaveParms(XPTwave)						//grab the crosspoint setup
		NoteStr += GetWaveParms(FilterVW)
		NoteStr += GetWaveParms(TVW)
		NoteStr += GetWaveParms(UserParmWave)
		NoteStr += LogFile[0,strlen(LogFile)-2]
		NoteStr += "Log File:Stop\r"
		NoteStr = ReplaceStringByKey("Date",NoteStr,Date(),":","\r",0)
		NoteStr = ReplaceStringByKey("Time",NoteStr,Time(),":","\r",0)
		string tempSeconds
		sprintf tempSeconds, "%u", DateTime
		NoteStr = ReplaceStringByKey("Seconds",NoteStr,tempSeconds,":","\r",0)
		Wave/Z GaussWave = $GetDF("VFM")+"GaussWave"
		if (WaveExists(GaussWave))
			NoteStr = ReplaceNumberByKey("VFM Field",NoteStr,GaussWave[td_ReadValue("VFM.CurrentValue")],":","\r",0)
		endif
		
		if (GV("MicroscopeID") == cMicroscopeCypher)
			NoteStr += "Cypher Temps Start"+"\r"
			NoteStr += ReturnCypherTemps()
			NoteStr += "Cypher Temps End"+"\r"
		endif
		
		NoteStr += GetWaveParms(GlobalStrings)
		if (ImagingMode == 2)
			NoteStr += GetWaveParms(FMVW)
		Endif
		NoteStr += GetWaveParms(AllAlias)
		
		
		NoteStr = ReplaceNumberByKey("VerDate",NoteStr,VerDate,":","\r",0)
		NoteStr = ReplaceStringByKey("Version",NoteStr,VersionString(),":","\r",0)
		NoteStr = ReplaceStringByKey("XopVersion",NoteStr,td_XopVersion(),":","\r",0)
		NoteStr = ReplaceStringByKey("OSVersion",NoteStr,StringByKey("OS",IgorInfo(3)),":","\r",0)
		NoteStr = ReplaceStringByKey("IgorFileVersion",NoteStr,StringByKey("IgorFileVersion",IgorInfo(3)),":","\r",0)
		NoteStr = ReplaceStringByKey("BaseName",NoteStr,BaseName,":","\r",0)
		
		
	
		if (SVAR_EXISTS(ImageNote))
			NoteStr = ReplaceStringByKey("ImageNote",NoteStr,ImageNote,":","\r",0)
		endif
		if (SVAR_EXISTS(TipSerialNumber))
			NoteStr = ReplaceStringByKey("TipSerialNumber",NoteStr,TipSerialNumber,":","\r",0)
		endif
		Note UniqueWave,NoteStr
		
//		Note UniqueWave,GetWaveParms(RVW)
//		Note UniqueWave,"32 bit channel: "+thirtyTwoStr
//		Note UniqueWave,"Real Parms: End"
//		Note UniqueWave,"Initial Parms: Start"
//		Note UniqueWave, GetWaveParms(OldMVW)							//this puts the master variable wave parms in the note
//		Note UniqueWave, GetwaveParms(NapVW)
//		Note UniqueWave, GetWaveParms(CVW)							//this puts the channel variable wave parms in the note
//		Note UniqueWave, GetWaveParms(XPTwave)						//grab the crosspoint setup
//		Note UniqueWave, GetWaveParms(FilterVW)
//		Note UniqueWave, GetWaveParms(TVW)
//		Note UniqueWave, GetWaveParms(UserParmWave)
//		Note UniqueWave, LogFile[0,strlen(LogFile)-2]
//		Note UniqueWave, "Log File:Stop\r"
//		Note UniqueWave, "Date: "+Date()
//		Note UniqueWave, "Time: "+Time()
//		string tempSeconds
//		sprintf tempSeconds, "%u", DateTime
//		Note UniqueWave, "Seconds: "+tempSeconds
//		Wave/Z GaussWave = $GetDF("VFM")+"GaussWave"
//		if (WaveExists(GaussWave))
//			Note UniqueWave,"VFM Field: "+num2str(GaussWave[td_ReadValue("VFM.CurrentValue")])
//		endif
//		
//		Note UniqueWave,GetWaveParms(GlobalStrings)
//		if (ImagingMode == 2)
//			Note UniqueWave,GetWaveParms(FMVW)
//		Endif
//		Note UniqueWave,GetWaveParms(AllAlias)
//	
//		Note UniqueWave, "VerDate: "+num2str(VerDate)
//		Note UniqueWave, "Version: "+VersionString()
//		Note UniqueWave, "XopVersion: "+td_XopVersion()
//		Note UniqueWave, "OSVersion: "+StringByKey("OS",IgorInfo(3))
//		Note UniqueWave, "IgorFileVersion: "+StringByKey("IgorFileVersion",IgorInfo(3))
//		Note UniqueWave, "BaseName:"+BaseName
//		if (SVAR_EXISTS(ImageNote))
//			Note UniqueWave, "ImageNote: "+ImageNote
//		endif
//		if (SVAR_EXISTS(TipSerialNumber))
//			Note UniqueWave,"TipSerialNumber:"+TipSerialNumber
//		endif
//	endif
//
//	if (saveImageCount == 0)
		CopyScales TestImage UniqueWave, Mask, LineWave, LineMask, PrevLine, PrevHist, Corr, LayerWave	//and scale it
		//JB- I do not know what the <edit> I am doing here.
		//I am trying to deal with large partial Saves.
		//For some reason I can't find the variables I want, but this seems to work. 1 pixel of course.
		Variable PixelY = RVW[%SlowScanSize][0]/(OldMVW[%ScanLines][0]-1) 
		
		Variable YStart = 0
		if (!doScan)
			if (ScanDown)
				YStart = RVW[%SlowScanSize][0]-PixelY*ScanLines
			endif
			SetScale/P y, YStart, PixelY, UniqueWave, LayerWave, Mask
		endif
	endif


	variable i, j, retrace, stop, layer = 0, NotScaled = 1, wrap = 0
	String ScalingFunction = ""
	Variable ScalingFunctionVar0, ScalingFunctionVar1
	
	for (i = 1;i <= ItemsInList(MDTL);i += 1)				//We now deal with the full range, 0 is off

		dataTypeStr = StringFromList(i,MDTL)		//go through once for trace and once for retrace
		userDataTypeStr = FindUserName(dataTypeStr,"Name")
		ScalingFunction = ""
		ScalingFunctionVar0 = 0
		ScalingFunctionVar1 = 0

		strswitch (dataTypeStr)

			case "Height":
				scale = -MVW[%ZPiezoSens][%value]
				offset = 70
				break

			case "Amplitude":
			case "Amplitude1":
				scale = MVW[%AmpInvOLS][%value]
				offset = 0//MVW[%AmplitudeSetpointVolts][%value]		//don't take out the set point
				break

			case "Amplitude2":
				scale = MVW[%Amp2InvOLS][%value]
				offset = 0//MVW[%AmplitudeSetpointVolts][%value]		//don't take out the set point
				break

			case "Deflection":
				scale = MVW[%InvOLS][%value]
				offset = MVW[%DeflectionSetpointVolts][%value]		//take out the set point
				break

			case "Phase1":
			case "Phase":
				scale = 1
				offset = RVW[%PhaseOffset][0] - MVW[%PhaseOffset][0]
				if (offset)
					wrap = 1
				endif
				break

			case "Phase2":
				scale = 1
				offset = RVW[%PhaseOffset1][0] - MVW[%PhaseOffset1][0]
				if (offset)
					wrap = 1
				endif
				break

			case "ZSensor":
				scale = -MVW[%ZLVDTSens][%value]
				offset = 0
				break
			
			case "Current":
				scale = -MVW[%OrcaGain][%value]
				offset = -OVW[%OrcaOffset][%value]
				break	
			
			case "Current2":
				scale = -MVW[%OrcaGain2][%value]
				offset = -OVW[%OrcaOffset2][%value]
				break	

			case "Frequency":
				scale = 1
		
				if ((FMVW[%FreqOffsetRelative][0]) && (!GrepString(thirtyTwoStr,"Frequency")))
					offset = -MVW[%DriveFrequency][%value]
				else	
					offset =0
				endif
				break
				
			case "UserIn0":
			case "UserIn1":
			case "UserIn2":
			case "Lateral":
				Scale = MVW[%$DataTypeStr+"Gain"][%Value]
				offset = -MVW[%$DataTypeStr+"Offset"][%Value]
				break
				
			case "Capacitance":
				Scale = MVW[%CapacitanceSens][%Value]
				Offset = MVW[%CapacitanceOffset][%Value]
				
			case "CapPhase":
				Scale = 1
				Offset = MVW[%CapPhaseOffset][%Value]
				break
				
			case "TipHeaterPower":
				Scale = 1		//Needs Roger's code for this.
				Offset = 0
				ScalingFunction = "CalcTipHeaterPower"
				ScalingFunctionVar0 = td_ReadValue("TipHeaterDrive")
				if (IsNan(ScalingFunctionVar0))
					ScalingFunctionVar0 = TVW[%TipHeaterDrive][%Value]
				endif
				ScalingFunctionVar1 = 1/-MVW[%OrcaGain][%value]
				break
				
			case "TipHeaterDrive":
				Scale = 1
				Offset = 0
				break
				
			default:								//the rest are assumed to be in volts with no scaling, for now
				scale = 1
				offset = 0
		endswitch
		
		
		ChannelNum = WhichListItem(num2str(i),ChannelNumList,",",0,0)+1
		Stop = 1+IsNap*2
		variable weDone 
		for (retrace = 0;retrace <= stop;retrace += 1)

			switch (retrace)
				
				case 0:
					tempSum = sum0
					weDone = 0
					break

				case 1:
					tempSum = sum1
					break

				case 2:
					tempSum = sum2
					weDone = 0
					break

				case 3:
					tempSum = sum3
					break

			endswitch

			if (!(2^(i-1) & tempSum))					//check if we are supposed to save this data type
				Continue
			endif
			wave Input = $userDataTypeStr+"Wave"		//grab the input wave
			if (!weDone)
				InfoStruct.ChannelNum = ChannelNum
				InfoStruct.IsNap = retrace > 1
				ARGetChannelInfo(InfoStruct)
				weDone = 1
			endif

			if (stringmatch(dataTypeStr,"UserCalc"))		//we might have to do something else for calculated
				WaveStats/R=[DimSize(Input,0),DimSize(Input,0)*(DimSize(Input,1)-2)-1]/Q/M=1 Input					//do a simple wavestats
				if (V_NumNaNs)							//NaNs would be a sign that some lines were missed.
					Wave/T CVD = root:Packages:MFP3D:Main:Variables:ChannelVariablesDescription
					String FuncName = CVD[%UserCalcFunc][%Title]			//grab the current function
					String FuncInfo
					Variable HaveFunction = !ARCheckFuncRef("CalcPhaseFromIQ",FuncName)

					if (HaveFunction)
						FuncRef CalcPhaseFromIQ UserCalcFunc=$FuncName			//set the new function
						Input = UserCalcFunc(p,q)										//calculate the whole input wave
					endif
				endif
			endif
			
			if (IsNap)

				switch (retrace)

					case 0:
						UniqueWave[][start,finish][layer] = (Input[p+scanPoints/8][scanTotal-1+(scanSign*(2*mod(q,256)))]-offset)*scale		//copy the correct part of the input wave
						SetDimLabel 2,layer,$userDataTypeStr+"Trace",UniqueWave				//set the label to the data type
						break
					
					case 1:
						UniqueWave[][start,finish][layer] = (Input[scanPoints*2.375-p-0][mod(scanTotal*2+scanSign*2*q,512)]-offset)*scale	//copy the correct part of the input wave
						SetDimLabel 2,layer,$userDataTypeStr+"Retrace",UniqueWave			//set the label to the data type
						break
						
					case 2:
						UniqueWave[][start,finish][layer] = (Input[p+scanPoints/8][scanTotal-1+(scanSign*(2*mod(q,256)+1))]-offset)*scale		//copy the correct part of the input wave
						SetDimLabel 2,layer,$"Nap"+userDataTypeStr+"Trace",UniqueWave				//set the label to the data type
						break

					case 3:
						UniqueWave[][start,finish][layer] = (Input[scanPoints*2.375-p-0][mod(scanTotal*2+scanSign*2*q+1,512)]-offset)*scale
						SetDimLabel 2,layer,$"Nap"+userDataTypeStr+"Retrace",UniqueWave			//set the label to the data type
						break

				endswitch
			
			else		//if ((scanLines > 800) || GV("ScanMode"))			//these were done with a raster scan

				if (retrace)
					UniqueWave[][start,finish][layer] = (Input[scanPoints*2.375-p-0][mod(scanTotal-1+scanSign*q,512)]-offset)*scale	//copy the correct part of the input wave
					SetDimLabel 2,layer,$userDataTypeStr+"Retrace",UniqueWave			//set the label to the data type
				else
					UniqueWave[][start,finish][layer] = (Input[p+scanPoints/8][mod(scanTotal-1+scanSign*q,512)]-offset)*scale		//copy the correct part of the input wave
					SetDimLabel 2,layer,$userDataTypeStr+"Trace",UniqueWave				//set the label to the data type
				endif


			endif
			
			if (!ARCheckFuncRef("CalcTipHeaterPower",ScalingFunction))
				FuncRef CalcTipHeaterPower ScalingFunc=$ScalingFunction
				UniqueWave[][Start,Finish][Layer] = ScalingFunc(UniqueWave[P][Q][R],ScalingFunctionVar0,ScalingFunctionVar1)
			endif
			
			if (wrap)
				UniqueWave[][][layer] = mod(UniqueWave[p][q][layer]+540,360)-180
			endif
			UpdateRealGraph(scanDown)

			
			if (doTop)
				Input[scanPoints*2.5-1][DimSize(Input,1)/2,] = NaN
			else
				Input[scanPoints*2.5-1][0,DimSize(Input,1)/2-1] = NaN
			endif
						
			variable hasPits = 1
			string flattenStr = "Magic Mask (Pits)"
			
			if (saveImageCount > 99)
				switch (InfoStruct.SavePlaneFit)			//deal with the variety of planefits
	
					case 0:												//no planefit
						WaveStats/Q/R=[layer*scanPoints*scanLines,(layer+1)*scanPoints*scanLines-1]/M=1 UniqueWave	//do wave stats
	
						Note UniqueWave, "Planefit "+num2str(layer)+": None"				//this is none and the rest are 0
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": -1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": -1"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": 0"
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Display Offset "+num2str(layer)+": "+num2str(V_avg)		//enter the display offset so the image will
						break																					//be visible in offline
	
					case 1:												//just remove the offset
						WaveStats/Q/R=[layer*scanPoints*scanLines,(layer+1)*scanPoints*scanLines-1]/M=1 UniqueWave	//wave stats
						UniqueWave[][][layer] -= V_avg												//subtract the average
	
						Note UniqueWave, "Planefit "+num2str(layer)+": Offset"					//this is offset
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": 0"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": -1"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(V_avg)		//this was the amount subtracted
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": 0"				//the rest are 0
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"
						break
	
					case 2:												//subtract a 1st order planefit
							ImageInterpolate/F={256/scanPoints,256/scanLines}/D=2 spline UniqueWave		//convert to 256 point wave
							wave M_InterpolatedImage
							Make/O/N=(DimSize(M_interpolatedImage,0),DimSize(M_InterpolatedImage,1)) FitLayer
							FitLayer = M_InterpolatedImage[p][q][layer]
							CopyScales/I UniqueWave FitLayer				//copy the scales
							CurveFit/N/Q poly2D 1, FitLayer	//do the fit
						wave W_coef
						UniqueWave[][][layer] -= poly2D(W_coef,x,y)		//subtract the plane
	
						Note UniqueWave, "Planefit "+num2str(layer)+": Planefit"								//it was a 1st order planefit
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": 1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": -1"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(W_coef[0])		//this is the offset
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": "+num2str(W_coef[1])		//the X slope
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": "+num2str(W_coef[2])		//the Y slope
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"								//this is 0
						break
	
					case 3:												//flatten 0
						ImageInterpolate/F={256/scanPoints,256/scanLines}/D=2 spline UniqueWave		//convert to 256 point wave
						wave M_InterpolatedImage
						Make/O/N=(DimSize(M_interpolatedImage,0),DimSize(M_InterpolatedImage,1)) FitLayer
						FitLayer = M_InterpolatedImage[p][q][layer]
						CopyScales/I UniqueWave FitLayer				//copy the scales
						CurveFit/N/Q poly2D 1, FitLayer	//do the fit
						wave W_coef
						UniqueWave[][][layer] -= poly2D(W_coef,x,y)		//subtract the plane
	
						FlattenParms[1][] = 0
			  			for (j = 0;j < scanLines;j += 1)				//loop through all of the lines
							LineWave = UniqueWave[p][j][layer]					//copy the line into LineWave
							WaveStats/M=1/Q LineWave	//do a line
							UniqueWave[][j][layer] -= v_avg			//subtract the offset
							FlattenParms[0][j] = v_avg
						endfor
						InsertFlattenParms(FlattenParms,offsetList,slopeList)
	
						Note UniqueWave, "Planefit "+num2str(layer)+": Flatten 0"								//it was a 0 order flatten
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": -1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": 0"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(W_coef[0])		//this is the offset
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": "+num2str(W_coef[1])		//the X slope
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Flatten Offsets "+num2str(layer)+": "+offsetList						//this is a list of the offsets for each line
						Note UniqueWave, "Flatten Slopes "+num2str(layer)+": "+slopeList						//this is a list of the slopes for each line
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"								//this is 0
						break
	
					case 4:											//flatten 1
						WaveStats/Q/R=[layer*scanPoints*scanLines,(layer+1)*scanPoints*scanLines-1]/M=1 UniqueWave	//wave stats
			  			for (j = 0;j < scanLines;j += 1)				//loop through all of the lines
							LineWave = UniqueWave[p][j][layer]					//copy the line into LineWave
							CurveFit/Q/N line LineWave	//do a line
							offset = W_coef[0]					//local variables are faster than wave points
							slope = W_coef[1]					//the above matters for big waves
							UniqueWave[][j][layer] -= offset+slope*x			//subtract the line
							FlattenParms[0][j] = offset
							FlattenParms[1][j] = slope
						endfor
						InsertFlattenParms(FlattenParms,offsetList,slopeList)
						Note UniqueWave, "Planefit "+num2str(layer)+": Flatten 1"								//it was a 1st order flatten
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": -1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": 1"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(V_avg)			//put a number in here so the drift software works
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": 0"							//the X slope
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Flatten Offsets "+num2str(layer)+": "+offsetList						//this is a list of the offsets for each line
						Note UniqueWave, "Flatten Slopes "+num2str(layer)+": "+slopeList						//this is a list of the slopes for each line
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"								//this is 0
						break
			
					case 5:										//histo flatten
						
						variable xStepSize = 3
						Make/O/N=4 CoefWave
	//					String JHand = "SpecialFlatten"
	//					InitJbar(JHand,num2str(ScanLines-1)+",","Flattening","","")
						LayerWave = UniqueWave[p][q][layer]
	//					Duplicate/O LayerWave,$DataFolder+"SlopeTempWave"
	//					Wave SlopeWave = $DataFolder+"SlopeTempWave"
						MatrixFilter/P=3/N=5 median LayerWave					// do some filtering to narrow down the slope distribution
						MatrixFilter/P=3/N=5 avg LayerWave						// do some filtering to narrow down the slope distribution
						Wave HistTemp = $InitOrDefaultWave(GetDF("Analyze")+"HistTemp",2000)
						
						Make/O/N=(DimSize(LayerWave,0)-xStepSize,DimSize(LayerWave,1)) SlopeWave
						SlopeWave = LayerWave[P+XStepSize][Q]-LayerWave[P][Q]
						MatrixFilter median SlopeWave
						
						Histogram/B=1 SlopeWave,HistTemp
						Redimension/N=(-1,1) HistTemp
						MatrixFilter median HistTemp
						Redimension/N=(-1,0) HistTemp
						
						CalcHistoMax(HistTemp,CoefWave)
						Slope = CoefWave[2]/XStepSize
						UniqueWave[][][layer] -= Slope*P
						
	
						WaveStats/Q/R=[layer*DimSize(UniqueWave,0)*DimSize(UniqueWave,1),(layer+1)*DimSIze(UniqueWave,0)*DimSize(UniqueWave,1)-1] UniqueWave		//stats of the whole Unique
						
						UniqueWave[][][Layer] -= V_avg			//subtract out the average
						imageOffset = V_avg
						
						Redimension/N=4 W_coef
						PrevLine = UniqueWave[p][0][Layer]
						WaveStats/Q/M=1 PrevLine
						UniqueWave[][0][Layer] -= V_Avg
						PrevLine -= V_avg
						
						FlattenParms[1][] = 0
						FlattenParms[0][0] = V_avg
						for (j = 1;j < ScanLines;j += 1)				//loop through all of the lines
	//						Jbar(JHand,I,0,.01)
							LineWave = UniqueWave[p][j][layer]					//copy the line into LineWave
							Redimension/N=(DimSize(PrevHist,0)) Corr
							SetScale/I x,min(wavemin(PrevLine),wavemin(LineWave)),Max(wavemax(PrevLine),wavemax(LineWave)),PrevHist,Corr
							Histogram/B=2 PrevLine,PrevHist
							Histogram/B=2 LineWave,Corr
							SetScale/P x,0,Dimdelta(Corr,0),Corr,PrevHist
							Correlate PrevHist,Corr
							CalcHistoMax(Corr,W_Coef)
							Offset = W_Coef[2]
							if (((Offset > leftx(Corr)) && (Offset < rightx(Corr))) && (numtype(Offset) == 0))
								FastOp PrevLine = LineWave+(-Offset)			//only update the previous line if it used a histogram.
								CopyScales LineWave,PrevLine
							else
								WaveStats/Q/M=1 LineWave
								Offset = V_Avg
							endif
								
							UniqueWave[][J][Layer] -= Offset
							FlattenParms[0][j] = offset
						endfor
						InsertFlattenParms(FlattenParms,offsetList,slopeList)
						Note UniqueWave, "Planefit "+num2str(layer)+": Histo Flatten"								//it was a Histogram flatten
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": -1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": 4"				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(imageOffset)		//this is the offset
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": "+num2str(slope)		//the X slope
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Flatten Offsets "+num2str(layer)+": "+offsetList						//this is a list of the offsets for each line
						Note UniqueWave, "Flatten Slopes "+num2str(layer)+": "+slopeList						//this is a list of the slopes for each line
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"								//this is 0
						break
	
					case 6:										//masked flatten
	
						WaveStats/Q/R=[layer*scanPoints*scanLines,(layer+1)*scanPoints*scanLines-1]/M=1 UniqueWave	//wave stats
						if ((!InfoStruct.IsRetraceSlave) && (mod(retrace,2)))		//we actually use the retrace value
							displayRange = InfoStruct.DataScale[1]
						else
							displayRange = InfoStruct.DataScale[0]
						endif
						
						MaskedLineFlatten(UniqueWave,FlattenParms,layer,displayRange)
						FlattenParms[1][] /= DimDelta(UniqueWave,0)
//						Duplicate/O FlattenParms TestParms
						InsertFlattenParms(FlattenParms,offsetList,slopeList)
						
						Note UniqueWave, "Planefit "+num2str(layer)+": Masked Line Flatten"								//it was a 1st order flatten
						Note UniqueWave, "PlanefitOrder "+num2str(layer)+": -1"				//This is the order number of the planefit, -1 for none
						Note UniqueWave, "FlattenOrder "+num2str(layer)+": "+num2str(InfoStruct.SavePlaneFit-2)				//This is the order number of the flatten, -1 for none
						Note UniqueWave, "Planefit Offset "+num2str(layer)+": "+num2str(V_avg)			//put a number in here so the drift software works
						Note UniqueWave, "Planefit X Slope "+num2str(layer)+": 0"							//the X slope
						Note UniqueWave, "Planefit Y Slope "+num2str(layer)+": 0"
						Note UniqueWave, "Flatten Offsets "+num2str(layer)+": "+offsetList						//this is a list of the offsets for each line
						Note UniqueWave, "Flatten Slopes "+num2str(layer)+": "+slopeList						//this is a list of the slopes for each line
						Note UniqueWave, "Display Offset "+num2str(layer)+": 0"								//this is 0
						break
		

			
	
				
				endswitch
				//record the range that was used
				if ((!InfoStruct.IsRetraceSlave) && (mod(retrace,2)))		//we actually use the retrace value
					Note UniqueWave, "Display Range "+num2str(layer)+": "+num2str(InfoStruct.DataScale[1])
					Note UniqueWave, "ColorMap "+num2str(Layer)+": "+StringFromList(1,InfoStruct.ColorMapList,";")
				else
					Note UniqueWave, "Display Range "+num2str(layer)+": "+num2str(InfoStruct.DataScale[0])
					Note UniqueWave, "ColorMap "+num2str(Layer)+": "+StringFromList(0,InfoStruct.ColorMapList,";")
				endif
				If (calcDrift && (layer == 0))
					Duplicate/O UniqueWave $"DriftWave"+num2str(driftCount)
					wave MoreUniqueWave = $"DriftWave"+num2str(driftCount)
					SimpleFlatten(MoreUniqueWave,1)
				endif
				if (ScanPoints > 1024)
	//				Redimension/N=(1,1) Input
				endif
			endif
			layer += 1						//increment the layer
		endfor
	endfor	

	if (saveImageCount > 99)
		if (GV("IsScanBias"))
			wave Image
			UniqueWave[][][layer] = Image[p][scanLines-1-q]
			SetDimLabel 2,layer,BiasRetrace,UniqueWave
		endif
	
	//	Note UniqueWave, "StartHeadTemp: "+num2str(GV("StartHeadTemp"))			//the start temps are already in there from the MVW
		Note UniqueWave, "EndHeadTemp: "+td_ReadString("Temperature@Head")			//do this as late as possible
	//	Note UniqueWave, "StartScannerTemp: "+num2str(GV("StartScannerTemp"))
		Note UniqueWave, "EndScannerTemp: "+td_ReadString("Temperature@Scanner")
		wave/Z DegreesWave = root:Packages:MFP3D:Heater:DegreesWave
		if (WaveExists(DegreesWave))
			//Note UniqueWave, "StartBioHeaterTemp: "+num2str(GV("StartBioHeaterTemp"))
			Note UniqueWave, "EndBioHeaterTemp: "+num2str(DegreesWave[td_ReadValue("CurrentValue@Heater")])
		endif
	endif
	
	if (saveImageCount > 99)
	
		if (doScan == 0)
		elseif (!(GV("SaveImage")) || (GV("ParmChange") == 1))		//if we want to save and ParmChange is not 1 which means next, then save
			PV("ScanDown",!ScanDown)					//change the scandown for next time
			if (GV("DelayUpdate") & 4)
				DoScanFunc("DoScan_0")
			else
				DoScanFunc("ContinueScan")										//start over
			endif
			if (LastMacroMode)
				SwapMacroMode(0)
				if (LastMacroMode & 1)
					PostARMacro("",nan,"","")		//just leave it empty, it will call the next step.
				endif
			endif
			//MasterARGhostFunc("","SaveLast_*")
			GhostMainPanel()
			//DisableControl("*","SaveLast_0",0)
//print (StopMSTimer(-2)-startTimer)*1e-6
			return 0
			//elseif (GV("SaveImage") == 1)
			//	CheckSaveStatus()
			//UpdateAllControls("NoSaveImage_0","Save Image","SaveImage_0","")
		endif
	
		sprintf numStr, "%4.4u", MVW[%BaseSuffix][%value]				//put the number into a 4 character string
		waveStr = BaseName+numStr									//combine the image name and the number
		Rename UniqueWave $waveStr
		wave UniqueWave = $waveStr
	
		ResaveImageFunc(UniqueWave,"SaveImage",1)
		//DisableControl("*","SaveLast_0",2)
		//MasterARGhostFunc("SaveLast_*","")
		GhostMainPanel()
		//doot doot doot looking out my back door
		//Save/C/P=SaveImage TempWave as waveStr+".ibw"			//save the image as an igor binary wave
		
		if (calcDrift)
			variable currentTime = DateTime
			NVAR DriftTime
			if (driftCount)
				wave StartDrift = $"DriftWave"+num2str(GV("DriftCount")-1)
				wave EndDrift = $"DriftWave"+num2str(GV("DriftCount"))
				wave XDriftWave, YDriftWave, FitXDriftWave, FitYDriftWave
				variable xDrift, yDrift, startTime, endTime, startXOffset, startYOffset, endXOffset, endYOffset, FitXDrift, FitYDrift
	
				startTime = str2num(StringByKey("Seconds",Note(StartDrift),":","\r"))
				startYOffset = str2num(StringByKey("YOffset",Note(StartDrift),":","\r"))
				startXOffset = str2num(StringByKey("XOffset",Note(StartDrift),":","\r"))
				endTime = str2num(StringByKey("Seconds",Note(EndDrift),":","\r"))
				endYOffset = str2num(StringByKey("YOffset",Note(EndDrift),":","\r"))
				endXOffset = str2num(StringByKey("XOffset",Note(EndDrift),":","\r"))
				
				CalcImageOffset(StartDrift,EndDrift,xDrift,yDrift,FitXDrift,FitYDrift)
	
				Redimension/N=(driftCount) XDriftWave, YDriftWave, FitYDriftWave, FitXDriftWave
				XDriftWave[driftCount-1] = (xDrift+startXOffset-endXOffset)/((endTime-startTime)/60)
				YDriftWave[driftCount-1] = (yDrift+startYOffset-endYOffset)/((endTime-startTime)/60)
				FitXDriftWave[driftCount-1] = (FitxDrift+startXOffset-endXOffset)/((endTime-startTime)/60)
				FitYDriftWave[driftCount-1] = (FityDrift+startYOffset-endYOffset)/((endTime-startTime)/60)
				MainSetVarFunc("XDriftRateSetVar_0",XDriftWave[driftCount-1],"",":Variables:MasterVariablesWave[%XDriftRate]")
				MainSetVarFunc("YDriftRateSetVar_0",YDriftWave[driftCount-1],"",":Variables:MasterVariablesWave[%YDriftRate]")
			else
				Make/O/N=1 XDriftWave, YDriftWave, FitXDriftWave, FitYDriftWave
				XDriftWave = NaN
				YDriftWave = NaN
				FitXDriftWave = NaN
				FitYDriftWave = NaN
			endif
			PV("DriftCount",driftCount+1)
	//		DriftTime = currentTime
		endif
	else
		if ((napScanLines <= 512) && !isNap)
			MVW[%SaveImageCount][0] = 100
		else
			MVW[%SaveImageCount][0] += 1
			if ((napScanLines) < (MVW[%SaveImageCount][0]*saveImageLines/(1+isNap)))
				MVW[%SaveImageCount][0] = 100
			endif
		endif
	endif
	
//print (StopMSTimer(-2)-startTimer)*1e-6
	if (saveImageCount > 99)
	//	KillWaves/Z TempWave TempLayer BrowseByteTemp		//kill the sundry extra waves
		if (doScan)
			Rename UniqueWave UniqueWave
		else
			rename UniqueWave PartialWave
		endif
		
		MVW[%BaseSuffix][%value] += 1												//increment the suffix
		PV("SaveImage",(2 & GV("SaveImage")))							//reset SaveImage
		
		if (doScan && (MVW[%DelayUpdate][0] & 4))
			if (scanDown)
				DoScanFunc("UpScan_0")
			else
				DoScanFunc("DownScan_0")
			endif
		elseif (doScan)
			PV("ScanDown",!ScanDown)					//change the scandown for next time
//			if (GV("DelayUpdate") & 4)
//				DoScanFunc("DoScan_0")
//			else
				DoScanFunc("ContinueScan")										//start over
//			endif
		endif
	
		if (LastMacroMode)
			SwapMacroMode(0)
			if (LastMacroMode & 1)
				PostARMacro("",nan,"","")		//just leave it empty, it will call the next step.
			endif
		endif
	endif
	
	SetDataFolder SavedDataFolder
end //SaveImageFunc

Function ResaveImageFunc(ImageWave,PName,Overwrite)
	Wave ImageWave
	String PName			//name of symbolic path that has already been set for this use.
	Variable Overwrite		//1 if you want to be able to overwrite the image file.
	//If overwrite is 1, then it will also clean up after itself and kill temp waves
	
	//returns 1 if SaveImage is a bad path, and the user canceled
	//returns 2 if you can't write to folder.
	
	//It is up to you to set the folder, it will make the wave BrowseByteTemp
	
	
	if (!SafePathInfo(PName))
		if (ARNewPath(Pname,CreateFlag=1))
			return(1)
		endif
	endif
	
	PV("LastImage",0)
	String TypeStr = ".ibw"
	
	if (Overwrite)
		Save/C/O/P=$PName ImageWave as NameOfWave(ImageWave)+TypeStr
	else
		Save/C/P=$PName ImageWave as NameOfWave(ImageWave)+TypeStr
	endif



	variable ScanPoints = DimSize(ImageWave,0)
	variable ScanLines = DimSize(ImageWave,1)
	variable fastScanSize = (DimSize(ImageWave,0)-1)*DimDelta(ImageWave,0)
	variable slowScanSize = (DimSize(ImageWave,1)-1)*DimDelta(ImageWave,1)

	variable browsePoints, browseLines
	if (fastScanSize > slowScanSize)
		browsePoints = 128
		browseLines = round(128*slowScanSize/fastScanSize)
	else
		browsePoints = round(128*fastScanSize/slowScanSize)
		browseLines = 128
	endif
	variable browsePointsFactor = (browsePoints-.999)/(scanPoints-1)			//the ratio of the images to the browse images in points
	variable browseLinesFactor = (browseLines-.999)/(scanLines-1)			//the ratio of the images to the browse images in lines

	Variable FileRef, fileStart
	String BrowseFooterStr = "",browseStr, tempStr

	Open/A/T="IGBW"/P=$PName FileRef NameOfWave(ImageWave)+TypeStr	//open the just saved image file
	FStatus FileRef												//get stats
	if (!V_Flag)
		return(2)
	endif
	fileStart = V_filePos										//this at the end of the file
	ImageInterpolate/F={(browsePointsFactor),(browseLinesFactor)}/D=2 spline ImageWave	//interpolate to the right size
	Wave BrowseTemp = M_interpolatedImage							//reference the output to browsetemp

	if (DimSize(BrowseTemp,0) != BrowsePoints)
		print "Bad Interpolate points: trying for",BrowsePoints,"got",DimSize(BrowseTemp,0)
		DoWindow/H
		BrowsePoints = DimSize(BrowseTemp,0)
	endif
	if (DimSize(BrowseTemp,1) != BrowseLines)
		print "Bad Interpolate Lines: trying for",BrowseLines,"got",DimSize(BrowseTemp,1)
		DoWindow/H
		BrowseLines = DimSize(BrowseTemp,1)
	endif

	browseFooterStr += "DataType:Byte;"						//these numbers are no longer hard wired
	browseFooterStr += "DataWidth:"+num2str(browsePoints)+";"
	browseFooterStr += "DataHeight:"+num2str(browseLines)+";"
	browseFooterStr += "DataLength:"+num2str(browsePoints*browseLines)+";"
	browseFooterStr += "NumberOfFiles:"+num2str(DimSize(ImageWave,2))+";"		//put in the number of files
	
//Print browsePointsFactor,browseLinesFactor-127/31
//Abort "Test"
	Make/O/B/N=(browsePoints,browseLines) BrowseByteTemp						//make a wave for the browse image
	
	Variable HalfScale
	variable i, stop = Max(DimSize(ImageWave,2),1)-1
	for (i = 0;i <= stop;i += 1)									//do all the layers

		WaveStats/Q/R=[i*browsePoints*browseLines,(i+1)*browsePoints*browseLines-1]/M=1 BrowseTemp		//wave stats of the current layer
//print v_min,v_max,v_avg
//continue
//abort "Test"
		HalfScale = Min(abs(V_max-V_avg),abs(V_min-V_avg))
		BrowseTemp[][][i] = limit((BrowseTemp[p][q][i]-V_avg)*127.5/HalfScale,-128,127)	//using the closer extreme throws away some spikes
		
		
//		if (abs(V_max-V_avg) > abs(V_min-V_avg))				//find the closer extreme to the average, and use that for scaling
//			BrowseTemp[][][i] = limit((BrowseTemp[p][q][i]-V_avg)*127.5/abs(V_avg-V_min),-128,127)	//using the closer extreme throws away some spikes
//		else																			//scale the wave to fit into 8 bits
//			BrowseTemp[][][i] = limit((BrowseTemp[p][q][i]-V_avg)*127.5/abs(V_max-V_avg),-128,127)
//		endif
		BrowseByteTemp = BrowseTemp[p][q][i]				//set the 8 bit wave to the result
		FBinWrite/B=3 fileRef, BrowseByteTemp			//write the wave into the file using Wintel byte order
		FStatus fileRef										//get the file status
		browseStr = GetDimLabel(ImageWave,2,i)			//get the data type of the current layer
		sprintf tempStr, "%d", fileStart					//put the file start into a string, num2str doesn't use enough digits
		browseFooterStr += browseStr+"FileStart:"+tempStr+";"		//add the file start info to the footer string
		fileStart = V_filePos								//set the file start to the next value
	endfor
//abort "test"
//	if (Overwrite)
	KillWaves/Z BrowseByteTemp	//,BrowseTemp Killing this actually kills M_InterpolatedImage, which UpdateRealGraph needs.
	if (!StringMatch(GetWavesDataFolder(BrowseTemp,1),GetDF("Main")))
		KillWaves/Z BrowseTemp
	endif
//	endif

	BrowseFooterStr += "IsImage:1;"

	sprintf tempStr, "%4.4u", strlen(browseFooterStr)+11		//put the length of the footer plus the length of the stuff still to be added into a string
	BrowseFooterStr += " "+tempStr+" MFP3D"						//put the length and the ident into the string
	FBinWrite FileRef, BrowseFooterStr					//write the string into the file
	Close(FileRef)


End //ResaveImageFunc

function SaveStatusFunc(ctrlName)				//this deals with the save image button
	string ctrlName
	
	
	String PName = "SaveImage"
	String ParmName = ARConvertName2Parm(CtrlName,"Button")
	
	strswitch (ParmName)

		case "SaveImage":						//this button means save an image once or force a save
			if (!SafePathInfo(Pname))							//if not there
				if (ARNewPath(PName,CreateFlag=1))													//if no folder was chosen, let the user 
					DoAlert 0,"You have to choose a folder to save images"	//know they have to pick a folder to save images
					return 1						//out of here
				endif
				ARCheckSuffix()
			endif
			
			if (GV("SaveImage"))						//if there is already something in SaveImage, then this will force a save
				if (!(2 & GV("ParmChange")))			//if the 2 bit is not set in ParmChange
					PV("ParmChange",GV("ParmChange")+2)		//then set the 2 bit, this will force a save
				endif
				if (2 & GV("SaveImage"))			//if the 2 bit is set then
					PV("SaveImage",3)				//add the 1 bit to SaveImage
				endif
			else
				PV("SaveImage",1)					//there is no drama, just set the 1 bit in SaveImage
			endif

//			if (!(GV("ParmChange") == 1))		//if this is 1 then leave the button as SaveImage_0 so that a save can be forced
//				UpdateAllControls("SaveImage_0","Don't Save","NoSaveImage_0","")
//			endif
			break

		case "NoSaveImage":		//we don't want to save the next image
			if (2 & GV("SaveImage"))		//if bit 2 is set, then saving automatically is on
				PV("ParmChange",1)			//setting the ParmChange will stop the next image from being saved
				PV("SaveImage",2)			//change this to regular auto save mode
			else								//it is not set to auto
				if (2 & GV("ParmChange"))		//the 2 bit means this will force a save
					PV("ParmChange",GV("ParmChange")-2)	//now it won't
				endif	
				PV("SaveImage",0)				//this will stop a save
			endif
//			UpdateAllControls("NoSaveImage_0","Save Image","SaveImage_0","")
			break

		case "BrowseImages":
			BrowseFolder()
			return 0
			
		case "FMapPath":
		case "ForcePath":
		case "ImagePath":
			MakePanel("ARSave")
			return(0)

		case "SaveLast":

			if (!SafePathInfo(PName))							//if not there
				if (ARNewPath(PName,CreateFlag=1))													//if no folder was chosen, let the user 
					DoAlert 0,"You have to choose a folder to save images"	//know they have to pick a folder to save images
					return 1						//out of here
				endif
				ARCheckSuffix()
			endif

			SVAR BaseName = root:Packages:MFP3D:Main:Variables:BaseName
			wave/Z UniqueWave = root:Packages:MFP3D:Main:UniqueWave
			if (WaveExists(UniqueWave) == 0)
				DoAlert 0, "There doesn't seem to be an available image."
				return 1
			endif
			
			string numStr, waveStr
			sprintf numStr, "%4.4u", GV("BaseSuffix")			//put the number into a 4 character string
			waveStr = BaseName+numStr									//combine the image name and the number
			Rename UniqueWave $waveStr
			wave UniqueWave = $waveStr
		
			ResaveImageFunc(UniqueWave,PName,1)
//			KillWaves/Z TempWave						//kill the sundry temp wave
			Rename UniqueWave UniqueWave					//rename the UniqueWave instead of killing
			//DisableControl("*","SaveLast_0",2)
			GhostMainPanel()
//			MasterARGhostFunc("SaveLast_*","")
			PV("BaseSuffix",GV("BaseSuffix")+1)									//increment the suffix
			break
			
		case "SavePartImage":
			Variable IsNap = RealScanParmFunc("NapMode","Value")
			if (IsNan(IsNap))
				IsNap = GV("NapMode")
			endif
			IsNap = IsNap > 0
			SaveImageFunc(200)
			Variable Chan1Image = RealScanParmFunc("Channel1DataType","Value")
			SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
			Wave TestWave = $"root:Packages:MFP3D:Main:"+FindUserName(StringFromList(Chan1Image,MDTL,";"),"Name")+"Wave"
			
//			wave TestWave = root:Packages:MFP3D:Main:Heightwave
//			if (DimSize(TestWave,0) < 32)
//				wave TestWave = root:Packages:MFP3D:Main:ZSensorWave
//			endif
			variable temp = NaN
			FastOp TestWave = (temp)
			break
					
	endswitch
		
	CheckSaveStatus()		//this takes care of the save status display
	PostARMacro(CtrlName,nan,"","")
	
end //SaveStatusFunc

function CheckSaveStatus()		//this takes care of the save status display on the main panel

	variable i
	
	
	String ControlList = "NoSaveImage;SaveImage;SavePartImage;"
	String TitleList = "Don't Save;Save Image;Save Partial;"
	Variable TabNum = ARPanelTabNumLookUp("MainPanel")
	String TabStr = "_"+Num2str(TabNum)
	ControlList = ListMultiply(ControlList,TabStr,";")
	Variable MinSize = 32
	Variable MinLines = 8
	String ShowList = "", HideList = ""
	Variable HaveShow = 0
	
	
	if (GV("ScanStatus") == 0)
		Variable Chan1Image = RealScanParmFunc("Channel1DataType","Value")
		SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
		Wave TestWave = $"root:Packages:MFP3D:Main:"+FindUserName(StringFromList(Chan1Image,MDTL,";"),"Name")+"Wave"
	
//		Wave TestWave = root:Packages:MFP3D:Main:Heightwave
		if (DimSize(TestWave,0) < MinSize)
			ShowList = "SaveImage"+TabStr
		endif
		if (!Strlen(ShowList))
			if (Td_WhereNow(TestWave,0) < MinLines)
				ShowList = "SaveImage"+TabStr
			else
				ShowList = "SavePartImage"+TabStr
				//use to leave after this point
				HaveShow = 1
			endif
		endif
	else
		ShowList = "SaveImage"+TabStr
	endif
	

	string titleStr
	string colorStr = "\f00\K(0,0,0)"
	variable saveStatus = GV("SaveImage")+(4*GV("ParmChange"))		//do weird logic math

	switch (saveStatus)

		case 0:					//both of these numbers mean that SaveImage = 0, no saving
		case 4:
			titleStr = "None"
			break

		case 1:			//these numbers mean that SaveImage > 0, and ParmChange = 0, so good saving conditions
		case 2:
		case 3:
			titleStr = "Save Current"
			break

		case 5:			//these numbers mean that SaveImage > 0, and ParmChange = 1, so wait till next time
		case 6:
		case 7:
			titleStr = "Save Next"
			colorStr = "\f01\K(65535,0,0)"
			if (!HaveShow)
				ShowList = "SaveImage"+TabStr
			endif
			//UpdateAllControls("NoSaveImage_0","Save Image","SaveImage_0","")
			break

		default:			//this means that SaveImage > 0, and ParmChange = 2, so save anyway
			titleStr = "Save Anyway"
			if (!HaveShow)
				ShowList = "NoSaveImage"+TabStr
			endif
			break
			
	endswitch
	UpdateAllTitleBoxes("SaveStatus"+TabStr,TitleStr="\F'Arial'\Z12\JR"+colorStr+titleStr)
	Variable Index = WhichListItem(ShowList,ControlList,";",0,0)
	if (Index >= 0)
		TitleList = StringFromList(Index,TitleList,";")
		HideList = RemoveListItem(Index,ControlList,";")
		HideList = ReplaceString(";",HideList,",")
		ButtonSwapper(ShowList,HideList,TitleList)
	endif
//	HideList = ListSubtract(ControlList,ShowList,";")
//	
//	
//	
//	
//	
//	
//	
//	String GraphList = "*"
//	DoWindow MasterPanel
//	if (V_Flag)
//		ControlInfo/W=MasterPanel MasterTab
//		if (V_Value != TabNum)
//			GraphList += "MasterPanel;"
//		endif
//	endif
//	SimpleShowControl(GraphList,ShowList,0)
//	SimpleShowControl(GraphList,HideList,1)

end //CheckSaveStatus


function SetScanBandwidth()		//sets the bandwidth on the input channels

	wave FVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave
	variable i
	String errorStr = ""
	ErrorStr += ir_Writemany(FVW)
//	for (i = 0;i < DimSize(FVW,0);i += 1)				//go through the wave
//
//					//set the bandwidth to whatever channel the dimension label says
//		errorStr += num2str(ir_WriteValue(ReplaceString("_",GetDimLabel(FVW,0,i)+"Filter.Freq","."),FVW[i][0]))+","
//	endfor
	
//	Struct ARImagingModeStruct ImagingModeParms
//	ARGetImagingMode(ImagingModeParms)
//	PV("FBFilterBW", GV(ImagingModeParms.FilterParm)) // Update FBFilterBW with the appropriate value

	ARReportError(errorStr)

end //SetScanBandwidth

function UpdateFilterWave()
	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main:Variables:Filter

	wave FVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave
	wave/T FVD = root:Packages:MFP3D:Main:Variables:FilterVariablesDescription
	wave DFV = DefaultFilterValues
	SetDimLabels(DFV,ReplaceString("_",GetDimLabels(DFV,0),"."),0)
	wave/T TempFilterParms
	string errorStr = ""
	errorStr += num2str(td_ReadMany("^**.Filter.Freq",TempFilterParms))+","
	
	
	variable i, stop, startSize, point, Index
	string checkStr, checkList = ""
	
	stop = DimSize(TempFilterParms,0)
	for (i = 0;i < stop;i += 1)
		//checkList += RemoveFromList("ARC.Filter.Freq.",TempFilterParms[i][1],".")+";"
		checkList += RemoveFromList("ARC.",TempFilterParms[i][1],".")+";"
	endfor
	
	
	Variable Low = FVW[0][%Low]
	Variable High = FVW[0][%High]
	Variable MinUnits = 1e3
	Variable StepSize = 1e3
	String Format = FVD[0][%Format]
	string units = FVD[0][%Units]
	String TitleStr = "Feedback Filter"		//this is for when it shows up on the main tab
	
	for (i = 0;i < DimSize(FVW,0);i += 1)
		checkStr = GetDimLabel(FVW,0,i)
		Index = WhichListItem(checkStr,checkList,";",0,0)
		if (Index < 0)
			DeletePoints i, 1, FVW, FVD
			i -= 1
		else
			CheckList = RemoveListItem(Index,CheckList,";")
		endif
	endfor
	
	startSize = DimSize(FVW,0)
	Stop = ItemsInList(CheckList,";")
	for (i = 0;i < stop;i += 1)
		checkStr = StringFroMList(i,CheckList,";")
		if (FindDimLabel(FVW,0,checkStr) < 0)
			point = DimSize(FVW,0)
			InsertPoints point, 1, FVW, FVD
			SetDimLabel 0, point, $checkStr, FVW, FVD
			if (DimSize(FVW,1) == 0)
				Redimension/N=(-1,6) FVW
				SetDimLabels(FVW,"value;units;low;high;minUnits;stepSize;",1)
				Redimension/N=(-1,5) FVD
				SetDimLabels(FVD,"description;format;units;title;panels;",1)
			endif
			Index = FindDimLabel(DFV,0,ReplaceString("Filter.Freq",CheckStr,""))
			if (Index >= 0)
				FVW[point][%value] = DFV[Index]
			else
				FVW[point][%value] = 1000
			endif
			FVW[point][%units] = UpdateUnits("",FVW[i][%Value])
			FVW[point][%low] = Low
			FVW[point][%high] = High
			FVW[point][%minUnits] = MinUnits
			FVW[point][%stepSize] = StepSize
			FVD[point][%format] = Format
			FVD[point][%units] = Units
			FVD[point][%Title] = TitleStr
		endif
	
	endfor

	ARReportError(errorStr)

	SetDataFolder SavedDataFolder
end //UpdateFilterWave


function MakeFilterPanel()		//Make the filter panel. This is a good generic panel generator


	String GraphStr = "FilterPanel"

	DoWindow/F $GraphStr		//bring the panel forward
	if (V_flag)					//look to see of the panel already exists
		return 0
	endif
	NewPanel/K=1/N=$GraphStr as "Filter Panel"		//make a panel
	wave FVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave
	
	variable i
	variable FirstSetVar = 80
	variable SetVarWidth = 160
	variable TextWidth = 100
	variable CurrentTop = 20
	variable scrRes = 72/ScreenResolution
	string filterStr, RowLabel
	Variable FontSize = 12
	Variable Enab = 0
	String ParmName, TitleStr, ControlName
	
	for (i = 0;i < DimSize(FVW,0);i += 1)		//go through the whole wave
		ParmName = GetDimLabel(FVW,0,i)
		filterStr = ReplaceString(".",ParmName,"_")			//grab the current variable from the dimension label
		TitleStr = ReplaceString("Filter Freq",ReplaceString(".",ParmName," "),"")
		ControlName = FilterStr
		
		MakeSetVar(GraphStr,ControlName,ParmName,titleStr,"FilterSetVarFunc","",FirstSetVar,CurrentTop,NaN,TextWidth,0,fontSize,Enab)
		
//		SetVariable $filterStr+"SetVar",win=$GraphStr,pos={FirstSetVar,CurrentTop},size={SetVarWidth,17},bodywidth=TextWidth
//		SetVariable $filterStr+"SetVar",win=$GraphStr,font="Arial",fsize=12,limits={-Inf,Inf,0},title=
//		SetVariable $filterStr+"SetVar",win=$GraphStr,value= root:Packages:MFP3D:Main:Variables:FilterVariablesWave[%$RowLabel][0],format="%.3W1PHz",proc=FilterSetVarFunc

//		SetVariable $filterStr+"ClickVar",win=$GraphStr,pos={FirstSetVar+SetVarWidth+3,CurrentTop},size={18,20}
//		SetVariable $filterStr+"ClickVar",win=$GraphStr,font="Arial",fsize=12,limits={-Inf,Inf,1000},title=" "
//		SetVariable $filterStr+"ClickVar",win=$GraphStr,value= root:Packages:MFP3D:Main:Variables:FilterVariablesWave[%$RowLabel][0],proc=FilterSetVarFunc
		CurrentTop += 25
	endfor
	
	ValDisplay SampleRateValDisplay,win=$GraphStr,value=GV("ScanRate")*GV("ScanPoints")*2.5,title="Sample Rate",format="%.2W1PHz",pos={130,CurrentTop},bodyWidth=TextWidth,font="Arial",fsize=12
	CurrentTop += 25
	
	MoveWindow/W=$GraphStr 200,20,200+220*scrRes,50+CurrentTop*scrRes		//make the panel the right size
	
end //MakeFilterPanel

Function FilterSetVarFunc(ctrlName,varNum,varStr,varName)	//takes care of all of the SetVars on the Filter panel
	String ctrlName
	Variable varNum
	String varStr			//this contains any letters as clues for range changes
	String varName

	string NameVar = UnitsCalcFunc(ctrlName,varNum,varStr,varName)		//this calculates any typed in units and also returns the new varNum

	varNum = limit(varNum,GVL(NameVar),GVH(NameVar))		//make sure that the number is in its limits
	String errorStr = ""
//	String LogString = ""
		
	Variable DoingThermal = GV("DoThermal")
	
	if (!DoingThermal)
//		Struct ARImagingModeStruct ImagingModeParms
//		ARGetImagingMode(ImagingModeParms)
//	
//		String FBFilterParm = imagingModeParms.FilterParm
//
//		if (StringMatch(NameVar,FBFilterParm) || StringMatch(NameVar, "FBFilterBW"))
//			PV("FBFilterBW", VarNum)
//			NameVar = FBFilterParm
//			LogString = "FBFilterParm ("+NameVar+")"
//		endif
		
		//ErrorStr += num2str(ir_WriteValue(ReplaceString("_",NameVar,".")+"Filter.Freq",varNum))+","
		ErrorStr += num2str(ir_WriteValue(NameVar,varNum))+","
		UpdateLog(NameVar,VarNum)

	endif
	
	
	PV(NameVar,varNum)			//put the value where it belongs
	UpdateUnits(NameVar,varNum)
	If (GV("AutoFMParms") && stringmatch(NameVar,"*Lockin*0*"))
		CalcFMGains(1)	// If we are using automatically calculated FM loop parms then recalculate them for the user when they change the Lockin.0 Filter
	endif

	ARReportError(errorStr)
	
End //FilterSetVarFunc

function AdjustScanWaves()			//adjust the size of the scan waves

	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:Packages:MFP3D:Main
	
	variable napMode = GV("NapMode")
	
	wave MarkerWave
	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
	variable scanPoints = GV("ScanPoints")		//grab all the happy variables
	variable scanLines = GV("ScanLines")
	variable scanSize = GV("ScanSize")
	variable scanRatio = GV("SlowRatio")/GV("FastRatio")
	variable DataTypeSum = GV("DataTypeSum")
	variable NaNVar = NaN
	variable displayPoints = scanPoints
	variable displayLines = scanLines
	variable checkLitho = 1
	variable fastScanSize, slowScanSize
	Wave OMVW = root:Packages:MFP3D:Main:Variables:OldMVW
	if (scanRatio > 1)
		fastScanSize = scanSize/scanRatio
		slowScanSize = scanSize
	else
		fastScanSize = scanSize
		slowScanSize = scanSize*scanRatio
	endif
	UpdateSpotZero()
	
	if (scanLines < 512)
		PV("SaveImageLines",scanLines/2)
	else
		PV("SaveImageLines",256)		
	endif
	//PV("MarkerRatio",GV("FastRatio"))
	if (scanLines > 512)
		for (;displayPoints > 800;)				//go through until the points are less than 800
			displayPoints /= 2
		endfor
		for (;displayLines > 800;)					//go through until the lines are less than 800
			displayLines /= 2
		endfor
	endif
	
	variable i, redoGraphs = 0//, redoImage
	string dataStr, userDataStr

	wave OffsetFrequencyWave
	if (napMode)
		Redimension/N=(scanLines*2) OffsetFrequencyWave
	else
		Redimension/N=(scanLines) OffsetFrequencyWave
	endif
	variable frequency = GV("DriveFrequency")
	FastOp OffsetFrequencyWave = (frequency)

	wave NapVW = root:Packages:MFP3D:Main:Variables:NapVariablesWave
	variable bit = 2^FindDimLabel(NapVW,0,"NapDriveFrequency")
	if ((bit & NapVW[%NapParms]) && (napMode))
		frequency = NapVW[%NapDriveFrequency]
		OffsetFrequencyWave[1,;2] = frequency
	endif
	
	SetScale/P x 0,fastScanSize/16,"m", MarkerWave			//make the marker wave go 1/16 across the graph
	SetScale d 0,0,"m", MarkerWave
	Make/O/N=(scanPoints,(scanLines/displayLines)) Slice
	Make/O/N=(scanPoints,displayLines) M_InterpolatedImage
	Make/O/N=(displayPoints) FitLine, PWave, P2Wave, MaskLine, PreMaskLine
	Make/O/N=(scanPoints) SaveFitLine, SavePWave, SaveP2Wave, SaveMaskLine, SavePreMaskLine
	Make/O/N=(scanPoints) ScopePWave
	Make/O/N=(2,scanLines) FlattenParms
	Make/O/N=2/D FitParm
	PWave = p
	FastOp P2Wave = PWave*PWave
	ScopePWave = p
	SavePWave = p
	SaveP2Wave = SavePWave^2
//	SetScale/P x 0,1,"", MaskLine, PreMaskLine, SaveMaskLine, SavePreMaskLine
	SetScale/I x 0,slowScanSize,"m", SaveFitLine, MaskLine, PreMaskLine, SaveMaskLine, SavePreMaskLine

	variable Sum0,Sum1,chanTotal, napChanTotal, OldRatio
	CalculateDataTypeSum(Sum0,Sum1,chanTotal,0)							//this returns data type sums for both trace and retrace
	if (napMode)
		CalculateDataTypeSum(Sum0,Sum1,napChanTotal,1)							//this returns data type sums for both trace and retrace for nap
		chanTotal += napChanTotal	
	endif
	wave/Z UniqueWave = $InitOrDefaultWave("UniqueWave",0)
	
	
	Wave LayerWave = $InitOrDefaultWave("LayerWave",0)
	Wave LineWave = $InitOrDefaultWave("LineWave",0)
	Wave PrevLine = $InitOrDefaultWave("PrevLine",0)
	Wave PrevHist = $InitOrDefaultWave("PrevHist",0)
	Wave Corr = $InitOrDefaultWave("Corr",0)
	Wave LineMask = $InitOrDefaultWave("LineMask",0)
	Wave Mask = $InitOrDefaultWave("Mask",0)
	Wave W_coef = $InitOrDefaultWave("W_coef",0)
	
	Redimension/B LineMask,Mask
	Redimension/N=(2)/D W_Coef
	
	if (!(DimSize(UniqueWave,0) == scanPoints) || !(DimSize(UniqueWave,1) == scanLines) || !(DimSize(UniqueWave,2) == chanTotal))
		PV("LastImage",0)
	endif
//	Redimension/N=(scanPoints,scanLines,chanTotal) TempWave				//make the wave that we will save

//variable start = StopMSTimer(-2)

//	if (((2^(WhichListItem("Height",MDTL)-1) & DataTypeSum) == 0) && ((2^(WhichListItem("ZSensor",MDTL)-1) & DataTypeSum) == 0))		//if neither height or ZSensor are needed
//		DataTypeSum += 2^(WhichListItem("Height",MDTL)-1)					//make sure height gets done anyway
//	endif															//as it is counted on in other functions to be the right size
	
	for (i = 1;i < ItemsInList(MDTL);i += 1)				//go through all the datatypes
		dataStr = StringFromList(i,MDTL)
		userDataStr = FindUserName(dataStr,"Name")

		wave InputWave = $userDataStr+"Wave"						//the input wave
		wave TraceWave = $userDataStr+"Image0"					//the image waves
		wave RetraceWave = $userDataStr+"Image1"
		wave TraceWaveNap = $userDataStr+"Image2"					//the image waves
		wave RetraceWaveNap = $userDataStr+"Image3"
		wave TraceScope = $userDataStr+"Scope0"					//the scope waves
		wave RetraceScope = $userDataStr+"Scope1"
		wave TraceScopeNap = $userDataStr+"Scope2"					//the scope waves
		wave RetraceScopeNap = $userDataStr+"Scope3"
	
//		if ((DimSize(TraceWave,0) > 2) && checkLitho)
//			CheckLithoWave(fastScanSize-OMVW[%FastScanSize][0],slowScanSize-OMVW[%SlowScanSize][0])
//			checkLitho = 0
//		endif
	
		if ((2^(i-1)) & DataTypeSum)							//see if this data type is needed
			if (DimSize(TraceWave,0) <= 4)				//if the size is one this wave was not being used
				redoGraphs += 1
				Redimension/N=(displayPoints,displayLines,1) TraceWave, RetraceWave
				if (napMode)
					Redimension/N=(displayPoints,displayLines,1) TraceWaveNap, RetraceWaveNap
				endif
				FastOp TraceWave = 0								//set it to zero
				FastOp RetraceWave = 0
				FastOp TraceWaveNap = 0								//set it to zero
				FastOp ReTraceWaveNap = 0
			elseif ((displayPoints != DimSize(TraceWave,0)) || (displayLines != DimSize(TraceWave,1)))		//if this is not the right size
				redoGraphs += 1									//then we have to redo graphs
				ARInterpImage(TraceWave,displayPoints,displayLines)
				ARInterpImage(RetraceWave,displayPoints,displayLines)

			endif
			variable inputScanLines = limit(scanLines*(1+(GV("NapMode") > 0)),32,512)
			Redimension/N=(scanPoints*2.5,inputScanLines) InputWave		//make the input wave the right size

			if (napMode)
				if ((displayPoints != DimSize(TraceWaveNap,0)) || (displayLines != DimSize(TraceWaveNap,1)))		//if this is not the right size
					redoGraphs += 1									//then we have to redo graphs
					ARInterpImage(TraceWaveNap,displayPoints,displayLines)
					ARInterpImage(RetraceWaveNap,displayPoints,displayLines)
				endif
			endif

			Redimension/N=(scanPoints) TraceScope, RetraceScope, TraceScopeNap, RetraceScopeNap			//resize the scope waves
			
			OldRatio = (DimSize(TraceWave,1)-1)*DimDelta(TraceWave,1)
			OldRatio /= (DimSize(TraceWave,0)-1)*DimDelta(TraceWave,0)
			OldRatio = Log2Round(OldRatio)
			//This check is incorrect if the number of points has changed
			//but since that already set RedoGraphs
			//We are just being redundant.
			if (OldRatio != ScanRatio)
				RedoGraphs += 1
			endif
			SetScale/I x 0,fastScanSize, "m", TraceWave, RetraceWave, TraceScope, RetraceScope		//set the scaling
			SetScale/I y 0,slowScanSize, "m", TraceWave, RetraceWave
			
			if (napMode)
				SetScale/I x 0,fastScanSize, "m", TraceWaveNap, ReTraceWaveNap, TraceScopeNap, RetraceScopeNap		//set the scaling
				SetScale/I y 0,slowScanSize, "m", TraceWaveNap, RetraceWaveNap
			else
				if (DimSize(TraceWaveNap,0) > 2)
					redoGraphs += 1
				endif
				Redimension/N=(2,2) TraceWaveNap, RetraceWaveNap
				Redimension/N=(2) TraceScopeNap, RetraceScopeNap
			endif
			
			FastOp InputWave = (NaNVar)							//use FastOp to set the input wave equal to NaN
		else															//if the wave set is not used set the dimensions to one
			Redimension/N=(2,2) InputWave
			Redimension/N=(2,2) TraceWave, RetraceWave, TraceWaveNap, RetraceWaveNap
			Redimension/N=(2) TraceScope, RetraceScope, TraceScopeNap, RetraceScopeNap
		endif
			
	endfor

//	wave HeightImage0				//SaveImageFunc uses this wave, so it always has to have the right size and scaling
//	if (DimSize(HeightImage0,0) < 16)
//		Redimension/N=(displayPoints,displayLines) HeightImage0
//		if (scanRatio > 1)
//			SetScale/I x 0,scanSize/scanRatio, "m", HeightImage0
//			SetScale/I y 0,scanSize, "m", HeightImage0
//		else
//			SetScale/I x 0,scanSize, "m", HeightImage0
//			SetScale/I y 0,scanSize*ScanRatio, "m", HeightImage0
//		endif
//	endif
	
	if (GV("IsScanBias"))
		chanTotal += 1
	endif
	
	Redimension/N=(scanPoints,scanLines,chanTotal) UniqueWave				//make the wave that we will save
	Redimension/N=(scanPoints,scanLines) Layerwave//, Mask
	Redimension/N=(scanPoints) LineWave, LineMask, PrevLine, PrevHist, Corr
	
	execute/Z/Q/P "UpdateRTSection()"			//update the realimage cursors...
	execute/Z/Q/P "ForceRTImageAxes()"			//make sure the Real time images have decent axes limits.
	if (GV("DisplayLVDTTraces"))									//if we are doing LVDT stuff then make them too
		Make/O/N=(scanPoints*2.5*2) XLVDT, YLVDT	//These need to be twice as big for double buffering
		Make/O/N=(scanPoints*2.5) DisplayXDrive, DisplayYDrive, DisplayXLVDT, DisplayYLVDT, XRes, YRes, StartXDrive, StartYDrive	//Zinput, ZOutput, NapHeight	//make things the right size
		Make/O/N=(scanPoints*2.5) SmallWave				//these are for the fake scanengine in CheckXPFunc
		Make/O/N=(scanPoints*2.5)/C ComplexWave

		CopyScales FastWave SmallWave, ComplexWave
//		Redimension/N=81 SmallWave, ComplexWave
		Make/O/N=(scanPoints*2.5) BigWave
		NVAR LVDTcount
		if (GV("ScanDown"))									//looks like this has changed
			LVDTcount = 0
		else
			LVDTcount = 0
		endif
	endif

	if (redoGraphs)									//if any of the channels have changed then redo all of them
		SwapMacroMode(1)
		variable dataNum
		for (i = 1;i <= 5;i += 1)					//go through them all
			dataNum = GV("Channel"+num2str(i)+"DataType")
			if (dataNum)
				SetDataTypePopupFunc("Channel"+num2str(i)+"DataTypePopup_"+num2str(i),dataNum,StringFromList(dataNum,MDTL))	//this redoes the graphs
			endif
		endfor
		SwapMacroMode(-1)
	endif

//print (StopMSTimer(-2)-start)/1e6

	SetDataFolder SavedDataFolder
end //AdjustScanWaves

Function XYGainsFunc(ctrlName,varNum,varStr,varName)		//Sets the XY gains
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	variable result = 10^varNum		//the number entered is the log of the actual value
	String errorStr = ""
	string whichStr = ctrlName[0]

	String LoopName = PIDSloopSearch("*","output."+WhichStr)
	if (!Strlen(LoopName))
		return(0)
	endif

	Variable Sens = GV(whichStr+"LVDTSens")

	
	strswitch (ctrlName[1])
		case "I":											//the first lettor is either I, P, or S, for Integral, Proportional, or Secret
			errorStr += num2str(ir_WriteValue("$output"+whichStr+"Loop.Igain",result*Sens))+","
			break
			
		case "P":
			errorStr += num2str(ir_WriteValue("$output"+whichStr+"Loop.Pgain",result*Sens))+","
			break
			
		case "S":
			errorStr += num2str(ir_WriteValue("$output"+whichStr+"Loop.Sgain",0))+","			//setting this to 0 first clears it of any current baggage
			errorStr += num2str(ir_WriteValue("$output"+whichStr+"Loop.Sgain",result*Sens))+","
			break
			
		case "D":
			errorStr += num2str(ir_WriteValue("$output"+whichStr+"Loop.Dgain",result*Sens))+","
			break
			
	endswitch
	
	ARReportError(errorStr)

End //XYGainsFunc


function MakeXYGainsPanel()										//make the XY gains panel
	
	InitXYGains()												//this makes the global variables the panel uses
	String GraphStr = "XYGainsPanel"
	DoWindow/F $GraphStr
	if (V_flag)
		return 0
	endif
	string SavedDataFolder = GetDataFolder(1)
	SetDataFolder root:packages:MFP3D:Main:Variables
	
	wave MasterVariablesWave = root:packages:MFP3D:Main:Variables:MasterVariablesWave
	
	NewPanel/K=1/N=$GraphStr /W=(475,250,650,450) as "XY gains"
	SetDrawLayer/W=$GraphStr UserBack
	DrawText/W=$GraphStr 10,27,"These values are now logs"
	SetVariable XIgainSetVar,win=$GraphStr,pos={11,39},size={149,14},proc=XYGainsFunc,title="X Integral"
	SetVariable XIgainSetVar,win=$GraphStr,font="Arial"
	SetVariable XIgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%XIgain][%Value],bodyWidth= 100
	SetVariable XPgainSetVar,win=$GraphStr,pos={24,64},size={136,14},proc=XYGainsFunc,title="X Prop"
	SetVariable XPgainSetVar,win=$GraphStr,font="Arial"
	SetVariable XPgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%XPgain][%Value],bodyWidth= 100
	SetVariable XSgainSetVar,win=$GraphStr,pos={16,89},size={144,14},proc=XYGainsFunc,title="X Secret"
	SetVariable XSgainSetVar,win=$GraphStr,font="Arial"
	SetVariable XSgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%XSgain][%Value],bodyWidth= 100
	SetVariable YIgainSetVar,win=$GraphStr,pos={11,114},size={149,14},proc=XYGainsFunc,title="Y Integral"
	SetVariable YIgainSetVar,win=$GraphStr,font="Arial"
	SetVariable YIgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%YIgain][%Value],bodyWidth= 100
	SetVariable YPgainSetVar,win=$GraphStr,pos={24,139},size={136,14},proc=XYGainsFunc,title="Y Prop"
	SetVariable YPgainSetVar,win=$GraphStr,font="Arial"
	SetVariable YPgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%YPgain][%Value],bodyWidth= 100
	SetVariable YSgainSetVar,win=$GraphStr,pos={16,164},size={144,14},proc=XYGainsFunc,title="Y Secret"
	SetVariable YSgainSetVar,win=$GraphStr,font="Arial"
	SetVariable YSgainSetVar,win=$GraphStr,limits={-Inf,Inf,0.15},value= MasterVariablesWave[%YSgain][%Value],bodyWidth= 100
	
//	UpdateCheckBox(GraphStr,"DoMungeCheck","Use Munge",16,189,"ARCheckFunc",GV("DoMunge"),0,0)
	
//	SetVariable XMungeAlphaSetVar,pos={16,214},size={144,14},proc=XYGainsFunc,title="X Alpha"
//	SetVariable XMungeAlphaSetVar,font="Arial"
//	SetVariable XMungeAlphaSetVar,limits={-Inf,Inf,0.05},value= MasterVariablesWave[%XMungeAlpha],bodyWidth= 100
//	SetVariable YMungeAlphaSetVar,pos={16,239},size={144,14},proc=XYGainsFunc,title="Y Alpha"
//	SetVariable YMungeAlphaSetVar,font="Arial"
//	SetVariable YMungeAlphaSetVar,limits={-Inf,Inf,0.05},value= MasterVariablesWave[%YMungeAlpha],bodyWidth= 100

	SetDataFolder SavedDataFolder
End //XYGainsPanel

function InitXYGains()			//converts the gain numbers to log for display purposes

	string SavedDataFolder = GetDataFolder(1)
//	NewDataFolder/O/S root:Packages:MFP3D:Main:Variables:XYGains
//
//	variable/G LogXIntegral, LogXProportional, LogXSecret, LogYIntegral, LogYProportional, LogYSecret	//make all of the globals
//	LogXIntegral = log(GV("XIgain"))										//set them to the log of the number that actually counts
//	LogXProportional = log(GV("XPgain"))
//	LogXSecret = log(GV("XSgain"))
//	LogYIntegral = log(GV("YIgain"))
//	LogYProportional = log(GV("YPgain"))
//	LogYSecret = log(GV("YSgain"))
	SetDataFolder root:Packages:MFP3D:Main:
//	if (GV("ScanMode") == 0)
//		Make/O/N=640 SmallWave
//		Make/O/N=640/C ComplexWave
//	else
//		Make/O/N=21 SmallWave
//		Make/O/N=21/C ComplexWave
//	endif
	variable/G CheckXY = 1
	if (WaveExists(DisplayXDrive))
		Execute "XLVDTGraph()"				//make the XY graphs
		Execute "YLVDTGraph()"
	endif
	
	SetDataFolder SavedDataFolder
end //InitXYGains

function CheckSaveFunc()

	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	wave RVW = root:Packages:MFP3D:Main:Variables:RealVariablesWave
	variable lineCount = mod(td_ReadValue("LinenumOutWave0"),RVW[%ScanLines][0]*(1+RVW[%NapMode][0]))
//NVAR TestCount = root:Packages:MFP3D:Main:TestCount
//TestCount = lineCount
	if ((RVW[%ScanLines][0] < 1024) && (RVW[%NapMode][0] == 0))
		if ((MVW[%SaveImageCount][0] == 0) && (lineCount > (MVW[%SaveImageLines][0]+15+round(MVW[%ScanRate][0]))))
			SaveImageFunc(0)
//			td_WriteString("OutWave0StatusCallback","")
		endif
	elseif ((RVW[%ScanLines][0] < 512) && RVW[%NapMode][0])
		if (lineCount > ((MVW[%SaveImageCount][0]+1)*limit(MVW[%saveImageLines][0]*2,0,256)+15+round(MVW[%ScanRate][0])))

			SaveImageFunc(MVW[%SaveImageCount][0])
		endif
	elseif (RVW[%NapMode][0])
		if (lineCount > ((MVW[%SaveImageCount][0]+1)*256+15+round(MVW[%ScanRate][0])))

			SaveImageFunc(MVW[%SaveImageCount][0])
		endif
	else
		if (lineCount > ((MVW[%SaveImageCount][0]+1)*256+15+round(MVW[%ScanRate][0])))
			SaveImageFunc(MVW[%SaveImageCount][0])
//			if (RVW[%ScanLines][0] < (MVW[%SaveImageCount][0]+1)*256+1)
//				td_WriteString("OutWave0StatusCallback","")
//			endif
		endif
	endif

end //CheckSaveFunc

function CheckXYFunc()		//this calculates the waves that display how well the XY is tracking
	
	CheckSaveFunc()
	
	DoWindow YLVDTGraph
	if (!V_Flag)
		DoWindow XLVDTGraph
	endif
	if (!V_Flag)
		return(0)
	endif
	
	Variable Tic = StopMsTimer(-2)
	Variable LVDTCount
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	wave FastWave = root:Packages:MFP3D:Main:FastWave
	wave SlowWave = root:Packages:MFP3D:Main:SlowWave
	wave XLVDT = root:Packages:MFP3D:Main:XLVDT
	wave YLVDT = root:Packages:MFP3D:Main:YLVDT
	wave DisplayXLVDT = root:Packages:MFP3D:Main:DisplayXLVDT
	wave DisplayYLVDT = root:Packages:MFP3D:Main:DisplayYLVDT
	wave DisplayXDrive = root:Packages:MFP3D:Main:DisplayXDrive
	wave DisplayYDrive = root:Packages:MFP3D:Main:DisplayYDrive
	wave XRes = root:Packages:MFP3D:Main:XRes
	wave YRes = root:Packages:MFP3D:Main:YRes
	wave/C ComplexWave = root:Packages:MFP3D:Main:ComplexWave
	
	LVDTCount = td_ReadValue("LinenumOutWave0")-MVW[%StartLineCount][0]
	variable scanPoints = DimSize(FastWave,0)
	variable scanLines = DimSize(SlowWave,0)/160
	variable secondHalf = mod(MVW[%StartLineCount][0]/scanLines,2)
	FakeScanEngineFast(FastWave,SlowWave,ComplexWave,1/(ScanPoints/80),((scanLines*secondHalf)+LVDTCount-1)*80)
	
	Variable Offset = scanPoints*!mod(LVDTCount,2)
	DisplayXLVDT = XLVDT[p+Offset]
	DisplayXDrive = Imag(ComplexWave)
	FastOp XRes = DisplayXLVDT-DisplayXDrive			//calculate the residuals
	
	DisplayYLVDT = YLVDT[p+Offset]
	DisplayYDrive = Real(ComplexWave)	
	FastOp YRes = DisplayYLVDT-DisplayYDrive
//print LVDTCount	
	//print (stopMsTimer(-2)-Tic)*1e-6
end //CheckXYFunc


function CheckOpenXYFunc()		//this calculates the waves that display how well the XY is tracking
	
	CheckSaveFunc()
	
	Variable Tic = StopMsTimer(-2)
	
	DoWindow YLVDTGraph
	if (!V_Flag)
		DoWindow XLVDTGraph
	endif
	if (!V_Flag)
		return(0)
	endif
	
	
	Variable LVDTCount
	//NVAR LVDTCount = root:Packages:MFP3D:Main:LVDTCount
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	wave FastWave = root:Packages:MFP3D:Main:FastWave
	wave SlowWave = root:Packages:MFP3D:Main:SlowWave
	wave XLVDT = root:Packages:MFP3D:Main:XLVDT
	wave YLVDT = root:Packages:MFP3D:Main:YLVDT
	wave DisplayXLVDT = root:Packages:MFP3D:Main:DisplayXLVDT
	wave DisplayYLVDT = root:Packages:MFP3D:Main:DisplayYLVDT
	wave DisplayXDrive = root:Packages:MFP3D:Main:DisplayXDrive
	wave DisplayYDrive = root:Packages:MFP3D:Main:DisplayYDrive
	wave XRes = root:Packages:MFP3D:Main:XRes
	wave YRes = root:Packages:MFP3D:Main:YRes
	wave/C ComplexWave = root:Packages:MFP3D:Main:ComplexWave

	variable scanPoints = DimSize(FastWave,0)
	LVDTCount = td_ReadValue("LinenumOutWave0")-MVW[%StartLineCount][0]
	FakeScanEngineFast(FastWave,SlowWave,ComplexWave,1/ScanPoints,LVDTCount)
	ComplexWave *= -1
	Variable Scale = 8*MVW[%XPiezoSens][%Value]/abs(MVW[%XLVDTSens][%Value])
	

	Variable Offset = scanPoints*!mod(LVDTCount,2)
	DisplayXLVDT = XLVDT[p+Offset]
	DisplayXDrive = Imag(ComplexWave)
	FastOp DisplayXDrive = (Scale)*DisplayXDrive
	
	WaveStats/Q/M=1 DisplayXDrive
	Variable DataOffset = V_Avg
	WaveStats/Q/M=1 DisplayXLVDT
	DataOffset -= V_Avg
	FastOp DisplayXDrive = (-DataOffset)+DisplayXDrive
	
	FastOp XRes = DisplayXLVDT-DisplayXDrive			//calculate the residuals
	
	
	
	Scale = 8*MVW[%YPiezoSens][%Value]/abs(MVW[%YLVDTSens][%Value])
	DisplayYLVDT = YLVDT[p+Offset]
	DisplayYDrive = Real(ComplexWave)
	FastOp DisplayYDrive = (Scale)*DisplayYDrive
	
	
	WaveStats/Q/M=1 DisplayYDrive
	DataOffset = V_Avg
	WaveStats/Q/M=1 DisplayYLVDT
	DataOffset -= V_Avg
	FastOp DisplayYDrive = (-DataOffset)+DisplayYDrive
	
	FastOp YRes = DisplayYLVDT-DisplayYDrive			//calculate the residuals


	//print (stopMsTimer(-2)-Tic)*1e-6
end //CheckOpenXYFunc

//function ScaleAllAtOnce(Parm,Output,XWave)
//	wave Parm, Output, XWave
//	
//	Output = XWave*Parm[1]+Parm[0]
//	
//	return 0
//	
//end //ScaleAllAtOnce

function/C FakeScanEngine(fastInput,slowInput)
	variable fastInput, slowInput
	
	wave/T SET = root:Packages:MFP3D:Main:ScanEngineText
	variable YOut, XOut
	
	YOut = 20*(-fastInput*str2num(SET[%sin])*str2num(SET[%YGain])+slowInput*str2num(SET[%cos])*str2num(SET[%YGain])+str2num(SET[%YOffset]))
	XOut = 20*(fastInput*str2num(SET[%cos])*str2num(SET[%XGain])+slowInput*str2num(SET[%sin])*str2num(SET[%XGain])+str2num(SET[%XOffset]))

	return cmplx(Yout,Xout)

end //FakeScanEngine


function FakeScanEngineFast(fastInput,slowInput,CmplxWave,IndexScale,IndexOffset)
	Wave fastInput, slowInput
	Wave/C CmplxWave
	Variable IndexScale, IndexOffset
	
	wave/T SET = root:Packages:MFP3D:Main:ScanEngineText
	
	Variable sineValue = str2num(SET[%sin])
	Variable YGain = str2num(SET[%YGain])
	Variable CosValue = str2num(SET[%cos])
	Variable YOffset = str2num(SET[%YOffset])
	Variable XGain = str2num(SET[%XGain])
	Variable XOffset = str2num(SET[%XOffset])
	
	
	Variable XSine = SineValue*XGain
	Variable YSine = SineValue*YGain
	Variable XCos = CosValue*XGain
	Variable YCos = CosValue*YGain
	
	
	CmplxWave[] = cmplx(20*(-fastInput(X)*YSine+slowInput[P*IndexScale+IndexOffset]*YCos+YOffset),20*(fastInput(X)*XCos+slowInput[P*IndexScale+IndexOffset]*XSine+XOffset))
	
	

end //FakeScanEngineFast

//function oldCheckXYFunc()		//this calculates the waves that display how well the XY is tracking
//	
//	NVAR LVDTCount = root:Packages:MFP3D:Main:LVDTCount
//	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
//	wave XWave = root:Packages:MFP3D:Main:XWave
//	wave YWave = root:Packages:MFP3D:Main:YWave
//	wave XLVDT = root:Packages:MFP3D:Main:XLVDT
//	wave YLVDT = root:Packages:MFP3D:Main:YLVDT
//	wave DisplayXDrive = root:Packages:MFP3D:Main:DisplayXDrive
//	wave DisplayYDrive = root:Packages:MFP3D:Main:DisplayYDrive
//	wave XRes = root:Packages:MFP3D:Main:XRes
//	wave YRes = root:Packages:MFP3D:Main:YRes
//	wave SmallWave = root:Packages:MFP3D:Main:SmallWave
//	wave BigWave = root:Packages:MFP3D:Main:BigWave
//
//	if ((abs(LVDTcount) < 1) || (abs(LVDTcount) > MVW[%ScanLines][%value]-2))		//don't do the very start or end
//		LVDTcount += 1
//		return 1
//	endif
//	
//	SmallWave = XWave[(abs(LVDTcount))*80+p]*MVW[%ScanSize][%value]/5e-9+MVW[%XOffset][%value]/MVW[%XLVDTSens][%value]		//grab one scan line of the XWave and then interpolate so the points
//	Execute "Interpolate/T=2/N=("+num2str(MVW[%ScanPoints][%value]*2.5+1)+")/E=1/Y=root:Packages:MFP3D:Main:BigWave root:Packages:MFP3D:Main:SmallWave"	//match the input waves
//	DisplayXDrive = BigWave//[MVW[%ScanPoints][%value]*2.5+p]	//set the DisplayXDrive equal to the wave that was just interpolated
//	XRes = XLVDT-DisplayXDrive			//calculate the residuals
//	
//	SmallWave = YWave[(abs(LVDTcount))*80+p]*MVW[%ScanSize][%value]/5e-9+MVW[%YOffset][%value]/MVW[%YLVDTSens][%value]
//	Execute "Interpolate/T=2/N=("+num2str(MVW[%ScanPoints][%value]*2.5+1)+")/E=1/Y=root:Packages:MFP3D:Main:BigWave root:Packages:MFP3D:Main:SmallWave"
//	DisplayYDrive = BigWave//[MVW[%ScanPoints][%value]*2.5+p]
//	YRes = YLVDT-DisplayYDrive
//	LVDTcount += 1				//increment the count
//
//end //oldCheckXYFunc

Window XLVDTGraph() : Graph		//graph the X LVDT action
	PauseUpdate; Silent 1		// building window...
	String fldrSav= GetDataFolder(1)
	SetDataFolder root:packages:MFP3D:Main:
	Display/K=1/W=(277.8,233.6,673.2,441.2) DisplayXDrive as "XLVDT Graph"
	AppendToGraph/L=resLeft XRes
	AppendToGraph DisplayXLVDT
	SetDataFolder fldrSav
	ModifyGraph rgb(DisplayXDrive)=(0,0,39168)
	ModifyGraph zero(resLeft)=1
	ModifyGraph lblPos(left)=40
	ModifyGraph freePos(resLeft)=0
	ModifyGraph axisEnab(left)={0,0.75}
	ModifyGraph axisEnab(resLeft)={0.8,1}
EndMacro

Window YLVDTGraph() : Graph
	PauseUpdate; Silent 1		// building window...
	String fldrSav= GetDataFolder(1)
	SetDataFolder root:packages:MFP3D:Main:
	Display/K=1/W=(277.8,233.6,673.2,441.2) DisplayYDrive as "YLVDT Graph"
	AppendToGraph/L=resLeft YRes
	AppendToGraph DisplayYLVDT
	SetDataFolder fldrSav
	ModifyGraph rgb(DisplayYDrive)=(0,0,39168)
	ModifyGraph zero(resLeft)=1
	ModifyGraph lblPos(left)=40
	ModifyGraph freePos(resLeft)=0
	ModifyGraph axisEnab(left)={0,0.75}
	ModifyGraph axisEnab(resLeft)={0.8,1}
EndMacro


function UpdateRealGraph(ScanDown)		//this function is called 10 times a second to update the real time graph
	variable ScanDown
	
	Variable OrgScanDown = ScanDown		//take a copy
	//Nap mode is going to hijack it.
	String SavedDataFolder = GetDataFolder(1)
	
	wave MeterStatus = root:Packages:MFP3D:Meter:MeterStatus
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave		//grabbing variables directly from the waves is faster than GV
	wave RVW = root:Packages:MFP3D:Main:Variables:RealVariablesWave		//grabbing variables directly from the waves is faster than GV
	wave NVW = root:Packages:MFP3D:Main:Variables:NapVariablesWave		//grabbing variables directly from the waves is faster than GV
	wave OVW = root:Packages:MFP3D:Main:Variables:ARDoIVVariablesWave		//grabbing variables directly from the waves is faster than GV

	if (MeterStatus[%Run][0])								//update the meter if this is on
		UpdateMeter()
	endif
	String GraphList = WinList("Channel*Image*",";","WIN:4097")

//	MVW[%UpdateCounter][%value] += 1
//	if (mod(MVW[%UpdateCounter][%value],10))	//only update the graphs once a second, or 1 out of 10 times through this function
//		return 0
//	endif

	//kill the data browser, it is too slow.
	if (Strlen(GetBrowserSelection(-1)))
		ARSaveDBState()
	endif
	
	NVAR gLineCount = root:Packages:MFP3D:Main:LineCount		//LineCount is the line number on the display image
	Variable LineCount = gLineCount
	
	wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
	wave NCVW = root:Packages:MFP3D:Main:Variables:NapChannelVariablesWave
	Wave AVW = root:Packages:MFP3D:Main:Variables:ArgyleVariablesWave
	Wave/T CVD = root:Packages:MFP3D:Main:Variables:ChannelVariablesDescription
	Wave TVW = root:Packages:MFP3D:Main:Variables:ThermalVariablesDescription
	wave MarkerWave = root:Packages:MFP3D:Main:MarkerWave
	wave Slice = root:Packages:MFP3D:Main:Slice
	wave smallSlice = root:Packages:MFP3D:Main:M_InterpolatedImage
	wave FitLine = root:Packages:MFP3D:Main:FitLine
	Wave MaskLine = $InitOrDefaultWave("root:Packages:MFP3D:Main:MaskLine",DimSize(FitLine,0))
	Wave PreMaskLine = $InitOrDefaultWave("root:Packages:MFP3D:Main:PreMaskLine",DimSize(FitLine,0))
	wave PWave = root:Packages:MFP3D:Main:PWave
	Wave P2Wave = $InitOrDefaultWave("root:Packages:MFP3D:Main:P2Wave",0)
	if (DimSize(P2Wave,0) == 0)
		Redimension/N=(DimSize(PWave,0)) P2Wave
		FastOp P2Wave = PWave*PWave
	endif
	Wave FitParm = $InitOrDefaultWave("root:Packages:MFP3D:Main:FitParm",0)
	if (DimSize(FitParm,0) == 0)
		Redimension/N=(2)/D FitParm
	endif
	wave ScopePWave = root:Packages:MFP3D:Main:ScopePWave
	wave UniqueWave = $InitOrDefaultWave("root:Packages:MFP3D:Main:UniqueWave",0)
	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
	
wave TimeWave = root:Packages:MFP3D:Main:TimeWave

	variable dataTypeSum = CVW[%DataTypeSum][%value]
	variable firstDataType = CVW[%Channel1DataType][%value]
//FirstDataType=1
	String FirstName = FindUserName(StringFromList(firstDataType,MDTL),"Name")
	Variable ScanStateChanged = MVW[%ScanStateChanged][%value]

	wave TestWave = $"root:Packages:MFP3D:Main:"+FirstName+"Wave"
	wave DisplayTestWave = $"root:Packages:MFP3D:Main:"+FirstName+"Image0"
	if (ScanStateChanged)								//has scan changed?
		CheckLithoWave(RVW[%FastScanSize]-pnt2x(DisplayTestWave,DimSize(DisplayTestWave,0)-1),RVW[%SlowScanSize]-(DimOffset(DisplayTestWave,0)+(DimDelta(DisplayTestWave,0)*(DimSize(DisplayTestWave,1)-1))))
		SetScale/I x 0,RVW[%FastScanSize][%value], "m", $"root:Packages:MFP3D:Main:"+FirstName+"Image0"
		SetScale/I y 0,RVW[%SlowScanSize][%value], "m", $"root:Packages:MFP3D:Main:"+FirstName+"Image0"
		ForceRTImageAxes(GraphList)
	endif

	Variable napOn = NVW[%NapMode][%Value] > 0				//changed this to NapOn because NapMode is a more complicated variable
	Variable NapFactor = napOn+1		//2 for Nap, 1 for normal
	
	variable scanPoints = RVW[%ScanPoints][0]			//Grab these from RVW since the input wave is now no more than 512 columns
	variable scanLines = RVW[%ScanLines][0]*NapFactor
	variable displayPoints = DimSize(DisplayTestWave,0)		//check what is being displayed
	variable displayLines = DimSize(DisplayTestWave,1)
	variable pointRatio = scanPoints/displayPoints			//the ratio of the two
	variable lineRatio = scanLines/displayLines/NapFactor
	variable scanRatio = RVW[%SlowRatio][0]/RVW[%FastRatio][0]
	variable saveImageCount = (MVW[%SaveImageCount][0]
	variable saveImageLines = (MVW[%SaveImageLines][0]
	

	variable uniqueGrab = 0
	variable resetArgyle = 0
	if ((lineCount == -1) && !scanDown && (saveImageCount > 0))
		if (saveImageCount > 99)
			uniqueGrab = scanLines-saveImageLines
		else
			uniqueGrab = saveImageCount*saveImageLines
		endif
		lineCount = uniqueGrab
	elseif ((lineCount == scanLines) && scanDown && (saveImageCount > 0))
		if (saveImageCount > 99)
			uniqueGrab = scanLines-saveImageLines
		else
			uniqueGrab = saveImageCount*saveImageLines
		endif
		lineCount = scanLines-uniqueGrab-1
	endif
	uniqueGrab /= lineRatio
	if (((lineCount == -1) && !scanDown) || ((lineCount == scanLines) && scanDown))
		resetArgyle = 1
	endif
//print uniqueGrab	
	variable otherLC = LineCount								//otherLC is the line number on the input wave
	if (ScanDown)
		otherLC = scanLines/NapFactor-LineCount-1					//the other line count is different on the down scan
	endif
	OtherLC *= NapFactor
	ImageTimeRemaining(otherLC,GraphList)
	OtherLC = mod(otherLC,512)
	Variable OtherLCMem = OtherLC
	variable numlines = 8192
	String DataFolder = "root:Packages:MFP3D:Main:"
	Variable A, nop, DataTypeNum, ChannelNum, maskCap
	String DataTypeList = MDTL
	DataTypeList = RemoveListItem(0,DataTypeList,";")
	DataTypeList = ARBitFromList(DataTypeSum,DataTypeList,";")
	String ChannelNumList = ""
	String MasterChannelNumList = ""
	string layerStr = ""
	nop = ItemsInList(DataTypeList,";")

	Variable k, scale, offset, grabOffset
	String ScalingFunction = ""
	Variable DoFuncScaling = 0
	Variable ScalingFunctionVar0, ScalingFunctionVar1
	String DataType, userDataType
	for (A = 1;A <= 5;A += 1)
		MasterChannelNumList += num2str(CVW[%$"Channel"+num2str(A)+"DataType"][%Value])+";"
	endfor
	
		
	for (A = 0;A < nop;A += 1)
		DataType = StringFromList(A,DataTypeList,";")
		DataTypeNum = WhichListItem(DataType,MDTL,";",0,0)
		ChannelNumList += num2str(WhichListItem(num2str(DataTypeNum),MasterChannelNumList,";",0,0)+1)+";"
		if (StringMatch(DataType,"UserCalc"))
			continue
		else		//if (stringmatch(DataType,"UserIn*"))
			userDataType = FindUserName(DataType,"Name")
		endif
		Wave TestWave = $DataFolder+userDataType+"Wave"
TestWave[0][0] += 0
		numLines = min(numLines,td_WhereNow(TestWave,OtherLC)-(OtherLC-1))	//this function returns the line that was last filled with data
	endfor

	numLines -= mod(numLines,lineRatio*NapFactor)				//only deal with even multiples of the ratio
	if (ScanDown)
		numLines = Min((LineCount)*NapFactor,numLines)
	else
		numLines = min(ScanLines-LineCount*NapFactor-1,numLines)
	endif
	if (numLines < 1)									//if there are no new lines, we are through
		return 0
	endif
	
	Variable IsLastNap = 0		//is the last collected line a nap line?
	if (napOn)
		IsLastNap = Mod(OtherLC+numLines,2) == 0		//even Line numbers are surface lines.
	endif
	numLines /= NapFactor

	variable otherSign = 1
	variable otherSP = 0
	if (ScanDown)
		numLines *= -1
		otherSign = -1
		otherSP = scanPoints-1
	endif

	string chanStr
	Variable DoNapAuto, DoNapPlaneFit, NapChannelShow
	Variable DoSurfaceAuto, DoSurfacePlaneFit, SurfaceChannelShow
	Variable DoAuto, DoPlaneFit, ChannelShow
	Variable OffsetMem
	Variable ScanPointScale = 1
	Variable PSign = 1
	Variable ScanPointOffset = 0
	Variable Doit, IsRetrace
	Variable NapLoop
	Variable KStart = 0
	String traceImageName, retraceImageName
	String napTraceImageName = "", napRetraceImageName = ""
	String DisplayImageName, NapDisplayImageName = ""
	Variable IsNap, DisplayIndex
	variable checkFrequency = 0
	String FuncName = CVD[%UserCalcFunc][%Title]
	Variable HaveFunction = 0
	if ((WhichListItem("UserCalc",DataTypeList,";",0,0) >= 0) && !ARCheckFuncRef("CalcPhaseFromIQ",FuncName))
		HaveFunction = 1
		FuncRef CalcPhaseFromIQ UserCalcFunc=$FuncName
	endif
	
	
	if (scanDown)
		kStart = scanLines-1
	endif
	Variable MarkerYPos = NaN
	variable Wrap, NapOffset, NapWrap, layer = 0

	for (A = 0;A < nop;A += 1)
		DataType = StringFromList(A,DataTypeList,";")
		ChannelNum = str2num(StringFromList(A,ChannelNumList,";"))
		DoSurfacePlaneFit = CVW[%$DataType+"1RealPlanefit"][%value]
		DoNapPlaneFit = NCVW[%$"Nap"+DataType+"1RealPlaneFit"][%Value]
		SurfaceChannelShow = CVW[%$"Channel"+num2str(ChannelNum)+"Show"][%value]
		NapChannelShow = NCVW[%$"NapChannel"+num2str(ChannelNum)+"Show"][%value]
		DoSurfaceAuto = CVW[%$"Channel"+num2str(ChannelNum)+"Auto"][%value]
		DoNapAuto = NCVW[%$"NapChannel"+num2str(ChannelNum)+"Auto"][%value]
		OtherLC = OtherLCMem
		maskCap = CVW[%$DataType+"1DataScale"][%value]/4
		//this is for big images.
		DoPlaneFit = DoSurfacePlaneFit
		DoAuto = DoSurfaceAuto
		ChannelShow = SurfaceChannelShow
		userDataType = FindUserName(DataType,"Name")

		wave Scope0 = $DataFolder+userDataType+"Scope0"
		wave Scope1 = $DataFolder+userDataType+"Scope1"
		Wave Scope2 = $DataFolder+userDataType+"Scope2"
		Wave Scope3 = $DataFolder+userDataType+"Scope3"

		Wave TraceImage = $DataFolder+userDataType+"Image0"	//pull them out here for big scans and ScanStateChanged.
		Wave RetraceImage = $DataFolder+userDataType+"Image1"
		if (napOn)
			Wave NapTraceImage = $DataFolder+userDataType+"Image2"
			Wave NapRetraceImage = $DataFolder+userDataType+"Image3"
		endif
	
		wave Input = $DataFolder+userDataType+"Wave"
		if (ScanStateChanged)								//has scan changed?
			SetScale/I x 0,RVW[%FastScanSize][%value], "m", TraceImage, RetraceImage//, FitLine, MaskLine, PreMaskLine	//change image scale
			SetScale/I y 0,RVW[%SlowScanSize][%value], "m", TraceImage, RetraceImage
			SetScale/P x 0,RVW[%ScanSize][%value]/16,"m", MarkerWave			//rescale the marker
			if (napOn)
				SetScale/I x 0,RVW[%FastScanSize][%value], "m", NapTraceImage, NapRetraceImage
				SetScale/I y 0,RVW[%SlowScanSize][%value], "m", NapTraceImage, NapRetraceImage
			endif
			FreeRTImageAxes(GraphList)
			UpdateRTSection()
			ForceRTImageAxes(GraphList)
		endif
		
		wrap = 0
		NapWrap = 0
		strswitch (DataType)

			case "Height":
				scale = -MVW[%ZPiezoSens][%value]
				offset = 70
				break
				
			case "Amplitude":
			case "Amplitude1":
				scale = MVW[%AmpInvOLS][%value]
				offset = 0//MVW[%AmplitudeSetpointVolts][%value]		//don't take out the set point
				break
				

			case "Amplitude2":
				scale = MVW[%Amp2InvOLS][%value]
				offset = 0//MVW[%AmplitudeSetpointVolts][%value]		//don't take out the set point
				break
				

			case "Deflection":
				scale = MVW[%InvOLS][%value]
				offset = MVW[%DeflectionSetpointVolts][%value]		//take out the set point
				break

			case "Phase":
			case "Phase1":
				scale = 1
				offset = RVW[%PhaseOffset][0] - MVW[%PhaseOffset][0]
				if (offset)
					wrap = 1
				endif
				break

			case "Phase2":
				scale = 1
				offset = RVW[%PhaseOffset1][0] - MVW[%PhaseOffset1][0]
				if (offset)
					wrap = 1
				endif
				break

			case "ZSensor":
				scale = -MVW[%ZLVDTSens][%value]
				offset = 0
				break
			
			case "Current":
				scale = -MVW[%OrcaGain][%value]
				offset = -OVW[%OrcaOffset][%value]*Scale
				break	
			
			case "Current2":
				scale = -MVW[%OrcaGain2][%value]
				offset = -OVW[%OrcaOffset2][%value]*Scale
				break	

			case "Frequency":
				scale = 1
				if (GrepString(firstName,"Frequency"))
					offset = 0
				else
					wave OffsetFrequencyWave = root:Packages:MFP3D:Main:OffsetFrequencyWave
					offset = -OffsetFrequencyWave[lineCount*napFactor]
				endif
				break
				
			case "UserIn0":
			case "UserIn1":
			case "UserIn2":
			case "Lateral":
				Scale = MVW[%$DataType+"Gain"][%Value]
				offset = -MVW[%$DataType+"Offset"][%Value]
				break
				
			case "Capacitance":
				Scale = MVW[%CapacitanceSens][%Value]
				Offset = MVW[%CapacitanceOffset][%Value]
				break
				
			case "CapPhase":
				Scale = 1
				Offset = MVW[%CapPhaseOffset][%Value]
				break
				
			case "TipHeaterPower":
				Scale = 1		//Needs Roger's code for this.
				Offset = 0
				ScalingFunction = "CalcTipHeaterPower"
				ScalingFunctionVar0 = td_ReadValue("TipHeaterDrive")
				if (IsNan(ScalingFunctionVar0))
					ScalingFunctionVar0 = TVW[%TipHeaterDrive][%Value]
				endif
				ScalingFunctionVar1 = 1/-MVW[%OrcaGain][%value]
				break
				
			case "TipHeaterDrive":
				Scale = 1
				Offset = 0
				break
				
			default:								//the rest are assumed to be in volts with no scaling, for now
				scale = 1
				offset = 0
		endswitch
		OffsetMem = Offset
		NapOffset = Offset
		DoFuncScaling = 0
		if (!ARCheckFuncRef("CalcTipHeaterPower",ScalingFunction))
			FuncRef CalcTipHeaterPower ScalingFunc=$ScalingFunction
			DoFuncScaling = 1
		endif

		if (StringMatch(DataType,"UserCalc"))
			Input[][otherLC,otherLC+abs(numLines)] = UserCalcFunc(P,Q)
		endif

		if (ScanStateChanged)
			if (scanRatio > 1)
				SetScale/I x 0,RVW[%ScanSize][%value]/scanRatio, "m", Scope0, Scope1, Scope2, Scope3
			else
				SetScale/I x 0,RVW[%ScanSize][%value], "m", Scope0, Scope1, Scope2, Scope3
			endif
		endif
		for (NapLoop = 0;NapLoop < 2;NapLoop += 1)
			if (NapLoop == 1)
				if (!napOn)
					continue
				elseif (!(abs(numLines)*NapFactor-(!IsLastNap)))
					Continue
				endif
				
				DoAuto = DoNapAuto
				DoPlaneFit = DoNapPlaneFit
				Wave Scope0 = $GetWavesDataFolder(Scope2,2)
				Wave Scope1 = $GetWavesDataFolder(Scope3,2)
				if (StringMatch(DataType,"Phase"))
					NapOffset = RVW[%NapPhaseOffset][0] - NVW[%NapPhaseOffset][0]
					NapWrap = !(!NapOffset)
					Offset = NapOffset
					Wrap = NapWrap
				endif
			else
				if (!(abs(numLines)*NapFactor-IsLastNap))
					continue
				endif
				DoAuto = DoSurfaceAuto
				DoPlaneFit = DoSurfacePlaneFit
				if (stringmatch(dataType,"Frequency"))
					checkFrequency = 1
				endif
			endif
			
//WRONG!
			Scope0 = (Input[p+(scanPoints/8)][mod(otherLC+abs(numLines*napFactor)-2+napLoop+(!NapOn),512)]-offset)*scale		//grab the correct part
			Scope1 = (Input[scanPoints*2.375-p+0][mod(otherLC+abs(numLines*napFactor)-2+napLoop+(!NapOn),512)]-offset)*scale	//of the last line
			if (wrap)
				Scope0 = Mod(Scope0+540,360)-180
				Scope1 = Mod(Scope1+540,360)-180
			endif
			if (DoFuncScaling)
				Scope0[] = ScalingFunc(Scope0[P],ScalingFunctionVar0,ScalingFunctionVar1)
				Scope1[] = ScalingFunc(Scope1[P],ScalingFunctionVar0,ScalingFunctionVar1)
			endif
				
		
			if (DoAuto == 0)
				
				switch (DoPlaneFit)		//which planefit?
					
					case 1:																		//just offset
						WaveStats/Q/M=1 Scope0
						FastOp Scope0 = Scope0-(V_avg)
	
						WaveStats/Q/M=1 Scope1
						FastOp Scope1 = Scope1-(V_avg)
						break																				//and subtract the average
	
					case 2:																		//subtract a line
					case 3:

						RemoveLine(Scope0,ScopePWave,"")
						RemoveLine(Scope1,ScopePWave,"")	
						break
				
				endswitch

			endif	
		endfor
//*************************************************************************
///<<<<<<<<<<<<<  START BIG IMAGES		START BIG IMAGES		START BIG IMAGES		START BIG IMAGES		
//*************************************************************************
		//this routine for big images
		if (lineRatio > 1)
			SetDataFolder(DataFolder)

			if (uniqueGrab)
			
				for (k = 0;abs(k) < abs(uniqueGrab);k += otherSign/napFactor)
	
					IsNap = (mod(LineCount+k,1) != 0)
					if ((NapOn) && (IsNap))
						Offset = NapOffset
						Wrap = NapWrap
					endif
	
							//k goes negative on the down scans
					if (IsNap)
						DoAuto = DoNapAuto
						DoPlaneFit = DoNapPlaneFit
						ChannelShow = NapChannelShow
						//Hijack the Left and Right, we are done with the surface.
						Wave TraceImage = $DataFolder+userDataType+"Image2"
						Wave RetraceImage = $DataFolder+userDataType+"Image3"
						layerStr = "Nap"+userDataType
					else
						DoAuto = DoSurfaceAuto
						DoPlaneFit = DoSurfacePlaneFit
						ChannelShow = SurfaceChannelShow
						Wave TraceImage = $DataFolder+userDataType+"Image0"	//pull them out here for big scans and ScanStateChanged.
						Wave RetraceImage = $DataFolder+userDataType+"Image1"
						layerStr = userDataType
					endif

					if (1 & ChannelShow)						//do the trace
						layer = FindDimLabel(UniqueWave,2,layerStr+"Trace")
						Slice = UniqueWave[p][kStart+q*napFactor+(k*lineRatio*napFactor)-isNap][layer]	//the slice is lineRatio high
//						ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
						if (lineRatio > 1)
							ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
						else
							Duplicate/O Slice smallSlice
						endif
						switch (DoPlaneFit)		//which planefit?
							
							case 0:																		//none
								TraceImage[][kStart/lineRatio+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
								break
	
							case 1:																		//just offset
								ImageStats/M=1 smallSlice
								TraceImage[][kStart/lineRatio+k] = smallSlice[p][0]-V_avg		//grab the just the part of the whole cycle that is the trace
								break																				//and subtract the average
	
							case 2:																		//subtract a line
							case 3:																		//the same for now
								RemoveLine(smallSlice,PWave,"")
								TraceImage[][kStart/lineRatio+k] = smallSlice[p][0]//-(W_coef[0]-W_coef[1]*x)	//subtract the line
								break
						
						endswitch
						
					endif
							
					if (2 & ChannelShow)						//do the retrace
		
						layer = FindDimLabel(UniqueWave,2,layerStr+"ReTrace")
						Slice = UniqueWave[p][kStart+q*napFactor+(k*lineRatio*napFactor)-isNap][layer]	//the slice is lineRatio high
						if (lineRatio > 1)
							ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
						else
							Duplicate/O Slice smallSlice
						endif
						
						switch (DoPlaneFit)		//which planefit?
							
							case 0:																		//none
								RetraceImage[][kStart/lineRatio+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
								break
	
							case 1:																		//just offset
								ImageStats/M=1 smallSlice
								RetraceImage[][kStart/lineRatio+k] = smallSlice[p][0]-V_avg		//grab the just the part of the whole cycle that is the trace
								break																			//and subtract the average
	
							case 2:																		//subtract a line
							case 3:																		//the same for now
								RemoveLine(smallSlice,PWave,"")
								RetraceImage[][kStart/lineRatio+k] = smallSlice[p][0]//-(W_coef[0]-W_coef[1]*x)	//subtract the line
								break
	
						endswitch
						
					endif
				endfor
				
				SetDataFolder(SavedDataFolder)
				MarkerYPos = floor((LineCount+numLines-OtherSign)/lineRatio)*DimDelta(TraceImage,1)+DimOffset(TraceImage,1)
			endif			

			for (k = 0;abs(k) < abs(numLines/lineRatio);k += otherSign/napFactor)

				IsNap = (mod(LineCount+k,1) != 0)
				if ((NapOn) && (IsNap))
					Offset = NapOffset
					Wrap = NapWrap
				endif

						//k goes negative on the down scans

				if (IsNap)
					DoAuto = DoNapAuto
					DoPlaneFit = DoNapPlaneFit
					ChannelShow = NapChannelShow
					//Hijack the Left and Right, we are done with the surface.
					Wave TraceImage = $DataFolder+userDataType+"Image2"
					Wave RetraceImage = $DataFolder+userDataType+"Image3"
				else
					DoAuto = DoSurfaceAuto
					DoPlaneFit = DoSurfacePlaneFit
					ChannelShow = SurfaceChannelShow
					Wave TraceImage = $DataFolder+userDataType+"Image0"	//pull them out here for big scans and ScanStateChanged.
					Wave RetraceImage = $DataFolder+userDataType+"Image1"
				endif

//*************************************************************************
///<<<<<<<<<<<<<  Continue BIG IMAGES		Continue BIG IMAGES		Continue BIG IMAGES		Continue BIG IMAGES		


				for (IsRetrace = 0;IsRetrace < 2;IsRetrace += 1)
	
					if (!(2^IsRetrace & ChannelShow))						//do the retrace
						continue
					endif
					if (IsRetrace)
						Slice = Input[scanPoints*2.375-p+0][q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap]	//the slice is lineRatio high
					else
						Slice = Input[p+scanPoints/8][q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap]	//the slice is lineRatio high
					endif
if ((1))//q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap) > 255)
print otherLC
print otherLCMem
//print q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap
endif
					FastOp Slice = Slice+(-Offset)
					FastOp Slice = (Scale)*Slice
//DoUpdate
					if (DoFuncScaling)
						Slice[] = ScalingFunc(Slice[P],ScalingFunctionVar0,ScalingFunctionVar1)
					endif
					if (lineRatio > 1)
						ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
					else
						Duplicate/O Slice smallSlice
					endif
DoUpdate					
					switch (DoPlaneFit)		//which planefit?
						
						case 0:																		//none
							break
	
						case 1:																		//just offset
							ImageStats/M=1 smallSlice
							Fastop SmallSlice = (-V_Avg)+SmallSlice
							break																			//and subtract the average
	
						case 2:																		//subtract a line
						case 3:																		//the same for now
							RemoveLine(smallSlice,PWave,"")
							break
	
					endswitch
					if (IsRetrace)
						RetraceImage[][floor(LineCount/lineRatio)+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
					else
						TraceImage[][floor(LineCount/lineRatio)+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
					endif
					
				endfor
//				if (1 & ChannelShow)						//do the trace
//					Slice = Input[p+scanPoints/8][q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap]	//the slice is lineRatio high
//					FastOp Slice = (Scale)*Slice+(-Offset)
//					if (DoFuncScaling)
//						Slice[] = ScalingFunc(Slice[P])
//					endif
//					ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
//					//******* ImageInterpolate changes M_InterpolatedImage, which is really SmallSlice!
//					
//					switch (DoPlaneFit)		//which planefit?
//						
//						case 0:																		//none
//							break
//
//						case 1:																		//just offset
//							ImageStats/M=1 smallSlice
//							Fastop SmallSlice = (-V_Avg)+SmallSlice
//							break																				//and subtract the average
//
//						case 2:																		//subtract a line
//						case 3:																		//the same for now
//							RemoveLine(smallSlice,PWave,"")
//							break
//					
//					endswitch
//					TraceImage[][floor(LineCount/lineRatio)+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
//					
//				endif
//						
////*************************************************************************
/////<<<<<<<<<<<<<  Continue BIG IMAGES		Continue BIG IMAGES		Continue BIG IMAGES		Continue BIG IMAGES		
//				if (2 & ChannelShow)						//do the retrace
//	
//						Slice = Input[scanPoints*2.375-p+0][q*napFactor+otherLC+(abs(k)*lineRatio*napFactor)-isNap]	//the slice is lineRatio high
//						FastOp Slice = (Scale)*Slice+(-Offset)
//						if (DoFuncScaling)
//							Slice[] = ScalingFunc(Slice[P])
//						endif
//						if (lineRatio > 1)
//							ImageInterpolate/F={(1/pointRatio),(1/lineRatio)}/D=2 spline Slice		//the output of this is 1 line high
//						else
//							Duplicate/O Slice smallSlice
//						endif
//						
//						switch (DoPlaneFit)		//which planefit?
//							
//							case 0:																		//none
//								break
//	
//							case 1:																		//just offset
//								ImageStats/M=1 smallSlice
//								Fastop SmallSlice = (-V_Avg)+SmallSlice
//								break																			//and subtract the average
//	
//							case 2:																		//subtract a line
//							case 3:																		//the same for now
//								RemoveLine(smallSlice,PWave,"")
//								break
//	
//						endswitch
//						RetraceImage[][floor(LineCount/lineRatio)+k] = smallSlice[p][0]		//grab the just the part of the whole cycle that is the trace
//						
//				endif
			endfor
			
			SetDataFolder(SavedDataFolder)
			MarkerYPos = floor((LineCount+numLines-OtherSign)/lineRatio)*DimDelta(TraceImage,1)+DimOffset(TraceImage,1)
//*************************************************************************
//<<<<<<END BIG IMAGES		END BIG IMAGES		END BIG IMAGES		END BIG IMAGES		END BIG IMAGES		
//*************************************************************************

		else				//small image

			if (uniqueGrab)
				for (IsRetrace = 0;IsRetrace < 2;IsRetrace += 1)
					DoIt = 0
					ChannelShow = NapChannelShow | SurfaceChannelShow
					if (IsRetrace)
						ScanPointScale = 2.25
						if (2 & ChannelShow)			//do the retrace, the same comments apply as in trace Below
							PSign = -1
							ScanPointOffset = scanPoints/8
							DoIt = 1
						endif	
						DisplayImageName = NameOfWave(RetraceImage)
						NapDisplayImageName = NameOfWave(NapRetraceImage)
						layerStr = dataType+"Retrace"
					else
						scanPointScale = 0
						if (1 & ChannelShow) // && !ScanDown)			//do the trace
							PSign = 1
							ScanPointOffset = scanPoints/8
							DoIt = 1
						endif
						DisplayImageName = NameOfWave(TraceImage)
						NapDisplayImageName = NameOfWave(NapTraceImage)
						layerStr = dataType+"trace"
					endif
					layer = FindDimLabel(UniqueWave,2,layerStr)
		
					if (!DoIt)
						Continue
					endif

					for (k = 0;abs(k) < abs(uniqueGrab);k += otherSign/NapFactor)				//k goes negative on down scans
						IsNap = mod(LineCount+k,1) != 0
						DisplayIndex = K + kStart
						if (OrgScanDown)
							DisplayIndex = Ceil(DisplayIndex)
						else
							DisplayIndex = Floor(DisplayIndex)
						endif
						if (IsNap)
							DoAuto = DoNapAuto
							DoPlaneFit = DoNapPlaneFit
							ChannelShow = NapChannelShow
							//Hijack the Left and Right, we are done with the surface.
							Wave DisplayImage = $DataFolder+NapDisplayImageName
						else
							DoAuto = DoSurfaceAuto
							DoPlaneFit = DoSurfacePlaneFit
							ChannelShow = SurfaceChannelShow
							Wave DisplayImage = $DataFolder+DisplayImageName
						endif
						if (!(ChannelShow & (2^IsRetrace)))
							continue
						endif
						Offset = OffsetMem
						if ((NapOn) && (IsNap))
							Offset = NapOffset
							Wrap = NapWrap
						endif
						grabOffset = 0
						
						switch (DoPlaneFit)		//which planefit?
						
							case 1:																		//just offset
								ImageStats/P=(layer)/M=1/G={0,scanPoints-1,DisplayIndex*NapFactor,DisplayIndex*NapFactor} UniqueWave
								grabOffset = V_Avg
							case 0:																		//none
								DisplayImage[][DisplayIndex] = UniqueWave[p][q][%$layerStr]-grabOffset		//grab the just the part of the whole cycle that is the trace
								break					
							
							case 2:																		//linefit
								FitLine = UniqueWave[p][DisplayIndex*NapFactor][%$layerStr]	//FitLine is a line with correct scale
								//mysterious wrong code >> (Input[p+scanPoints*ScanPointScale+1][otherLC+abs(k*NapFactor)]-offset)*scale	
								RemoveLine(FitLine,PWave,"")
								DisplayImage[][DisplayIndex] = FitLine[p]
								break
	
							case 3:
								FitLine = UniqueWave[p][DisplayIndex*NapFactor][%$layerStr]	//FitLine is a line with correct scale
								//mysterious wrong code >> (Input[p+scanPoints*ScanPointScale+1][otherLC+abs(k*NapFactor)]-offset)*scale
									RemoveLine(FitLine,PWave,"PreMaskLine")
								MaskLine = PreMaskLine > maskCap ? 0 : 1
								CalcLineParm(FitLine,MaskLine,PWave,P2Wave,FitParm)
								DisplayImage[][DisplayIndex] = FitLine[p]-FitParm[0]-FitParm[1]*p
								break
								
						endswitch
						if (wrap)
							DisplayImage[][DisplayIndex] = mod(DisplayImage[p][q]+540,360)-180
						endif
					endfor		//K loop [Scan Lines and IsNap]
				endfor		//IsRetrace
//				kStart = 0
			endif	

			for (IsRetrace = 0;IsRetrace < 2;IsRetrace += 1)
				DoIt = 0
				ChannelShow = NapChannelShow | SurfaceChannelShow
				if (IsRetrace)
					ScanPointScale = 2.25
					if (2 & ChannelShow)			//do the retrace, the same comments apply as in trace Below
						PSign = -1
						ScanPointOffset = scanPoints/8
						DoIt = 1
					endif	
					DisplayImageName = NameOfWave(RetraceImage)
					NapDisplayImageName = NameOfWave(NapRetraceImage)
				else
					scanPointScale = 0
					if (1 & ChannelShow) // && !ScanDown)			//do the trace
						PSign = 1
						ScanPointOffset = scanPoints/8
						DoIt = 1
					endif
					DisplayImageName = NameOfWave(TraceImage)
					NapDisplayImageName = NameOfWave(NapTraceImage)
				endif
	
				if (!DoIt)
					Continue
				endif
				
				
				for (k = 0;abs(k) < abs(numLines);k += otherSign/NapFactor)				//k goes negative on down scans
					IsNap = mod(LineCount+k,1) != 0
					DisplayIndex = LineCount+K
					if (OrgScanDown)
						DisplayIndex = Ceil(DisplayIndex)
					else
						DisplayIndex = Floor(DisplayIndex)
					endif
					if (IsNap)
						DoAuto = DoNapAuto
						DoPlaneFit = DoNapPlaneFit
						ChannelShow = NapChannelShow
						//Hijack the Left and Right, we are done with the surface.
						Wave DisplayImage = $DataFolder+NapDisplayImageName
					else
						DoAuto = DoSurfaceAuto
						DoPlaneFit = DoSurfacePlaneFit
						ChannelShow = SurfaceChannelShow
						Wave DisplayImage = $DataFolder+DisplayImageName
					endif
					if (!(ChannelShow & (2^IsRetrace)))
						continue
					endif
					Offset = OffsetMem
					if ((NapOn) && (IsNap))
						Offset = NapOffset
						Wrap = NapWrap
					endif
					
					FitLine = Input[scanPoints*ScanPointScale+(P*PSign)+ScanPointOffset][otherLC+abs(k*NapFactor)]
					FastOp FitLine = FitLine+(Offset)
					FastOp FitLine = (Scale)*FitLine
					if (DoFuncScaling)
						FitLine[] = ScalingFunc(FitLine[P],ScalingFunctionVar0,ScalingFunctionVar1)
					endif
										

					switch (DoPlaneFit)		//which planefit?
						case 0:																		//none
							//Do Nothing
							break					
						
						case 1:																		//just offset
							WaveStats/M=1/Q FitLine
							FastOp FitLine = (-V_avg)+FitLine
							break
							
						case 2:																		//linefit
							RemoveLine(FitLine,PWave,"")
							break

						case 3:
							RemoveLine(FitLine,PWave,"PreMaskLine")
							MaskLine = PreMaskLine > maskCap ? 0 : 1
							CalcLineParm(FitLine,MaskLine,PWave,P2Wave,FitParm)
							FitLine[] = FitLine[p]-FitParm[0]-FitParm[1]*p
							break
							
					endswitch
					DisplayImage[][DisplayIndex] = FitLine[p]
					
					if (wrap)
						DisplayImage[][DisplayIndex] = mod(DisplayImage[p][q]+540,360)-180
					endif
				endfor		//K loop [Scan Lines and IsNap]
			endfor		//IsRetrace
			MarkerYPos = DisplayIndex*DimDelta(DisplayImage,1)+DimOffset(DisplayImage,1)
	
				
		
		endif				//big image switch			

	endfor				//DataType loop

//	ImageTimeRemaining(otherLC,GraphList)					moved to before otherLC gets mod 512

	gLineCount += numLines+uniqueGrab*lineRatio-(2*scanDown*uniqueGrab*lineRatio)										//increment the LineCount
	if (lineRatio > 1)
		gLineCount -= otherSign*mod(gLineCount+scanDown,lineRatio)
	endif
//	MarkerWave = RVW[%ScanSize][%value]/MVW[%MarkerRatio][%value]*limit((gLineCount*NapFactor+OrgScanDown*napOn)/scanLines,0,1)		//put the marker wave in the last line done
//	MarkerWave = (gLineCount-otherSign)/lineRatio*DisplayDelta+DisplayOffset
	MarkerWave = MarkerYPos



	MVW[%ScanStateChanged][%value] = 0
	// Cycle through the ARgyle windows and update the scanline marker
	Variable RealArgyleReal = AVW[%RealArgyleReal][0]
	if (RealArgyleReal)
		String strARgyleWin
		String strARgyleWinList = WinList("Channel*",";","WIN:4096")
		Variable nARgyle = ItemsInList(strARgyleWinList)
		
		for (A = 0;A < nARgyle;A += 1)
			strARgyleWin = StringFromList( A, strARgyleWinList )
			
			if (strlen(strARgyleWin) != 0)
				// found the window, now lets operate on it
				if (uniqueGrab || resetArgyle)
					argl_WriteValue(strArgyleWin,"WaveSection.reset",1)
//					if (scanDown)
//						argl_WriteValue(strArgyleWin,"WaveSection.line",scanLines)
//					else
//						argl_WriteValue(strArgyleWin,"WaveSection.line",0)
//					endif
				endif
				ArGL_WriteValue( strARgyleWin, "WaveSection.line", LineCount/lineRatio )
				ArGL_WriteValue( strARgyleWin, "ScanMarker.line", LineCount/lineRatio )
			endif
		endfor
	endif
	

	UpdateRTSection()

	ARCallbackFunc("ImageUpdt")
//print (StopMsTimer(-2)-Tic)
	return 0				//this is a background function, it needs this to keep running

end //UpdateRealGraph

function LineFitNextPoint(InputWave,count)
	wave InputWave
	variable count
	
	Make/O/N=(count-1) TempLine
	Make/O/D/N=2 w_coef
	variable i
	for (i = 0;i < DimSize(InputWave,0);i += 1)
		TempLine = InputWave[i][p]
		CurveFit/Q/NTHR=0 line TempLine
		InputWave[i][count] = w_coef[0]+w_coef[1]*count
	
	endfor
	
end //LineFitNextPoint

function td_WhereNow(w,startLine)		//a hopefully temporary function to calculate how far along an input wave is filled
	wave w
	variable startLine
	
	variable scanPoints = DimSize(w,0)
	variable scanLines = DimSize(w,1)	
	variable i
	for (i = startLine;i < scanLines;i += 1)	//start at what we have already done
		if (numtype(w[scanPoints-1][i]) == 2)							//look for NaN
			break
		endif
	endfor	
	
	return i-1											//return the position of the last good data
	
end //td_WhereNow


Function AR_Stop([OKList])
	String OKList
	
	//This functions job is to handle stopping other buttons.
	//so lets say you stop a tune by starting a scan.
	//This function will call the stop Tune for you....
	
	if (ParamIsDefault(OKList))
		OKList = ""
	endif
	
	String DataFolder = GetDF("Main")
	SVAR WhatsRunning = $InitOrDefaultString(DataFolder+"WhatsRunning","")
	
	String RunList = WhatsRunning 		//keep a local copy
	RunList = ListSubtract(RunList,OKList,";")
	
	
	//The Global will be changing as we go.
	Variable A, nop = ItemsInList(RunList,";")
	String RunListItems = "Scan;Thermal;Force;Tune;Litho;Engage;Maveric;FreqFB;DriveFB;PotFB;FMap;PMap;DoIV;"
	String FuncListItems = "DoScanFunc;DoThermalFunc;DoForceFunc;CantTuneFunc;DoLithoFunc;DoScanFunc;FMVDoItFunc;FMCheckboxFunc;FMCheckboxFunc;ElectricBoxFunc;DoScanFunc;PMapButtonFunc;ARDoIVButtonFunc;"
	String FuncListArgs = "StopScan_0;StopThermalButton_1;StopForce_2;DoTuneStop_3;StopLitho;StopEngageButton;FMVStopButton_0;FreqGainOnBox_0;DriveGainOnBox_0;PotentialGainOnBox;StopScan_0;StopScan_5;ArDoIVStopButton_1;"
	String FuncTypeList = "Button;Button;Button;Button;Button;Button;Button;CheckBox;CheckBox;CheckBox;Button;Button;Button;"
	String RunItem = ""
	String FuncItem = ""
	String FuncArgItem = ""
	String FuncTypeItem = ""
	Variable Index
	SwapMacroMode(1)
	//PV("ElectricTune",0)		//if stop was called, then something is probably starting, and electric tune is no longer a valid thing to look at.
	for (A = 0;A < nop;A += 1)
		RunItem = StringFromList(A,RunList,";")
		Index = WhichListItem(RunItem,RunListItems,";",0,0)
		if (Index < 0)
			continue
		endif
		
		FuncItem = StringFromList(Index,FuncListItems,";")
		FuncArgItem = StringFromList(Index,FuncListArgs,";")
		FuncTypeItem = StringFromList(Index,FuncTypeList,";")
		
		ARExecuteControl2(FuncArgItem,FuncItem,"","",GetFunctionFlag(FuncTypeItem),0,"")
		
//		FuncRef DoScanFunc StopFunc = $FuncItem
//		StopFunc(FuncArgItem)
		if (StringMatch(RunItem,"Force"))
			HideForceButtons("Stop")		//we probably 
			//won't finish the current FP
			//which is when the buttons actually get fixed.
			//So do it now.
		endif
		
	endfor
	SwapMacroMode(-1)
	
	//all these functions should have removed their strings...
	if (Strlen(listSubtract(WhatsRunning,OKList,";")))
		print GetCallingFuncName(2)+" called: "+GetFuncName()+"\r"+WhatsRunning+" Still running"
		DoWindow/H
	endif
	
	//here is my notebook
	//for easy function jumping....
	
//	Thermal
//	DoThermalFunc("StopThermalButton_1")
//	
//	Scan
//	DoScanFunc("StopScan_0")
//	
//	Litho
//	DoLithoFunc("StopLitho")
//	
//	Maveric
//	FMVDoItFunc("FMVDoItButton_0")
//	FMVDoItFunc("FMVStopButton_0")
//	
//	Enage
//	SimpleEngageMe
//	DoScanFunc("StopEngageButton")
//	
//	Tune
//	CantTuneFunc("DoTuneStop_3")
//	
//	Force
//	DoForceFunc("StopForce_2")
//
	
End //AR_Stop


Function ARManageRunning(WhatIsRunning,IsItRunning)
	String WhatIsRunning
	Variable IsItRunning
	
	//See AR_Stop
	//WhatIsRunning must be defined in that function
	//so far it can be:
	//Scan
	//Thermal
	//Force
	//Tune
	//Litho (step and normal are treated the same)
	//Engage
	//Maveric

	String DataFolder = GetDF("Main")
	SVAR GlobalList = $InitOrDefaultString(DataFolder+"WhatsRunning","")

	
	if (IsItRunning)
		GlobalList = SpliceStringList(GlobalList,WhatIsRunning)
	else
		GlobalList = ListSubtract(GlobalList,WhatIsRunning,";")
	endif
	ARUpdateStatusLED()

End //ARManageRunning


function UpdateLog(Parameter,Value)		//this updates the log file, which is a record of parameter changes during scanning
	string Parameter
	variable Value
	
	SVAR LogFile = root:Packages:MFP3D:Main:LogFile
	NVAR LineCount = root:Packages:MFP3D:Main:LineCount
	LogFile += Parameter+": "+num2str(Value)+"@"+"Line: "+num2str(LineCount)+"\r"	//add the parameter and the new value and add the line number
	
end //UpdateLog


function ADCcheck(chanStr,waveStr,chanTotal,inCount)		//this adjusts all of these variables according to how full the crosspoint is
	string &chanStr, &waveStr				//chanStr is the input channel, waveStr is the name of the input wave
	variable &chanTotal, &inCount			//chanTotal is the total number of channels, inCount is the number of available ADCs being used
	
	Variable output = 0

	if (stringmatch(chanStr,"None"))
		chanStr = ""
		waveStr = ""
		chanTotal -= 1
		return(output)
	endif
	
	if (stringmatch(waveStr,"Deflection") && (GV("ImagingMode") == 3))
		chanStr = "A%Input"
	endif

	switch (inCount)
		
		case 0:										//no ADCs used yet
			if (stringmatch(chanStr,"A%Input"))	//now one is used
				inCount = 1							//this is now one
			endif
			break
			
		case 1:										//one ADC is already used
			if (stringmatch(chanStr,"A%Input"))	//another is needed
				chanStr = "B%Input"					//A was already used, switch to B
				inCount = 2							//now both are used
			endif
			break
			
		case 2:										//both extra ADCs are now used
			if (stringmatch(chanStr,"A%Input"))	//another one is asked for
				chanStr = ""							//sorry, none left
				print "There is not an ADC free to capture "+waveStr//relay the news
				DoWindow/H
				waveStr = ""							//set the waveStr to null
				chanTotal -= 1						//reduced the channel total by one
				output = 1
			endif	
			break
	
	endswitch
	return(output)

end //ADCcheck


Function ImageTimeRemaining(LineNum,GraphList)
	Variable LineNum
	String GraphList

	//function to put the time remaining for the scan on all the graphs in GraphList
	//If LineNum is Nan it will remove the Time remaining.
	
	//Wave TWave = root:Packages:MFP3D:Main:TWave
	//Variable Tic = StopMsTimer(-2)
	//1 ms
	if (!Strlen(GraphList))
		GraphList = WinList("Channel*Image*",";","WIN:4097")
	endif
	String GraphStr
	Variable A, nop = ItemsInList(GraphList,";")
	String ImageTitle
	Variable Index
	//TWave[0] = (StopMsTimer(-2)-Tic)
	//Print "1",(StopMsTimer(-2)-Tic)
	
	//400 us
	String DataFolder = GetDF("Variables")
	Wave RVW = $DataFolder+"RealVariablesWave"
	Wave NVW = $DataFolder+"NapVariablesWave"
	Variable ScanRate = RVW[%ScanRate][0]
	Variable ScanLines = RVW[%ScanLines][0]
	SVAR MDTL = $DataFolder+"MasterDataTypeList"
	Variable TraceOrRetrace, ChannelNumber
	String userDataType, ToR = "Trace;Retrace;"
	Variable napOn = NVW[%NapMode][%Value] > 0		//changed to napOn as NapMode is a more complicated variable
	Variable NapFactor = napOn+1
	//Print "2",(StopMsTimer(-2)-Tic)
	//TWave[1] = (StopMsTimer(-2)-Tic)
	
	
	
	String AppendStr = ""
	Variable TimeLeft = (ScanLines*NapFactor-LineNum)/ScanRate
	
	
	if (!IsNan(LineNum))
		//AppendStr = "| "+SmartTimeStr(TimeLeft,SigFigs=2)
		AppendStr = "| "
		AppendStr += Num2StrLen(floor(TimeLeft/60/60),2)+":"
		TimeLeft -= floor(TimeLeft/60/60)*60*60
		AppendStr += Num2StrLen(floor(TimeLeft/60),2)+":"
		TimeLeft -= floor(TimeLeft/60)*60
		AppendStr += Num2StrLen(floor(TimeLeft),2)
	endif
	
	//Print "3",(StopMsTimer(-2)-Tic)
	//TWave[2] = (StopMsTimer(-2)-Tic) 

	for (A = 0;A < nop;A += 1)
		GraphStr = StringFromList(A,GraphList,";")
		if (!IsWindow(GraphStr))
			continue
		endif
		//Print "A,1",(StopMsTimer(-2)-Tic)
		//TWave[A*3+3] = (StopMsTimer(-2)-Tic) 
		
		//ImageTitle = GetWindowTitle(GraphStr)
		//Index = strsearch(ImageTitle,"|",0)
		//if (Index >= 0)
		//	ImageTitle = ImageTitle[0,Index-1]
		//endif
		
		
		ImageTitle = ""
		TraceOrRetrace = GetEndNum(GraphStr)
		ChannelNumber = str2num(GraphStr[strlen("Channel")])
		if (TraceOrRetrace > 1)
			TraceOrRetrace -= 2
			ImageTitle = "Nap"
		endif
		userDataType = FindUserName(StringFromList(GV("Channel"+num2str(ChannelNumber)+"DataType"),MDTL),"Name")
		ImageTitle += userDataType
		ImageTitle += StringFromList(TraceOrRetrace,ToR,";")
		
		
		//Print "A,2",(StopMsTimer(-2)-Tic)
		//TWave[A*3+4] = (StopMsTimer(-2)-Tic) 
		
		
		ImageTitle += AppendStr

		//500 us
		DoWindow/T $GraphStr ImageTitle
		//Print "A,3",(StopMsTimer(-2)-Tic)
		//TWave[A*3+5] = (StopMsTimer(-2)-Tic) 
		
	endfor
	
	//Print "End",(StopMsTimer(-2)-Tic)
	//TWave[12] = (StopMsTimer(-2)-Tic) 
	
End //ImageTimeRemaining


Function DoScanStopCallback(CtrlName)
	String CtrlName
	
	PostARMacro(CtrlName,NaN,"","")
	
	ARRestoreDBState()
	ARCallbackFunc("Stop")

End //DoScanStopCallback()	


//
//Function SCMAppendDataTypes(DataTypeList)
//	STRING &dataTypeList
//
//
//	Variable Handle = GetValue("PNAHandle","Value",0)
//	if (IsNan(Handle))
//		return(0)
//	endif
//
//	if (handle)
//		dataTypeList += "PnaFrameBuffer;"
//	endif
//
//
//End //SCMAppendDataTypes
//
//
//Function SCMRemoveDataTypes(DataTypeList,ChannelNumList)
//	String &DataTypeList, &ChannelNumList
//	
//	Variable Handle = GetValue("PNAHandle","Value",0)
//	if (IsNan(Handle))
//		return(0)
//	endif
//
//
//	Variable Index
//	if (handle)
//		Index = WhichListItem("pnaFrameBuffer",DataTypeList,";",0,0)
//		if (Index >= 0)
//			DataTypeList = RemoveListItem(Index,DataTYpeList,";")
//			ChannelNumList = RemoveListItem(index,ChannelNumList,";")
//		endif
//	endif
//
//End //SCMRemoveDataTypes



Function/S ImageModeList([AllModes])
	Variable AllModes
	if (ParamIsDefault(AllModes))
		AllModes = 0
	endif
	String output = ""
	output = "Contact;AC mode;"
	if (GV("HasFM") || AllModes)
		Output += "FM Mode"
	endif
	output += ";"
	Output += "PFM Mode;"

	Struct ARTipHolderParms TipParms
	ARGetTipParms(TipParms)
	
	if (TipParms.IsSTM || AllModes)
		Output += "STM"
	endif
	output += ";"
	return(output)
end //ImageModeList


function CalculateDataTypeSum(Sum0,Sum1,chanTotal,isNap)		//calculates the data sum for trace (0) and retrace (1)
	variable &Sum0, &Sum1, &chanTotal,isNap							//variables by reference!
	
	SVAR MDTL = root:Packages:MFP3D:Main:Variables:MasterDataTypeList
	
	wave DataTypeCheck = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
	if (isNap)
		wave CVW = root:Packages:MFP3D:Main:Variables:NapChannelVariablesWave
	else
		wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
	endif
		
	variable i, DataType
	string chanStr
	Sum0 = 0
	Sum1 = 0
	chanTotal = 0
	
	for (i = 1;i <= 5;i += 1)			//go through the 5 channels
		DataType = DataTypeCheck[%$"Channel"+num2str(i)+"DataType"][0]		//see if the data type is turned on
		if (DataType)													//if yes
			if (isNap)
				chanStr = "Nap"
			else
				chanStr = ""
			endif
			chanStr += StringFromList(DataType,MDTL)				//then grab the data type
			switch (CVW[%$chanStr+"Capture"][0])				//and check to see what we are saving
				case 1:												//1 means trace
					Sum0 += 2^(DataType-1)							//add in the right bit to the sum
					chanTotal += 1
					break
					
				case 2:												//2 means retrace
					Sum1 += 2^(DataType-1)
					chanTotal += 1
					break
					
				case 3:												//3 means both
					Sum0 += 2^(DataType-1)
					Sum1 += 2^(DataType-1)
					chanTotal += 2
					break
					
			endswitch
		endif
	endfor
	
end //CalculateDataTypeSum
