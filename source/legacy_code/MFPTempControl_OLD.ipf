#pragma rtGlobals=1		// Use modern global access method.

Function TemperatureControl(Rcant_sp, Rsense, Vstart)
	variable Rcant_sp, Rsense, Vstart
	
	variable Error = 0	
	Variable PIS_loop = 5
	variable Input = Vstart
	variable Setpoint = 0
	variable PGain = -1
	//variable PGain = -(1+(Rcant_sp/Rsense))
	variable IGain = 0
	variable SGain = 0
	
	//Execute("root:Packages:MFP3D:XPT:Originals:DCLitho[%Out0] = \"OutB\"")
	//Execute("root:Packages:MFP3D:XPT:DCLitho[%Out0] = \"OutB\"")
	
	//This one doesn't work:
	td_WriteString("InB%Crosspoint@Controller","In0")
	//This one works:
	td_WriteString("Out0%Crosspoint@Controller","OutA")
	
	td_wv("A%Output",Vstart)
	
	Execute("root:Packages:MFP3D:XPT:Originals:ACMeter[%Out0] = \"OutA\"")
	Execute("root:Packages:MFP3D:XPT:ACMeter[%Out0] = \"OutA\"")
	
	Execute("root:Packages:MFP3D:XPT:Originals:ACMeter[%InB] = \"In0\"")
	Execute("root:Packages:MFP3D:XPT:ACMeter[%InB] = \"In0\"")
	
	
	XPTButtonFunc("WriteXPT")
		
	Error += td_stop()
	
	Error += td_xSetPISLoop(PIS_loop,"always", "B%Input@Controller", SetPoint, PGain, IGain, SGain, "A%Ouput@Controller")

	if (Error)
		print "Error in one of the td_ functions in TemperatureControl: ", Error
	endif
	
end

Function TempCont2()

	//Manually (for now):
	//Crosspoint:
	//InB >> BNCIn0
	//BNCOut0 >> OutA
	
	//td_wv("A%Output",2)
	//td_rv("B%Input")
	
	XPTPopupFunc("BNCOut0Popup",1,"OutA")
	XPTPopupFunc("InBPopup",7,"BNCIn0")
	XPTButtonFunc("WriteXPT")
	ARCheckFunc("DontChangeXPTCheck",1)
	
	//XPTLoad is the main Wave having current setup's changes
	//Edit/K=0 'XPTLoad';DelayUpdate
	
	Variable Setpoint = 0
	Variable PGain = -1
	
	td_xSetPISLoop(5,"always", "B%Input@Controller", Setpoint, Pgain, 0, 0, "A%Output@Controller")
	//Not so effective:
	//td_stopPISLoop(0)
	//Try:
	//td_stop()
	
End
