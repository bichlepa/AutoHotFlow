;When an element finishes it must call this function
;It sets some values that tell the run loop that the element has finished and the next ones can be executed
MarkThatElementHasFinishedRunning(InstanceID,threadID,ElementID,ElementIDInInstance,value,reason="")
{
	global
	if reason
		Instance_%InstanceID%_%threadID%_%ElementID%_%ElementIDInInstance%_reason:=reason
	
	Instance_%InstanceID%_%threadID%_%ElementID%_%ElementIDInInstance%_result:=value
	Instance_%InstanceID%_%threadID%_%ElementID%_%ElementIDInInstance%_finishedRunning:=true

}

MarkThatElementHasFinishedRunningOneVar(InstanceIDWithElementID,value)
{
	global
	%InstanceIDWithElementID%_result:=value
	%InstanceIDWithElementID%_finishedRunning:=true
	
	
}


