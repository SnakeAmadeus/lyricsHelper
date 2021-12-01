
import QtQuick 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls 2.00
import MuseScore 3.0
import FileIO 3.0
import "zparkingb/selectionhelper.js" as SelHelper



MuseScore 
{
    menuPath:    "Plugins.Lyrics Helper"
    version:     "3.0"
    description: qsTr("A plugin intends to help input lyrics. It is designed for East Asian languages (monosyllabic languages like Sino-Tibetian languages) but also work for other language texts with workarounds.")
    pluginType: "dock"

    implicitHeight: controls.implicitHeight * 1.5
    implicitWidth: controls.implicitWidth
    
    property var lrc: String("");
    property var lrcCursor: 0;

    onRun: {}

    FileIO 
    {
        id: myFileLyrics
        onError: console.log(msg + "  Filename = " + myFileLyrics.source);
    }
        
    FileDialog 
    {
        id: fileDialog
        title: qsTr("Please choose a .txt or .lrc file")
        nameFilters: ["lyrics files (*.txt *.lrc)"]
        onAccepted: 
        {
            var filename = fileDialog.fileUrl;
            //console.log("You chose: " + filename)
            if(filename)
            {
                myFileLyrics.source = filename;
                //behaviors after reading the text file
                lyricSource.text = "当前文件：" + myFileLyrics.source.slice(8); //trim path name for better view
                lyricSource.horizontalAlignment = Text.AlignLeft;
                lrc = myFileLyrics.read(); //file selection pop-up
                lrcDisplay.text = lrc; //update lyrics text to displayer
                lrcCursor = 0; //reset @lrcCursor
                inputButtons.enabled = true; //recover input buttons' availability
                updateDisplay();
            }
        }
    }
    //for debugging purpose. copy-pasted from https://github.com/mirabilos/mscore-plugins/blob/master/notenames-as-lyrics.qml
    function nameElementType(elementType) {
        switch (elementType) {
        case Element.ACCIDENTAL:
            return "ACCIDENTAL";
        case Element.AMBITUS:
            return "AMBITUS";
        case Element.ARPEGGIO:
            return "ARPEGGIO";
        case Element.ARTICULATION:
            return "ARTICULATION";
        case Element.BAGPIPE_EMBELLISHMENT:
            return "BAGPIPE_EMBELLISHMENT";
        case Element.BAR_LINE:
            return "BAR_LINE";
        case Element.BEAM:
            return "BEAM";
        case Element.BEND:
            return "BEND";
        case Element.BRACKET:
            return "BRACKET";
        case Element.BRACKET_ITEM:
            return "BRACKET_ITEM";
        case Element.BREATH:
            return "BREATH";
        case Element.CHORD:
            return "CHORD";
        case Element.CHORDLINE:
            return "CHORDLINE";
        case Element.CLEF:
            return "CLEF";
        case Element.COMPOUND:
            return "COMPOUND";
        case Element.DYNAMIC:
            return "DYNAMIC";
        case Element.ELEMENT:
            return "ELEMENT";
        case Element.ELEMENT_LIST:
            return "ELEMENT_LIST";
        case Element.FBOX:
            return "FBOX";
        case Element.FERMATA:
            return "FERMATA";
        case Element.FIGURED_BASS:
            return "FIGURED_BASS";
        case Element.FINGERING:
            return "FINGERING";
        case Element.FRET_DIAGRAM:
            return "FRET_DIAGRAM";
        case Element.FSYMBOL:
            return "FSYMBOL";
        case Element.GLISSANDO:
            return "GLISSANDO";
        case Element.GLISSANDO_SEGMENT:
            return "GLISSANDO_SEGMENT";
        case Element.HAIRPIN:
            return "HAIRPIN";
        case Element.HAIRPIN_SEGMENT:
            return "HAIRPIN_SEGMENT";
        case Element.HARMONY:
            return "HARMONY";
        case Element.HBOX:
            return "HBOX";
        case Element.HOOK:
            return "HOOK";
        case Element.ICON:
            return "ICON";
        case Element.IMAGE:
            return "IMAGE";
        case Element.INSTRUMENT_CHANGE:
            return "INSTRUMENT_CHANGE";
        case Element.INSTRUMENT_NAME:
            return "INSTRUMENT_NAME";
        case Element.JUMP:
            return "JUMP";
        case Element.KEYSIG:
            return "KEYSIG";
        case Element.LASSO:
            return "LASSO";
        case Element.LAYOUT_BREAK:
            return "LAYOUT_BREAK";
        case Element.LEDGER_LINE:
            return "LEDGER_LINE";
        case Element.LET_RING:
            return "LET_RING";
        case Element.LET_RING_SEGMENT:
            return "LET_RING_SEGMENT";
        case Element.LYRICS:
            return "LYRICS";
        case Element.LYRICSLINE:
            return "LYRICSLINE";
        case Element.LYRICSLINE_SEGMENT:
            return "LYRICSLINE_SEGMENT";
        case Element.MARKER:
            return "MARKER";
        case Element.MEASURE:
            return "MEASURE";
        case Element.MEASURE_LIST:
            return "MEASURE_LIST";
        case Element.MEASURE_NUMBER:
            return "MEASURE_NUMBER";
        case Element.NOTE:
            return "NOTE";
        case Element.NOTEDOT:
            return "NOTEDOT";
        case Element.NOTEHEAD:
            return "NOTEHEAD";
        case Element.NOTELINE:
            return "NOTELINE";
        case Element.OSSIA:
            return "OSSIA";
        case Element.OTTAVA:
            return "OTTAVA";
        case Element.OTTAVA_SEGMENT:
            return "OTTAVA_SEGMENT";
        case Element.PAGE:
            return "PAGE";
        case Element.PALM_MUTE:
            return "PALM_MUTE";
        case Element.PALM_MUTE_SEGMENT:
            return "PALM_MUTE_SEGMENT";
        case Element.PART:
            return "PART";
        case Element.PEDAL:
            return "PEDAL";
        case Element.PEDAL_SEGMENT:
            return "PEDAL_SEGMENT";
        case Element.REHEARSAL_MARK:
            return "REHEARSAL_MARK";
        case Element.REPEAT_MEASURE:
            return "REPEAT_MEASURE";
        case Element.REST:
            return "REST";
        case Element.SCORE:
            return "SCORE";
        case Element.SEGMENT:
            return "SEGMENT";
        case Element.SELECTION:
            return "SELECTION";
        case Element.SHADOW_NOTE:
            return "SHADOW_NOTE";
        case Element.SLUR:
            return "SLUR";
        case Element.SLUR_SEGMENT:
            return "SLUR_SEGMENT";
        case Element.SPACER:
            return "SPACER";
        case Element.STAFF:
            return "STAFF";
        case Element.STAFFTYPE_CHANGE:
            return "STAFFTYPE_CHANGE";
        case Element.STAFF_LINES:
            return "STAFF_LINES";
        case Element.STAFF_LIST:
            return "STAFF_LIST";
        case Element.STAFF_STATE:
            return "STAFF_STATE";
        case Element.STAFF_TEXT:
            return "STAFF_TEXT";
        case Element.STEM:
            return "STEM";
        case Element.STEM_SLASH:
            return "STEM_SLASH";
        case Element.STICKING:
            return "STICKING";
        case Element.SYMBOL:
            return "SYMBOL";
        case Element.SYSTEM:
            return "SYSTEM";
        case Element.SYSTEM_DIVIDER:
            return "SYSTEM_DIVIDER";
        case Element.SYSTEM_TEXT:
            return "SYSTEM_TEXT";
        case Element.TAB_DURATION_SYMBOL:
            return "TAB_DURATION_SYMBOL";
        case Element.TBOX:
            return "TBOX";
        case Element.TEMPO_TEXT:
            return "TEMPO_TEXT";
        case Element.TEXT:
            return "TEXT";
        case Element.TEXTLINE:
            return "TEXTLINE";
        case Element.TEXTLINE_BASE:
            return "TEXTLINE_BASE";
        case Element.TEXTLINE_SEGMENT:
            return "TEXTLINE_SEGMENT";
        case Element.TIE:
            return "TIE";
        case Element.TIE_SEGMENT:
            return "TIE_SEGMENT";
        case Element.TIMESIG:
            return "TIMESIG";
        case Element.TREMOLO:
            return "TREMOLO";
        case Element.TREMOLOBAR:
            return "TREMOLOBAR";
        case Element.TRILL:
            return "TRILL";
        case Element.TRILL_SEGMENT:
            return "TRILL_SEGMENT";
        case Element.TUPLET:
            return "TUPLET";
        case Element.VBOX:
            return "VBOX";
        case Element.VIBRATO:
            return "VIBRATO";
        case Element.VIBRATO_SEGMENT:
            return "VIBRATO_SEGMENT";
        case Element.VOLTA:
            return "VOLTA";
        case Element.VOLTA_SEGMENT:
            return "VOLTA_SEGMENT";
        default:
            return "(Element." + (elementType + 0) + ")";
        }
    }

    function getSelectedTicks() //get ticks of current selected segements, modified from https://musescore.org/en/node/293025
    {
        var minpos = 2147483647;
        var maxpos = 0;
        var seen = 0;
        var end = "";

        if (curScore.selection && curScore.selection.elements &&
            curScore.selection.elements.length) {
            var elts = curScore.selection.elements;
            console.log("operating on selection: " + elts.length);
            for (var idx = 0; idx < elts.length; ++idx) {
                var e = elts[idx];
                while (e) {
                    if (e.type == Element.SCORE) {
                        console.log("child of score");
                    } else if (e.type == Element.PAGE) {
                        console.log("child of page");
                    } else if (e.type == Element.SYSTEM) {
                        console.log("child of system");
                    } else if (e.type == Element.MEASURE) {
                        console.log("child of measure");
                    } else if (e.type != Element.SEGMENT) {
                        e = e.parent;
                        continue;
                    }
                    break;
                }
                if (!e || e.type != Element.SEGMENT) {
                    console.log("#" + idx + " skipped, " +
                        "no segment as parent");
                    continue;
                }
                console.log("#" + idx + " at " + e.tick);
                if (e.tick < seen) {
                    console.log("below " + seen + ", ignoring");
                    continue;
                }
                seen = e.tick ? 1 : 0;
                if (e.tick < minpos)
                    minpos = e.tick;
                if (e.tick > maxpos)
                    maxpos = e.tick;
            }
        }

        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);
        if (cursor.segment) {
            console.log("operating on cursor at " + cursor.tick);
            seen = cursor.tick ? 1 : 0;
            if (cursor.tick < minpos)
                minpos = cursor.tick;
            if (cursor.tick > maxpos)
                maxpos = cursor.tick;
            cursor.rewind(Cursor.SELECTION_END);
            if (!cursor.tick) {
                /* until end of the score */
                cursor.rewind(Cursor.SELECTION_START);
                while (cursor.next())
                    /* nothing */;
                end = " (end of score)";
                console.log("EOS at " + cursor.tick);
            } else
                console.log("cursor until " + cursor.tick);
            var csrmax = cursor.tick - 1;
            if (csrmax > seen) {
                if (csrmax < minpos)
                    minpos = csrmax;
                if (csrmax > maxpos)
                    maxpos = csrmax;
            }
        }

        if (minpos == 2147483647)
        {
            alert.text = "could not find position";
            return;
        }
        else if (maxpos <= minpos)
            return minpos + end;
        else
        {
            alert.text = "from " + minpos + " to " + maxpos + end;
            return;
        }  
        alert.open();
    }

    function getSelectedCursor() //move the cursor to the ticks from getSelectedTicks() and check if user selections are wack
    {
       //First, get current selected note (Uses: https://github.com/lgvr123/musescore-durationeditor/blob/master/zparkingb/selectionhelper.js)
       var selection = SelHelper.getNotesFromSelection();
       console.log("getSelectedCursor(): Current Selection is " + nameElementType(selection));
       //check if selection is empty or not a single note
       if (!selection || (selection.length == 0))
       {
            console.log("getSelectedCursor(): You ain't select nothing");
            return false;
       }
       console.log(selection.length);
       if (selection.length != 1)
       {
            console.log("getSelectedCursor(): Current Selection Must Be a Single Note!");
            return false;
       }
       //extract the first element of the selection and move the cursor onto it.
       var cursor = curScore.newCursor();
       cursor.track = selection[0].track;
       cursor.inputStateMode = 1;
       cursor.rewindToTick(getSelectedTicks()); //move cursor's to the ticks of selection.
       console.log(cursor.tick);
       return cursor;
    }

    function addSyllable(cursor)
    {
       //fill in the lyrics
       if(cursor)
       {
            console.log("-----------addSyllable() start----------");
            //in order to prevent crashing and bugs, let's create a "probing" cursor first to detect EOF before adding the lyrics
            var nextCursor = cursor; nextCursor.next();
            if(nextCursor.element == null) //if reaches the score EOF
            {
                if(getSelectedCursor().element.lyrics.length == 1) //if there already been lyrcis on the next element, do nothing
                {
                    console.log("EOF detected, you can't add more lyrics");
                    return false;
                }
                else //if no lyrics on the current note, add it but no future cursor is forwarded.
                {
                    var character = lrc.charAt(lrcCursor);
                    var fill = newElement(Element.LYRICS);
                    fill.text = character;
                    fill.voice = getSelectedCursor().voice;
                    curScore.startCmd();
                        console.log("410: current character = " + fill.text);
                        getSelectedCursor().element.add(fill);
                    curScore.endCmd();
                    nextChar();
                    updateDisplay();
                    return true;
                }
            }
            //if probing cursor passed the check, proceed to the main body of the function
            var cursor = getSelectedCursor(); //if no EOF are found, override the probing cursor with the normal cursor
            var character = lrc.charAt(lrcCursor);
            var fill = newElement(Element.LYRICS);
            fill.text = character;
            fill.voice = cursor.voice;
            //wrap the actions in startCmd() and endCmd() for real-time reactions from the score. 
            //Sepcial Thanks to Jojo-Schmitz https://musescore.org/en/node/326916
            curScore.startCmd();
                console.log("current character = " + fill.text);
                cursor.element.add(fill);
                var tempTick = cursor.tick;
                cursor.next();
                console.log("431: Next Selection is " + nextCursor.element.type);
                //if the next element is not a note
                if(cursor.element.type != 93) 
                {
                    var exceptionType = cursor.element.type;
                    if(exceptionType == 25) //if the next element is a rest.
                    {
                        while(cursor.element.type != 93) // wind forward until detecting a valid note
                        {
                            cursor.next();
                            console.log("441: Rest detected, move to next selection: " + nameElementType(cursor.element) + " at " + cursor.tick);
                            if(nextCursor.element == null) 
                            {
                                console.log("444: EOF detected, close the lyrics input process");
                                cursor.rewindToTick(tempTick);//corner case: tail of score are rests:
                                if(cursor.element.lyrics.length > 1) removeElement(cursor.element.lyrics[1]);
                                curScore.selection.clear();
                                curScore.endCmd();
                                return false;//encounters the EOF, immediately shut down
                            }
                        }
                    }
                }
                curScore.selection.select(cursor.element.notes[0]);//move selection to the next note
            curScore.endCmd();
            //move the lyrics cursor to the next character
            nextChar();
            updateDisplay();
            console.log("------------addSyllable() end-------------");
       }
    }

    function addMelisma(cursor)
    {
        if(cursor && (cursor.element.lyrics.length == 1))
        {
            var existed = cursor.element.lyrics[0].text;
            console.log("r");
        }
    }

    function addPolysyllable(cursor)
    {
        
    }

    function updateDisplay() //update display to lrcDisplay.text
    {
        if(lrcCursor == 0)
        {
            lrcDisplay.text = "<b>" + lrc.slice(0,1) + "</b>" + "<font color=\"grey\">" + lrc.slice(1) + "</font>";
        }
        else if(lrcCursor == lrc.length - 1)
        {
            lrcDisplay.text = "<font color=\"grey\">" + lrc.slice(0, current) + "</font>" + "<b>" + lrc.slice(current) + "</b>";
        }
        else
        {
             lrcDisplay.text = "<font color=\"grey\">" + lrc.slice(0,lrcCursor) + "</font>" + "<b>" + lrc.slice(lrcCursor, lrcCursor + 1) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor + 1) + "</font>";
        }
    }

    function nextChar() //advancing the @lrcCursor forward by a char
    {
        var next = lrcCursor + 1;
        if(next >= lrc.length) //loops back to the begining if the @lrcCursor reaches EOF.
        { 
            lrcCursor = 0; return false;
        }
        else //normal case
        {
            lrcCursor = next;
            //check if the next character is "\n" or white space, if it is, skip first
            if(next <= lrc.length - 1) //check if index out of bound error first
            {
                if(lrc.charAt(next) == '\n' || lrc.charAt(next) == ' ')
                {
                    nextChar(); return false; //continously skip until no '\n' or whitespaces were found
                }
            }
            else return true;
        }
    }

    function prevChar() //stepping the @lrcCursor back by a char, same structure as the nextChar() above
    {
        var prev = lrcCursor - 1;
        if(prev <= lrc.length) //loops back to the begining if the @lrcCursor reaches begining.
        { 
            lrcCursor = lrc.length - 1; return false;
        }
        else //normal case
        {
            lrcCursor = prev;
            //check if the next character is "\n" or white space, if it is, skip first
            if(prev <= lrc.length - 1) //check if index out of bound error first
            {
                if(lrc.charAt(prev) == '\n' || lrc.charAt(prev) == ' ')
                {
                    prevChar(); return false; //continously skip until no '\n' or whitespaces were found
                }
            }
            else return true;
        }
    }

    Column 
    {
        id: controls
        Grid
        {
            id: lyricSourceControl
            columns: 2
            rows: 1
            spacing: 4
            Text 
            {
                id: lyricSource
                height: parent.height
                width: inputButtons.width - buttonOpenFile.width
                wrapMode: Text.WrapAnywhere
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "先点这儿打开一个歌词文件→"
            }
            Button 
            {
                id : buttonOpenFile
                width: nextButton.width/4
                text: qsTr("...")
                onClicked: {
                     fileDialog.open();
                }
            }
        }
        Grid
        {
            id: inputButtons
            columns: 3
            rows: 1
            spacing: 4
            enabled: false
            Button 
            {
                id: nextButton
                text: "单音"
                onClicked:
                {   
                    addSyllable(getSelectedCursor());
                }
            }
            Button 
            {
                id: melismaButton
                text: "转音"
                onClicked:
                {
                    addMelisma(getSelectedCursor());
                }
            }
            Button 
            {
                id: polySyllabicButton
                text: "多音"
                onClicked:
                {
                    addPolysyllable(getSelectedCursor());
                }
            }
        }
        Text
        {
            id: lrcDisplay
            text: "请先选择一个歌词文件"
        }
    }
}

