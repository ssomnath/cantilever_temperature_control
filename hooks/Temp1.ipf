#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=Temp1


Function/S IR_WritePIDSloop(FB)
	Struct ARFeedbackStruct &FB
	
	
	String WaveNames = InitPIDSloopWaves()
	Wave/T PIDSLoopWave = $StringFromList(0,WaveNames,";")
	Wave/T PIDSGroup = $StringFromList(1,WaveNames,";")
	
	String output = ""
	//Hack in the Log scale
	if (StringMatch(FB.Input,"Log.Output"))
		Output += num2str(td_SetLog("Current",td_ReadValue("Log.InputOffset")))+","//td_ReadValue("Current")*.95))+","
		FB.Setpoint = GetLogValue(FB.Input,FB.Setpoint)		//The log output changes sign around 0.
	endif
	
	PIDSLoopWave[%InputChannel][FB.Bank] = FB.Input
	PIDSLoopWave[%OutputChannel][FB.Bank] = FB.Output
	if (isNan(FB.Setpoint))
		PIDSLoopWave[%DynamicSetpoint][FB.Bank] = "Yes"
		PIDSLoopWave[%Setpoint][FB.Bank] = "0"
	else
		PIDSLoopWave[%DynamicSetpoint][FB.Bank] = "No"
		PIDSLoopWave[%Setpoint][FB.Bank] = num2str(FB.Setpoint)
	endif
	//PIDSLoopWave[%DynamicSetpoint][FB.Bank] = StringFromList(FB.DynamicSetpoint,"No;Yes;",";")
	PIDSLoopWave[%SetpointOffset][FB.Bank] = num2str(FB.SetpointOffset)
	PIDSLoopWave[%DGain][FB.Bank] = num2str(FB.DGain)
	PIDSLoopWave[%PGain][FB.Bank] = num2str(FB.PGain)
	PIDSLoopWave[%IGain][FB.Bank] = num2str(FB.IGain)
	PIDSLoopWave[%SGain][FB.Bank] = num2str(FB.SGain)
	PIDSLoopWave[%OutputMin][FB.Bank] = num2str(FB.OutputMin)
	PIDSLoopWave[%OutputMax][FB.Bank] = num2str(FB.OutputMax)
	PIDSLoopWave[%StartEvent][FB.Bank] = FB.StartEvent
	PIDSLoopWave[%StopEvent][FB.Bank] = FB.StopEvent
	PIDSLoopWave[%Status][FB.Bank] = "0"
	
	
	
//	//clear any old alias in there.
//	if (Strlen(PIDSLoopWave[%LoopName][FB.Bank]))
//		output += num2str(td_WriteString("Alias:"+PIDSLoopWave[%LoopName][FB.Bank],""))+","
//	endif
	
	SetDimLabel 1,FB.Bank,$FB.LoopName,PIDSLoopWave
	//PIDSLoopWave[%LoopName][FB.Bank] = FB.LoopName
	
	
	
	PIDSGroup[][0] = PIDSLoopWave[P][FB.Bank]
	String LoopName = FB.LoopName
	String LoopDest = "PIDSloop."+num2str(FB.Bank)
	Variable UpdateAliases = 0
	Variable NeedZCheck = 0
	Wave/T/Z DynamicAlias = $""
	if (StringMatch(ir_ReadAlias(FB.output),"*output.Z"))
		NeedZCheck = 1
		Wave/T DynamicAlias = $GetDF("Alias")+"DynamicAlias"
	endif
	
	
	
	if (!Strlen(LoopName))
		LoopName = LoopDest
	else
		//HACK HACK HACK HACK
		//if we are using the cypher specific FB loops, then use them.
//print ir_readAlias(FB.Input)+"&"+ir_ReadAlias(FB.output)		
		strswitch (ir_readAlias(FB.Input)+"&"+ir_ReadAlias(FB.output))
		
			case "Cypher.LockinA.0.Theta&Cypher.LockinA.0.FreqOffset":
				LoopDest = "Cypher.PIDSloop.0"
				break
				
			case "Cypher.LockinA.0.r&Cypher.LockinA.0.Amp":
				LoopDest = "Cypher.PIDSloop.1"
				break
				
			case "Cypher.LockinA.0.FreqOffset&Output.Z":
				//out alias is pointing to the wrong output.Z, we need to fix it.
				output += num2str(td_WriteString("ARC.ZDACSource","Cypher"))+","
				DynamicAlias[%Height] = "Cypher.Output.Z"
				UpdateAliases = 1
			case "Cypher.LockinA.0.FreqOffset&Cypher.Output.Z":
				LoopDest = "Cypher.PIDSloop.2"
				NeedZCheck = 0		//either it was right, or we are fixing it
				break
				
			case "Cypher.LockinA.0.Amp&Output.Z":
				output += num2str(td_WriteString("ARC.ZDACSource","Cypher"))+","
				DynamicAlias[%Height] = "Cypher.Output.Z"
				UpdateAliases = 1
			case "Cypher.LockinA.0.Amp&Cypher.Output.Z":
				LoopDest = "Cypher.PIDSloop.3"
				NeedZCheck = 0		//either it was right, or we are fixing it
				break
			
//			default:
//				if (Stringmatch(ir_readAlias(FB.output),"*output.Z"))
//					output += num2str(td_WriteString("ARC.ZDACSource","ARC"))+","
//				endif
//				break
//				
		endswitch
		
		Output += num2str(td_WriteString("Alias:"+LoopName,LoopDest))+","
		output += ReadAllAliases()
	endif
	
	if (NeedZCheck)		//then we need to make sure we are on arc Z.
		if (StringMatch(ir_ReadAlias(FB.output),"Cypher.output.Z"))
			output += num2str(td_WriteString("ARC.ZDACSource","ARC"))+","
			DynamicAlias[%Height] = "Output.Z"
			UpdateAliases = 1
		endif
	endif
	
	if (UpdateAliases)
		WriteAllAliases()
	endif

	Output += num2str(td_WriteGroup(LoopName,PIDSgroup))+","
	Output += num2str(td_ReadGroup(LoopName,PIDSgroup))+","
	PIDSLoopWave[][FB.Bank] = PIDSGroup[P][0]
	
	
//	PIDSLoopWave[0,DimSize(PIDSLoopWave,0)-2][FB.Bank] = PIDSGroup[P][0]
	
	return(output)
End //IR_WritePIDSloop


Function/S ir_readAlias(Input)
	String Input
	
	//recursive function to read aliases fully.
	
	string output = "", Ending = ""
	output = td_ReadString("Alias:"+input)
	if (cmpstr(output[0],"$") == 0)
		output = output[1,strlen(output)-1]		//drop the "$"
		Ending = RemoveListItem(0,output,".")
		if (Strlen(Ending))
			Ending = "."+Ending
		endif
		output = ir_ReadAlias(stringFromlist(0,output,"."))+Ending
	endif
	return(output)
End //ir_readAlias


Function/S InitPIDSloopWaves()


	String DataFolder = GetDF("Main")
	Wave/T PIDSLoopWave = $InitOrDefaultTextWave(DataFolder+"PIDSLoop",0)
	Wave/T PIDSGroup = $InitOrDefaultTextWave(DataFolder+"PIDSGroup",0)
	
	String output = ""
	String Labels = ir_GetGroupLabels("PIDSloop.0")

	Variable A, nop = ItemsInList(Labels,";")
	
	Redimension/N=(nop) PIDSGroup
	SetDimLabels(PIDSGroup,Labels,0)
	
//	Labels += "LoopName;"
//	nop += 1
	
	Variable NumOfPIDS = 6
	
	Redimension/N=(nop,NumOfPIDS) PIDSloopWave
	SetDimLabels(PIDSloopWave,Labels,0)
	//SetDimLabels(PIDSLoopWave,ListMultiply("Bank",MakeValueStringList(NumOfPIDS-1,0),";"),1)

	output = GetWavesDataFolder(PIDSloopWave,2)+";"
	Output += GetWavesDataFolder(PIDSGroup,2)+";"
	return(output)

End //InitPIDSLoopWaves


Function ir_ReadPIDSLoop(WhichLoop,[LoopName])
	Variable WhichLoop
	String LoopName
	

	String Temp
	if (!ParamIsDefault(LoopName))
		Temp = td_ReadString("Alias:"+Loopname)
		WhichLoop = Str2num(Temp[Strlen(Temp)-1])
	endif
	if (IsNan(WhichLoop))
		return(WhichLoop)
	endif

	String WaveNames = InitPIDSloopWaves()
	Wave/T PIDSLoopWave = $StringFromList(0,WaveNames,";")
	Wave/T PIDSGroup = $StringFromList(1,WaveNames,";")
	
	String ErrorStr = ""
	
	
	variable start = 0
	variable stop = 5
	variable i
	
	if (whichLoop != -1)
		start = whichLoop
		stop = whichLoop
	endif
	
	for (i = start;i <= stop;i += 1)
	
		ErrorStr += num2str(td_ReadGroup("PIDSloop."+num2str(i),PIDSGroup))+","
		//PIDSLoopWave[0,DimSize(PIDSloopWave,0)-2][i] = PIDSGroup[P]
		PIDSLoopWave[][i] = PIDSGroup[P]
	endfor
	
	ARReportError(errorStr)
	return(WhichLoop)


End //ir_ReadPIDSLoop


function ir_SetPISLoop(whichLoop,eventString,inChannelString,setpoint,pgain,igain,sgain,outChannelString,OutputMin,OutputMax,[LoopName])
	variable whichLoop, setpoint, pgain, igain, sgain
	string eventString, inChannelString, outChannelString
	Variable outputMin, OutputMax
	String LoopName
	
	if (ParamIsDefault(LoopName))
		LoopName = ReplaceString(".",outChannelString,"")+"Loop"
	endif
	
	Struct ARFeedbackstruct FB
	FB.Input = InChannelString
	FB.Output = OutChannelString
	FB.Setpoint = Setpoint
	FB.pGain = PGain
	FB.IGain = IGain
	FB.sGain = sGain
	FB.DGain = 0
	FB.SetpointOffset = 0
	FB.StartEvent = StringFromList(0,EventString,",")
	FB.StopEvent = StringFromList(1,EventString,",")
	FB.outputMax = OutputMax
	FB.OutputMin = OutputMin
	FB.LoopName = LoopName
	FB.Bank = WhichLoop
	
	String ErrorStr = ir_WritePIDSloop(FB)
	ARReportError(ErrorStr)
	return(0)
end //ir_SetPISLoop


Function ir_WriteValue(parmStr,value)
	string parmStr
	variable value
	
	
	string whichParm = ""
	
	if (GrepString(parmStr,"(?i)SetpointOffset*"))
		whichParm = "setpointOffset"
	elseif (GrepString(parmStr,"(?i)Setpoint*"))
		whichParm = "setpoint"
	elseif (GrepString(parmStr,"(?i)PGain*"))
		whichParm = "pGain"
	elseif (GrepString(parmStr,"(?i)IGain*"))
		whichParm = "iGain"
	elseif (GrepString(parmStr,"(?i)SGain*"))
		whichParm = "sGain"
	elseif (GrepString(parmStr,"(?i)DGain*"))
		whichParm = "dGain"
	elseif (GrepString(parmStr,"(?i)outputMax*"))
		whichParm = "outputMin"
	elseif (GrepString(parmStr,"(?i)outputMin*"))
		whichParm = "OutputMax"
	endif
	String LoopName = ""
	Variable WhichLoop = NaN
	if (Strlen(WhichParm))		//PIDS loop
		if (StringMatch(ParmStr,"$*"))		//alias Name
			LoopName = ParmStr[1,Strlen(ParmStr)-Strlen(WhichParm)-2]
		else
			WhichLoop = str2num(ParmStr[Strlen(ParmStr)-Strlen(WhichParm)-2])
		endif
	endif
	
	Variable output = td_WriteValue(parmStr,value)
	
	if (Strlen(WhichParm))		//it was a PIDS loop parm
		if (Strlen(LoopName))				//we found an alias name for the PIDS loop
			ir_ReadPIDSLoop(NaN,LoopName=LoopName)
		elseif (!IsNan(WhichLoop))			//we found a PIDS loop number
			ir_ReadPIDSLoop(WhichLoop)
		else
			//this is an error, perhaps we should spit out a report for debugging.
			print ReplaceString(";",GetRTStackInfo(0)," -> ")+" Can not figure out which PIDSloop from: "+ParmStr
			DoWindow/H
		endif
	endif
	return(output)
	
end //ir_WriteValue


//function ir_WriteValue(parmStr,value)
//	string parmStr
//	variable value
//	
//	wave/T PISLoopWave = root:Packages:MFP3D:Main:PISLoopWave
//	variable whichLoop = -1
//	string whichColumn = ""
//	
//	if (GrepString(parmStr,"(?i)Setpoint*"))
//		//whichLoop = str2num(parmStr[strlen(parmStr)-1])
//		whichColumn = "setpoint"
//		WhichLoop = -2
//	elseif (GrepString(parmStr,"(?i)PGain*"))
//		//whichLoop = str2num(parmStr[strlen(parmStr)-1])
//		whichColumn = "pGain"
//		WhichLoop = -2
//	elseif (GrepString(parmStr,"(?i)IGain*"))
//		//whichLoop = str2num(parmStr[strlen(parmStr)-1])
//		whichColumn = "iGain"
//		WhichLoop = -2
//	elseif (GrepString(parmStr,"(?i)SGain*"))
//		//whichLoop = str2num(parmStr[strlen(parmStr)-1])
//		whichColumn = "sGain"
//		WhichLoop = -2
//	endif
//	String LoopStr = ""
//	if (WhichLoop == -2)
//		LoopStr = ReplaceString(WhichColumn,ParmStr,"")
//		LoopStr = ReplaceString("PISloop",LoopStr,"")
//		LoopStr = ReplaceString("%",LoopStr,"")
//		LoopStr = ReplaceString(".",LoopStr,"")
//		WhichLoop = Str2num(LoopStr)
//	endif
//	
//	
//	if (whichLoop >= 0)
//		PISLoopWave[whichLoop][%$whichColumn] = num2str(value)
//	endif
//	return td_WriteValue(parmStr,value)
//	
//end //ir_WriteValue

function ir_WV(parmStr,value)
	string parmStr
	variable value
	
	return ir_WriteValue(parmStr,value)
end //ir_WV


Function/S ir_ReadMany(ParmWave)
	Wave ParmWave
	
//	Variable Tic = StopMsTimer(-2)
//print StopMsTimer(-2)-tic
	Variable Error = td_ReadMany("",ParmWave)
//print StopMsTimer(-2)-tic
	String ParmName
	if (Error == ae_BadParm)
		Variable A, nop = DimSize(ParmWave,0)
		for (A = 0;A < nop;A += 1)
			ParmName = GetDimLabel(ParmWave,0,A)
			ParmWave[A] = td_ReadValue(ParmName)
		endfor
//		print "Error> slow backup code running"
	endif
	String output = num2str(Error)+","
	return(output)
	
End //ir_ReadMany


Function/S ir_Writemany(ParmWave,[ParentGroup])
	Wave ParmWave
	String ParentGroup
	
	
	if (ParamIsDefault(ParentGroup))
		ParentGroup = ""
	endif
//	if (Strlen(ParentGroup))
//		ParentGroup += "."
//	endif
	
	
	Variable IsText = WaveType(ParmWave) == 0
	if (IsText)
		Wave/T TextWave = $GetWavesDataFolder(ParmWave,2)
	endif
	
	
	
	
	Variable A, nop = DimSize(ParmWave,0)
	String ParmName, ErrorStr = ""
	for (A = 0;A < nop;A += 1)
		ParmName = ParentGroup+GetDimLabel(ParmWave,0,A)
		if (IsText)
			ErrorStr += num2str(td_WriteString(ParmName,TextWave[A][0]))+","
		else
			ErrorStr += num2str(td_WriteValue(ParmName,ParmWave[A][0]))+","
		endif
	endfor
	
	
	return(ErrorStr)
End //ir_WriteMany


function ir_StopPISLoop(whichLoop,[LoopName])
	variable whichLoop
	String LoopName
	
	
	String Temp
	String ErrorStr = ""
	if (!ParamIsDefault(LoopName) && Strlen(LoopName))
		Temp = td_ReadString("Alias:"+Loopname)
		if (StringMatch(Temp,"*Error*"))
			return(0)
		endif
		WhichLoop = str2num(Temp[Strlen(Temp)-1])
		if (IsNan(WhichLoop))
			return(0)
		endif
		//deal with indiviual cypher loops;
		ErrorStr += num2str(td_WriteValue("$"+LoopName+".Status",-1))+","
	endif
	
	
	String WaveNames = InitPIDSloopWaves()
	Wave/T PIDSLoopWave = $StringFromList(0,WaveNames,";")
	Wave/T PIDSGroup = $StringFromList(1,WaveNames,";")
	
	
	
	
	variable start = 0
	variable stop = 5
	variable i
	
	if (whichLoop != -1)
		start = whichLoop
		stop = whichLoop
	endif
	
	for (i = start;i <= stop;i += 1)
	
		errorStr += num2str(td_WriteValue("PIDSLoop."+num2str(i)+".Status",-1))+","
		//ErrorStr += num2str(td_WriteString("ALIAS:"+PIDSLoopWave[%LoopName][i],""))+","
		ErrorStr += num2str(td_WriteString("ALIAS:"+GetDimLabel(PIDSLoopWave,1,i),""))+","
		SetDimLabel 1,i,$"",PIDSloopWave
		ErrorStr += num2str(td_ReadGroup("PIDSloop."+num2str(i),PIDSGroup))+","
		//PIDSLoopWave[0,DimSize(PIDSloopWave,0)-2][i] = PIDSGroup[P]
		PIDSLoopWave[][i] = PIDSGroup[P]
	endfor
	if ((WhichLoop == -1) && (GV("MicroscopeID") == cMicroscopeCypher))
		Start = 0
		Stop = 3
		for (i = start;i <= stop;i += 1)
			errorStr += num2str(td_WriteValue("Cypher.PIDSLoop."+num2str(i)+".Status",-1))+","
		endfor
	endif
	ErrorStr += ReadAllAliases()	
	ARReportError(errorStr)
	return 0
end //ir_StopPISLoop	


function ir_Stop()
	
	String WaveNames = InitPIDSloopWaves()
	Wave/T PIDSLoopWave = $StringFromList(0,WaveNames,";")
	PIDSloopWave[%Status][] = "-1"
	SetDimLabels(PIDSloopWave,ListReplicate("",DimSize(PIDSloopWave,1)),1)		//clear the dim labels

	Wave/T InWaves = $InitOrDefaultTextWave(GetDF("")+"InWaves",0)
	if (numpnts(InWaves) == 0)
		Redimension/N=(5,5) InWaves
		SetDimLabels(InWaves,MakeValueStringList(4,0),0)
		SetDimLabels(InWaves,"Event;Channel;Wave;Callback;Decimation;",1)
	endif
	InWaves = ""
	
	return td_stop()
