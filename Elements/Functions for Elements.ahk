MarkThatElementHasFinishedRunning(InstanceID,threadID,ElementID,ElementIDInInstance,value)
{
	global
	Instance_%InstanceID%_%threadID%_%ElementID%_%ElementIDInInstance%_result:=value
	Instance_%InstanceID%_%threadID%_%ElementID%_%ElementIDInInstance%_finishedRunning:=true

}

MarkThatElementHasFinishedRunningOneVar(InstanceIDWithElementID,value)
{
	global
	%InstanceIDWithElementID%_result:=value
	%InstanceIDWithElementID%_finishedRunning:=true
	
	
}


