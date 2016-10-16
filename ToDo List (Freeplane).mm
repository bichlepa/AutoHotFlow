<map version="freeplane 1.5.9">
<!--To view this file, download free mind mapping software Freeplane from http://freeplane.sourceforge.net -->
<node TEXT="AutoHotFlow" FOLDED="false" ID="ID_594270831" CREATED="1475843060040" MODIFIED="1475844015344" STYLE="oval">
<font SIZE="18"/>
<hook NAME="MapStyle">
    <properties fit_to_viewport="false;" show_icon_for_attributes="true" show_note_icons="true"/>

<map_styles>
<stylenode LOCALIZED_TEXT="styles.root_node" STYLE="oval" UNIFORM_SHAPE="true" VGAP_QUANTITY="24.0 pt">
<font SIZE="24"/>
<stylenode LOCALIZED_TEXT="styles.predefined" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="default" COLOR="#000000" STYLE="fork">
<font NAME="SansSerif" SIZE="10" BOLD="false" ITALIC="false"/>
</stylenode>
<stylenode LOCALIZED_TEXT="defaultstyle.details"/>
<stylenode LOCALIZED_TEXT="defaultstyle.attributes">
<font SIZE="9"/>
</stylenode>
<stylenode LOCALIZED_TEXT="defaultstyle.note" COLOR="#000000" BACKGROUND_COLOR="#ffffff" TEXT_ALIGN="LEFT"/>
<stylenode LOCALIZED_TEXT="defaultstyle.floating">
<edge STYLE="hide_edge"/>
<cloud COLOR="#f0f0f0" SHAPE="ROUND_RECT"/>
</stylenode>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.user-defined" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="styles.topic" COLOR="#18898b" STYLE="fork">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.subtopic" COLOR="#cc3300" STYLE="fork">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.subsubtopic" COLOR="#669900">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.important">
<icon BUILTIN="yes"/>
</stylenode>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.AutomaticLayout" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="AutomaticLayout.level.root" COLOR="#000000" STYLE="oval" SHAPE_HORIZONTAL_MARGIN="10.0 pt" SHAPE_VERTICAL_MARGIN="10.0 pt">
<font SIZE="18"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,1" COLOR="#0033ff">
<font SIZE="16"/>
<edge COLOR="#ff0000"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,2" COLOR="#00b439">
<font SIZE="14"/>
<edge COLOR="#0000ff"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,3" COLOR="#990000">
<font SIZE="12"/>
<edge COLOR="#00ff00"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,4" COLOR="#111111">
<font SIZE="10"/>
<edge COLOR="#ff00ff"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,5">
<edge COLOR="#00ffff"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,6">
<edge COLOR="#7c0000"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,7">
<edge COLOR="#00007c"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,8">
<edge COLOR="#007c00"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,9">
<edge COLOR="#7c007c"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,10">
<edge COLOR="#007c7c"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,11">
<edge COLOR="#7c7c00"/>
</stylenode>
</stylenode>
</stylenode>
</map_styles>
</hook>
<hook NAME="AutomaticEdgeColor" COUNTER="7" RULE="ON_BRANCH_CREATION"/>
<node TEXT="Flow Editor" LOCALIZED_STYLE_REF="AutomaticLayout.level,1" POSITION="right" ID="ID_676038067" CREATED="1475843156191" MODIFIED="1475844030384" HGAP_QUANTITY="22.249999754130847 pt" VSHIFT_QUANTITY="-34.499998971819906 pt">
<node TEXT="Triggers" ID="ID_1650859575" CREATED="1475844012652" MODIFIED="1475844030383" HGAP_QUANTITY="14.0 pt" VSHIFT_QUANTITY="-28.499999150633833 pt">
<node TEXT="In particular" ID="ID_1672454178" CREATED="1475844039452" MODIFIED="1475844080792">
<node TEXT="Startup" ID="ID_985758743" CREATED="1475844083336" MODIFIED="1475844087997">
<node TEXT="Trigger on startup." ID="ID_1056069031" CREATED="1475844089652" MODIFIED="1475844102965"/>
</node>
</node>
</node>
<node TEXT="Elements" ID="ID_826895148" CREATED="1475843415003" MODIFIED="1475843432325">
<node TEXT="No dedicated types anymore." ID="ID_1435583786" CREATED="1475843442615" MODIFIED="1475843475831"/>
<node TEXT="Different shapes" ID="ID_511092078" CREATED="1475843478093" MODIFIED="1475843488296"/>
<node TEXT="Can have multiple entry points" ID="ID_1107635035" CREATED="1475843515705" MODIFIED="1475843524422"/>
<node TEXT="Can have multiple exit points" ID="ID_359550175" CREATED="1475843489564" MODIFIED="1475843506258"/>
<node TEXT="Simple API for element developers" ID="ID_423582846" CREATED="1475845870849" MODIFIED="1475845879686"/>
</node>
<node TEXT="Connections" ID="ID_366287541" CREATED="1475843437086" MODIFIED="1475843543613"/>
</node>
<node TEXT="Flow Execution" LOCALIZED_STYLE_REF="AutomaticLayout.level,1" POSITION="right" ID="ID_1223785699" CREATED="1475843207551" MODIFIED="1475843640681" HGAP_QUANTITY="17.749999888241295 pt" VSHIFT_QUANTITY="64.49999807775026 pt">
<node TEXT="Variable handling" ID="ID_442809546" CREATED="1475843321053" MODIFIED="1475843332071"/>
</node>
<node TEXT="Manager" LOCALIZED_STYLE_REF="AutomaticLayout.level,1" POSITION="left" ID="ID_1708887403" CREATED="1475843225641" MODIFIED="1475843757583" HGAP_QUANTITY="16.249999932944778 pt" VSHIFT_QUANTITY="-100.4999970048667 pt">
<node TEXT="Save Flow" ID="ID_236910174" CREATED="1475843370703" MODIFIED="1475843713678">
<icon BUILTIN="75%"/>
</node>
<node TEXT="Load Flow" ID="ID_1768334866" CREATED="1475843374472" MODIFIED="1475843717894">
<icon BUILTIN="75%"/>
</node>
<node TEXT="Show all flows" ID="ID_1200204304" CREATED="1475843822817" MODIFIED="1475843828861">
<node TEXT="Show their status" ID="ID_892587054" CREATED="1475843845460" MODIFIED="1475843849559"/>
</node>
<node TEXT="Edit flows" ID="ID_138894098" CREATED="1475843832585" MODIFIED="1475843868107"/>
<node TEXT="Delete flows" ID="ID_970764188" CREATED="1475843872508" MODIFIED="1475843874196"/>
<node TEXT="Rename flows" ID="ID_60623700" CREATED="1475843876498" MODIFIED="1475843878252"/>
<node TEXT="Start / stop Flows" ID="ID_937711218" CREATED="1475843880039" MODIFIED="1475843884275"/>
<node TEXT="Enable / Disable flows" ID="ID_425302366" CREATED="1475843885267" MODIFIED="1475843889280">
<node TEXT="On start, enable some flows." ID="ID_527088318" CREATED="1475843969756" MODIFIED="1475843999628"/>
</node>
<node TEXT="Copy flow" ID="ID_1591381192" CREATED="1475843952795" MODIFIED="1475843954499"/>
</node>
<node TEXT="Demonstration" LOCALIZED_STYLE_REF="AutomaticLayout.level,1" POSITION="left" ID="ID_1553043717" CREATED="1475843403493" MODIFIED="1475843758959" HGAP_QUANTITY="16.999999910593036 pt" VSHIFT_QUANTITY="68.99999794363981 pt">
<node TEXT="Demonstration flows" ID="ID_432309714" CREATED="1475843895834" MODIFIED="1475843899745">
<node TEXT="Can be hidden" ID="ID_1465179143" CREATED="1475843904798" MODIFIED="1475843917580"/>
<node TEXT="Cannot be changed" ID="ID_757323189" CREATED="1475843921587" MODIFIED="1475843927229"/>
<node TEXT="Can be copied and then become a normal editable flow" ID="ID_883218460" CREATED="1475843928538" MODIFIED="1475843946404"/>
</node>
</node>
</node>
</map>
