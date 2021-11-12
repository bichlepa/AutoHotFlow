# AutoHotFlow [[Download here]](https://github.com/bichlepa/AutoHotFlow/releases)
This script is designed to make programming and automation easy as never before! Just pull in some elements in the graphical interface and set up some triggers. Ready! :smile:
This project ist made for people who never have programmed before and for those who want to make some automation, etc. without writing long codes.
It's very easy to use. You need to pull an action or a condition, configurate them and connect them.
You can optionally add some triggers, that will trigger the flow in certain cases.

When the flow executes the currently running elements are highlighted red.

![Element Tooltip](/Documentation/screenshots/Flow%20Editor.png)

Every element has settings

![Element Tooltip](/Documentation/screenshots/Element%20Tooltip.png)

There is also flow manager

![Element Tooltip](/Documentation/screenshots/Manager.png?dl=1)

It has all basic functions. I'm working on it and its abilities are raising.

My aim is to include many elements that would need many lines of ahk-code and thus to allow programming some complex things easier.

It could also demontrate the broad possibilities of AutoHotkey.
You can track the progress on [trello](https://trello.com/b/Ca91IaeG/autohotflow). 

# How to install and use
Go the the [Relases section](https://github.com/bichlepa/AutoHotFlow/releases) and download the installer of the current version.
# How to develop
Here you'll find instructions for those who want to work on AHF.
After first checkout, `find modules.ahk` will be automatically started by AHF. Please run `find modules.ahk` every time after you pulled some changes. Otherwise errors may sometimes occur.
## Add new elements
If you want to add some new elements, you'll find everything you need in the folder `Tools for contributors\Element creation`.
## Improve AHF and create an installer
To create an installer, you have to run the script `innoSetupPrebuildSteps.ahk`. This will update the content of some files.
Then you can open the InnoSetup file `innoSetupScript.iss`.  To do that you have to install InnoSetup on your PC.
