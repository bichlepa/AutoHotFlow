; creates and opens the "about" GUI
init_about_gui()
{
	global

    ; define the license text, which will be shown in the GUI
    local licenseText
    licenseText := global_aboutText
    licenseText := StrReplace(licenseText, "#aboutTextOtherCodeOverview" "Start")
    licenseText := StrReplace(licenseText, "#aboutTextOtherCodeOverview" "Stop")

    local gplLicenseText
    fileread, gplLicenseText, %a_scriptDir%\..\License.txt
    licenseText .= gplLicenseText

    ; create the gui
    gui, about:default
    gui, destroy

    gui, add, edit, w700 h500 readonly vGuiAboutEditControl, % licenseText
    gui, add, button, w700 h30 gguiAboutCloseButton, % lang("Close")

    gui, show,, % lang("About AutoHotFlow")
}

; react if user clicks on the close button
guiAboutCloseButton()
{
    global

    gui, destroy
}

; react if user closes the window
aboutGuiClose()
{
    global

    gui, destroy
}

; define the text which will be shown in the gui.
; the content will be modified by the "find modles.ahk" script.
global global_aboutText
global_aboutText =
(
AutoHotFlow - Written by bichlepa (Paul Bichler)
Licensed under GNU General Public License 3
Sourcecode: https://github.com/bichlepa/AutoHotFlow

This application contains some code, which was written by other authors. This is an overview:
#aboutTextOtherCodeOverviewStart
Gdip standard library v1.45
author: tic (Tariq Porter)
source: https://github.com/tariqporter/Gdip
license: unknown

AutoHotkey-JSON
author: cocobelgica
source: https://github.com/cocobelgica/AutoHotkey-JSON
license: WTFPL
link to license text: http://www.wtfpl.net/

Yunit
author: Uberi
source: https://github.com/Uberi/Yunit
license: GPL
link to license text: http://www.gnu.org/licenses/

Class_Monitor
author: jNizM
source: https://github.com/jNizM/Class_Monitor
license: The Unlicense
link to license text: https://unlicense.org/

Eject
author: SKAN
source: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4491
license: public domain
link to license text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

HTTPRequest v2.49
author: VxE
source: https://github.com/camerb/AHKs/blob/master/thirdParty/HTTPRequest.ahk
license: BSD
link to license text: https://opensource.org/licenses/BSD-3-Clause

HTTPRequest v2.49
author: VxE
source: https://autohotkey.com/board/topic/69205-lib-oauth-10a-ahk-basic-ahk-l-unicode-v103/page-2
license: BSD
link to license text: https://opensource.org/licenses/BSD-3-Clause

Easy Text to speech
author: Learning one
source: https://autohotkey.com/board/topic/53429-function-easy-text-to-speech/
license: unknown (probably public domain)

#aboutTextOtherCodeOverviewStop
Full text of the GNU General Public License 3:


)