end //ir_Stop


Function/S ir_GetGroupLabels(Group)		//Jason - Code to fix an annoying bug where the XOP assignments for the XPT do not match those in the Originals directory
	String Group
	
	Wave/T TempWave = $InitOrDefaultTextWave(GetDF("Temp")+"TempText",0)
	
	
	td_GetGroupLabels(Group,TempWave)		//td_GetGroupLabels works even if controller is not turned on.
	//BUT, td_GetGroupLabels returns crap for PIDSloop.X
	//td_ReadGroup(Group,TempWave)		//so we will just read the group as well.
	//OK, looks like Todd has this fixed, so groupLabels works without the controller powered up.
	
	String output = GetDimLabels(TempWave,0)
	Return(output)

End //ir_GetGroupLabels


function FindTextMultiWave(TextWave,findMeStr,columnStr)
	wave/T TextWave
	string findMeStr, columnStr
	
	variable i, column, stop = DimSize(TextWave,0)
	if (NumType(str2num(columnStr)) == 0)
		column = str2num(columnStr)
		if ((column < 0) || (column >= DimSize(TextWave,1)))
			return NaN
		endif
		for (i = 0;i < stop;i += 1)
			if (stringmatch(TextWave[i][column],findMeStr))
				return i
			endif
		endfor
		return -1
	else
		if (FindDimLabel(TextWave,1,columnStr) == -2)
			return NaN
		endif	
		for (i = 0;i < stop;i += 1)
			if (stringmatch(TextWave[i][%$columnStr],findMeStr))
				return i
			endif
		endfor
		return -1
	
	endif

end //FindTextMultiWave


//Function PISloopSearch(InMatchList,OutMatchList)
//	String InMatchList, OutMatchList
//	
//	//More specific version of FindTextMutliWave
//	//Searches through the PISLoopWave for a pisloop (row) that matches both InMatchList and outMatchList
//	
//	
//	//EX: Variable PISIndex = PISLoopSearch("Fast%Input;R%Input;","Z%output")
//	//will find a pisloop for fast or amplitude driving Z%output
//	//This function can handle "*"
//	//EX: Variable PISIndex = PISLoopSearch("DDSAmplitude0","*")
//	//will find the first pisloop that has DDSAmplitude0 as an input and will ignore the outputs.
//	//Note, if the output or Input for a given pisloop is empty (in the wave).
//	//This function can NOT return that PISloop as a match
//	//explictly empty string does not match wildcard.
//	//(the way it is currently written).
//	
//	Wave/T PISLoopWave = root:Packages:MFP3D:Main:PISLoopWave
//
//
//	Variable A, nop = DimSize(PISloopWave,0)
//	
//	for (A = 0;A < nop;A += 1)
//		if (Strlen(ARMatchListList(PISLoopWave[A][%InChannelString],InMatchList,";")))
//			if (Strlen(ARMatchListList(PISLoopWave[A][%OutChannelString],OutMatchList,";")))
//				return(A)
//			endif
//		endif
//	endfor	
//	
//	
//	return(-1)
//	
//End //PISloopSearch


Function/S PIDSloopSearch(InMatchList,OutMatchList)
	String InMatchList, OutMatchList
	
	//More specific version of FindTextMutliWave
	//Searches through the PIDSLoopWave for a pisloop (Column) that matches both InMatchList and outMatchList
	
	
	//EX: Variable PISIndex = PIDSLoopSearch("Deflection;Amplitude;","Height")
	//will find a pisloop for deflection or amplitude driving Height
	//This function can handle "*"
	//returns the LoopName for Aliases ($LoopName.Setpoint), or td_RG(LoopName,Text)
	//EX: Variable PISIndex = PISDLoopSearch("DDSAmplitude0","*")
	//will find the first pisloop that has DDSAmplitude0 as an input and will ignore the outputs.
	//Note, if the output or Input for a given pisloop is empty (in the wave).
	//This function can NOT return that PISloop as a match
	//explictly empty string does not match wildcard.
	//(the way it is currently written).
	
	String WaveNames = InitPIDSloopWaves()
	Wave/T PIDSLoopWave = $StringFromList(0,WaveNames,";")
	String output = ""


	Variable A, nop = DimSize(PIDSLoopWave,1)
	
	for (A = 0;A < nop;A += 1)
		if (td_ReadValue("PIDSLoop."+num2str(A)+".Status") == -1)		//don't trust our value, read the controller.
		//if (Str2num(PIDSLoopWave[%Status][A]) == -1)
			continue		//this is not running
		endif
		if (Strlen(ARMatchListList(PIDSLoopWave[%InputChannel][A],InMatchList,";")))
			if (Strlen(ARMatchListList(PIDSLoopWave[%outputChannel][A],OutMatchList,";")))
				return(GetDimLabel(PIDSLoopWave,1,A))
				//return(PIDSLoopWave[%LoopName][A])
			endif
		endif
	endfor	
	
	
	return(output)
	
End //PIDSloopSearch


Function/S IR_XSetInWavePair(whichBank,eventString,channelStringA,waveA,channelStringB,waveB,callback,decimation)
	Variable WhichBank
	String EventString, ChannelStringA
	Wave WaveA
	String ChannelStringB
	Wave WaveB
	String Callback
	Variable Decimation
	
	
	
	Variable Nop
	if (WaveDims(WaveA) == 1)
		nop = DimSize(WaveA,0)
		if (mod(nop,32))
			nop += 32-mod(nop,32)
			redimension/N=(nop) WaveA,WaveB
		elseif (DimSize(WaveB,0) != nop)
			Redimension/N=(nop) WaveA,WaveB
		endif
	endif
	
	
	String ErrorStr = ""
	Wave/T InWaves = $InitOrDefaultTextWave(GetDF("")+"InWaves",0)
	if (numpnts(InWaves) == 0)
		Redimension/N=(5,5) InWaves
		SetDimLabels(InWaves,MakeValueStringList(4,0),0)
		SetDimLabels(InWaves,"Event;Channel;Wave;Callback;Decimation;",1)
	endif
	InWaves[WhichBank*2,WhichBank*2+1][] = ""
	InWaves[WhichBank*2][%Event] = EventString
	InWaves[WhichBank*2][%Channel] = ChannelStringA
	InWaves[WhichBank*2][%Wave] = GetWavesDataFolder(WaveA,2)
	InWaves[WhichBank*2][%Callback] = Callback
	InWaves[WhichBank*2][%Decimation] = num2str(Decimation)

	InWaves[WhichBank*2+1][%Event] = EventString
	InWaves[WhichBank*2+1][%Channel] = ChannelStringB
	InWaves[WhichBank*2+1][%Wave] = GetWavesDataFolder(WaveB,2)
	InWaves[WhichBank*2+1][%Callback] = Callback
	InWaves[WhichBank*2+1][%Decimation] = num2str(Decimation)
	

	ErrorStr = num2str(td_xSetInWavePair(whichBank,eventString,channelStringA,waveA,channelStringB,waveB,callback,decimation))+","
	return(ErrorStr)

End //IR_XSetInWavePair


Function/S IR_XSetInWave(whichBank,eventString,channelString,waveA,callback,decimation)
	Variable WhichBank
	String EventString, ChannelString
	Wave WaveA
	String Callback
	Variable Decimation


	Variable Nop
	if (WaveDims(WaveA) == 1)
		nop = DimSize(WaveA,0)
		if (mod(nop,32))
			nop += 32-mod(nop,32)
			redimension/N=(nop) WaveA
		endif
	endif
	
	
	String ErrorStr = ""
	
	
	Wave/T InWaves = $InitOrDefaultTextWave(GetDF("")+"InWaves",0)
	if (numpnts(InWaves) == 0)
		Redimension/N=(5,5) InWaves
		SetDimLabels(InWaves,MakeValueStringList(4,0),0)
		SetDimLabels(InWaves,"Event;Channel;Wave;Callback;Decimation;",1)
	endif
	InWaves[WhichBank*2,WhichBank*2+1][] = ""
	InWaves[WhichBank*2][%Event] = EventString
	InWaves[WhichBank*2][%Channel] = ChannelString
	InWaves[WhichBank*2][%Wave] = GetWavesDataFolder(WaveA,2)
	InWaves[WhichBank*2][%Callback] = Callback
	InWaves[WhichBank*2][%Decimation] = num2str(Decimation)
	

	ErrorStr = num2str(td_xSetInWave(whichBank,eventString,channelString,waveA,callback,decimation))+","
	return(ErrorStr)


End //IR_XSetInWave


Function/S ir_StopInWaveBank(WhichBank)
	Variable WhichBank
	
	
	
	String ErrorStr = ""
	Wave/T InWaves = $InitOrDefaultTextWave(GetDF("")+"InWaves",0)
	if (numpnts(InWaves) == 0)
		Redimension/N=(5,5) InWaves
		SetDimLabels(InWaves,MakeValueStringList(4,0),0)
		SetDimLabels(InWaves,"Event;Channel;Wave;Callback;Decimation;",1)
	endif
	
	
	if (WhichBank < 0)
		InWaves = ""
	else
		InWaves[WhichBank*2,WhichBank*2+1][] = ""
	endif
	ErrorStr = num2str(td_StopInWaveBank(WhichBank))+","
	return(ErrorStr)
	
End //Ir_StopInWaveBank
	

Function Ir_ResetInWaves()

	
	
	String ErrorStr = ""
	
	
	td_StopInWaveBank(-1)		//YES, td, NOT IR!
	
	
	Wave/T InWaves = $InitOrDefaultTextWave(GetDF("")+"InWaves",0)
	if (!NumPnts(InWaves))
		return(0)		//no info, get out
	endif
	
	Variable A, nop = 3//banks
	for (A = 0;A < nop;A += 1)
		if ((Strlen(InWaves[A*2][0])) && (Strlen(InWaves[A*2+1][0])) && (A < 2))
			Wave Data0 = $inWaves[A*2][%Wave]
			Wave Data1 = $inWaves[A*2+1][%Wave]
			ErrorStr += num2str(td_xSetInWavePair(A,InWaves[A*2][%Event],InWaves[A*2][%Channel],Data0,InWaves[A*2+1][%Channel],Data1,InWaves[A*2][%Callback],str2num(InWaves[A*2][%Decimation])))+","
		elseif (Strlen(InWaves[A*2][0]))
			Wave Data0 = $inWaves[A*2][%Wave]
			ErrorStr += num2str(td_xSetInWave(A,InWaves[A*2][%Event],InWaves[A*2][%Channel],Data0,InWaves[A*2][%Callback],str2num(InWaves[A*2][%Decimation])))+","
		else
			continue
		endif
	endfor
	
	ARReportError(ErrorStr)
	


End //IR_ResetInWaves


Function/S ir_WriteCTFC(CTFCParms)
	Struct ARCTFCParms &CTFCParms
	//must set NumOfSegmentsUsed before calling this function.
	//should be cMaxCTFCSegments until we get the CTFC overhaul.
	
	
	Wave/T CTFCParmWave = $InitOrDefaultTextWave(GetDF("Force")+"CTFCParms",0)
	String ErrorStr = ""
	//Never care about the error on reading a CTFC, it is often bogus the first time.
	td_ReadGroup("CTFC",CTFCParmWave)
	
	
	CTFCParmWave[%RampChannel][0] = CTFCParms.RampChannel
	CTFCParmWave[%Callback][0] = CTFCParms.Callback
	CTFCParmWave[%EventDwell][0] = CTFCParms.DwellEvent
	CTFCParmWave[%EventRamp][0] = CTFCParms.RampEvent
	CTFCParmWave[%EventEnable][0] = CTFCParms.StartEvent
	CTFCParmWave[%TriggerHoldoff2][0] = num2str(CTFCParms.TriggerDelay)
	
	Variable A, nop = CTFCParms.NumOfSegmentsUsed
	for (A = 0;A < Nop;A += 1)
		CTFCParmWave[%$"RampOffset"+num2str(A+1)][0] = num2str(CTFCParms.RampDistance[A])
		CTFCParmWave[%$"RampSlope"+num2str(A+1)][0] = num2str(CTFCParms.RampRate[A])
		CTFCParmWave[%$"TriggerChannel"+num2str(A+1)][0] = CTFCParms.TriggerChannel[A]
		CTFCParmWave[%$"TriggerType"+num2str(A+1)][0] = CTFCParms.TriggerType[A]
		CTFCParmWave[%$"TriggerCompare"+num2str(A+1)][0] = CTFCParms.TriggerSlope[A]
		CTFCParmWave[%$"TriggerValue"+num2str(A+1)][0] = num2str(CTFCParms.TriggerValue[A])
		CTFCParmWave[%$"DwellTime"+num2str(A+1)][0] = num2str(CTFCParms.DwellTime[A])
	endfor
	

	ErrorStr += num2str(td_WriteGroup("CTFC",CTFCParmWave))+","

	
	return(ErrorStr)
	
End //ir_WriteCTFC


Function/S ir_ReadCTFC(CTFCParms)
	Struct ARCTFCParms &CTFCParms
	
	Wave/T CTFCParmWave = $InitOrDefaultTextWave(GetDF("Force")+"CTFCParms",0)
	String ErrorStr = ""
	//Never care about the error on reading a CTFC, it is often bogus the first time.
	ErrorStr += Num2Str(td_ReadGroup("CTFC",CTFCParmWave))+","
	
	CTFCParms.RampChannel = CTFCParmWave[%RampChannel][0]
	CTFCParms.Callback = CTFCParmWave[%Callback][0]
	CTFCParms.DwellEvent = CTFCParmWave[%EventDwell][0]
	CTFCParms.RampEvent = CTFCParmWave[%EventRamp][0]
	CTFCParms.StartEvent = CTFCParmWave[%EventEnable][0]
	CTFCParms.TriggerDelay = str2num(CTFCParmWave[%TriggerHoldoff2][0])

	Variable A, nop = cMaxCTFCSegments
	for (A = 0;A < nop;A += 1)
		CTFCParms.RampDistance[A] = str2num(CTFCParmWave[%$"RampOffset"+num2str(A+1)][0])
		CTFCParms.RampRate[A] = str2num(CTFCParmWave[%$"RampSlope"+num2str(A+1)][0])
		CTFCParms.TriggerChannel[A] = CTFCParmWave[%$"TriggerChannel"+num2str(A+1)][0]
		CTFCParms.TriggerType[A] = CTFCParmWave[%$"TriggerType"+num2str(A+1)][0]
		CTFCParms.TriggerSlope[A] = CTFCParmWave[%$"TriggerCompare"+num2str(A+1)][0]
		CTFCParms.TriggerValue[A] = str2num(CTFCParmWave[%$"TriggerValue"+num2str(A+1)][0])
		CTFCParms.DwellTime[A] = str2num(CTFCParmWave[%$"DwellTime"+num2str(A+1)][0])
		CTFCParms.TriggerTime[A] = str2num(CTFCParmWave[%$"TriggerTime"+num2str(A+1)][0])
	endfor
	CTFCParms.StartTime = str2num(CTFCParmWave[%StartTime][0])
	CTFCParms.RampTrigger = str2num(CTFCParmWave[%RampTrigger][0])	
	
	
	
	return(ErrorStr)
End //ir_ReadCTFC


Function FMapBoxFunc(CtrlName,Checked)
	String CtrlName
	Variable Checked
	
	String ParmName = ARConvertName2Parm(CtrlName,"Box")
	Variable Index, A, nop, LowLimit, HighLimit
	String OtherParmName
	String ParmList = ""
	StrSwitch (ParmName)
		case "FMapSlowScanDisabled":
			ARCheckFunc(CtrlName,Checked)
			
			break
			
		case "FMapAutoName":
			ARCheckFunc(CtrlName,Checked)
			GhostForceMapPanel()
			break
			
		case "FMapUseFunc0":
		Case "FMapUseFunc1":
		case "FMapUseFunc2":
		case "FMapuseFunc3":
			ARCheckFunc(CtrlName,Checked)
			break
			
		case "FMapDisplayLVDTTraces":
			ARCheckFunc(CtrlName,Checked)
			if (Checked)
				FmapLVDTGraphFunc()
			else
				DoWindow/K FMapLVDTGraph
			endif
			break
			
		case "FMapDelayUpdate":
			ARCheckFunc(CtrlName,Checked)
			break
			
		case "FMapOffForce":
		case "FMapForceDist":
		case "FMapForceScanRate":
		case "FMapVelocity":
			ParmList = "FMapForceDist;FMapForceScanRate;FMapVelocity;"
			Index = WhichListItem(ParmName,ParmList,";",0,0)
			ParmList = RemoveListItem(index,ParmList,";")
			Wave PanelParms = $GetDF("Windows")+"ForceMapPanelParms"
			PanelParms[%HamsterNumber1][0] = Index+1
			nop = ItemsInList(ParmList,";")
			for (A = 0;A < nop;A += 1)
				UpdateAllCheckBoxes(StringFromList(A,ParmList,";")+"Box_X",0,DropEnd=1)
			endfor
			UpdateAllCheckBoxes(CtrlName,1)
			
			break
			
		case "FMapOffImage":
		case "FMapScanSize":
		case "FMapScanTime":
		case "FMapXYVelocity":
		case "FMapXOffset":
		case "FMapYOffset":
			ParmList = "FMapScanSize;FMapScanTime;FMapXYVelocity;FMapXOffset;FMapYOffset;"
			Index = WhichListItem(ParmName,ParmList,";",0,0)
			ParmList = RemoveListItem(index,ParmList,";")
			Wave PanelParms = $GetDF("Windows")+"ForceMapPanelParms"
			PanelParms[%HamsterNumber0][0] = Index+1		//this line is different//look at me.
			nop = ItemsInList(ParmList,";")
			for (A = 0;A < nop;A += 1)
				UpdateAllCheckBoxes(StringFromList(A,ParmList,";")+"Box_X",0,DropEnd=1)
			endfor
			UpdateAllCheckBoxes(CtrlName,1)
			
			break
			
		case "FMapTimeHasForceRate":
			if (Checked)
				LowLimit = .01
				HighLimit = 500
			else
				LowLimit = 1e-6
				HighLimit = 50
			endif
			OtherParmName = "FMapScanTime"
			//dont break
		case "FMapIsXYMax":
			if (StringMatch(ParmName,"FMapIsXYMax"))
				LowLimit = 1e-9*cFMapXYVelocityFactor*max(Checked*cFMapXYVelocityFactor,1)/cFMapXYVelocityFactor
				HighLimit = .0004*cFMapXYVelocityFactor*max(Checked*cFMapXYVelocityFactor,1)/cFMapXYVelocityFactor
				OtherParmName = "FMapXYVelocity"
			endif				
			ARCheckFunc(CtrlName,Checked)
			PVL(OtherParmName,LowLimit)
			PVH(OtherParmname,HighLimit)
			CalcFMapTime(StringMatch(ParmName,"*ForceRate"))
			break	
		
	endswitch
	
	
