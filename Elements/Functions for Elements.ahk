MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,value)
{
	global
	Instance_%InstanceID%_%ElementID%_%ElementIDInInstance%_result:=value
	Instance_%InstanceID%_%ElementID%_%ElementIDInInstance%_finishedRunning:=true

}

MarkThatElementHasFinishedRunningOneVar(InstanceIDWithElementID,value)
{
	global
	%InstanceIDWithElementID%_result:=value
	%InstanceIDWithElementID%_finishedRunning:=true

}


