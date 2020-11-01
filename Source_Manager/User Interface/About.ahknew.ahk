; creates and opens the "about" GUI
init_about_gui()
{
	global
    
	; Disables the main manager gui
	Disable_Manager_GUI()

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

    gui, add, edit, w500 h500 readonly vGuiAboutEditControl, % licenseText
    gui, add, button, w500 h30 gguiAboutCloseButton, lang("Close")

    gui, show
}

guiAboutCloseButton()
{
    global

    gui, destroy
}

global global_aboutText
global_aboutText =
(
AutoHotFlow - Written by bichlepa (Paul Bichler)
Licensed under GNU General Public License 3
Sourcecode: https://github.com/bichlepa/AutoHotFlow

This application contains some code, which was written by other authors. This is an overview:

#aboutTextOtherCodeOverviewStart
Gdip standard library v1.45 - written by tic (Tariq Porter)
source: https://github.com/tariqporter/Gdip
license: unknown

AutoHotkey-JSON - written by cocobelgica
source: https://github.com/cocobelgica/AutoHotkey-JSON
license: WTFPL(see http://www.wtfpl.net/

Yunit - written by Uberi
source: https://github.com/Uberi/Yunit
license: GPL(see http://www.gnu.org/licenses/

Class_Monitor - written by jNizM
source: https://github.com/jNizM/Class_Monitor
license: The Unlicense(see https://unlicense.org/

Eject - written by SKAN
source: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4491
license: public domain(see https://creativecommons.org/publicdomain/zero/1.0/legalcode

HTTPRequest v2.49 - written by VxE
source: https://github.com/camerb/AHKs/blob/master/thirdParty/HTTPRequest.ahk
license: BSD(see https://opensource.org/licenses/BSD-3-Clause

HTTPRequest v2.49 - written by VxE
source: https://autohotkey.com/board/topic/69205-lib-oauth-10a-ahk-basic-ahk-l-unicode-v103/page-2
license: BSD(see https://opensource.org/licenses/BSD-3-Clause

Easy Text to speech - written by Learning one
source: https://autohotkey.com/board/topic/53429-function-easy-text-to-speech/
license: unknown (probably public domain)

#aboutTextOtherCodeOverviewStop

Full text of the GNU General Public License 3:


)