End //FMapBoxFunc


Function FMapButtonFunc(CtrlName)
	String CtrlName
	
	
	String ParmName = ARConvertName2Parm(CtrlName,"Button")
	StrSwitch (ParmName)
		case "UpFMap":
		case "DownFMap":
			if (GV("FMapStatus"))
				DoScanFunc("StopScan_4")
			endif
			PV("FMapScanDown",StringMatch(ParmName,"Down*"))
			//don't break
		case "DoFMap":
			//Double Check Parms.
			if (GV("ForceScanRate") > 2.1)
				DoAlert 0,"Force Mapping can not currently do > 2 Hz Force Scan Rate"
				return(0)
			elseif (!GV("TriggerChannel"))
				DoAlert 0,"Force Maps only work with triggered Force plots\rPlease setup your trigger point"
				return(0)
			elseif (CalcFMapTime(1,CheckSpace=1))
				return(0)
			elseif (!GV("FMapSave"))
				//now lets make sure they are saving something, these things are slow.
				//but this is a soft error, things still work, I just don't see the point
				Print "Force Map Started!\r\tBut Data is NOT being Saved!"
				DoWindow/H
				//so we let things continue
				
			//**** dont put elseif after here that return, put them above the
			//!GV("FMapSave")
			//ELSEIF, DONT do it
			endif
			
			PV("FMapCounter;FMapLineCounter;FMapPointCounter;",0)
			AR_Stop(OKList="FreqFB;Force;PotFB;FMap;")		//stop all other actions.
			PV("FMapStatus",1)
			PV("FMapPaused",0)
			Wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
			Duplicate/O MVW root:Packages:MFP3D:Main:Variables:OldMVW
			RealScanParmFunc("All","Copy")		//copy the real parms over to the RealVariablesWave
			AdjustScanWaves()
			GhostForceMapPanel()
			DoForceMap()
			break
			
		case "LastFMap":
			PV("FMapStatus",2)
			GhostForceMapPanel()
			break
		
		case "FMapTimePrefs":
			MakeFMapPrefPanel(1)
			break
			
		case "ClearImage":
			break
			
		case "PauseFMap":
			PauseFMap(0)
			break
			
		case "RestartFMap":
			PauseFMap(-1)
			break
			
	endswitch
	
	
End //FMapButtonFunc


Function DoForceMap()




//	//Update the SaveForce path if needed.
//	String PName = "SaveForce"
//	Variable EndNum = 0
//	if (GV("SaveForce") & 2)
//		if (SafePathInfo(PName))
//			PathInfo $PName
//			String CurrentFolder = LastDir(S_Path)
//			EndNum = GetEndNum(CurrentFolder)
//			if ((!IsNan(EndNum)) && (StringMatch(CurrentFolder,"ForceMap"+num2str(EndNum))))
//				//we have already saved to a SubFolder
//				NewPath/C/O/Q/Z $PName UpDir(S_Path)+":ForceMap"+num2str(EndNum+1)
//			else
//				NewPath/C/O/Q/Z $Pname S_Path+"ForceMap0"
//			endif
//		endif
//	else
//		//we need to store the folder in a global string.
//		String ParmFolder = ARGetForceFolder("Parameters","")
//		Wave/T ForceFolderListWave = $ParmFolder+"ForceFolderListWave"
//		SVAR FMapDestFolder = $InitOrDefaultString(ParmFolder+"FMapDestFolder","")
//		
//		EndNum = 0
//		Variable Index = Find1Twave(ForceFolderListWave,"ForceMap"+num2str(EndNum))
//		
//		if (Index >= 0)
//			do
//				Index = Find1Twave(ForceFolderListWave,"ForceMap"+num2str(EndNum))
//				EndNum += 1
//			while (Index >= 0)
//			EndNum -= 1
//		endif
//		FMapDestFolder = "ForceMap"+num2str(EndNum)
//		
//	endif

	if (GV("ShowXYSpot"))
		PutOnXYSpot(1)
		ARBackground("RedSpotBackground",0,"")		//stop the background from running, it is too slow
	endif
	
		
	ARManageRunning("FMap",1)		//we are now doing a force map.
	ReCalcFMapMatrix()
	Struct ARFMapParms Parms
	GetARFMapParms(Parms)
	Wave XPoints = Parms.XPoints
	Wave YPoints = Parms.YPoints

	String ErrorStr = ""
	Variable XIgain = Parms.XLVDTSens*10^GV("XIGain")
	Variable YIgain = Parms.YLVDTSens*10^GV("YIGain")
	
	
	Variable XStart, YStart, TotalTime
	String RampChannelX, RampChannelY
	
	
	if (Parms.XYClosedLoop)
		RampChannelX = "$outputXLoop.Setpoint"
		RampChannelY = "$outputYLoop.Setpoint"
	
		Xstart = td_ReadValue("XSensor")		//calculate where the XY actually is with the gains and
		Ystart = td_ReadValue("YSensor")		//offset that we will be using
		
		
		Struct ARFeedbackStruct FB
		ARGetFeedbackParms(FB,"outputX")
		FB.SetpointOffset = 0
		FB.Setpoint = XStart
		IR_WritePIDSloop(FB)

		ARGetFeedbackParms(FB,"outputY")
		FB.SetpointOffset = 0
		FB.Setpoint = YStart
		IR_WritePIDSloop(FB)

		TotalTime = sqrt(((Parms.XPoints[Parms.Counter]-XStart)*abs(Parms.XLVDTSens))^2+((Parms.YPoints[Parms.Counter]-YStart)*abs(Parms.YLVDTSens))^2)/Parms.ScanSpeed
	else			//open loop
		RampChannelX = "output.X"
		RampChannelY = "output.Y"
	
		Xstart = td_ReadValue(RampChannelX)		//calculate where the XY actually is with the gains and
		Ystart = td_ReadValue(RampChannelY)		//offset that we will be using
		
		
		ir_StopPISLoop(NaN,LoopName="outputXLoop")
		ir_StopPISLoop(NaN,LoopName="outputYLoop")
		
		
		TotalTime = sqrt(((Parms.XPoints[Parms.Counter]-XStart)*Parms.XPiezoSens)^2+((Parms.YPoints[Parms.Counter]-YStart)*Parms.YPiezoSens)^2)/Parms.ScanSpeed
	endif
	
	TotalTime = Min(TotalTime,5)		//don't spend more than 5 seconds starting things, people have things to do.
	SineRamp(Parms.XPoints[Parms.Counter],Parms.YPoints[Parms.Counter],RampChannelX,RampChannelY,TotalTime,Parms.RampX,Parms.RampY,2,"4","ARFMapRampCallback(Init=1)")
	ErrorStr += num2str(td_WriteString("Event.4","Once"))+","
	
	
	//time to setup the force plot stuff.
	//DoForceFunc("
	
	ARReportError(ErrorStr)


End //DoForceMap


Function RecalcFMapMatrix()

	Struct ARFMapParms Parms
	GetARFMapParms(Parms)
	Wave XPoints = Parms.XPoints
	Wave YPoints = Parms.YPoints
	
	Redimension/n=(Parms.nopX*Parms.NopY) Parms.XPoints,Parms.YPoints
	Redimension/n=(Parms.nopX*Parms.nopY)/C Parms.ComplexWave
	XPoints = (abs((Parms.nopX-1)*mod(floor(P/Parms.nopX),2-Parms.Bookwise)-mod(P,Parms.nopX))/(Parms.nopX-1)-.5)
//	XPoints = abs((Parms.nopX-1)*mod(floor(P/Parms.nopX),1)-mod(P,Parms.nopX))/(Parms.nopX-1)-.5
	
	YPoints = (floor(P/Parms.nopX)/(Parms.nopY-1)-.5)
	FastOp YPoints = (1/Max(Parms.ScanRatio,1))*YPoints
	FastOp XPoints = (min(Parms.ScanRatio,1))*XPoints
	Parms.ComplexWave = rotateWave(YPoints[P],XPoints[P],Parms.ScanAngle)
	XPoints = Imag(Parms.ComplexWave[P])
	YPoints = Real(Parms.ComplexWave[P])
	
	
	//X
	FastOp XPoints = (Parms.ScanSize/abs(Parms.XLVDTSens))*XPoints+(Parms.XOffset/abs(Parms.XLVDTSens)+Parms.XLVDTOffset)
	
	
	//Y
	FastOp YPoints = (Parms.ScanSize/abs(Parms.YLVDTSens))*YPoints+(Parms.YOffset/abs(Parms.YLVDTSens)+Parms.YLVDTOffset)
	if (!Parms.FrameUp)
		//flip the matrix
		FlipVector(XPoints)
		FlipVector(YPoints)
	endif
	UpdateForceMapXYTime()
	

End //RecalcFMapMatrix


Function CheckFMapSaveStatus()


End //CheckFMapSaveStatus


Function SaveFMapData([Done])
	Variable Done
	
	if (ParamIsDefault(Done))
		Done = 0
	endif
	
	Variable Status = GV("ScanStatus")+2*GV("FMapStatus")
	if (Done)
		if (Status)
			DoScanFunc("StopScan_0")
		endif
	endif
	
	
	
	
	
	
	
	
	if (Done == 1)		//enter a single value, we can start up the next scan
		Execute/P/Q "FMapButtonFunc(\"DoFMap_4\")"
	endif
	
	
ENd //SaveFMapData


Function CalcFMapTime(KeepVelocity,[CheckSpace])
	Variable KeepVelocity
	Variable CheckSpace

//OK, the user had changed:
//FMapScanPoints
//ForceScanRate
//ScanSize
//SlowRatio

//and so we must recalculte XYVelocity and ScanLineTime
//trying to keep one of them constant

//or the user had changed 
//FMapXYVelocity
//FMapScanTime
//and we need to enforce limits and calc the other.

	Variable ScanPoints = GV("FMapScanPoints")
	Variable ScanLines = GV("FMapScanLines")
	Variable ForceScanRate = GV("ForceScanRate")
	Variable Velocity = GV("FMapXYVelocity")

	
	
	if (ParamIsDefault(CheckSpace))
		CheckSpace = 0
	endif
	
	
	
	Variable TimeScale
	String TimeUnits = GUS("FMapScanTime")
	if (StringMatch(TimeUnits,"Min*"))
		TimeScale = 60
	elseif (StringMatch(TimeUnits,"Hour*"))
		TimeScale = 60^2
	endif

	Variable ScanSize = GV("ScanSize")
	Variable Ratio = GV("FastRatio")/GV("SlowRatio")
	
	
	
	Variable FastSize = ScanSize/Max(Ratio,1)
	Variable SlowSize = ScanSize*min(Ratio,1)
	Variable IsMax = GV("FMapIsXYMax")		//I have hidden the interface to change this, but will keep the depenancy on the parm.
	Variable MaxFactor = cFMapXYVelocityFactor		//conversion factor from max to average.
	
	
	Variable HasFRate = GV("FMapTimeHasForceRate")
	Variable ScanTime = GV("FMapScanTime")*TimeScale  //Seconds
	//We don't need to worry about synch, since the rate takes that into account
	Variable DwellTime = GV("DwellTime")
	if (!GV("DwellSetting"))
		DwellTime = 0
	endif
	//we know we are triggered, so just check if a custom dwell is being used.
	
	
	Variable DoIV = GV("ARDoIVFP")
	Variable ImagingMode = GV("ImagingMode")
	wave PanelParm = root:Packages:MFP3D:Main:Windows:ForceChannelPanelParms
	DoIV *= ((!(!PanelParm[%Current][0])) || (ImagingMode == 3))		//if imagingMode is 3 (PFM)
	
	String DwellFolder = GetDF("Force:Dwell")
	Wave/Z TempWave = $DwellFolder+"DwellDriveWave"
	Variable IndentMode = GV("IndentMode")
	if (WaveExists(TempWave) == 0)
		UpdateARIndentDwell()
		Wave/Z TempWave = $DwellFolder+"DwellDriveWave"
	endif
	IndentMode *= WaveExists(TempWave)
	if ((!IndentMode) && (!WaveExists(TempWave)))
		Wave/Z TempWave = $GetDF("DoIV")+"DriveWave"
		if (!WaveExists(TempWave))
			ARDoIVMakeDriveWave($InitOrDefaultWave(GetDF("DoIV")+"DriveWave",0))
			Wave/Z TempWave = $GetDF("Force:Dwell")+"DwellDriveWave"
		endif
		DoIV *= WaveExists(TempWave)
	endif
		
	if (DoIV || IndentMode)
		DwellTime = rightx(TempWave)-.01		//taken from FinishForceFunc
	endif
	
	
	Variable ForceTime = 1/ForceScanRate+DwellTime		//seconds per force plot
	Variable nop = ScanLines*ScanPoints
	Variable RampDist = FastSize*ScanLines+SlowSize	 	//total XY Distance we will travel.
	Variable XYRampTime = RampDist/Velocity
	
	Variable TabNum = ARPanelTabNumLookup("ForceMapPanel")
	String TabStr = num2str(TabNum)



	String OrderList = ""
	if (KeepVelocity)
		OrderList = "ScanTime;Velocity;"
	else
		OrderList = "Velocity;ScanTime;"
	endif
	
	String ParmName, Units
	Variable B, nopB = ItemsInList(OrderList,";")
	for (B = 0;B < nopB;B += 1)
		ParmName = StringFromList(B,OrderList,";")
		StrSwitch (ParmName)
			case "ScanTime":
				ScanTime = ForceTime*nop+XYRampTime
				//if > 1 hour, then those are our units
				if (ScanTime > 3600)
					Units = "hours"
					TimeScale = 3600
				else
					Units = "Mins"
					TimeScale = 60
				endif
				PUS("FMapScanTime",Units)
				ScanTime /= TimeScale
				ARSetVarFunc("FMapScanTimeSetVar_"+TabStr,ScanTime,"",":Variables:ForceVariablesWave[%FMapScanTime]")
				ScanTime = GV("FMapScanTime")*TimeScale
				break
				
			case "Velocity":
				Velocity = RampDist/(ScanTime-ForceTime*nop)
				if (IsMax)
					Velocity *= MaxFactor
				endif
				if (Velocity < 0)
					Velocity = inf
				endif
				ARSetVarFunc("FMapXYVelocitySetVar_"+TabStr,Velocity,"",":Variables:ForceVariablesWave[%FMapXYVelocity]")
				XYRampTime = RampDist/Velocity
				break
				
		endswitch
		
	endfor
	if (!CheckSpace)
		return(0)
	endif

	Variable NPPS = GV("NumPtsPerSec")
	Variable ForcePoints = NPPS*ForceTime
	Variable OverHead = 8194		//bytes of extra used space
	//mostly from the note, which seemed to be about 6732 chars when above test was run
	MakeSaveWave()
	Wave SaveWave = root:Packages:MFP3D:Force:SaveWave
	Variable Channels = DimSize(SaveWave,1)
	
	Variable FPSize = ForcePoints*Channels*4		//32 bit wave = 4 byte points
	FPSize += OverHead
	FPSize *= nop
	
	Variable FreeSpace = GetFreeDiskSpace("RealSaveForce")
	
	
	if (FPSize/FreeSpace > .9)		//if it will take 90% or more of the disk space, we worry.
	
		String Message = "Your Force Map will take approx. "+Bytes2Str(FPSize)+"\r"
		Message += "You only have "+bytes2Str(FreeSpace)+" left on the HD"
		ARDoAlert(Message,-1,0)
		return(1)
	
	endif
	return(0)
	
	

End //CalcFMapTime


Function MakeFMapPrefPanel(Var)
	Variable Var
	
	
	String GraphStr = GetFuncName()
	GraphStr = GraphStr[4,Strlen(GraphStr)-1]
	DoWindow/F $GraphStr
	if (!V_Flag)
		NewPanel/N=$Graphstr/K=1
	endif
	String WindowsFolder = GetDF("Windows")
	Wave PanelParms = $WindowsFolder+"ForceMapPanelParms"
	Variable Red = PanelParms[%RedColor][0]
	Variable Green = PanelParms[%GreenColor][0]
	Variable Blue = PanelParms[%BlueColor][0]
	
	Variable CurrentTop = 15
	String ParmName, ControlName
	ParmName = "FMapTimeHasForceRate"
	ControlName = ParmName+"Box"
	MakeCheckbox(GraphStr,ControlName,"Scan Line Time includes Force Plot Time",20,CurrentTop,"FMapBoxFunc",GV(ParmName),0,0)
	CurrentTop += 25
	
	
	ParmName = "FMapIsXYMax"
	ControlName = ParmName+"Box"
	MakeCheckbox(GraphStr,ControlName,"Is XY Velocity Max (checked) or average (unchecked)",20,CurrentTop,"FMapBoxFunc",GV(ParmName),0,0)
	CurrentTop += 25
	
	
	
	ScalePanel(GraphStr)
	ARDrawRect(GraphStr,Red,Green,Blue)
	
	
End //MakeFMapPrefPanel


Function SineRamp(Dest0,Dest1,Chan0,Chan1,TotalTime,Ramp0,Ramp1,Bank,Event,Callback,[Method])
	Variable Dest0, Dest1
	String Chan0, Chan1
	Variable TotalTime
	Wave Ramp0,Ramp1
	Variable Bank
	String Event
	String Callback
	String Method
	if (ParamIsDefault(Method))
		Method = "Custom"
	endif
	
	Redimension/S Ramp0,Ramp1		//must be singles
	
	Variable Start0 = td_ReadValue(Chan0)
	Variable Start1 = td_ReadValue(Chan1)
	
	
	Variable Dist0 = Dest0-Start0
	Variable Dist1 = Dest1-Start1
	
	
	Variable nop = 128
	Variable Deci = round(cMasterSampleRate*TotalTime/nop)
	Deci = Max(Deci,1)
	nop = round(cMasterSampleRate*TotalTime/Deci)
