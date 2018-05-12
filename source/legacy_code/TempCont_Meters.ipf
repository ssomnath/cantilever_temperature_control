#pragma rtGlobals=1		// Use modern global access method.

Menu "Macros"
	"Temperature Control Meters", TempContMeterDriver()
End

Function TempContMeterDriver()
	
	// If the panel is already created, just bring it to the front.
	DoWindow/F TempContMeterPanel
	if (V_Flag != 0)
		return 0
	endif
	
	String dfSave = GetDataFolder(1)
	// Create a data folder in Packages to store globals.
	NewDataFolder/O/S root:packages:TempCont
	NewDataFolder/O/S root:packages:TempCont:Meter
	
	//Variables declaration
	Variable/G GRcant = 0
	Variable/G GIcant = 0
	Variable/G GPcant = 0
	Variable/G GVcant = 0

	// Create the control panel.
	Execute "TempContMeterPanel()"
	//Reset the datafolder to the root / previous folder
	SetDataFolder dfSave

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// Temperature Control Meter Panel //////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// This function renders a simple meter panel
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Window TempContMeterPanel(): Panel
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(485,145, 975,315) as "Temperature Control Meter"
	SetDrawLayer UserBack
	
	ValDisplay vd_Rcant,pos={16,16},size={385,20},title="R cant (k Ohm)", mode=0
	ValDisplay vd_Rcant,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Rcant, fsize=18, value=root:Packages:TempCont:Meter:GRcant
	
	ValDisplay vd_Pcant,pos={39,51},size={362,20},title="P cant (mW)", mode=0
	ValDisplay vd_Pcant,limits={0,20,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Pcant, fsize=18, value=root:Packages:TempCont:Meter:GPcant
	
	ValDisplay vd_Icant,pos={52,88},size={351,20},title="I cant (mA)", mode=0
	ValDisplay vd_Icant,limits={0,1.75,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Icant, fsize=18, value=root:Packages:TempCont:Meter:GIcant
	
	ValDisplay vd_Vcant,pos={58,123},size={346,20},title="V cant (V)", mode=0
	ValDisplay vd_Vcant,limits={0,10,0},barmisc={0,70},highColor= (0,43520,65280)
	ValDisplay vd_Vcant, fsize=18, value=root:Packages:TempCont:Meter:GVcant
	
	ValDisplay vd_statusLED, value=str2num(root:packages:MFP3D:Main:PIDSLoop[%Status][5])
	ValDisplay vd_statusLED, mode=2, limits={-1,1,0}, highColor= (0,65280,0), zeroColor= (65280,65280,16384)
	ValDisplay vd_statusLED, lowColor= (65280,0,0), pos={420,66},size={54,83}, barmisc={0,0}

	SetDrawEnv fsize=18
	DrawText 429,37, "PID"
	SetDrawEnv fsize=18
	DrawText 419,63, "Status"
End


// This should be sitting in UserCalculated.ipf
Function Vcant(RowIndex, ColIndex)
	Variable RowIndex, ColIndex
	
	String SavedDataFolder = GetDataFolder(1)
	SetDataFolder("root:Packages:MFP3D:Main:")
	
	Wave VsenseWave = UserIn0Wave
	// For now use a BNC splitter and pipe in the total voltage into User In 1
	Wave VoutWave = UserIn1Wave
	
	SetDataFolder root:packages:MFPTempCont
	NVAR gRsense
	// Can let a meter piggy back on this function.
	// Meter would require that Vcant be one of the acquired channels
		
	Variable vtot = VoutWave[RowIndex][ColIndex]
	Variable vsense = VsenseWave[RowIndex][ColIndex]
	Variable vcant = vtot - vsense
	
	SetDataFolder root:packages:TempCont:Meter
	NVAR GRcant,  GIcant, GPcant, GVcant
	
	GVcant = vcant
	GIcant = vsense/ gRsense // in mA
	GPcant = vcant * GIcant // in mW
	GRcant = vcant / GIcant // in k Ohms
		
	SetDataFolder(SavedDataFolder)
	// The whole point of this is to calculate a single V cant channel after all:
	return Vcant
End