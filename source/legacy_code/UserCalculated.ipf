#pragma rtGlobals=1		// Use modern global access method.

// This should be sitting in UserCalculated.ipf
Function Vcant(RowIndex, ColIndex)
	Variable RowIndex, ColIndex
	
	String SavedDataFolder = GetDataFolder(1)
	SetDataFolder("root:Packages:MFP3D:Main:")
	
	Wave VsenseWave = UserIn0Wave
	// For now use a BNC splitter and pipe in the total voltage into User In 1
	Wave VoutWave = UserIn1Wave
	
	Variable vtot = VoutWave[RowIndex][ColIndex]
	Variable vsense = VsenseWave[RowIndex][ColIndex]
	Variable vcant = vtot - vsense
	
	SetDataFolder root:packages:MFPTempCont
	NVAR gRsense
	// Can let a meter piggy back on this function.
	// Meter would require that Vtot be one of the acquired channels
	
	SetDataFolder root:packages:TempCont:Meter
	NVAR GRcant,  GIcant, GPcant, GVcant
	
	GVcant = vcant
	GIcant = vsense/ gRsense // in mA
	GPcant = vcant * GIcant // in mW
	GRcant = vcant / GIcant // in k Ohms
	
	//Performing any control stuff here completely hangs Igor
	// DO NOT do anything else here	
		
	SetDataFolder(SavedDataFolder)
	// The whole point of this is to calculate a single V cant channel after all:
	return Vcant
End