//Print Deci,Nop,TotalTime	
	
	if ((nop <= 5) || IsNan(Nop))		//very bad.
		//but it probably means we are already there.
		//so just execute the callback.
		Execute/P/Q/Z Callback
		return(0)
	endif
	
	
	Wave Temp = $InitOrDefaultWave(GetDF("Temp")+GetFuncName()+"Wave",nop)
	Redimension/S Temp
	String LastMethod = Note(Temp)
	if (!Stringmatch(LastMethod,Method) || (DimSize(Temp,0) != nop))
		redimension/N=(nop) Temp
		StrSwitch (Method)
			case "Custom":
			case "Clint":
			case "Red":
				//this is some special adaption of sine waves that clint came up with
				//does the best job with minimizing overshoot
				Temp[0,nop/4] = .5*sin(P/(nop-1)*pi*4+PI*3/2)+.5
				Temp[nop*3/4,nop-1] = -.5*sin(P/(nop-1)*pi*4+PI*3/2)+-.5
				Temp[nop/4,nop*3/4] = sin((P/(nop-1)+1)*pi*2)
				Integrate Temp
				Integrate Temp
				break
				
			case "Accel":
			case "Acceleration":
			case "Blue":
			//Acelation is a sine wave.
				Temp = sin(P/(nop-1)*2*Pi)
				Integrate Temp
				Integrate Temp
				break
			
			case "Vel":
			case "Velocity":
			case "Black":
			//Velocity is a sine wave
				Temp = Sin(P/(Nop-1)*PI)
				Integrate Temp
				break
				
			case "Line":
			case "Linear":
			case "Nuts":
				Temp = P/(nop-1)
				break
			
		endswitch
		//WaveStats/Q Temp
		FastOp Temp = (1/Temp[nop-1])*Temp
	endif
	Redimension/N=(nop) Ramp0,Ramp1
	FastOp Ramp0 = (Dist0)*Temp+(Start0)
	FastOp Ramp1 = (Dist1)*Temp+(Start1)
	
	
	
	
	//set it up!
	String ErrorStr = ""
	ErrorStr += num2str(td_WriteString("Event."+event,"Clear"))+","
	Variable Error
	Error = td_xSetOutWavePair(Bank,Event,Chan0,Ramp0,Chan1,Ramp1,Deci)
	if (Error == ae_USB)		//there was a problem sending down the wave, try again...
		Error = td_xSetOutWavePair(Bank,Event,Chan0,Ramp0,Chan1,Ramp1,Deci)
		print "Problem sending down the ramp waves at "+Time()+"  "+Date()+", resending..."
	endif
	ErrorStr += num2str(Error)+","
	ErrorStr += num2str(td_WriteString("OutWave"+num2str(Bank)+"StatusCallback",Callback))+","
	
	ARReportError(ErrorStr)
	
	
	
End //SineRamp


Function ARFMapRampCallback([Init])
	Variable Init
	if (ParamIsDefault(Init))
		Init = 0
	endif

	String DataFolder = GetDF("Variables")
	Wave FVW = $DataFolder+"ForceVariablesWave"


	if (Init)
		//we need to do a real force plot first.
//		NVAR TIC = root:TIC
//		Tic = stopMsTimer(-2)
		DoForceFunc("ManyForce_2")
		FVW[%ContForce][0] = 2
		//PV("ContForce",2)
//		
//	else
//		//we just do our already setup force plot
//		td_WriteString("CTFC.EventEnable","0")
//		ir_ResetInWaves()
//		td_WriteString("Event.0","Once")
//		
	endif
	Struct ARFMapParms Parms
	GetARFMapParms(Parms)

	Parms.Counter += 1
	FVW[%FMapCounter][0] = Parms.Counter
	//PV("FMapCounter",Parms.Counter)
	if (Parms.Counter >= Parms.nopX*Parms.nopY)
		//DoScanFunc("StopScan_0")
		//we are all done
		//Do our clean up.
		//nope, the last force plot is running.
		DoForceFunc("StopTriggerForce_2")
		FVW[%FMapScanDown][0] = !FVW[%FMapScanDown][0]
		//PV("FMapScanDown",!GV("FMapScanDown"))
		//DoScanFunc("StopScan_4")
		return(0)
	endif
	Variable TotalTime
	String RampChannelX, RampChannelY
	
	
	if (Parms.XYClosedLoop)
		RampChannelX = "$outputXLoop.Setpoint"
		RampChannelY = "$outputYLoop.Setpoint"
		TotalTime = sqrt(((Parms.XPoints[Parms.Counter]-Parms.XPoints[Parms.Counter-1])*abs(Parms.XLVDTSens))^2+((Parms.YPoints[Parms.Counter]-Parms.YPoints[Parms.Counter-1])*abs(Parms.YLVDTSens))^2)/Parms.ScanSpeed
	else		//open loops
		RampChannelX = "output.X"
		RampChannelY = "output.Y"
		TotalTime = sqrt(((Parms.XPoints[Parms.Counter]-Parms.XPoints[Parms.Counter-1])*Parms.XPiezoSens)^2+((Parms.YPoints[Parms.Counter]-Parms.YPoints[Parms.Counter-1])*Parms.YPiezoSens)^2)/Parms.ScanSpeed
		
	endif

	String ErrorStr = ""

	SineRamp(Parms.XPoints[Parms.Counter],Parms.YPoints[Parms.Counter],RampChannelX,RampChannelY,TotalTime,Parms.RampX,Parms.RampY,2,"4","")
	//ErrorStr += num2str(td_WriteString("Event.4","Once"))+","
	
	if (FVW[%FMapDisplayLVDTTraces][0])
		//work up our display waves.
		Duplicate/O Parms.RampX,$Parms.DataFolder+"XRampWaveLast"
		Duplicate/O Parms.RampY,$Parms.DataFolder+"YRampWaveLast"
//		Wave XDisplay = $Parms.DataFolder+"XRampWaveLast"
//		Wave YDisplay = $Parms.DataFolder+"YRampWaveLast"
//		FastOp XDisplay = (Parms.XLVDTSens)*XDisplay
//		FastOp YDisplay = (Parms.YLVDTSens)*YDisplay
//		SetScale d,0,0,"m",XDisplay,YDisplay
		//No, timing is going to be a <edit>
		//so we will just waite for the input wave callback to hit
		//the input waves should be longer (always?)
	endif
	

	ARReportError(ErrorStr)
	
	if (FVW[%ShowXYSpot][0])
		RedSpotBackground()
	endif
	
	

End //ARFMapRampCallback


Function GetARFMapParms(Parms)
	Struct ARFMapParms &Parms
//runs in 0.000876648 seconds on old 2 GHz rig.
	String DataFolder = GetDF("Variables")
	Wave RVW = $DataFolder+"RealVariablesWave"
	Wave MVW = $DataFolder+"MasterVariablesWave"
	Wave FVW = $DataFolder+"ForceVariablesWave"
	Parms.nopX = RVW[%FMapScanPoints][0]
	Parms.nopY = RVW[%FMapScanLines][0]
	Parms.ScanSize = RVW[%ScanSize][0]
	Parms.XOffset = RVW[%XOffset][0]
	Parms.YOffset = RVW[%YOffset][0]
	Parms.XLVDTSens = MVW[%XLVDTSens][0]
	Parms.YLVDTSens = MVW[%YLVDTSens][0]
	Parms.XPiezoSens = MVW[%XPiezoSens][0]
	Parms.YPiezoSens = MVW[%YPiezoSens][0]
	Parms.XLVDTOffset = MVW[%XLVDTOffset][0]
	Parms.YLVDTOffset = MVW[%YLVDTOffset][0]
	Parms.ScanAngle = RVW[%ScanAngle][0]
	Parms.ScanSpeed = RVW[%FMapXYVelocity][0]
	Parms.XYClosedLoop = MVW[%ScanMode][0] == 0
	Parms.Counter = FVW[%FMapCounter][0]
	Parms.FrameUp = !FVW[%FMapScanDown][0]
	Parms.ScanRatio = RVW[%FastRatio][0]/RVW[%SlowRatio][0]
	Parms.BookWise = !(!FVW[%FMapBookwise][0])
	
	Parms.DataFolder = GetDF("FMap")
	Wave Parms.XPoints = $InitOrDefaultWave(Parms.DataFolder+"XPoints",0)
	Wave Parms.YPoints = $InitOrDefaultWave(Parms.DataFolder+"YPoints",0)
	Wave/C Parms.ComplexWave = $InitOrDefaultWave(Parms.DataFolder+"ComplexWave",0)
	Wave Parms.RampX = $InitOrDefaultWave(Parms.DataFolder+"RampX",0)
	Wave Parms.RampY = $InitOrDefaultWave(Parms.DataFolder+"RampY",0)

	
End //GetARFMapParms


//
//
//Function ir_SetInWavePair(whichBank, eventString, channelStringA, waveA, channelStringB, waveB, callback, decimation)
//Variable WhichBank
//String EventString, ChannelStringA
//Wave WaveA
//String ChannelStringB
//Wave waveB
//String Callback
//Variable decimation
//
//
//
//Wave/T InWaves = $InitOrDefaultTextWave("root:Packages:MFP3D:Main:InWaves",0)
//if (!DimSize(InWaves,0))
//	Redimension/N=(5,5) InWaves
//	SetDimLabels(InWaves,"Event;Channel;Data;Callback;decimation;",1)
//endif
//InWaves[WhichBank*2,WhichBank*2+1][%Event] = EventString
//InWaves[WhichBank*2,WhichBank*2+1][%Callback] = Callback
//InWaves[WhichBank*2,WhichBank*2+1][%decimation] = num2str(decimation)
//InWaves[WhichBank*2][%Data] = GetWavesDataFolder(WaveA,2)
//InWaves[WhichBank*2+1][%Data] = GetWavesDataFolder(WaveB,2)
//InWaves[WhichBank*2][%Channel] = ChannelStringA
//InWaves[WhichBank*2+1][%Channel] = ChannelStringB
//
//
//Variable output = td_xSetInWavePair(whichBank, eventString, channelStringA, waveA, channelStringB, waveB, callback, decimation)
//return(output)
//
//
//End //ir_SetInWavePair
//
//
//
//Function ir_SetInWave(whichBank, eventString, channelString, Data, callback, decimation)
//Variable WhichBank
//String EventString, ChannelString
//Wave Data
//String Callback
//Variable decimation
//
//
//
//Wave/T InWaves = $InitOrDefaultTextWave("root:Packages:MFP3D:Main:InWaves",0)
//if (!DimSize(InWaves,0))
//	Redimension/N=(5,5) InWaves
//	SetDimLabels(InWaves,"Event;Channel;Data;Callback;decimation;",1)
//endif
//
//InWaves[WhichBank*2+1][] = ""
//InWaves[WhichBank*2][%Event] = EventString
//InWaves[WhichBank*2][%Callback] = Callback
//InWaves[WhichBank*2][%decimation] = num2str(decimation)
//InWaves[WhichBank*2][%Data] = GetWavesDataFolder(Data,2)
//InWaves[WhichBank*2][%Channel] = ChannelString
//
//
//Variable output = td_xSetInWave(whichBank, eventString, channelString,Data, callback, decimation)
//return(output)
//
//
//End //ir_SetInWave
//
//
//
//Function ir_ResetInWaves()
//
//	
//	Wave/T/Z InWaves = root:Packages:MFP3D:Main:InWaves
//	if (!WaveEXists(InWaves))
//		return(1)
//	endif
//	
//	Variable A, output = 0
//	for (A=0;A<3;A+=1)
//		if (!Strlen(InWaves[A*2][%Event]))
//			continue
//		elseif ((A==2) || (!Strlen(InWaves[A*2+1][%Event])))
//			output += td_xSetInWave(A,InWaves[A*2][%Event],InWaves[A*2][%Channel],$InWaves[A*2][%Data],InWaves[A*2][%Callback],str2num(InWaves[A*2][%Decimation]))
//		else
//			output += td_xSetInWavePair(A,InWaves[A*2][%Event],InWaves[A*2][%Channel],$InWaves[A*2][%Data],InWaves[A*2+1][%Channel],$InWaves[A*2+1][%Data],InWaves[A*2][%Callback],str2num(InWaves[A*2][%Decimation]))
//		endif
//	endfor
//	
//	return(output)
//
//
//End //ir_ResetInWaves



Function FMapBaseNameSetVarFunc(ctrlName,varNum,varStr,varName)
	String ctrlName
	Variable varNum
	String varStr	
	String varName
	//takes care of the Force Map base name

	PostARMacro(CtrlName,VarNum,VarStr,VarName)
	
	
	
	if (stringmatch(ctrlName,"FMapBaseSuffix*"))
		if (numtype(VarNum) != 0)
			VarNum = 0
		endif
		VarNum /= 10^(max(strlen(num2istr(VarNum))-2,0))
		VarNum = floor(Abs(VarNum))
		PV("FmapBaseSuffix",varNum)
		return 0
	endif
	
	if (!Strlen(VarStr))
		VarStr = "ForceMap"
	endif
	
	
	String NewVarStr = CleanUpname(VarStr,0)
	NewVarStr = NewVarStr[0,7]
	
	if (stringmatch(varStr,NewVarStr) == 0)			//check to see if the name is legal, warn if not
		DoAlert 0, "Your Base Name had illegal characters\rOnly letters, numbers, and \"_\" are allowed\rIt also has to start with a letter, cannot contain the string \"Mask\", and must be <= 8 characters long.  It has been fixed."
		varStr = NewVarStr
	endif
	
	//Force, BaseName = 17, suffix ("0001") = 4, DataType ("Force") = 5, Section ("_Away") = 5
	//total = 31
	
	SVAR FMapBaseName = root:Packages:MFP3D:Main:Variables:FmapBaseName
	FMapBaseName = varStr
	PV("FmapBaseSuffix",0)													//reset the suffix to 0
	ARCheckFMapSuffix()

End //FMapBaseNameSetVarFunc


Function FMapLVDTDisplayCallback()

	Struct ARFMapParms Parms
	GetARFMapParms(Parms)

	Wave/Z RampX = $Parms.DataFolder+"XRampWaveLast"
	if (!WaveExists(RampX))
		return(0)
	endif
	Wave RampY = $Parms.DataFolder+"YRampWaveLast"
	Wave XLVDTWave = $Parms.DataFolder+"XLVDTWave"
	Wave YLVDTWave = $Parms.DataFolder+"YLVDTWave"
	
	
	Duplicate/O RampX,$Parms.DataFolder+"XRampWaveDisplay"
	Wave RampX = $Parms.DataFolder+"XRampWaveDisplay"
	Duplicate/O RampY,$Parms.DataFolder+"YRampWaveDisplay"
	Wave RampY = $Parms.DataFolder+"YRampWaveDisplay"
	
	
	Wave XResid = $InitOrDefaultWave(Parms.DataFolder+"XDiffWave",0)
	Wave YResid = $InitOrDefaultWave(Parms.DataFolder+"YDiffWave",0)
	
	
	Redimension/N=(DimSize(XLVDTWave,0)) XResid,YResid
	CopyScales/P XLVDTWave,XResid,YResid
	
	
	
	CurveFit/NTHR=1/TBOX=0/Q poly 9, RampX
	Wave/D W_Coef = W_Coef
	
	
	XResid = X < Rightx(RampX) ? Poly(W_Coef,X)-XLVDTWave[P] : RampX[DimSize(RampX,0)-1]-XLVDTWave[P]
	
	
	//XResid = RampX[x2pnt(RampX,X)]-XLVDTWave[P]
	
	CurveFit/NTHR=1/TBOX=0/Q poly 9, RampY
	
	YResid = X < Rightx(RampY) ? Poly(W_Coef,X)-YLVDTWave[P] : RampY[DimSize(RampY,0)-1]-YLVDTWave[P]
	//YResid = RampY[x2pnt(RampY,X)]-YLVDTWave[P]
	
	//Scale all to distance.
	FastOp XLVDTWave = (abs(Parms.XLVDTSens))*XLVDTWave
	FastOp XResid = (abs(Parms.XLVDTSens))*XResid
	FastOp RampX = (abs(Parms.XLVDTSens))*RampX
	
	FastOp YLVDTWave = (abs(Parms.YLVDTSens))*YLVDTWave
	FastOp YResid = (abs(Parms.YLVDTSens))*YResid
	FastOp RampY = (abs(Parms.YLVDTSens))*RampY
	
	SetScale d,0,0,"m",XLVDTWave,XResid,RampX,YLVDTWave,YResid,RampY
	
	
	//td_stop()


End //FMapLVDTDisplayCallback


Function FmapLVDTGraphFunc()
	String GraphStr = "FMapLVDTGraph"
	DoWindow/F $GraphStr
	if (V_Flag)
		return(0)
	endif
	String DataFolder = GetDF("FMap")
	
	
	Wave YLVDTWave = $InitOrDefaultWave(DataFolder+"YLVDTWave",0)
	Wave XLVDTWave = $InitOrDefaultWave(DataFolder+"XLVDTWave",0)
	Wave XRampWaveDisplay = $InitOrDefaultWave(DataFolder+"XRampWaveDisplay",0)
	Wave YRampWaveDisplay = $InitOrDefaultWave(DataFolder+"YRampWaveDisplay",0)
	Wave XDiffWave = $InitOrDefaultWave(DataFolder+"XDiffWave",0)
	Wave YDiffWave = $InitOrDefaultWave(DataFolder+"YDiffWave",0)
	
	Display/N=$GraphStr/W=(1069.2,120.2,1611,485.6)/K=1/L=YWaves/Hide=1 YLVDTWave
	AppendToGraph/W=$GraphStr/L=XWaves XLVDTWave
	AppendToGraph/W=$GraphStr/L=YWaves YRampWaveDisplay
	AppendToGraph/W=$GraphStr/L=XWaves XRampWaveDisplay
	AppendToGraph/W=$GraphStr/L=YResid YDiffWave
	AppendToGraph/W=$GraphStr/L=XResid XDiffWave

	ModifyGraph/W=$GraphStr margin(top)=36
	ModifyGraph/W=$GraphStr lSize(YRampWaveDisplay)=2,lSize(XRampWaveDisplay)=2
	ModifyGraph/W=$GraphStr rgb(YLVDTWave)=(0,12800,52224),rgb(XLVDTWave)=(0,12800,52224)
	ModifyGraph/W=$GraphStr lblPos=90
	ModifyGraph/W=$GraphStr freePos(YWaves)={0,bottom}
	ModifyGraph/W=$GraphStr freePos(XWaves)={0,bottom}
	ModifyGraph/W=$GraphStr freePos(YResid)={0,bottom}
	ModifyGraph/W=$GraphStr freePos(XResid)={0,bottom}
	ModifyGraph/W=$GraphStr axisEnab(YWaves)={0.5,0.73}
	ModifyGraph/W=$GraphStr axisEnab(bottom)={0.15,1}
	ModifyGraph/W=$GraphStr axisEnab(XWaves)={0,0.23}
	ModifyGraph/W=$GraphStr axisEnab(YResid)={0.75,1}
	ModifyGraph/W=$GraphStr axisEnab(XResid)={0.25,0.48}
	Label/W=$GraphStr YWaves "Y Tracking"
	Label/W=$GraphStr XWaves "X Tracking"
	Label/W=$GraphStr YResid "Y Diff"
	Label/W=$GraphStr XResid "X Diff"
	Legend/W=$GraphStr/C/N=text0/J/F=0/A=MC/X=5.91/Y=55.51 "\\s(YLVDTWave) Collected                   \\s(YRampWaveDisplay) Setpoint\r"
	SetWindow $GraphStr,Hide=0
End //FMapLVDTGraphFunc


Function ForcePlotCleanUp()
	
	//OK, we have a couple of places to come in here.
	
	//1
	//		all is good, but we have reached the end of batch of curves.
	//2
	//		we are doing a force map, but ran out of Z range, on either end
	//		of the range.
	
	
	//if this is called when all is good
	//then the output will tell us if we do a few other things at the end of TriggerScale
	//If output is 1, we do the other things
	//otherwise we don't
	
	
	Wave FVW = root:Packages:MFP3D:Main:Variables:ForceVariablesWave
	Wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	Variable ContForce = FVW[%ContForce][0]
	Variable SaveForce = FVW[%SaveForce][0]
	Variable FMapStatus = FVW[%FMapStatus][0]
	if (FMapStatus)
		SaveForce = FVW[%FMapSaveForce][0]
	endif
	String OutputName = ""
	String ImageFolder = GetDF("ImageRoot")
	Variable Index
	String PName
	String ErrorStr = ""

	if (ContForce == 0)

		HideForceButtons("Stop")					//change the buttons if we are not still pulling
		ErrorStr += SetLowNoise(0)
		ForceRealTimeUpdateOffline()
		ARCallbackFunc("ForceDone")
		ARManageRunning("Force",0)
		IR_StopInWaveBank(-1)
		td_StopOutWaveBank(-1)
		
		//I don't think we want to stop the main Z loop after a force plot.
//		ir_StopPISLoop(nan,LoopName="HeightLoop")
//		ir_StopPISLoop(nan,LoopName="outputZLoop")
		ir_StopPISLoop(nan,LoopName="DwellLoop")		//but we don't want the dwell loop acidently fireing
		if (GV("DFRTOn"))
			ir_StopPISLoop(nan,LoopName="FrequencyLoop")
			ir_StopPISLoop(nan,LoopName="DriveLoop")
		endif

		
		
		td_WriteString("Event.1","Clear")
		td_WriteString("Event.2","Clear")
//		if ((MVW[%MicroscopeID][0] == cControllerTBD) && !MVW[%DontChangeXPT][0])
//			LoadXPTState("Meter")
//		endif
		//stop that.
		
		
		if (FMapStatus)
			Wave FDVW = root:Packages:MFP3D:Main:Variables:ForceDispVariablesWave
			Wave/T FDVD = root:Packages:MFP3D:Main:Variables:ForceDispVariablesDescription
//			HandleFMapSuffix(FMapStatus,SaveForce)
//			if (((SaveForce) && (!(FMapStatus & 2)))	|| ((Sum(FDVW,FindDimLabel(FDVW,0,"FMapUseFunc0"),FindDimLabel(FDVW,0,"FMapUseFunc"+num2str(cMaxFMapImageChannels-1)))) && (FDVW[%FMapAutoName][0])))
//				FVW[%FMapBaseSuffix][0] += 1
//				//PV("FMapBaseSuffix",GV("FMapBaseSuffix")+1)
//			endif

			if ((SaveForce & 2) && (Sum(FDVW,FindDimLabel(FDVW,0,"FMapUseFunc0"),FindDimLabel(FDVW,0,"FMapUseFunc"+num2str(cMaxFMapImageChannels-1)))))
				//if they are saving to disk, AND they are calculating some image on the fly, lets save it.
				OutputName = FDVD[%FMapOutputImage][0]
				PName = "SaveForce"
				if (FDVW[%FMapAutoName][0])
					SVAR BaseName = root:Packages:MFP3D:Main:Variables:FMapBaseName
					OutputName = BaseName+num2strLen(FVW[%FMapBaseSuffix][0],4)
				endif	
				ResaveImageFunc($ImageFolder+OutputName,PName,1)
				//then we need to update the LoadDirPath wave.
				Wave/T LoadPathWave = $ImageFolder+"LoadPathWave"
				Wave/T ListWave = $ImageFolder+"MemListWave"
				Index = Find1Twave(ListWave,OutputName)
				if (Index >= 0)
					PathInfo $PName
					LoadPathWave[Index][0] = S_Path
				endif
			endif
			

//			if ((SaveForce) && (!(FMapStatus & 2)))			//if Status & 2, then the stop scan will incriment the suffix.
//				FVW[%FMapBaseSuffix][0] += 1
//				//PV("FMapBaseSuffix",GV("FMapBaseSuffix")+1)
//			endif
			//OK, now we figure out if we start up a new FMap.
			DoScanFunc("StopScan_4")
			if (GV("FMapContinuous"))
				aru_Callback(3,2000,"FMapButtonFunc(\"DoFMap_4\")")
				//Execute/P/Q "FMapButtonFunc(\"DoFMap_4\")"
			endif
				
				
//			if (FMapStatus & 1)		//we want to go again.
//				FMapButtonFunc("DoFMap_4")
//			elseif (FMapStatus & 2)		//Clean up (last Scan)
//				DoScanFunc("StopScan_4")
//			endif
		endif
		

		return 0
		
	elseif (ContForce == 2)		//Force mapping.
		//td_WriteString("Event.4","once")		//start the ramp
		ARFMapRampCallback()
		td_WriteString("Event.3","Clear")		//triggered with dwell may have a defleciton feedback loop runing
		ARCallbackFunc("ForceAll")
		return 0
	elseif ((FVW[%ZStateChanged][0] == 1) && (FVW[%FakeCont][0] == 0))

		FVW[%FakeCont][0] = 1
		td_WriteString("Event.0","Clear")
			
	elseif (FVW[%FakeCont][0] == 1)
		
		FVW[%FakeCont][0] = 0
		DoForceFunc("ManyForce")
	endif

	ARREportError(ErrorStr)

	return(1)
	
End //ForcePlotCleanUp


Function/C GetFMapPos(ScanDown,ScanLines,ScanPoints,Counter)
	Variable ScanDown, ScanLines,ScanPoints,Counter
	
Counter -= 1

	Variable PointNum = mod(Counter,ScanPoints)
	Variable LineNum = Floor(Counter/ScanPoints)
	
	
	if (ScanDown)
		if (Mod(ScanLines,2))		//odd number of lines
			if (Mod(LineNum+1,2))
				PointNum = ScanPoints-PointNum-1
			endif
		else
			if (Mod(LineNum,2))
				PointNum = ScanPoints-PointNum-1
			endif
		endif
		LineNum = ScanLines-LineNum-1
	else		//scan up
		//LineNum is normal
		if (Mod(LineNum,2))
			PointNum = ScanPoints-PointNum-1
		endif
	endif
	PointNum = Round(PointNum)
	LineNum = Round(LineNum)		//Make sure it is an Int	
	
	
	Variable/C Output = Cmplx(PointNum,LineNum)
//print 	ScanDown, ScanLines,ScanPoints,Counter,output
	return(output)
	
	
End //GetFmapPos


Function FMapCalcByFP(YData,XData,ParmWave,Section,FuncName,OutputName,Lines,Points,ScanSize)
	Wave YData
	Wave/Z XData
	Wave/Z ParmWave
	String Section, FuncName, OutputName
	Variable/C Lines, Points, ScanSize
	
	//This is a hacked up version of FMapCalc that can calculate a FMapImage on a force plot by force plot basis.
	//it is intended for RT use only.
	//X and Y Data are full waves, this will pull out the correct section from those force plots.
	//Lines and points are complex
	//Real(Lines) = LineIndex
	//Imag(Lines) = MaxNumOfLInes
	//Real(POints) = PointIndex
	//Imag(Points) = MaxNumOfPoints
	//Real(ScanSize) = XScanSize
	//Imag(ScanSize) = YScanSize
	
	
	if (!ARChecKFuncRef("FMapCalcAdhesion",FuncName))
		FuncRef FMapCalcAdhesion WorkFunc=$FuncName
	else
		DoAlert 0,FuncName+" Is Not a valid function"
		return(0)
	endif
	
	
	
	String InfoStr = "CalcType:Height;"
	String DestLayerName = ""
	if (!ARCheckFuncRef("GetForceMapList",FuncName+"info"))
		
		FuncRef FMapCalcHeightInfo InfoFunc = $FuncName+"info"
		InfoStr = InfoFunc()
	endif
	DestLayerName = "Map"+StringByKey("CalcType",InfoStr,":",";")


	
	
	Variable LineIndex = Round(Real(Lines))
	Variable MaxLines = Round(Imag(Lines))
	Variable PointIndex = round(Real(Points))
	Variable MaxPoints = Round(Imag(Points))
	
	if (LineIndex < 0)		//error, we went over with the counter
		//how to deal with this?
		return(0)		//? maybe this is enough.
	endif
		
	
	//first get a list of FPs
	String SavedDataFolder = GetDataFolder(1)
	String TempFolder = ARGetForceFolder("Temp","","")
	SetDataFolder(TempFolder)
	String DestFolder = GetDF("ImageRoot")
	Wave/Z OutPutWave = $DestFolder+OutputName
	
	Variable XDelta = Real(ScanSize)/(MaxPoints-1)
	Variable YDelta = Imag(ScanSize)/(MaxLines-1)
	Variable LayerIndex
	String NoteStr = ""

	if (WaveExists(OutputWave) == 0)
		Make/N=(MaxPoints,MaxLines,1) $DestFolder+OutputName
		Wave OutPutWave = $DestFolder+OutputName
		FastOp Outputwave = (Nan)
		SetScale/P x,0,XDelta,"m",OutPutWave
		SetScale/P y,0,YDelta,"m",OutPutWave
		LayerIndex = 0
		SafeSetDimLabel(Outputwave,DestLayerName,layerIndex,2)
		SetScale d,0,0,"m",Outputwave		//offline images need this.
		UpdateMemListWaves()
		//we need to update the note.
		
		Wave OldMVW = root:Packages:MFP3D:Main:Variables:OldMVW
		Wave RVW = root:Packages:MFP3D:Main:Variables:RealVariablesWave
		Wave/T RVD = root:Packages:MFP3D:Main:Variables:RealVariablesDescription
		Wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
		Wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
		Wave XPTwave = root:Packages:MFP3D:XPT:XPTLoad		
		Wave UserParmWave = root:Packages:MFP3D:Main:Variables:UserVariablesWave
		Wave/T GlobalStrings = $GetDF("Strings")+"GlobalStrings"
		Wave FilterVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave
	
		Note/K OutputWave												//kill the note
		NoteStr += GetWaveParms(RVW)
		NoteStr = ReplaceStringByKey("ImagingMode", NoteStr,RVD[%ImagingMode][%Title],":","\r",0)
		NoteStr += "Real Parms: End\r"
		NoteStr += "Initial Parms: Start\r"
		NoteStr += GetWaveParms(OldMVW)							//this puts the master variable wave parms in the note
		NoteStr += GetWaveParms(CVW)							//this puts the channel variable wave parms in the note
		NoteStr += GetWaveParms(XPTwave)						//grab the crosspoint setup
		NoteStr += GetWaveParms(FilterVW)
		NoteStr += GetWaveParms(UserParmWave)
		NoteStr += "Date: "+Date()+"\r"
		NoteStr += "Time: "+Time()+"\r"
		string tempSeconds
		sprintf tempSeconds, "%u", DateTime
		NoteStr += "Seconds: "+tempSeconds+"\r"
		NoteStr += "ForceMapImage:1\r"
		NoteStr += GetWaveParms(GlobalStrings)
		Note outputWave,NoteStr

		
//		Note OutputWave,GetWaveParms(RVW)
//		Note OutputWave,"Real Parms: End"
//		Note OutputWave,"Initial Parms: Start"
//		Note OutputWave, GetWaveParms(OldMVW)							//this puts the master variable wave parms in the note
//		Note OutputWave, GetWaveParms(CVW)							//this puts the channel variable wave parms in the note
//		Note OutputWave, GetWaveParms(XPTwave)						//grab the crosspoint setup
//		Note OutputWave, GetWaveParms(FilterVW)
//		Note OutputWave, GetWaveParms(UserParmWave)
//		Note OutputWave, "Date: "+Date()
//		Note OutputWave, "Time: "+Time()
//		string tempSeconds
//		sprintf tempSeconds, "%u", DateTime
//		Note OutputWave, "Seconds: "+tempSeconds
//		Note OutPutWave,"ForceMapImage:1"
//	
//		Note OutputWave,GetWaveParms(GlobalStrings)
		
		
		Execute/P/Q "DisplayImage("+GetWavesDataFolder(OutputWave,2)+")"
		
	elseif ((DimSize(OutputWave,0) != MaxPoints) || (dimSize(Outputwave,1) != MaxLines))
		//I don't think we can really support this.
		//This means that they already had an image there with the requested name
		//and it had a different number of points
		//Yeah, I am going to make sure this does not happen in the init of the force map.
		//So this should never hit.
		return(0)
	else
		//we need to find the layer Index.


		//we need to see where to insert the layer.
		//I think we are always going to insert the layers as mod1...
		//that is if there is a name conflict.
		
		LayerIndex = FindDimLabel(OutputWave,2,DestLayerName)
		if (LayerIndex < 0)
			LayerIndex = Max(DimSize(outputWave,2),1)
			InsertPoints/M=2 LayerIndex,1,OutputWave
			SetDimLabel 2,LayerIndex,$DestLayerName,OutputWave
			//we need to update any graphs, that have this wave on them.
			UpdateDisplayTabs(cOfflineBaseName+"*"+OutputName)
		endif
	endif





	NoteStr = Note(YData)
	String Indexes = StringByKey("Indexes",NoteStr,":","\r",0)
	String Directions = StringByKey("Direction",NoteStr,":","\r",0)
	
	
		

	Wave TempY = $InitOrDefaultWave(TempFolder+NameOfWave(YData)+"_"+Section,0)
	ExtractForceSection(YData,TempY,Indexes=Indexes,Directions=Directions)
	if (WaveExists(XData))
		Wave TempX = $InitOrDefaultWave(TempFolder+NameOfWave(XData)+"_"+Section,0)
		ExtractForceSection(XData,TempX,Indexes=Indexes,Directions=Directions)
	else
		Wave/Z TempX = $""
	endif

	
	
	
	FMapCalcWorker(TempY,TempX,ParmWave,"Null","","","","",WorkFunc,cmplx(PointIndex,LineIndex),OutputWave,$"",$"",LayerIndex=LayerIndex)
	Wave/Z/T LookupTable = $GetWavesDataFolder(outputWave,2)+"LK"
	if (!WaveExists(LookupTable))
		Make/N=(DimSize(OutputWave,0),DimSize(OutputWave,1))/T/O $GetWavesDataFolder(OutputWave,2)+"LK"
		Wave/T LookupTable = $GetWavesDataFolder(outputWave,2)+"LK"
		Note/K LookupTable
		SVAR BaseName = root:Packages:MFP3D:Main:Variables:FMapBaseName
		Note LookupTable BaseName+num2strlen(GV("FMapBaseSuffix"),2)

		//Note LookupTable
	endif
//	String BaseName, Suffix, DataType, SectionStr
//	
//	ExtractForceWaveName(NameOfWave(YData),BaseName,Suffix,DataType,SectionStr)
	LookupTable[PointIndex][LineIndex] = "Line"+num2strLen(LineIndex,4)+"Point"+num2strlen(PointIndex,4)



	KillWaves/Z TempY, TempX
	
	
End //FMapCalcByFP


Function FMapPopFunc(Ctrlname,PopNum,PopStr)
	String CtrlName
	Variable PopNum
	String PopStr
	
	
	ARPopFunc(CtrlName,PopNum,PopStr)
	Variable RemIndex = FindLast(CtrlName,"_")
	String TabStr = CtrlName[RemIndex,Strlen(PopStr)-1]
	String ParmName = ARConvertName2Parm(CtrlName,"Popup")
	Variable WhichOne = GetEndNum(ParmName)
	ParmName = ParmName[0,Strlen(ParmName)-2]
	String InfoStr
	
	String FullDataTypeList = GetRTForceDataTypes()
	String DataTypeList = RemoveListItem(0,FullDataTypeList,";")
	

	StrSwitch (ParmName)
		case "FMapFunc":
			if (!ARCheckFuncRef("GetForceMapList",PopStr+"info"))
				FuncRef GetForceMapList InfoFunc = $PopStr+"info"
				InfoStr = InfoFunc()
				
				
				
				CtrlName = "FMapYData"+num2str(WhichOne)+"Popup"+TabStr
				PopStr = StringByKey("DataType",InfoStr,":",";")
				PopNum = WhichListItem(PopStr,DataTypeList,";",0,0)+1
				FMapPopFunc(Ctrlname,PopNum,PopStr)
				
				CtrlName = "FMapXData"+num2str(WhichOne)+"Popup"+TabStr
				PopStr = StringByKey("DataTypeB",InfoStr,":",";")
				PopNum = WhichListItem(PopStr,FullDataTypeList,";",0,0)+1
				FMapPopFunc(Ctrlname,PopNum,PopStr)
				
				CtrlName = "FMapSection"+num2str(WhichOne)+"Popup"+TabStr
				PopStr = StringByKey("Section",InfoStr,":",";")
				PopNum = WhichListItem(PopStr,GetFMapSections(),";",0,0)+1
				FMapPopFunc(Ctrlname,PopNum,PopStr)
				
				
			endif
				
			break
			
	endswitch
	
		
	
End //FMapPopFunc


Function/S GetFMapSections()

	String output = "Ret;Ext;"
	Variable DwellSetting = GV("DwellSetting")
	Variable ForceSign = GV("ForceDistSign")
	Variable Value = DwellSetting*ForceSign
	Switch (Value)
		case 1:
		case -2:
			output += "Dwell Towards;"
			break
			
		case -1:
		case 2:
			output += "Dwell Away;"
			break
			
	Endswitch
	
	
	return(output)

End //GetFMapSections


Function FMapStringSetVarFunc(CtrlName,VarNum,VarStr,VarName)
	String CtrlName
	Variable VarNum
	String VarStr, VarName
	
	//our job is to check to make sure that the name is reasonable.
	//Note that this DOES NOT need to be a string input, it could be the clicker.
	
	String ParmName = ARConvertVarName2ParmName(VarName)
	Variable IsClicker = 0
	String ImageList, SuffixStr, BaseName
	Variable Suffix, A, nop, SuffixLen, DoCheck, Index, LastValue
	if (StringMatch(VarName,"*VariablesWave*"))		//number
		IsClicker = 1
		VarStr = GDS(ParmName)
		LastValue = GVU(ParmName)
		PVU(ParmName,VarNum)

		SuffixStr = GetEndNumStr(VarStr)
		DoCheck = 1
		if (Strlen(SuffixStr) > 4)
			SuffixStr = VarStr[Strlen(VarStr)-4,Strlen(VarStr)-1]
			SuffixLen = 4
			DoCheck = 0
		endif
		Suffix = str2num(SuffixStr)
		if (IsNan(Suffix))
			Suffix = -1
			SuffixStr = ""
		endif
		BaseName = VarStr[0,Strlen(VarStr)-Strlen(SuffixStr)-1]
		if (DoCheck)
			SuffixLen = Strlen(SuffixStr)
		endif
		
		Suffix += VarNum-LastValue
		Suffix = Max(Suffix,0)
		SuffixStr = num2strlen(Suffix,SuffixLen)
		VarStr = BaseName+SuffixStr
		PDS(ParmName,VarStr)
	endif


	//Wave/T SourceWave = $GWDS(ParmName)
	
	
	String OrgVarStr = VarStr
	VarStr = CleanupName(VarStr,0)
	VarStr = VarStr[0,16]
	if (CmpStr(VarStr,OrgVarStr))
		PDS(ParmName,VarStr)
	endif
	
	
	String DataFolder = GetDF("ImageRoot")
	Wave/Z ImageWave = $DataFolder+VarStr
	if (WaveExists(ImageWave))
		//Lets see if it has the same number of points and lines
		Variable Points = GV("FMapScanPoints")
		Variable Lines = GV("FMapScanLines")
		if ((Points != DimSize(ImageWave,0)) || (Lines != DimSize(ImageWave,1)))
			ImageList = ARWaveList(DataFolder,"*",";","")
			SuffixStr = GetEndNumStr(VarStr)
			DoCheck = 1
			if (Strlen(SuffixStr) > 4)
				SuffixStr = VarStr[Strlen(VarStr)-4,Strlen(VarStr)-1]
				SuffixLen = 4
				DoCheck = 0
			endif
			Suffix = str2num(SuffixStr)
			if (IsNan(Suffix))
				Suffix = -1
				SuffixStr = ""
			endif
			BaseName = VarStr[0,Strlen(VarStr)-Strlen(SuffixStr)-1]
			nop = ItemsInList(ImageList,";")
			if (DoCheck) 
				SuffixLen = Strlen(SuffixStr)
			endif
			
			
			Do
				Suffix += 1
				SuffixStr = num2strLen(Suffix,SuffixLen)
				Index = WhichListItem(BaseName+SuffixStr,ImageList,";",0,0)
				
			
			While (Index >= 0)
			
			
			VarStr = BaseName+SuffixStr
			PDS(ParmName,VarStr)
			if (!IsClicker)
				DoAlert 0,"Name Exists as Image, with different # of points\rYour Name has been altered"
			endif
			return(1)
		endif
	endif
	
	
	
	return(0)
	
	
End //FMapStringSetVarFunc


Function/S GetRTForceDataTypes()


	wave FVW = root:Packages:MFP3D:Main:Variables:ForceVariablesWave
	wave PanelParm = root:Packages:MFP3D:Main:Windows:ForceChannelPanelParms
	SVAR FWL = root:Packages:MFP3D:Force:ForceWavesList
	SVAR SFWL = root:Packages:MFP3D:Force:ShortForceWavesList
	String output = "None;Raw;", DataType, UserEditName
	Variable A, nop = WhichListItem("ZSensor",FWL,";",0,0)+1
	for (A = 1;A < nop;A += 1)
		DataType = StringFromList(A,FWL)
		UserEditName = ARGetUserChannelName(DataType,$"")
		if (!Strlen(UserEditName))
			UserEditName = DataType
		endif
		
		if (PanelParm[%$UserEditName][0] >= 2)
			DataType = StringFromList(A,SFWL)
			Output += DataType+";"
		endif
	
	endfor


	//now add all the calcable data types
	String ChildrenTypes = GetCalcAbleForceTypes()
	String DoubleChildrenTypes = GetDoubleCalcAbleForceTypes()
	String RealOutput = "", SubDataTypes

	nop = ItemsInList(Output,";")
	for (A = 0;A < nop;A += 1)
		DataType = StringFromList(A,output,";")
		SubDataTypes = StringByKey(DataType,ChildrenTypes,":",",")
		RealOutput = SpliceStringList(RealOutput,DataType+";"+SubDataTypes)
	endfor


	String TempStr, Parents, Mom, Dad
	nop = ItemsInList(DoubleChildrenTypes,";")
	for (A = 0;A < nop;A += 1)
		TempStr = StringFromList(A,DoubleChildrenTypes,";")
		Parents = StringFromList(0,TempStr,":")
		Mom = StringFromList(0,Parents,"_")
		Dad = StringFromList(1,Parents,"_")
		if ((WhichListItem(Mom,RealOutput,";",0,0) >= 0) && (WhichListItem(Dad,RealOutput,";",0,0) >= 0))
			RealOutput += StringFromList(1,TempStr,":")+";"
		endif
	endfor



	return(Realoutput)
	
	
End //GetRTForceDataTypes



Function UpdateForceMapXYTime()
	
	
	Struct ARFMapParms Parms
	GetARFMapParms(Parms)
	Wave XPoints = Parms.XPoints
	Wave YPoints = Parms.YPoints
	Variable IsMax = GV("FMapIsXYMax")		//I have hidden the interface to change this, but will keep the depenancy on the parm.
	Parms.ScanSpeed = GV("FMapXYVelocity")/(IsMax*cFMapXYVelocityFactor+!IsMax)
	String DataFolder = GetWavesDataFolder(XPoints,1)
	Make/N=(DimSize(XPoints,0)-1)/O $DataFolder+"TotalTime"
	Wave TotalTime = $DataFolder+"TotalTime"
	TotalTime = Sqrt((((XPoints[P+1]-XPoints[P])*abs(Parms.XLVDTSens))^2)+(((YPoints[P+1]-YPoints[P])*abs(Parms.YLVDTSens))^2))/Parms.ScanSpeed

	NVAR MaxTime = $InitOrDefault(DataFolder+"MaxTime",0)
	Variable LocalMaxTime = Max(Wavemax(TotalTime),.001)		//bad things happen when this is too small, < 2 points at 2 kHz.
	MaxTime = LocalMaxTime
	return(LocalMaxTime)

End //UpdateForceMapXYTime


Function PauseFMap(Step)
	Variable Step

	//we will put a callback on bank 2 for dealing with this...
	String ErrorStr = ""

	Wave/T InWaves = $GetDF("")+"InWaves"
	Wave Input0 = $InWaves[5][%Wave]  //LVDT must be running.




	Switch (Step)
		case 0:		//stop the CTFC
			ErrorStr += num2str(td_WriteString("Event.0","Clear"))+","
			aru_Callback(4,rightx(Input0)*1000+30,GetFuncName()+"(1)")
			PV("FMapPaused",1)
			GhostForceMapPanel()
			MakeBrowseWaitPanel(WinName(0,64),"Pausing Force Map ["+num2str(RightX(Input0)*2)+" secs]")
			break
		
		case 1:		//stop the input
			ErrorStr += num2str(td_WriteString("Event.0","Clear"))+","
			ARU_Callback(4,rightx(Input0)*1000+30,GetFuncName()+"(2)")
			break
		
		case 2:		//ghost buttons
			DoWindow/K WaitPanel
			break
	
		default:		//restart
			Wave/T CTFCParms = $GetDF("Force")+"CTFCParms"
			IR_ResetInWaves()
			ErrorStr += num2str(td_WriteGroup("CTFC",CTFCParms))+","
			ErrorStr += num2str(td_WriteString("Event.1","Set"))+","
			ErrorStr += num2str(td_WriteString("Event.0","Set"))+","
			PV("FMapPaused",0)
			GhostForceMapPanel()
			break
	
	endswitch

	ARReportError(ErrorStr)

End //PauseFMap


Function SineMovePanel(GraphStr)
	String GraphStr
	
//	Variable Direction = 2
	
	//Direction
	//1 = Left to right
	//2 = Right to left
	
	
	if (!IsWindow(GraphStr))
		return(1)
	endif
		
	NVAR Counter = $InitOrDefault(GetDF("TOC")+GraphStr+"Counter",0)
	NVAR Direction = $InitOrDefault(GetDF("TOC")+GraphStr+"Dir",0)
	Variable nop = 20
	
	Variable Freq = 2		//oscillations / screen
	
	GetWindow $Graphstr,Wsize
	
	Variable Height, Width
	Height = V_Bottom-V_Top
	Width = V_Right-V_left
	
	
	if (Counter > nop)
		doWindow/K $GraphStr
		return(1)
	endif

	Variable ScrRes = 72/ScreenResolution
	Variable XPos,YPos, Xoff, YOff
	Variable ScreenWidth, ScreenHeight
	ARScreenSize(ScreenWidth,ScreenHeight)
	ScreenWidth *= ScrRes
	ScreenHeight *= ScrRes
	ScreenWidth -= Width
	Variable XStep = ScreenWidth/nop
	String Info = IgorInfo(0)
	String SCR = StringByKey("Screen1",Info,":",";",0)
	String Str2Find = "Rect="
	Variable Index = strsearch(SCR,Str2Find,0,2)+Strlen(Str2Find)
	XOff = str2num(StringFromList(0,SCR[Index,Strlen(SCR)-1],","))
	
	SCR = StringByKey("Screen2",Info,":",";",0)
	if (Strlen(SCR))
		Index = strsearch(SCR,Str2Find,0,2)+Strlen(Str2Find)
		Xoff = Min(XOff,str2num(StringFromList(0,SCR[Index,Strlen(SCR)-1],",")))
	endif
	
	YOff = (ScreenHeight-Height)/2
	
	if (Direction == 2)
		XOff = ScreenWidth+XOff
		XPos = XOff-Counter*XStep
	else
		XPos = Counter*XStep+XOff
	endif
	Variable Amp = Height/2
	
	
	
	YPos = sin(Counter/nop*Freq*2*pi)*Amp+YOff
	
	DoWindow/F $GraphStr
	MoveWindow/W=$GraphStr XPos,YPos,XPos+Width,YPos+Height
	SetWindow $GraphStr,Hide=0
	
	Counter += 1
	return(0)
	
End //SineMovePanel


Function HalloweenEgg()



	//check the datetime


	String Now = ARU_Date()
	Variable Month = Str2num(StringFromList(1,Now,"-"))
	Variable Day = Str2num(StringFromList(2,Now,"-"))

	String TimeStr = Time()
	Variable Hour = str2num(StringFromList(0,TimeStr,":"))
	if (stringmatch(TimeStr,"*PM"))
		Hour += 12
	endif
	Variable Mins = Str2num(StringFromList(1,TimeStr,":"))
	Variable Secs = Str2num(StringFromList(2,TimeStr,":"))

	Variable DoIt = 0
	if ((Day == 31) && (Month == 10))
		if (Hour >= 20)
			if (mod(mins+Secs/60,20) == 0)
				DoIt = 1
			endif
		endif
	endif
	if (!DoIt)
		return(0)
	endif


	String GraphStr = GetFuncName()+"Panel"

	NewPanel/K=1/W=(98,89,473,543)/Hide=1/N=$GraphStr
	SetDrawLayer UserBack
	String PictName = PanelFuncs#ARLoadButtonPicture("Ghost")
	DrawPICT -1,-0,1.78673,1.84959,$PictName

	NVAR Counter = $InitOrDefault(GetDF("TOC")+GraphStr+"Counter",0)
	Counter = 0
	NVAR Direction = $InitOrDefault(GetDF("TOC")+GraphStr+"Dir",0)
	Direction = IntRand(2)+1
	
	ARBackground("SineMovePanel",60,GraphStr)
	return(0)
End //HalloweenEgg


Function ARGetImagingMode(InfoStruct, [ImagingMode])
	Struct ARImagingModeStruct &InfoStruct
	Variable ImagingMode
	
	//average call time on a 2.6 GHz core 2 duo
	//131.204 s
	//20 times slower than GV("ImagingMode")
	
	String DataFolder = GetDF("Variables")
	Wave MVW = $DataFolder+"MasterVariablesWave"
	Wave FVW = $DataFolder+"ForceVariablesWave"
	Wave FMVW = $cFMVW
	Wave TVW = $DataFolder+"ThermalVariablesWave"
	Wave/T MVD = $DataFolder+"MasterVariablesDescription"
	Wave FilterWave = $DataFolder+"FilterVariablesWave"
	Wave NVW = $DataFolder+"NapVariablesWave"

	//Layout constitent with the stucture declarations

	//Start of structure variables

	//ARFeedbackStruct
	Variable Bank
	String StartEvent = "Always"
	String StopEvent = "Never"
	String Input
	String Output
	String LoopName
	Variable PGain = MVW[%ProportionalGain][0]
	Variable IGain = MVW[%IntegralGain][0]
	Variable SGain = MVW[%SecretGain][0]
	Variable DGain = 0		//we don't use DGain yet
	Variable OutputMax = inf
	Variable OutputMin = -inf
	Variable Setpoint
	Variable SetpointOffset = 0
	Variable NapMode = NVW[%NapMode][0]
	if ((NapMode == 1) || (NapMode == 3))
		StartEvent = "1"
	endif
	
	

	Variable FeedbackCount = 1
	Variable GainSign = 0		//you better set it, it is starting out at zero
	Variable ADCGain
	Variable UseDDS
	String ImagingModeName = MVD[%ImagingMode][%Title]
	Variable FakeImagingMode = 1
	if (paramisdefault(ImagingMode))
		FakeImagingMode = 0
		ImagingMode = MVW[%ImagingMode][0]
	endif
	String SetpointParm
	Variable SetpointLimitLow
	Variable SetpointLimitHigh
	String FilterParm = ""
	Variable DidRead = 1		//we just read it.
	Variable DFRTOn = TVW[%DFRTOn][0]
	Variable DualAC = !(!TVW[%DualACMode][0])		//force to be 0 / 1
	String XPTString
	
	//ARDDSStruct
	Variable DCOffset = Nan
	Variable FreqOffset = 0
	Variable DDSFreq0 = MVW[%DriveFrequency][0]
	Variable DDSFreq2 = MVW[%DriveFrequency1][0]
	Variable PhaseOffset0 = MVW[%PhaseOffset][0]
	Variable PhaseOffset2 = MVW[%PhaseOffset1][0]
	Variable DDSAmp0 = MVW[%DriveAmplitude][0]		//Yes, 0 and 2.  You see 0, you KNOW it is the first one
	Variable DDSAmp2 = MVW[%DriveAmplitude1][0]	//, you see 2, you KNOW it is the second

	if (NVW[%ElectricTune][0])				//these all need to be the nap values if electric tune is on
		PhaseOffset0 = NVW[%NapPhaseOffset][0]
		DDSFreq0 = NVW[%NapDriveFrequency][0]
		DDSAmp0 = NVW[%NapDriveAmplitude][0]
	endif


	String WhichDDS = StringFromList(TVW[%TuneLockin][0],"LockIn.;Cypher.LockinA.;Cypher.LockinB.;",";")
	Variable DDSFilter0, DDSFilter2
	if (FVW[%ContForce][0])		//we are doing force plots
		DDSFilter0 = FVW[%ForceFilterBW][0]
		DDSFilter2 = DDSFilter0
	else
		DDSFilter0 = FilterWave[%$WhichDDS+"0.Filter.Freq"][0]
		DDSFilter2 = FilterWave[%$WhichDDS+"1.Filter.Freq"][0]
	endif
	Variable QGain = TVW[%TuneGain][0]
		
	// End of structure variables
	
	// Other Variables
	Variable SurfaceVoltage = MVW[%SurfaceVoltage][0]	
	Variable TriggerSlope = FVW[%TriggerSlope][0]
	Variable MicroscopeID = MVW[%MicroscopeID][0]
	Variable DFRTFrequencyWidth = TVW[%DFRTFrequencyWidth][0]
	Variable DFRTFrequencyCenter = TVW[%DFRTFrequencyCenter][0]
	Variable FrequencyFeedback = FMVW[%FrequencyFeedback][0]
	Variable PScale = 0.1
	Variable IScale = 100
	Variable SScale = 1e-12
	Variable DScale = 1
	
	//Clear out the 2 other optional feedback loops.
	Struct ARFeedbackStruct Feedback1
	Struct ARFeedbackStruct Feedback2
	
	Feedback1.Bank = NaN
	Feedback1.StartEvent = ""
	Feedback1.StopEvent = ""
	Feedback1.Input = ""
	Feedback1.Output = ""
	Feedback1.LoopName = ""
	Feedback1.PGain = NaN
	Feedback1.IGain = NaN
	Feedback1.SGain = NaN
	Feedback1.DGain = NaN
	Feedback1.Setpoint = NaN
	Feedback1.SetpointOffset = NaN
	Feedback1.DynamicSetpoint = 0
	Feedback1.OutputMin = -inf
	Feedback1.OutputMax = inf
	
	Feedback2 = Feedback1	

	Switch (ImagingMode)

		case 0:		//Contact
			GainSign = 1
			Input = "Deflection"
			SetpointParm = "DeflectionSetpointVolts"
			Setpoint = MVW[%$SetpointParm][0]
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Start of code modification by Suhas
			if(DataFolderExists("root:packages:TemperatureControl:Imaging" ))
				String dfSave = GetDataFolder(1)
				SetDataFolder root:packages:TemperatureControl:Imaging
				NVAR gScanMode, gVcant
				// Allow thermal feedback ONLY if heated and correct mode is chosen
				if(gScanMode == 3)
					//print "correct mode chosen"
					if(td_RV("PIDSLoop.5.Status") < 1)
						//print "Cantilever not heated. Engaging normally"
					else
						Input = "Input.A"//"Lateral"// This is causing problems
						SetpointParm = "DeflectionSetpointVolts"//This is wrong
						Setpoint = gVcant
					endif
				endif
				SetDataFolder dfSave
			endif
			// End of code modification by Suhas
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			UseDDS = 0
			DDSAmp0 = 0
			DDSAmp2 = 0
			DDSFreq2 = 0
			ADCGain = 0
			DFRTOn = 0
			DualAC = 0
			Wave InfoStruct.SetpointVarWave = MVW
			XPTString = "DC"
			FilterParm = "Input.Fast.Filter.Freq"
			break
			
		case 1:		//AC
			GainSign = -1
			Input = "Amplitude"
			SetpointParm = "AmplitudeSetpointVolts"
			Setpoint = MVW[%$SetpointParm][0]
			UseDDS = 1
			DDSAmp2 *= DualAC
			DDSFreq2 *= DualAC
			if (MicroscopeID == cMicroscopeCypher)
				ADCGain = 0
			else
				ADCGain = 12
			endif
			DFRTOn = 0
			Wave InfoStruct.SetpointVarWave = MVW
			XPTString = "AC"
			FilterParm = "Lockin.0.Filter.Freq"
			break
			
		case 2:		//FM

			FeedbackCount = 3
			GainSign = FMVW[%FMFeedbackSign][0]
			if (MicroscopeID == cMicroscopeCypher)
				ADCGain = 0
			else
				ADCGain = 12
			endif
			UseDDS = 1
			Wave InfoStruct.SetpointVarWave = FMVW
			DFRTOn = 0
			XPTString = "AC"

			if (FrequencyFeedback == 1)
				PScale = FMVW[%FreqPGainScaleZ][0]
				IScale = FMVW[%FreqIGainScaleZ][0]
				SScale = FMVW[%FreqSGainScaleZ][0]
				SetpointParm = "FrequencySetpointHz"
				Input = "DDSFrequencyOffset0"
			else
				PScale = FMVW[%DrivePGainScaleZ][0]
				IScale = FMVW[%DriveIGainScaleZ][0]
				SScale = FMVW[%DriveSGainScaleZ][0]
				SetpointParm = "DissipationSetpointVolts"
				Input = "Dissipation"
			endif

			FilterParm = "Lockin.0.Filter.Freq"
			// DDS 
			DDSFreq2 = 0
			DDSAmp2 = 0
			
			StartEvent = "1"
			
			// [0] Z Feedback Struct
			Setpoint = FMVW[%$SetpointParm][0]
			SetpointLimitLow = FMVW[%$SetpointParm][%Low]
			SetpointLimitHigh = FMVW[%$SetpointParm][%High]
			
			// [1] Drive Loop (Dissipation)
			Feedback1.Bank = 3
			Feedback1.StartEvent = StartEvent
			Feedback1.StopEvent = "Never"
			Feedback1.Input = "Amplitude"
			Feedback1.Output = "Dissipation"
			Feedback1.LoopName = "DriveLoop"
			Feedback1.PGain = MVW[%DrivePGain][0]/2	// Hardware gain of 2x on 3D Controller
			Feedback1.IGain = MVW[%DriveIGain][0]/2		// Hardware gain of 2x on 3D Controller
			Feedback1.SGain = 0
			Feedback1.DGain = 0
			Feedback1.Setpoint = FMVW[%DriveLoopSetpointVolts][0]
			Feedback1.SetpointOffset = 0
			Feedback1.DynamicSetpoint = 0
			Feedback1.OutputMin = 0
			Feedback1.OutputMax = FMVW[%DissipationLimit][0]
	
			// [2] Frequency Loop
			Feedback2.Bank = 4
			Feedback2.StartEvent = StartEvent
			Feedback2.StopEvent = "Never"
			Feedback2.Input = "Phase"
			Feedback2.Output = "DDSFrequencyOffset0"
			Feedback2.LoopName = "FrequencyLoop"
			Feedback2.PGain = MVW[%FreqPGain][0]
			Feedback2.IGain = MVW[%FreqIGain][0]*1000
			Feedback2.SGain = 0
			Feedback2.DGain = 0
			Feedback2.Setpoint = 90
			Feedback2.SetpointOffset = 0
			Feedback2.DynamicSetpoint = 0
			Feedback2.OutputMin = -FMVW[%FrequencyLimit][0]
			Feedback2.OutputMax = -Feedback2.OutputMin
			break
			
		case 3:		//PFM
			GainSign = 1
			Input = "Deflection"
			SetpointParm = "DeflectionSetpointVolts"
			Setpoint = MVW[%$SetpointParm][0]
			Wave InfoStruct.SetpointVarWave = MVW
			UseDDS = 1
			if (DFRTOn || FakeImagingMode)		//if the imagingMode is not set, then we are just asking what it would be.
				DDSFreq0 = DFRTFrequencyCenter-DFRTFrequencyWidth/2
				DDSFreq2 = DFRTFrequencyCenter+DFRTFrequencyWidth/2
				StartEvent = "1"		//we have multiple FB loops to setup, do it on event 1
				
				// [1] setup drive
				Feedback1.Bank = 3
				Feedback1.StartEvent = StartEvent
				Feedback1.StopEvent = "Never"
				Feedback1.Input = "DDSFrequency0"
				Feedback1.Output = "DDSFrequency1"
				Feedback1.LoopName = "DriveLoop"
				Feedback1.PGain = -1
				Feedback1.IGain = 0
				Feedback1.SGain = 0
				Feedback1.DGain = 0
				Feedback1.Setpoint = DDSFreq0
				Feedback1.SetpointOffset = 0
				Feedback1.DynamicSetpoint = 0
				Feedback1.OutputMin = 0
				Feedback1.OutputMax = inf			//we will want to change this at some point.

				// [2] Setup Freq FB
				Feedback2.Bank = 4
				Feedback2.StartEvent = StartEvent
				Feedback2.StopEvent = "Never"
				Feedback2.Input = "LinearCombo.Output"
				Feedback2.Output = "Frequency"
				Feedback2.LoopName = "FrequencyLoop"
				Feedback2.PGain = MVW[%DARTPGain][0]
				Feedback2.IGain = MVW[%DARTIGain][0]*1e6
				Feedback2.SGain = 0
				Feedback2.DGain = 0
				Feedback2.Setpoint = 0
				Feedback2.SetpointOffset = 0
				Feedback2.DynamicSetpoint = 0
				Feedback2.OutputMax = TVW[%PFMFrequencyLimit][0] > 0 ? TVW[%PFMFrequencyLimit][0] : inf
				Feedback2.OutputMin = -Feedback2.OutputMax
			
				DualAC = 1
				FeedbackCount = 3
			
			else
				DDSAmp2 *= DualAC
				DDSFreq2 *= DualAC
			endif
			ADCGain = 20
			XPTString = "PFM"
			FilterParm = "Input.A.Filter.Freq"
			break
			
		case 4:		//STM
			GainSign = -Sign(SurfaceVoltage)
			SetpointParm = "CurrentSetpointVolts"
			Setpoint = MVW[%$SetpointParm][0]*GainSign
			Wave InfoStruct.SetpointVarWave = MVW
			Input = "Log.Output"
			UseDDS = 0
			DDSAmp0 = 0
			DDSAmp2 = 0
			DDSFreq2 = 0
			ADCGain = 0
			DFRTOn = 0
			DualAC = 0
			XPTString = "STM"
			FilterParm = "Input.Fast.Filter.Freq"
			Break
			
		Default:
			Abort "Undefined ImagingMode"
			break			//just to be clear, in case someone changes the abort, and puts another case after.
			
			
	EndSwitch
	
	
	//now we set the FilterParm, but that is really just a default.  If aliases are working, we read the inputs of the FB loop.
	String FBAlias = ir_ReadAlias(Input)
	if (!stringMatch(FBAlias,"*Error*"))
		FilterParm = ReplaceString("ARC.",FBAlias,"")
		if (StringMatch(FilterParm,"*LockIn*"))		//Aliases to the Lockin point to some item, we need to go 1 level up
			FilterParm = RemoveListItem(ItemsInList(FilterParm,".")-1,FilterParm,".")
		endif
		if (CmpStr(FilterParm[Strlen(FilterParm)-1],".") != 0)
			FilterParm += "."
		endif
		FilterParm += "Filter.Freq"
	endif
	

	// First build the Z loop [0]
	Struct ARFeedbackStruct Feedback
	Feedback.Bank = 2
	Feedback.StartEvent = StartEvent
	Feedback.StopEvent = StopEvent
	Feedback.Input = Input
	Feedback.Output = "Height"
	Feedback.LoopName = Feedback.Output+"Loop"
	Feedback.PGain = PGain*PScale*GainSign
	Feedback.IGain = IGain*IScale*GainSign
	Feedback.SGain = SGain*SScale*GainSign
	Feedback.DGain = DGain*DScale*GainSign
	Feedback.Setpoint = Setpoint
	Feedback.SetpointOffset = SetpointOffset
	if (IsNan(Feedback.Setpoint))
		Feedback.DynamicSetpoint = 1
	else
		Feedback.DynamicSetpoint = 0
	endif
	Feedback.OutputMin = OutputMin
	Feedback.OutputMax = OutputMax
	
	
	// Then build the DDS Struct
	Struct ARDDSStruct DDS
	DDS.DCOffset = DCOffset
	DDS.FreqOffset = FreqOffset
	DDS.Freq[0] = DDSFreq0
	DDS.Freq[1] = DDSFreq2
	DDS.PhaseOffset[0] = PhaseOffset0
	DDS.PhaseOffset[1] = PhaseOffset2
	DDS.Amp[0] = DDSAmp0
	DDS.Amp[1] = DDSAmp2
	DDS.Filter[0] = DDSFilter0
	DDS.Filter[1] = DDSFilter2
	DDS.QGain = QGain

	// Then the ImagingMode Struct
	InfoStruct.Feedback[0] = Feedback
	InfoStruct.Feedback[1] = Feedback1
	InfoStruct.Feedback[2] = Feedback2
	InfoStruct.FeedbackCount = FeedbackCount
	InfoStruct.GainSign = GainSign
	InfoStruct.PScale = PScale
	InfoStruct.IScale = IScale
	InfoStruct.SScale = SScale
	InfoStruct.ADCGain = ADCGain
	InfoStruct.UseDDS = UseDDS
	InfoStruct.ImagingModeName = ImagingModeName
	InfoStruct.ImagingMode = ImagingMode
	InfoStruct.SetpointParm = SetpointParm
	//InfoStruct.SetpointVarWave = SetpointVarWave
	InfoStruct.SetpointLimits[0] = SetpointLimitLow
	InfoStruct.SetpointLimits[1] = SetpointLimitHigh
	InfoStruct.FilterParm = FilterParm
	InfoStruct.DidRead = DidRead
	InfoStruct.DFRTOn = DFRTOn
	InfoStruct.DualAC = DualAC
	InfoStruct.XPTString = XPTString
	InfoStruct.DDS = DDS
	
End //ARGetImagingMode


Function ARGetFeedbackParms(FB,Loop[,ImagingMode])
	Struct ARFeedbackStruct &FB
	String Loop 
	Variable ImagingMode
		// Frequency
		// Drive or Dissipation
		// Z or Height
	
	
	Variable output = 0
	Variable LVDTSens
	
	Wave MVW = $GetDF("Variables")+"MasterVariablesWave"
	
	StrSwitch (Loop)
		Case "X":
		case "OutputX":
		case "XSensor":
			FB.Bank = 0
			FB.Input = "XSensor"
			FB.Output = "Output.X"
			FB.Setpoint = NaN
			FB.DynamicSetpoint = 1
			FB.SetpointOffset = 0
			
			LVDTSens = MVW[%XLVDTSens][0]
			
			FB.Pgain = LVDTSens*10^MVW[%XPGain][0]		//multiplying by the sensitivity takes care of some gain issues,
			FB.Igain = LVDTSens*10^MVW[%XIGain][0]			//but more importantly makes sure the sign is correct
			FB.Sgain = LVDTSens*10^MVW[%XSGain][0]
			FB.DGain = 0
			
			FB.StartEvent = "Always"
			FB.StopEvent = "Never"
			FB.OutputMin = -Inf
			FB.OutputMax = inf
			
			FB.LoopName = "outputXLoop"
			
			return(output)
			break
			
		case "Y":
		case "outputY":
		case "YSensor":
			FB.Bank = 1
			FB.Input = "YSensor"
			FB.Output = "Output.Y"
			FB.Setpoint = NaN
			FB.DynamicSetpoint = 1
			FB.SetpointOffset = 0
			
			LVDTSens = MVW[%YLVDTSens][0]
			
			FB.Pgain = LVDTSens*10^MVW[%YPGain][0]		//multiplying by the sensitivity takes care of some gain issues,
			FB.Igain = LVDTSens*10^MVW[%YIGain][0]			//but more importantly makes sure the sign is correct
			FB.Sgain = LVDTSens*10^MVW[%YSGain][0]
			FB.DGain = 0
			
			FB.StartEvent = "Always"
			FB.StopEvent = "Never"
			FB.OutputMin = -Inf
			FB.OutputMax = inf
			
			FB.LoopName = "outputYLoop"
			
			return(output)
			break
			
		case "Z":
		case "OutputZ":
		case "ZSensor":
			FB.Bank = 2
			FB.Input = "ZSensor"
			FB.Output = "Output.Z"
			FB.Setpoint = NaN
			FB.DynamicSetpoint = 1
			FB.SetpointOffset = 0
			
			LVDTSens = MVW[%ZLVDTSens][0]
			
			FB.Pgain = LVDTSens*10^MVW[%ZPGain][0]		//multiplying by the sensitivity takes care of some gain issues,
			FB.Igain = LVDTSens*10^MVW[%ZIGain][0]			//but more importantly makes sure the sign is correct
			FB.Sgain = LVDTSens*10^MVW[%ZSGain][0]
			FB.DGain = 0
			
			FB.StartEvent = "Always"
			FB.StopEvent = "Never"
			FB.OutputMin = -Inf
			FB.OutputMax = inf
			
			FB.LoopName = "outputZLoop"
			
			return(output)
			break
			
		case "Potential":
			Wave NVW = $GetDF("Variables")+"NapVariablesWave"

			FB.Bank = 4
			FB.Input = "InputQ"
			FB.output = "Potential"
			FB.StartEvent = "Always"
			FB.StopEvent = "Never"
			FB.outputMax = 10-NVW[%NapDriveAmplitude][0]
			FB.outputMin = -FB.outputMax
			FB.Setpoint = 0
			FB.DynamicSetpoint = 0
			FB.SetpointOffset = 0

			
			
			FB.PGain = NVW[%PotentialPGain][0]
			FB.IGain = NVW[%PotentialIGain][0]*1000
			FB.SGain = 0
			FB.DGain = 0
			FB.LoopName = "PotentialLoop"
			return(output)
			break
			
	endswitch
	
	
	Struct ARImagingModeStruct ARImagingModeStruct
	if (ParamIsDefault(ImagingMode))
		ARGetImagingMode(ARImagingModeStruct)
		ImagingMode = ARImagingModeStruct.ImagingMode
	else
		ARGetImagingMode(ARImagingModeStruct,ImagingMode=ImagingMode)
	endif

	strswitch (Loop)
	
		case "Height":
			FB = ARImagingModeStruct.Feedback[0]
			break
		
		case "Drive":
		case "Dissipation":
			FB = ARImagingModeStruct.Feedback[1]
			break

		case "Frequency":
			Switch (ImagingMode)
				case 0:		//contact
				case 1:		//AC
				case 4:		//STM
					
					FB.Bank = 4
					FB.Input = "Phase"
					FB.output = "Frequency"
					FB.StartEvent = "Always"
					FB.StopEvent = "Never"
					FB.outputMax = Inf
					FB.outputMin = -inf
					FB.Setpoint = 90
					FB.DynamicSetpoint = 0
					FB.SetpointOffset = 0
	
					FB.PGain = MVW[%FreqPGain][0]
					FB.IGain = MVW[%FreqIGain][0]*1000
					FB.SGain = 0
					FB.DGain = 0
				
					FB.LoopName = "FrequencyLoop"
					
					
					break
					
				case 2:		//FM
				case 3:		//PFM
					FB = ARImagingModeStruct.Feedback[2]
					break
			endswitch
			break
		
		default:
			output = 1
			break
			
	endswitch
	return(output)
end //ARGetFeedbackParms
		

Function/S ARWriteDDS(DDS)
	Struct ARDDSStruct &DDS
	
	//writes the DDS [Lockin] parms based on what is in the DDS structure.
	//Does this by creating a wave and doing a writeMany.
//Variable Tic = StopMsTimer(-2)
	
	String ErrorStr = ""

	String DataFolder = GetDF("HardWare")
	Wave DDSWave = $InitOrDefaultWave(DataFolder+"DDSWave",10)
	Redimension/D/N=(0) DDSWave
	if (!IsNan(DDS.DCoffset))
		SafePVByLabel(DDSWave,DDS.DCoffset,"DDSDCOffset0")
	endif
	if (!IsNan(DDS.FreqOffset))
		SafePVByLabel(DDSWave,DDS.FreqOffset,"DDSFrequencyOffset0")
	endif
	if (!IsNan(DDS.QGain))
		SafePVByLabel(DDSWave,DDS.QGain,"Damping.Gain")
		SafePVByLabel(DDSWave,-90,"Damping.Angle")
	endif
	String FilterParm
	Variable A, nop = 2
	for (A = 0;A < nop;A += 1)
		if (!IsNan(DDS.Freq[A]))
			SafePVByLabel(DDSWave,DDS.Freq[A],"DDSFrequency"+num2str(A))
		endif
		if (!IsNan(DDS.PhaseOffset[A]))
			SafePVByLabel(DDSWave,DDS.PhaseOffset[A],"DDSPhaseOffset"+num2str(A))
		endif
		if (!IsNan(DDS.Amp[A]))
			SafePVByLabel(DDSWave,DDS.Amp[A],"DDSAmplitude"+num2str(A))
		endif
			
		if (!IsNan(DDS.Filter[A]))
			FilterParm = "$LockIn."+num2str(A)+".Filter.Freq"
			SafePVByLabel(DDSWave,DDS.Filter[A],FilterParm)
		endif
	endfor
	
//print 0,StopMsTimer(-2)-tic			//100
	ErrorStr += ir_WriteMany(DDSWave)
//print 1,StopMsTimer(-2)-tic			// 56091.4
	
	
	Variable TempVal
	Variable HaveBoth = 0
	String OtherList = ";1;"
	String ParmName = "DriveFrequency"
	Wave NVW = root:Packages:MFP3D:Main:Variables:NapVariablesWave
	Variable ElectricTune = NVW[%ElectricTune][0]
	if (ElectricTune)
		ParmName = "Nap"+ParmName
		nop = 1
	endif
	for (A = 0;A < nop;A += 1)
		if (IsNan(DDS.Freq[A]))
			Continue
		endif
		HaveBoth += 1
		TempVal = td_ReadValue("DDSFrequency"+num2str(A))
		if (!IsNan(TempVal))
			DDS.Freq[A] = TempVal
			Thermal#PVTune(ParmName+StringFromList(A,OtherList,";"),TempVal)
		endif
	endfor
			
	if (HaveBoth == 2)
		Thermal#PVTune("FrequencyRatio",DDS.Freq[1]/DDS.Freq[0])
	endif

	return(ErrorStr)
End //ARWriteDDS


Function/S InitZFeedback(InfoStruct, [NoZ])
	Struct ARImagingModeStruct &InfoStruct
	Variable NoZ
	
	if (ParamIsDefault(NoZ))
		NoZ = 0
	endif
	NoZ = !(!NoZ)		//Force to be 0, 1 since we are using the value, not just true / false

	String ErrorStr = ""
	if (!InfoStruct.DidRead)
		ARGetImagingMode(InfoStruct)
	endif
	PV("ElectricTune",0)		//we never engage when in electric Tune Mode, but we need to make sure it is cleared
	//since that determines where we get some DDS parms.

	ErrorStr += ARWriteDDS(InfoStruct.DDS)

	if (InfoStruct.DFRTOn)
		wave/T DynamicAlias = $GetDF("Alias")+"DynamicAlias"
		DynamicAlias[%Frequency][0] = "$DDSFrequency0"//td_ReadString("Alias:DDSFrequency0")//"Lockin.0.Freq"
		WriteAllAliases()
		Wave FeedbackCoef = root:Packages:MFP3D:Main:FeedbackCoef
		FeedbackCoef = {0,-1}
		errorStr += num2str(td_SetLinearCombo("Amplitude1",root:Packages:MFP3D:Main:FeedbackCoef,"Amplitude"))+","
	endif
	
	if (InfoStruct.ImagingMode == 4)		//STM is special
		//the imaging gains are pretty low
		//which would cause overshoot in the engage.
		//so we use a CTFC to engage, and turn on the FB loop.
		if (InfoStruct.Feedback[0].PGain || InfoStruct.Feedback[0].IGain)
			RunEngageModule(InfoStruct.ImagingModeName,InfoStruct.Feedback[0].Setpoint,20,0)
			return(ErrorStr)
		endif
	endif

	Variable A, nop = InfoStruct.FeedbackCount
	Variable FreqGainOn
	Variable DriveGainOn
	Struct ARFeedbackStruct FB
	for (A = NoZ;A < nop;A += 1)
		FB = InfoStruct.Feedback[A]
		ErrorStr += ir_WritePIDSloop(FB)
	endfor

	Variable NeedUpdate = 0
	If (InfoStruct.ImagingMode == 2 && nop > 1)		// Fix up things for the FM loops
		FreqGainOn = GV("FreqGainOn")
		DriveGainOn = GV("DriveGainOn")
		If (!FreqGainOn)
			PV("FreqGainOn", 1)
			ARManageRunning("FreqFB",1)
			UpdateAllCheckBoxes("FreqGainOnBox_0",1)
			NeedUpdate = 1
		endif
		If (!DriveGainOn)
			PV("DriveGainOn", 1)
			ARManageRunning("DriveFB",1)
			UpdateAllCheckBoxes("DriveGainOnBox_0",1)
			NeedUpdate = 1
		endif
		if (NeedUpdate)
			UpdateMeterStatus(0)
			GhostNapPanel()							
			GhostFMPanel()
		endif
	endif			
	
	if (StringMatch(InfoStruct.Feedback[0].StartEvent,"1"))		//then we need to start them up at the same time.
		ErrorStr += num2str(td_WriteString("Event.1","Once"))+","
	endif


	return(ErrorStr)
End //InitZFeedback


Function MakePIDSLoopPanel(Var)
	Variable Var


	String WindowsFolder = GetDF("Windows")
	String GraphStr = GetFuncName()
	GraphStr = GraphStr[Strlen("Make"),Strlen(GraphStr)-1]
	Wave PanelParms = $WindowsFolder+GraphStr+"Parms"

	
	Variable HelpPos = PanelParms[%HelpPos][0]
	Variable SetUpLeft = PanelParms[%SetupLeft][0]
	Variable ControlBit = PanelParms[%Control1Bit][0]
	Variable OldControlBit = PanelParms[%oldControl1Bit][0]
	Variable Margin = PanelParms[%Margin][0]
	Variable ButtonWidth = PanelParms[%ButtonWidth][0]
	Variable ButtonHeight = PanelParms[%ButtonHeight][0]
	Variable Red = PanelParms[%RedColor][0]
	Variable Green = PanelParms[%GreenColor][0]
	Variable Blue = PanelParms[%BlueColor][0]
	Variable StepSize = 25
	Variable BodyWidth = PanelParms[%BodyWidth][0]
	
	Variable SecondMargin = PanelParms[%SecondMargin][0]
	
	Variable Bit
	String HelpFunc = "ARHelpFunc"
	String SetupFunc = "ARSetupPanel"
	Variable Enab = 0
	Variable DisableHelp = 0
	Variable LeftPos = Margin
	Variable FontSize = 11
	String ControlName, ControlName0, ControlName1, ControlName2, ControlName3, ControlName4
	String HelpName
	
	Variable TabNum = ARPanelTabNumLookup(GraphStr)
	String TabStr = "_"+num2str(TabNum)
	String SetupTabStr = TabStr+"9"
	String SetUpBaseName = GraphStr[0,strlen(GraphStr)-6]+"Bit_"
	
	String MakeTitle = "", MakeName = "", SetupName = ""
	Variable CurrentTop = 10
	if (Var == 0)		//MasterPanel
		CurrentTop = 40
		MakeTitle = "Make PIDSloop Panel"
		MakeName = GraphStr+"Button"+TabStr
		Enab = 1		//hide the controls, tabfunc will clear us up.
		GraphStr = ARPanelMasterLookup(GraphStr)
	elseif (Var == 1)	
		CurrentTop = 10
		MakeTitle = "Make Master PIDS Panel"
		MakeName = ARPanelMasterLookup(GraphStr)+Tabstr
		Enab = 0
	endif
	SetupName = GraphStr+"Setup"+TabStr


	String ParmName, ParmName0, ParmName1, ParmName2
	Variable Mode, GroupBoxTop
	Variable Width = 130


	LeftPos = 50
	String PIDSWaves = InitPIDSloopWaves()
	Wave/T PIDSloopWave = $StringFromList(0,PIDSWaves,";")
	String TableName = "PIDSLoopTable"

	edit/HOST=$GraphStr/N=$TableName/W=(LeftPos,48,965+LeftPos,522) PIDSloopWave.ld
	ModifyTable/W=$GraphStr+"#"+TableName size=16,width=Width,width(Point)=30


	CurrentTop += 522



	ControlName = "ReadPIDSloopAll"
	MakeButton(GraphStr,ControlName,"Read ALL",ButtonWidth+20,ButtonHeight,LeftPos,CurrentTop,"PIDSloopButtonFunc",Enab)
	ControlName = "WritePIDSLoopALL"
	MakeButton(GraphStr,ControlName,"Write ALL",ButtonWidth+20,ButtonHeight,LeftPos,CurrentTop+StepSize,"PIDSloopButtonFunc",Enab)

	ControlName = "StartPIDSLoopALL"
	MakeButton(GraphStr,ControlName,"Start ALL",ButtonWidth+20,ButtonHeight,LeftPos,CurrentTop+StepSize*2,"PIDSloopButtonFunc",Enab)
	ControlName = "StopPIDSLoopALL"
	MakeButton(GraphStr,ControlName,"Stop ALL",ButtonWidth+20,ButtonHeight,LeftPos,CurrentTop+StepSize*3,"PIDSloopButtonFunc",Enab)
	



	Struct ARColorStruct RedColor
	Struct ARColorStruct GreenColor
	Struct ARColorStruct YellowColor
	RedColor.Red = 65535
	GreenColor.Green = 65535
	YellowColor.Red = 65280
	YellowColor.Green = 65280//43520

	LeftPos += 188
	Variable A, nop = DimSize(PIDSloopWave,1)
	for (A = 0;A < nop;A += 1)
		ControlName = "ReadPIDSloop"+num2str(A)
		ControlName0 = "WritePIDSloop"+num2str(A)
		ControlName1 = "StartPIDSLoop"+num2str(A)
		ControlName2 = "StopPIDSLoop"+num2str(A)
		ControlName3 = "DefaultPIDSLoop"+num2str(A)
		ControlName4 = "PIDSLoopStatus"+num2str(A)

		MakeButton(GraphStr,ControlName,"Read",ButtonWidth,ButtonHeight,LeftPos+A*Width,CurrentTop,"PIDSloopButtonFunc",Enab)
		MakeButton(GraphStr,ControlName0,"Write",ButtonWidth,ButtonHeight,LeftPos+A*Width,CurrentTop+StepSize,"PIDSloopButtonFunc",Enab)
		MakeButton(GraphStr,ControlName1,"Start",ButtonWidth,ButtonHeight,LeftPos+A*Width,CurrentTop+StepSize*2,"PIDSloopButtonFunc",Enab)
		MakeValDisplay(GraphStr,ControlName4,"BogusVar"," ","title=\"\",size={15,15},mode=1,value=str2num("+GetWavesDataFolder(PIDSLoopWave,2)+"[%Status]["+num2str(A)+"])","",LeftPos+A*Width-10,CurrentTop+StepSize*2.5+3,-1,1,0,0,15,NaN,Enab,HighColor=GreenColor,ZeroColor=YellowColor,LowColor=RedColor)
		//MakeValDisplay(GraphStr,ControlName,ParmName,titleStr,executeStr																																											,Format,LeftPos,						CurrentTop,	LowValue,HighValue,MidValue,ValueWidth,BodyWidth,fontSize,Enab,[HighColor,ZeroColor,LowColor])
		MakeButton(GraphStr,ControlName2,"Stop",ButtonWidth,ButtonHeight,LeftPos+A*Width,CurrentTop+StepSize*3,"PIDSloopButtonFunc",Enab)

		MakePopup(GraphStr,ControlName3,"DefaultLoop",LeftPos-6+A*Width,CurrentTop+StepSize*4,"DefaulLoopPopFunc","GetDefaultLoopOps("+num2str(A)+")",0,Enab)

	endfor



End //MakePIDSLoopPanel


Function/S GetDefaultLoopOps(WhichLoop)
	Variable WhichLoop

	String output = ""
	Variable HasFM = GV("HasFM")
	Switch (WhichLoop)
		case 0:
			output = "XSensor;"
			break
		
		case 1:
			output = "YSensor;"
			break
		
		case 2:
			output = "Height;ZSensor;"
			break
		
		case 3:
			if (HasFM)
				output += "Drive(FM);"
			endif
			output += "Drive(PFM);"
			break
		
		case 4:
			output = "Potential;Frequency;"		//Potential drives the amplitude to zero, so it would prevent a Freq loop from running, so list these exclusive loops in the same bank.
			if (HasFM)
				Output += "Frequency(FM);"
			endif
			output += "Frequency(PFM);"
			break
		
		case 5:
			output = "None;"
			break
		
	endswitch

	return(output)
End //GetDefaultLoopOps


Function PIDSloopButtonFunc(InfoStruct)
	Struct WMButtonAction &InfoStruct
	//CtrlName
	//EventMod
	//EventCode
	
	if (InfoStruct.EventCode != 2)
		return(0)
	endif
	String CtrlName = InfoStruct.CtrlName
	Variable EventMod = InfoStruct.EventMod
	
	
	
	Variable DoWrite = stringmatch(CtrlName,"Write*")
	Variable DoAll = StringMatch(CtrlName,"*All")
	Variable DoStart = StringMatch(CtrlName,"Start*")

	Variable WhichLoop = GetEndNum(CtrlName)
	if (StringMatch(CtrlName,"Stop*"))
		if (DoAll)
			WhichLoop = -1
		endif
		ir_StopPISLoop(WhichLoop)
		return(0)
	endif
	
	String PIDSWaves = InitPIDSloopWaves()
	Wave/T PIDSloopWave = $StringFromList(0,PIDSWaves,";")
	Wave/T PIDSGroup = $StringFromList(1,PIDSWaves,";")
	Variable Start = 0
	Variable Stop = DimSize(PIDSLoopWave,1)
	if (!DoAll)
		Start = WhichLoop
		Stop = Start+1
	endif
	
	
	

	String output = "", LoopName

	Variable A
	for (A = Start;A < Stop;A += 1)
		if (DoStart)
			if (td_ReadValue("PIDSloop."+num2str(A)+".Status") != -1)
				//output += num2str(td_WriteValue("PIDSloop."+num2str(A)+".Status",1))+","
				output += num2str(td_WriteString("Event."+PIDSloopWave[%StartEvent][A],"once"))+","
			endif

		elseif (DoWrite)		//write
	
			LoopName = GetDimLabel(PIDSloopWave,1,A)//PIDSLoopWave[DimSize(PIDSloopWave,0)-1][A]
			if (!Strlen(LoopName))
				Loopname = "PIDSLoop."+num2str(A)
			else
				Output += num2str(td_WriteString("Alias:"+LoopName,"PIDSloop."+num2str(A)))+","
				output += ReadAllAliases()
			endif
			if (EventMod & 4)		//alt
				PIDSLoopWave[][A] = ""		//clear the wave
				SetDimLabel 1,A,$"",PIDSLoopWave
			endif
			PIDSGroup[] = PIDSLoopWave[P][A]
			if (str2num(PIDSGroup[%Status]) == -1)
				PIDSGroup[%Status] = "0"
			endif
			Output += num2str(td_WriteGroup(LoopName,PIDSgroup))+","
		endif
		
		ir_ReadPIDSLoop(A)
//		Output += num2str(td_ReadGroup(LoopName,PIDSgroup))+","
//		PIDSLoopWave[0,DimSize(PIDSLoopWave,0)-2][A] = PIDSGroup[P][0]
			
	endfor

	

	arreportError(output)
End //PIDSloopButtonFunc


Function DefaulLoopPopFunc(CtrlName,PopNum,PopStr)
	String CtrlName
	Variable PopNum		//not used
	String PopStr
	
	
	Variable WhichLoop = GetEndNum(CtrlName)
	
	
	Struct ARFeedbackStruct FB
	
	StrSwitch (PopStr)
	
		case "XSensor":
		case "YSensor":
		case "Height":
		case "ZSensor":
		case "Potential":
			ARGetFeedbackParms(FB,PopStr)
			break
		
		case "Drive(FM)":
		case "Frequency(FM)":
		case "Drive(PFM)":
		case "Frequency(PFM)":
			ARGetFeedbackParms(FB,PopStr[0,strsearch(PopStr,"(",0)-1],ImagingMode=2+Stringmatch(PopStr,"*(PFM)"))
			break
		
		case "Frequency":
			ARGetFeedbackParms(FB,PopStr,ImagingMode=1)
			break
		
		
	EndSwitch



	String PIDSWaves = InitPIDSloopWaves()
	Wave/T PIDSloopWave = $StringFromList(0,PIDSWaves,";")


	PIDSLoopWave[%InputChannel][WhichLoop] = FB.Input
	PIDSLoopWave[%OutputChannel][WhichLoop] = FB.Output
	if (isNan(FB.Setpoint))
		PIDSLoopWave[%DynamicSetpoint][WhichLoop] = "Yes"
		PIDSLoopWave[%Setpoint][WhichLoop] = "0"
	else
		PIDSLoopWave[%DynamicSetpoint][WhichLoop] = "No"
		PIDSLoopWave[%Setpoint][WhichLoop] = num2str(FB.Setpoint)
	endif
	//PIDSLoopWave[%DynamicSetpoint][WhichLoop] = StringFromList(FB.DynamicSetpoint,"No;Yes;",";")
	PIDSLoopWave[%SetpointOffset][WhichLoop] = num2str(FB.SetpointOffset)
	PIDSLoopWave[%DGain][WhichLoop] = num2str(FB.DGain)
	PIDSLoopWave[%PGain][WhichLoop] = num2str(FB.PGain)
	PIDSLoopWave[%IGain][WhichLoop] = num2str(FB.IGain)
	PIDSLoopWave[%SGain][WhichLoop] = num2str(FB.SGain)
	PIDSLoopWave[%OutputMin][WhichLoop] = num2str(FB.OutputMin)
	PIDSLoopWave[%OutputMax][WhichLoop] = num2str(FB.OutputMax)
	PIDSLoopWave[%StartEvent][WhichLoop] = FB.StartEvent
	PIDSLoopWave[%StopEvent][WhichLoop] = FB.StopEvent
	PIDSLoopWave[%Status][WhichLoop] = "0"
	SetDimLabel 1,WhichLoop,$FB.LoopName,PIDSLoopWave
	//PIDSLoopWave[%LoopName][WhichLoop] = FB.LoopName

End //DefaulLoopPopFunc


Function RunEngageModule(ImagingMode,Setpoint,RampRate,DelayTime)
	String ImagingMode
	Variable SetPoint,RampRate,DelayTime
	
	//front end to run the engage module from other places.
	
	String input = ""
	
	Input = EngageModule("Info")		//init the string
	
	String Argument
	Argument = StringByKey("ArgumentString0",Input,cMacroSep0,cMacroKey0,0)
	Argument = ReplaceStringBykey("StrValue",Argument,ImagingMode,cMacroSep1,cMacroKey1,0)
	Input = ReplaceStringByKey("ArgumentString0",Input,Argument,cMacroSep0,cMacroKey0,0)
	
	
	Argument = StringByKey("ArgumentString1",Input,cMacroSep0,cMacroKey0,0)
	Setpoint = Limit(Setpoint,NumberByKey("Low", Argument,cMacroSep1,cMacroKey1,0),NumberByKey("High", Argument,cMacroSep1,cMacroKey1,0))
	Argument = ReplaceNumberBykey("Value",Argument,Setpoint,cMacroSep1,cMacroKey1,0)
	Input = ReplaceStringByKey("ArgumentString1",Input,Argument,cMacroSep0,cMacroKey0,0)
	
	Argument = StringByKey("ArgumentString2",Input,cMacroSep0,cMacroKey0,0)
	RampRate = Limit(RampRate,NumberByKey("Low", Argument,cMacroSep1,cMacroKey1,0),NumberByKey("High", Argument,cMacroSep1,cMacroKey1,0))
	Argument = ReplaceNumberBykey("Value",Argument,RampRate,cMacroSep1,cMacroKey1,0)
	Argument = ReplaceStringBykey("UnitString",Argument,"V/s",cMacroSep1,cMacroKey1,0)
	Input = ReplaceStringByKey("ArgumentString2",Input,Argument,cMacroSep0,cMacroKey0,0)
	
	Argument = StringByKey("ArgumentString3",Input,cMacroSep0,cMacroKey0,0)
	DelayTime = Limit(DelayTime,NumberByKey("Low", Argument,cMacroSep1,cMacroKey1,0),NumberByKey("High", Argument,cMacroSep1,cMacroKey1,0))
	Argument = ReplaceNumberBykey("Value",Argument,DelayTime,cMacroSep1,cMacroKey1,0)
	Input = ReplaceStringByKey("ArgumentString3",Input,Argument,cMacroSep0,cMacroKey0,0)
	
	Input = ReplaceStringByKey("CallbackName",Input,"",cMacroSep0,cMacroKey0,0)
	
	EngageModule(Input)

End //RunEngageModule
