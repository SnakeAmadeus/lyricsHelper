//==============================================
//  Lyrics Helper
//  Copyright (©) 2021 Snake4Y5H
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENCE.GPL
//==============================================
import QtQuick 2.9
import QtQuick.Dialogs 1.2
import QtQuick.Controls 2.2
import QtQml 2.2
import MuseScore 3.0
import FileIO 3.0
import Qt.labs.folderlistmodel 2.2
import "zparkingb/selectionhelper.js" as SelHelper

MuseScore 
{
    menuPath:    "Plugins.Lyrics Helper"
    version:     "3.0"
    description: qsTr("A plugin intends to help input lyrics. It is designed for East Asian languages (monosyllabic languages like Sino-Tibetian languages) but also work for other language texts with workarounds.\nGithub Page: https://github.com/SnakeAmadeus/lyricsHelper\nby Snake4y5h")
    pluginType: "dock"
    dockArea: "Right"

    implicitHeight: controls.implicitHeight * 1.5
    implicitWidth: controls.implicitWidth

    //@replaceMode indicates whether replacing the existed lyrics when encountering a lyrics conflict. default = true
    property alias replaceMode : replaceModeCheckBox.checked;
    //@previewSoundMode decides whether preview note's sound when cursor advances. default = true
    property alias previewSoundMode: previewSoundModeCheckBox.checked;
    //@maximumUndoStep decides the max amount of actions that is done by lyricsHelper can be undone. default = 50
    property alias maximumUndoSteps: maximumUndoStepsSpinBox.value;
    //@skipTiedNotesMode decides whether the cursor advancing while inputing lyrics treat tied notes as one note or multiple notes. default = false
    property alias skipTiedNotesMode: skipTiedNotesModeCheckBox.checked;

    property var lrc: String("");
    property var lrcCursor: [0];
    //helper toString() function for @lrcCursor
    function lrcCursorToString(c) {if(c.length == 1) return c[0]; else return c[0] + "-" + c[1];}
    //helper parse() function that parses the string format of toString()
    function lrcCursorParse(c) {if(c.split('-').length == 1) return [parseInt(c)]; else return [parseInt(c.split('-')[0]),parseInt(c.split('-')[1])];}
    //helper clone() that clones a copy of lrcCursor
    function lrcCursorClone(c) {return c.slice();}

    //@hyphenatedMode decides whether the single unit of lyrics selection is between whitespaces or (whitespaces and hyphens.) default = false
    property alias hyphenatedMode: hyphenatedModeToggle.checked;
    property var separator: [' '];
    function isSeparator(s) {for(var i = 0; i < separator.length; i++) {if (s == separator[i]) return i.toString();} return false;}

    //decides which line of lyrics is going to input.
    property var lyricsLineNum: 0;

    property var isFirstRun: true;

    onRun: {}

    FileIO 
    {
        id: myFileLyrics
        onError: console.log("Failed to read lyrics file: " + myFileLyrics.source);
    }

    FileDialog 
    {
        id: openLrcDialog
        title: qsTr("Please choose a .txt or .lrc file")
        nameFilters: ["lyrics files (*.txt *.lrc)"]
        onAccepted: 
        {
            var filename = openLrcDialog.fileUrl;
            acceptFile(filename);
        }
    }

    FileDialog 
    {
        id: lrcExportDialog
        function saveFile(fileUrl, text)
        {
            var request = new XMLHttpRequest();
            request.open("PUT", fileUrl, false);
            request.send(text);
            return request.status;
        }
        function getPath(fileUrl) {
            for(var i = fileUrl.length - 1; i >= 0 ;i--) {if(fileUrl.charAt(i) == '/') return fileUrl.substring(0,i);}}
        title: qsTr("Save As...")
        nameFilters: ["lyrics files (*.txt *.lrc)"]
        selectExisting: false
        onAccepted: saveFile(lrcExportDialog.fileUrl, lrcEdit.text);
    }
    
    function acceptFile(filename) //helper function that reads a file for widget openLrcDialog and fileDrop
    {
        if(filename)
        {
            //console.log("You chose: " + filename)
            myFileLyrics.source = filename;
            //behaviors after reading the text file
            lyricSource.text = qsTr("Current File: ") + myFileLyrics.source.slice(8); //trim path name for better view
            lyricSource.horizontalAlignment = Text.AlignLeft;
            acceptLyrics(myFileLyrics.read());
            //for japaneseToKana backup its before converting lyrics
            if(japaneseToKana.hasJapanese(lrc)) japaneseToKana.lrcBackup = lrc;
        }
    }
    function acceptLyrics(text)
    {
        lrc = text;
        lrcDisplay.text = text; //update lyrics text to displayer
        lrcDisplay.width = lrcDisplayScrollView.width;
        if(lrcCursor.length == 1) lrcCursor = [0]; else {lrcCursor = [0,1]; expandCharToWord(0);}//reset @lrcCursor
        prevChar(); nextChar(); //forcefully skip all the whitespaces in the file head.
        inputButtons.enabled = true; //recover input buttons' availability
        updateDisplay(); 
        texteditButtons.enableLrcDisplay();
        //check the language of lyrics, see if they are convertable in specific language.
        hyphenation.enabled = hyphenation.hasLatinAlphabet(lrc);
        hyphenation.text = hyphenation.enabled ? hyphenation.deafultText : hyphenation.langNotFoundText;
        japaneseToKana.enabled = japaneseToKana.hasJapanese(lrc);
        japaneseToKana.text = japaneseToKana.enabled ? japaneseToKana.deafultText : japaneseToKana.langNotFoundText;
        //if its plugin's first run, prompt user how to adjust lyics verse lines
        if(isFirstRun) 
        {
            lyricsLineNumIndicatorGrid.visible = true; 
            lyricsLineNumIndicator.tooltip = qsTr(" (Scroll Mouse Here to Adjust)")
            lyricsLineNumIndicator.downArrow = "▼ "; lyricsLineNumIndicator.upArrow = " ▲";
            lyricsLineNumAdjust.updateLyricsLineDisplay();
            lyricsLineNumScroll.enabled = true; lyricsLineNumAdjust.enabled = true;
            lyricsLineNumIndicatorPrompt.start();
            isFirstRun = false;
        }
        //resize the panel
        controls.height = lyricSourceControl.height + inputButtons.height + lrcDisplayScrollView.height;
        //clean vertical increment cache
        verticalIncrementsCache = [];
        getVerticalIncrement();
        //clean undo stack
        undo_stack = [];
    }

    //Functionality: click on lyricSource to auto load a text file to the lyricsHelper
    //that contains the current score's name, in the same path as the current score
    property var curScorePath : "";
    property var curScoreFileName : "";
    property var curScoreName : "";
    function autoLoadLyrics()
    {
        var scorePath = curScore.path.replace(/\\/g, '/');
        if(scorePath.charAt(0) == '/') scorePath = scorePath.substring(1);
        myFileScore.source = "file:///" + scorePath; //in some MuseScore's languages context, the os.sep is \ instead of / idk why
        console.log("autoLoadLyrics(): Current Score is: " + myFileScore.source);
        curScoreFileName = myFileScore.source.split('/').pop();
        curScorePath = myFileScore.source.slice(0,myFileScore.source.lastIndexOf(curScoreFileName));
        curScoreName = curScoreFileName.split('.')[0];
        searchTxtFolderListModel.folder = curScorePath;
        curScorePath = curScorePath.slice(8);
        lyricSource.horizontalAlignment = Text.AlignHCenter;
        lyricSource.text = qsTr("Auto Loading Lyrics...");
        searchTxtDelayRunning.start();
    }
    FileIO //FileIO stores the path of the current score
    {
        id: myFileScore
        onError: console.log("Failed to read Score: " + myFileScore.source);
    }
    FolderListModel //FolderListModel assists autoLoadLyrics() to search .txt files in the specified folder
    {
        id: searchTxtFolderListModel
        property var tempLrcCursor : [];
        function searchTxt()
        {
            tempLrcCursor = lrcCursor;
            for(var i = 0; i < searchTxtFolderListModel.count; i++)
                  if(searchTxtFolderListModel.get(i, "fileName").split('.').pop() == "txt")
                        if (searchTxtFolderListModel.get(i, "fileName").toLowerCase().includes(curScoreName.toLowerCase())) //make it non-case-sensitive
                              {acceptFile(searchTxtFolderListModel.get(i, "fileURL")); return true;}
            //in case nothing was found:
            lyricSource.text = qsTr("Couldn't find any .txt file contains\nthe Current Score's name in the same path."); 
            autoReadLyricsFailedMessage.start();
        }
    }
    
    //Functionality: Drag&Drop lyrics text file to the plugin
    //workarounds for DropArea validates file extensions because the DropArea.keys were not functioning properly
    //Reference: https://stackoverflow.com/a/28800328
    MouseArea 
    { 
        anchors.fill: controls
        hoverEnabled: true
        enabled: !fileDrop.enabled
        onContainsMouseChanged: fileDrop.enabled = true
    }
    DropArea
    {
        id: fileDrop
        anchors.fill: controls
        onEntered:
        {
            if(drag.urls.length == 1) 
                if(drag.urls[0].split('.').pop() == "txt")
                    return;
            drag.accept();
            fileDrop.enabled = false
        }
        onDropped:
        {
            var filename = Qt.resolvedUrl(drop.urls[0]);
            acceptFile(filename);
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
            //console.log("operating on selection: " + elts.length);
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
                    //console.log("#" + idx + " skipped, " + "no segment as parent");
                    continue;
                }
                //console.log("#" + idx + " at " + e.tick);
                if (e.tick < seen) {
                    //console.log("below " + seen + ", ignoring");
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
            //console.log("operating on cursor at " + cursor.tick);
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
       //console.log(selection.length);
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
       //console.log(cursor.tick);
       return cursor;
    }

    //helper function that returns a string of currently selected lyrics
    function getSelectedLyric() {if(lrcCursor.length == 1) return lrc.charAt(lrcCursor[0]); else return lrc.substring(lrcCursor[0],lrcCursor[1]);}

    //helper function that returns the note's lyrics object at cursor's position with specified verse line. If not found @return false.
    function getNoteLyrics(cursor, verseLine)
    {
        if(cursor.element.lyrics.length == 0) return false;
        for(var i = 0; i < cursor.element.lyrics.length; i++)
            if(cursor.element.lyrics[i].verse == verseLine) return cursor.element.lyrics[i];
        return false;
    }

    //core function for the "Add Syllable" button
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
                cursor = getSelectedCursor();
                if(getNoteLyrics(cursor,lyricsLineNum)) //if there already been lyrcis on the next element, do nothing and deselect
                {
                    console.log("addSyllable(): EOF detected, you can't add more lyrics");
                    curScore.selection.clear();
                    curScore.endCmd();
                    return false;
                }
                else //if no lyrics on the current note, add it but no future cursor is forwarded.
                {
                    var character = getSelectedLyric();
                    var fill = newElement(Element.LYRICS);
                    fill.text = character;
                    fill.verse = lyricsLineNum;
                    curScore.startCmd();
                        console.log("addSyllable(): current character = " + fill.text);
                        cursor.element.add(fill);
                        addHyphen(cursor);
                        pushToUndoStack(cursor, "addSyllable()");
                    curScore.endCmd();
                    nextChar();
                    updateDisplay();
                    return true;
                }
            }
            //if probing cursor passed the check, proceed to the main body of the function
            var cursor = getSelectedCursor(); //if no EOF are found, override the probing cursor with the normal cursor
            var character = getSelectedLyric();
            var fill = newElement(Element.LYRICS);
            fill.text = character;
            fill.verse = lyricsLineNum;
            //wrap the actions in startCmd() and endCmd() for real-time reactions from the score. 
            //Sepcial Thanks to Jojo-Schmitz https://musescore.org/en/node/326916
            curScore.startCmd();
                console.log("addSyllable(): current character = " + fill.text);
                var tempTick = cursor.tick;
                if(getNoteLyrics(cursor,lyricsLineNum)) //if replaceMode is ON, replace the existed character
                {
                    console.log("addSyllable(): conflicted lyrics detected!");
                    if(replaceMode == 1)
                    {
                        removeElement(getNoteLyrics(cursor,lyricsLineNum));
                    }
                    else
                    {
                        curScore.endCmd();
                        return false;
                    }
                }
                if(isInsideMelismaLine(cursor)) //if replaceMode is ON, and selection is inside a melisma line, cut the line and add the character
                {
                    console.log("addSyllable(): conflicted melisma line detected!");
                    if(replaceMode == 1)
                    {
                        var checkLength = 0;
                        do
                        {
                            cursor.prev();
                            checkLength += durationTo64(cursor.element.duration);
                        }while(durationTo64(getNoteLyrics(cursor,lyricsLineNum).lyricTicks) == 0) 
                        getNoteLyrics(cursor,lyricsLineNum).lyricTicks = fraction(checkLength, 64);
                    }
                    else
                    {
                        curScore.endCmd();
                        return false;
                    }
                }
                cursor.rewindToTick(tempTick);
                if((cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) && skipTiedNotesMode) //if selected note is inside a tie, jump to the begining of the tie
                {
                    curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                    cursor = getSelectedCursor();
                }
                cursor.element.add(fill);
                addHyphen(cursor);
                pushToUndoStack(cursor, "addSyllable()");
                cursor.next();
                console.log("addSyllable(): Next Selection is " + nextCursor.element.type);
                //if the next element is not a note
                if(cursor.element.type != 93) 
                {
                    var exceptionType = cursor.element.type;
                    if(exceptionType == 25) //if the next element is a rest.
                    {
                        while(cursor.element.type != 93) // wind forward until detecting a valid note
                        {
                            cursor.next();
                            console.log("addSyllable(): Rest detected, move to next selection: " + nameElementType(cursor.element) + " at " + cursor.tick);
                            if(cursor.element == null) 
                            {
                                console.log("addSyllable(): EOF detected, close the lyrics input process");
                                cursor.rewindToTick(tempTick);//corner case: tail of score are rests:
                                if(getNoteLyrics(cursor,lyricsLineNum)) removeElement(getNoteLyrics(cursor,lyricsLineNum));
                                curScore.selection.clear();
                                curScore.endCmd();
                                return false;//encounters the EOF, immediately shut down
                            }
                        }
                    }
                }
                var nextNote = cursor.element.notes[0];
                //if the next note is a tied note
                if((nextNote.tieBack != null) && skipTiedNotesMode)
                {
                    curScore.selection.select(nextNote.lastTiedNote);
                    console.log("addSyllable(): Tied Note detected, move to tied note's tail at " + cursor.tick);
                    cursor.next();
                    if(cursor.element == null)//corner case: the element after the tail of the tied note is score EOF, deselect and shut down.
                    {
                        console.log("addSyllable(): EOF detected, you can't add more lyrics");
                        curScore.selection.clear();
                        curScore.endCmd();
                        return false;
                    }
                    if(cursor.element.type != 93) //corner case: the element after the tail of the tied note is a rest
                    {
                        var exceptionType = cursor.element.type;
                        if(exceptionType == 25) //if the next element is a rest.
                        {
                            while(cursor.element.type != 93) // wind forward until detecting a valid note
                            {
                                cursor.next();
                                console.log("addSyllable(): Rest detected, move to next selection: " + nameElementType(cursor.element) + " at " + cursor.tick);
                                if(nextCursor.element == null) 
                                {
                                    console.log("addSyllable(): EOF detected, close the lyrics input process");
                                    //corner corner case = = : after-tail of tied notes's elements are rests and also extend to the EOF:
                                    curScore.selection.clear();
                                    curScore.endCmd();
                                    return false;//encounters the EOF, immediately shut down
                                }
                            }
                        }
                    }
                }
                curScore.selection.select(cursor.element.notes[0]);//move selection to the next note
                if (previewSoundMode == 1) playCursor(cursor);
            curScore.endCmd();
            //move the lyrics cursor to the next character
            nextChar();
            updateDisplay();
            console.log("------------addSyllable() end-------------");
            return true;
       }
    }

    //core function for the "Extend Melisma" button
    function addMelisma(cursor)
    {
        if(cursor)
        {
            console.log("-----------addMelisma() start----------");
            //MuseScore's Lyrics' Melisma was manipulated by the lyrics.lyricTicks property, which is a property of Ms::PluginAPI::Element
            //Because the lyrics Object was wrapped in Ms::PluginAPI::Element, so the cursor.element.lyrics's type is actually Ms::PluginAPI::Element, instead of a lyrics object
            //There is no direct access to the object of Lyrics' members as shown in the libmscore/lyrics.h
            //The definition of this lyrics.lyricTicks is the sum of note values from *begining* of the first note to the *begining* of the last note.
            //So the calculation rule of the length of Melisma line will be from the selected note to the last note that has lyrics under it.
            //Move the cursor backward, Add up the note value of [start note, end note); if rests are other wack occurred, abort the operation.
            var tempTick = cursor.tick; //backup cursor's original position
            var melismaLength = 0;
            //things need to be checked for the current selected note to avoid glitches
            //if the skipTiedNotesMode is ON, then:
            //check if the selected note is in the middle of the tie that has lyric on the first tied note, give users the option to decide whether treat tied notes as one note or not
            if((cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) && skipTiedNotesMode)
            {
                curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                cursor = getSelectedCursor();
                if(getNoteLyrics(cursor,lyricsLineNum))
                {
                    console.log("addMelisma(): Middle of the tie detected, do nothing"); 
                    cursor.rewindToTick(tempTick);
                    curScore.selection.select(cursor.element.notes[0]);
                    return false;
                }
                cursor.rewindToTick(tempTick);
                curScore.selection.select(cursor.element.notes[0]);
            }
            //check if the current note already has lyrics, it will cause conflicts in this case
            if(getNoteLyrics(cursor,lyricsLineNum))
            {
                if(replaceMode == 1)//depends on whether replace mode is ON or OFF. If ON, current lyrics will be dropped and become melisma line
                {
                    console.log("addMelisma(): Lyrics conflict detected, drop existed lyrics");
                    removeElement(getNoteLyrics(cursor,lyricsLineNum));
                }
                else
                {
                    console.log("addMelisma(): Lyrics conflict detected, do nothing"); return false;
                }
            }
            //other things need to be checked for the prev note to avoid glitches
            cursor.prev();
            if(cursor.element == null) //check if reach the filehead
            {
                console.log("addMelisma(): Filehead detected, do nothing"); return false;
            }
            if(cursor.element.type == 25) //if the prev element is a rest.
            {
                console.log("addMelisma(): Rest detected, do nothing"); return false;
            }
            cursor.next(); //finish checking
            //Start searching for the last note that has lyrics
            do
            {
                cursor.prev();
                if(cursor.element == null) //check if reach the filehead
                {
                    console.log("addMelisma(): Filehead detected, do nothing"); return false;
                }
                if(cursor.element.type == 25) //if the prev element is a rest.
                {
                    console.log("addMelisma(): Rest detected, do nothing"); return false;
                }
                melismaLength += durationTo64(cursor.element.duration);//duration to 64 for more convenient calculation
            } while(!getNoteLyrics(cursor,lyricsLineNum))
            melismaLength = fraction(melismaLength, 64); //64 to duration
            curScore.startCmd();
                getNoteLyrics(cursor,lyricsLineNum).lyricTicks = melismaLength;
                console.log("addMelisma(): Final Melisma Length: " + getNoteLyrics(cursor,lyricsLineNum).lyricTicks.str);
                cursor.rewindToTick(tempTick);
                cursor.next();
                //if reaches the score EOF
                if(cursor.element == null)
                {
                    console.log("addMelisma(): EOF detected, close the lyrics input process");
                    curScore.selection.clear();
                    curScore.endCmd();
                    return false;
                }
                //if the next element is not a note
                if(cursor.element.type == 25) //if the next element is a rest.
                {
                    while(cursor.element.type != 93) // wind forward until detecting a valid note
                    {
                        cursor.next();
                        console.log("addMelisma(): Rest detected, move to next selection: " + nameElementType(cursor.element) + " at " + cursor.tick);
                        if(cursor.element == null) 
                        {
                            console.log("addMelisma(): EOF detected, close the lyrics input process");
                            cursor.rewindToTick(tempTick);//corner case: tail of score are rests:
                            curScore.selection.clear();
                            curScore.endCmd();
                            return false;//encounters the EOF, immediately shut down
                        }
                    }
                }
                curScore.selection.select(cursor.element.notes[0]);//move selection to the next note
                if (previewSoundMode == 1) playCursor(cursor);
            curScore.endCmd();
            console.log("------------addMelisma() end-------------");
            return true;
        }
    }

    //core function for the "Concatenate Synalepha" button
    function addSynalepha(cursor)
    {
        if (cursor) 
        {
            var tempTick = cursor.tick;
            var character = getSelectedLyric();
            //if current notes has lyrics already, concatenate the character to the original one right away.
            if(getNoteLyrics(cursor,lyricsLineNum))
            {
                curScore.startCmd();
                    console.log("addSynalepha(): character to be added: " + character);
                    var concatenated = getNoteLyrics(cursor,lyricsLineNum).text + character;
                    getNoteLyrics(cursor,lyricsLineNum).text = concatenated;
                    nextChar();
                    updateDisplay();
                    pushToUndoStack(cursor, "addSynalepha()");
                curScore.endCmd();
                return true;
            }
            //in the case of current selected note has no lyrics but the pervious has lyrics (MOST LIKELY it's in the middle of the editing),
            //add Synalepha to the previous character
            if(!getNoteLyrics(cursor,lyricsLineNum))
            {
                do
                {
                    cursor.prev();
                    if(cursor.element == null) //check if reach the filehead, dump the character to the original selection
                    {
                        console.log("addSynalepha(): Filehead detected, dump character " + character + " to the original selected note");
                        curScore.startCmd();
                            var fill = newElement(Element.LYRICS);
                            fill.text = character;
                            fill.voice = cursor.voice;
                            cursor.rewindToTick(tempTick);
                            cursor.element.add(fill);
                            pushToUndoStack(cursor, "addSynalepha()");
                            nextChar();
                            updateDisplay();
                        curScore.endCmd();
                        return true;
                    }
                } while(cursor.element.type != 93) //if no notes were found before the selection, cursor will eventually reach the filehead.
                //assume we found a note
                if(getNoteLyrics(cursor,lyricsLineNum))
                {
                    curScore.startCmd();
                        console.log("addSynalepha(): character to be added: " + character);
                        var concatenated = getNoteLyrics(cursor,lyricsLineNum).text + character;
                        getNoteLyrics(cursor,lyricsLineNum).text = concatenated;
                        pushToUndoStack(cursor, "addSynalepha()");
                        nextChar();
                        updateDisplay();
                    curScore.endCmd();
                    return true;
                }
                else //if we found a note but that note has no lyrics ()
                {
                    var tempTick2 = cursor.tick; //backup cursor's position before calling isInsideMelismaLine(cursor)
                    //if that note has no lyrics but inside a melisma line, dump the character to the begining of the melisma line
                    if(isInsideMelismaLine(cursor)) 
                    {
                        while(durationTo64(getNoteLyrics(cursor,lyricsLineNum).lyricTicks) == 0) {cursor.prev();}
                        curScore.startCmd();
                            console.log("addSynalepha(): Note inside a melisma line detected, character to be added at the begining of melisma line: " + character);
                            var concatenated = getNoteLyrics(cursor,lyricsLineNum).text + character;
                            getNoteLyrics(cursor,lyricsLineNum).text = concatenated;
                            pushToUndoStack(cursor, "addSynalepha()");
                            nextChar();
                            updateDisplay();
                        curScore.endCmd();
                        return true;
                    }
                    //if that note is inside a tied note, dump the character to the begining of the tie
                    cursor.rewindToTick(tempTick2);
                    if((cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) && skipTiedNotesMode)
                    {
                        curScore.startCmd();
                            curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                            cursor = getSelectedCursor();
                            if(!getNoteLyrics(cursor,lyricsLineNum))
                            {
                                console.log("addSynalepha(): Note inside a tie detected, character to be dumped at the begining of the tie: " + character);
                                var fill = newElement(Element.LYRICS);
                                fill.text = character;
                                fill.voice = cursor.voice;
                                cursor.element.add(fill);
                            }
                            else
                            {
                                console.log("addSynalepha(): Note inside a tie detected, character to be added at the begining of the tie: " + character);
                                var concatenated = getNoteLyrics(cursor,lyricsLineNum).text + character;
                                getNoteLyrics(cursor,lyricsLineNum).text = concatenated;
                            }
                            nextChar();
                            updateDisplay();
                            cursor.rewindToTick(tempTick);
                            curScore.selection.select(cursor.element.notes[0]);
                            pushToUndoStack(cursor, "addSynalepha()");
                        curScore.endCmd();
                        return true;
                    }
                    //if that note is neither inside melisma line nor inside a tie, dump the character to the original selection
                    console.log("addSynalepha(): Prev note is neither inside melisma line nor inside a tie, dump " + character + " to the original selected note");
                    curScore.startCmd();
                        var fill = newElement(Element.LYRICS);
                        fill.text = character;
                        fill.voice = cursor.voice;
                        cursor.rewindToTick(tempTick);
                        cursor.element.add(fill);
                        nextChar();
                        updateDisplay();
                        pushToUndoStack(cursor, "addSynalepha()");
                    curScore.endCmd();
                    return true;
                }
            }
        }
    }

    //core function for "hyphenated mode". The way that MuseScore's lyrics hyphens work is by the element.lyrics[0].syllabic property.
    //start syllable of a hyphenated word, syllabic = 1
    //middle syllable of a hyphenated word, syllabic = 3
    //end syllable of a hyphenated word, syllabic = 2
    //for example, the word Sep-tem-ber, the syllabic number of "Sep" will be 1, "tem" will be 3, "ber" will be 2
    function addHyphen(cursor)
    {
        function findhyphenationNum()
        {
            if(lrcCursor[1] >= lrc.length - 1) return 0;
            if(lrcCursor[0] == 0)
            {
                if(lrc.charAt(lrcCursor[1]) == '-') return 1;
                else return 0;
            } 
            var leftBound = lrc.charAt(lrcCursor[0] - 1);
            var rightBound = lrc.charAt(lrcCursor[1]);
            if(((leftBound == ' ') || (leftBound == '\n')) && (rightBound == '-')) return 1;
            if((leftBound == '-') && (rightBound == '-')) return 3;
            if((leftBound == '-') && ((rightBound == ' ') || (rightBound == '\n'))) return 2;
            return 0;
        }
        if((lrcCursor.length == 2) && cursor)
        {
            var hyphenationNum = findhyphenationNum();
            getNoteLyrics(cursor,lyricsLineNum).syllabic = hyphenationNum;
        }
    }

    //helper function, check if a note is inside a melisma line
    function isInsideMelismaLine(cursor)
    {
        var checkLength = 0;
        do
        {
            cursor.prev();
            if(cursor.element == null) return false;
            if(cursor.element.type != 93) return false;
            checkLength += durationTo64(cursor.element.duration);
        } while(!getNoteLyrics(cursor,lyricsLineNum))
        var melismaLength = durationTo64(getNoteLyrics(cursor,lyricsLineNum).lyricTicks)
        if(melismaLength == 0) return false;
        if(melismaLength < checkLength) return false;
        return true;
    }

    function playCursor(cursor) //plays the note's sound at cursor, Special Thanks to Sammik's idea of using cmd("prev-chord") & cmd("next-chord") as workarounds : https://musescore.org/en/node/327715
    {
        cursor.prev();
        if(cursor.element == null) //if cursor is at the first note of the score
        {
            cmd("prev-chord");
            cursor.next(); //restores cursor's position
            return;
        } 
        if(cursor.element.type != 93) // if previous element is a rest
        {
            cmd("prev-chord");
            cmd("next-chord");
            cursor.next();
            return;
        }
        //if previous element is a note, in order to prevent playing the sound of previous note, use cursor to select that note.
        curScore.selection.select(cursor.element.notes[0]);
        cmd("next-chord");
        cursor.next();
        return;
    }

    function durationTo64(duration) { return 64 * duration.numerator / duration.denominator;} //helper function for converting duration to 64 for addMelisma()

    function convertLineBreak(x) { return x.replace(/\n/g, "<br />"); } //special thanks to @Jack-Works for wrapping linebreaks in HTML

    function convertWhiteSpace(x) { return x.replace(/\s/g, "&nbsp;"); } //convert whitespaces in HTML &nbsp;

    function updateDisplay() //update display to lrcDisplay.text
    {
        if(isOnlyContainsSeparator()) {lrcDisplay.text = qsTr("Error: your lyrics file only contains whitespaces or separators like \'-\'!"); return false;}
        if(lrcCursor.length == 1) //if the selected text is single char (normal case)
        {
            if(lrcCursor[0] == 0)
            {
                lrcDisplay.text = convertLineBreak("<b>" + lrc.slice(0,1) + "</b>" + "<font color=\"grey\">" + lrc.slice(1) + "</font>");
            }
            else if(lrcCursor[0] == lrc.length - 1)
            {
                lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0, lrcCursor[0]) + "</font>" + "<b>" + lrc.slice(lrcCursor[0]) + "</b>");
            }
            else
            {
                lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0,lrcCursor[0]) + "</font>" + "<b>" + lrc.slice(lrcCursor[0], lrcCursor[0] + 1) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor[0] + 1) + "</font>");
            }
        }
        else if(lrcCursor.length == 2) //if the selected text is more than one char (like in hyphenated mode)
        {
            if(lrcCursor[1] == 1)
            {
                lrcDisplay.text = convertLineBreak("<b>" + lrc.slice(0,1) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor[1]) + "</font>");
            }
            else if(lrcCursor[1] >= lrc.length - 1)
            {
                lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0, lrcCursor[0]) + "</font>" + "<b>" + lrc.slice(lrcCursor[0]) + "</b>");
            }
            else
            {
                if(lrcCursor[0] == lrcCursor[1])
                    lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0,lrcCursor[0]) + "</font>" + "<b>" + lrc.charAt(lrcCursor[0]) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor[1]) + "</font>");
                else
                    lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0,lrcCursor[0]) + "</font>" + "<b>" + lrc.slice(lrcCursor[0], lrcCursor[1]) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor[1]) + "</font>");
            }
        }
    }

    //Basic Lyrics Selection Functions:
    function isOnlyContainsSeparator(text) //helper function to check if lyrics only contain \n and separators to avoid infinate loops
    {
        for(var i = 0; i < lrc.length; i++) {if((lrc.charAt(i)) != '\n' && !isSeparator(lrc.charAt(i))) return false;}
        return true;
    }
    function getNextAvailableCharPos(pos, direction) //from the @lrcCursor, searching the position of next non-'\n',-whitespace, or -separator char in the lyrics
    {
        for(var i = pos + direction; i != pos; i += direction)
        {
            if((direction == 1) && (i >= lrc.length)) i = 0;
            if((direction == -1) && (i < 0)) i = lrc.length - 1;
            if ((lrc.charAt(i)) == '\n' || isSeparator(lrc.charAt(i))) continue; else return i;
        }
    }
    function getNextSeparatorPos(pos, direction) //from the @lrcCursor, searching the position of next '\n', whitespace, or separator in the lyrics
    {
        for(var i = pos + direction; i != pos; i += direction)
        {
            if((direction == 1) && (i >= lrc.length)) return i;
            if((direction == -1) && (i < 0)) return -1;
            if((lrc.charAt(i)) != '\n' && !isSeparator(lrc.charAt(i))) continue; else return i;
        }
    }
    function expandCharToWord(charPos) //selects the word that selected character belongs to
    {
        //if the the char that is to expand is a '\n' or separator, find the next available char first then expand.
        if ((lrc.charAt(charPos)) == '\n' || isSeparator(lrc.charAt(charPos))) charPos = getNextAvailableCharPos(charPos, 1);
        lrcCursor[0] = getNextSeparatorPos(charPos, -1) + 1;
        lrcCursor[1] = getNextSeparatorPos(charPos, 1);
    }
    function nextChar() //advancing the @lrcCursor forward by skipping the @seperator to the next selection
    {
        if(lrcCursor.length == 1) lrcCursor[0] = getNextAvailableCharPos(lrcCursor[0], 1); //if the selected text is single char (normal case)
        else if(lrcCursor.length == 2) //if the selected text is more than one char (like in hyphenated mode)
            expandCharToWord(getNextAvailableCharPos(lrcCursor[1], 1));
    }
    function prevChar() //stepping the @lrcCursor back by a word or syllable, same structure as the nextChar() above
    {
        if(lrcCursor.length == 1) lrcCursor[0] = getNextAvailableCharPos(lrcCursor[0], -1); //if the selected text is single char (normal case)
        else if(lrcCursor.length == 2) //if the selected text is more than one char (like in hyphenated mode)
            expandCharToWord(getNextAvailableCharPos(lrcCursor[0], -1));
    }

    //verticalIncrements and separatorIncrements indicate how many pixels of a line & a whitespace (or other separators) on user's deivce screen.
    //use getVerticalIncrement() to forcefully resize the invisible lrcDisplayDummy and use its width to store the pixel line height increments
    //This is a very cheesy solution but worked pretty well.
    property var separatorIncrements: [];
    property var newlinePositions: [0]; 
    property var verticalIncrements: [];
    property var verticalIncrementsCache: []; //use cache to prevent the lag
    function getVerticalIncrement() 
    {   //use @separatorIncrements to store the horizontal lengths (in pixel) of each separators
        separatorIncrements = [];
        lrcDisplayDummyWrapped.text = convertLineBreak("1");
        for(var i = 0; i < separator.length; i++)
        {
            lrcDisplayDummyWrapped.text = convertLineBreak("1");
            var before = lrcDisplayDummyWrapped.width;
            lrcDisplayDummyWrapped.text = convertLineBreak("1" + separator[i]);
            separatorIncrements.push(lrcDisplayDummyWrapped.width - before);
        }
        console.log("Current separators: " + separator + ". separatorIncrements: " + separatorIncrements);
        //Start record each line's height and the start index of the newlines. Put them into @verticalIncrements and @newlinePositions for findChar()
        verticalIncrements = []; newlinePositions = [];
        for(var i = 0, j = 0; i < lrc.length; i++)
        {
            if (lrc.charAt(i) == '\n') //detects newline, start checking if the newline is wrapped
            {
                newlinePositions.push(j);
                lrcDisplayDummyWrapped.text = convertLineBreak(lrc.substring(j,i)); //lrcDisplayDummyWrapped is for detecting wrapping events
                lrcDisplayDummy.text = convertLineBreak(lrc.substring(j,i)); //compare the heights of lrcDisplayDummy with lrcDisplayDummyWrapped to see if wrapping happens
                var height = lrcDisplayDummy.height;
                if(lrcDisplayDummyWrapped.height > lrcDisplayDummy.height) //check possible wrapped line
                {//if a wrapped line was found, start calculating newline's wrapped contents, and record their vertical height like normal newlines
                    lrcDisplayDummyWrapped.text = "";
                    //Text's Text.wrapMode wraps the line by word's boundries. so first get newline's list of words:
                    var wordlist = lrc.substring(j,i).replace(/\s+$/gm, ' ').split(' '); 
                    for(var k = 0, indexOfk = j; k < wordlist.length; k++)
                    {
                        height = lrcDisplayDummyWrapped.height;
                        //fill in lrcDisplayDummyWrapped one word by one, force its width increases, until the line wrapping happens
                        lrcDisplayDummyWrapped.text = convertLineBreak(lrcDisplayDummyWrapped.text + String(wordlist[k]).replace(/\s+$/gm, ' ') + ' '); 
                        if(lrcDisplayDummyWrapped.height > height) 
                        {//find the word that causes wrapping behavior, chop all previous words and put them in the records,
                         //and start filling lrcDisplayDummyWrapped again from that word
                            newlinePositions.push(indexOfk)
                            verticalIncrements.push(height);
                            console.log("wrapped point found! caused word: " + wordlist[k] + ", position at: " + indexOfk);
                            lrcDisplayDummyWrapped.text = convertLineBreak(String(wordlist[k]).replace(/\s+$/gm, ' '));
                            height = lrcDisplayDummyWrapped.height;
                        }
                        indexOfk += wordlist[k].length + 1; //update the word's starting character's index
                    }
                    verticalIncrements.push(lrcDisplayDummyWrapped.height);
                } else verticalIncrements.push(height); //if no wrapping happens
                j = i + 1;
            }
        }
        console.log("verticalIncrements: " + verticalIncrements);
        console.log("newlinePositions: " + newlinePositions);
        //cache the vertical increment for later use
        storeVerticalIncrementCache(lrcDisplay.font.pointSize);
    }
    function storeVerticalIncrementCache(i) //helper function that stores the vertical increments of specific font point size
    {
        var distance = i - (verticalIncrementsCache.length - 1);
        if(distance > 0) for(var j = 0; j < distance; j++) verticalIncrementsCache.push(false); 
        verticalIncrementsCache[i] = [separatorIncrements, verticalIncrements];
    }
    function retrieveVerticalIncrementCache(i) //helper function that retrieves the vertical increments of specific font point size
    {
        separatorIncrements = verticalIncrementsCache[i][0];
        verticalIncrements = verticalIncrementsCache[i][1];
    }
    function findChar(posX, posY) //finds char in the given X, Y in lrcDisplay. @return: lrcCursor index of found character
    {
        var targetRow = 0; //stores targetRow #
        var targetRowPos = 0; //stores targetRow's starting index in lrc

        var sum = 0; var found = false;
        for(var i = 0; i < verticalIncrements.length; i++)
        {
            sum += verticalIncrements[i]; //add line heights until reaches user click posY
            if(sum > posY) {targetRowPos = newlinePositions[i]; targetRow = i; found = true; /*found mark*/ break;}
        }
        if(!found) targetRowPos = newlinePositions[verticalIncrements.length]; //if user click is the EOF empty line
        
        lrcDisplayDummy.text = ""; 
        for(var i = targetRowPos; i < lrc.length; i++)
        {
            //forcefully calculate the horizontal size of lyrics by append characters to the invisible lrcDisplayDummy
            //THIS IS SUCH A DIRTY WORKAROUND
            //trim trailing spaces and wrap line breaks to avoid problems, because HTML doesn't wrap trailing whitespaces here:
            lrcDisplayDummy.text = convertLineBreak(lrcDisplayDummy.text + String(lrc.charAt(i))).replace(/\s+$/gm, ' '); 
            if(lrcDisplayDummy.text.startsWith("<br />")) lrcDisplayDummy.text = lrcDisplayDummy.text.substring(6);
            //console.log("buffered text: " + lrcDisplayDummy.text)
            if(posX < lrcDisplayDummy.width) 
            {
                if(isSeparator(lrc.charAt(i))) //if user selects a whitespace, snap to the nearest character
                {
                    //if the whitespace is the head or tail of the lyrics, ignore to avoid outOfIndex error
                    if(i == 0 || i == lrc.length - 1) return -1; 
                    if(lrc.charAt(i-1) == '\n' && lrc.charAt(i+1) == '\n' ) return -1;
                    if(lrc.charAt(i-1) == '\n' && lrc.charAt(i+1) != '\n' ) return getNextAvailableCharPos(i, 1);
                    if(lrc.charAt(i-1) != '\n' && lrc.charAt(i+1) == '\n' ) return getNextAvailableCharPos(i, -1);
                    //snap to the nearest character (use prevChar() and nextChar() to also skip all the nearest whitespaces)
                    if(posX - (lrcDisplayDummy.width - separatorIncrements[parseInt(isSeparator(lrc.charAt(i)))]) < lrcDisplayDummy.width - posX)
                        return getNextAvailableCharPos(i, -1);
                    else
                        return getNextAvailableCharPos(i, 1);
                }    
                return i;
            }
            if(i == lrc.length - 1 || lrc.charAt(i+1) == '\n') return -1; //if reach the EOF or not found a character in the given X position before going to next line
        }
        return -1;
    }

    //A "fake" undo system for this plugin, because apparently the lrcCursor's position won't roll back after users hit Ctrl+Z
    //Every addSyllable() and addSynalepha() action will push a snapshots about what they had done (note ticks and lyrics added) into this undo stack.
    //When user undos an action, The plugin will using the top snapshot in the undo stack to identify whether this action is done by lyricsHelper. 
    //The official documentation stated MS's undo/redo function is still experimental. Thus, in the future this functionality might be completely changed.
    property var undo_stack : [];
    function pushToUndoStack(cursor, type) //helper function that pushes the plugin action at cursor into undo_stack
    {
        if(cursor) 
        {
            var tempTick = cursor.tick;
            undo_stack.push(getSelectedCursor().tick);
            cursor.rewindToTick(tempTick);
            undo_stack.push(getNoteLyrics(cursor,lyricsLineNum).text);
            undo_stack.push(lrcCursor);
        }
        else 
        {
            console.log("Lyrics clicking event recorded, Push: \"" + type + "\" to the undo stack.");
            undo_stack.push(0); undo_stack.push("←NULL→"); undo_stack.push(0);
        }
        undo_stack.push(type);
        //Clean undo_stack when reach maximumUndoSteps
        var tempStack = []; var maxUndoActions = maximumUndoSteps * 4;
        if(undo_stack.length > maxUndoActions)
        {
            //console.log("pre undo_stack: " + undo_stack);
            for(var i = 0; i < maxUndoActions; i++) tempStack.push(undo_stack.pop());
            undo_stack = [];
            for(var i = 0; i < maxUndoActions; i++) undo_stack.push(tempStack.pop());
            //console.log("post undo_stack: " + undo_stack);
        }
    }
    onScoreStateChanged: 
    {   
        if(state.undoRedo)
        {
            console.log("-----Undo/redo action detected.-----");
            if(undo_stack.length > 1)
            {
                console.log("Pre undo_stack = " + undo_stack);
                var top = undo_stack.pop();
                while (top.split(':').length == 2) //check for lyrics clicking events
                {
                    var parse = top.split(':')
                    if(parse[0] == '彁')
                    {
                        lrcCursor = lrcCursorParse(parse[1].split('->')[0]);
                        console.log("Lyrics Selection history detected, roll lrcCursor back to " + lrcCursorToString(lrcCursor));
                        updateDisplay(); 
                        for (var i = 0; i < 3; i++) undo_stack.pop();
                        top = undo_stack.pop();
                    }
                }
                var snapshot_type = top;
                var snapshot_lrcCursor = undo_stack.pop();
                var snapshot_lyrics = undo_stack.pop();
                var snapshot_note_ticks = undo_stack.pop();
                var cursor = getSelectedCursor();
                var tempLrcCursor = lrcCursorClone(lrcCursor);
                prevChar(); //get last lrcCursor position but skip all the whitespaces and \n.
                var current_lyrics = getSelectedLyric();
                console.log("Snapshot note ticks = " + snapshot_note_ticks + ", " + "Current ticks: " + cursor.tick);
                console.log("Snapshot lyrics = " + snapshot_lyrics + ", " + "Current lyrics: " + current_lyrics);
                if(snapshot_type == "addSyllable()")
                {   // if the action is likely from addSyllable()
                    if(cursor.tick == snapshot_note_ticks && current_lyrics == snapshot_lyrics) 
                    {   
                        updateDisplay();
                        console.log("Post undo_stack = " + undo_stack);
                        console.log("-----The action is likely from addSyllable(), roll back lrcCursor successfully.-----");
                        return true;
                    }
                }
                else if(snapshot_type == "addSynalepha()")
                {
                    if(snapshot_lyrics.charAt(snapshot_lyrics.length - 1) == current_lyrics && cursor.tick == snapshot_note_ticks)
                    {   // if the action is likely from addSynalepha()
                        updateDisplay();
                        console.log("Post undo_stack = " + undo_stack);
                        console.log("-----The action is likely from addSynalepha(), roll back lrcCursor successfully.-----");
                        return true;
                    }
                }
                // if not, put the snapshots back to the stack.
                undo_stack.push(snapshot_note_ticks);
                undo_stack.push(snapshot_lyrics);
                undo_stack.push(snapshot_lrcCursor);
                undo_stack.push(snapshot_type);
                lrcCursor = lrcCursorClone(tempLrcCursor); //also roll back the lrcCursor
                console.log("But the action that has been undone is not from this plugin");
                updateDisplay(); 
                return false;
            }
            console.log("But undo stack is empty.");
        }
    }
    
    //main UI body of the plugin
    Column 
    {
        id: controls 
        Grid
        {
            id: lyricSourceControl
            columns: 2
            rows: 1
            spacing: 2
            Text 
            {
                id: lyricSource
                height: parent.height
                width: inputButtons.width - (syllableButton.width/3.75) - 2
                wrapMode: Text.WrapAnywhere
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: qsTr("Click \"...\" to open a .txt file→")
                MouseArea //click lyricSource to call autoLoadLyrics();
                {
                    id: autoReadLyricsMouseArea
                    acceptedButtons: Qt.LeftButton
                    anchors.left: parent.left
                    anchors.top: parent.top
                    height: parent.height - 9 //avoid users misclicking autoLoadLyrics() when clicking inputButtons
                    width: parent.width
                    onClicked: autoLoadLyrics();
                }
                Timer 
                { 
                    id: searchTxtDelayRunning // for autoLoadLyrics()
                    repeat: false
                    interval: 250
                    onTriggered: searchTxtFolderListModel.searchTxt()
                } 
                Timer // in case of autoLoadLyrics() not finding any matched .txt files, prompt failed message and roll back the lyrics
                {   
                    id: autoReadLyricsFailedMessage
                    repeat: false
                    interval: 1000
                    onTriggered: {
                        if(myFileLyrics.source) {acceptFile(myFileLyrics.source); lrcCursor = searchTxtFolderListModel.tempLrcCursor; updateDisplay();}
                        else {lyricSource.horizontalAlignment = Text.AlignRight; lyricSource.text = qsTr("Click \"...\" to open a .txt file→");}
                    } 
                }
            }
            Button 
            {
                id : buttonOpenFile
                width: syllableButton.width/3.75
                text: "..."
                hoverEnabled: true
                ToolTip.delay: 250
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Tips：Right Click \"...\" to open Plugin Settings⚙")
                Rectangle {  // background, also allowing the click
                    id: settingsOverlayColor
                    anchors.fill: settingsOverlay
                    border.color: "grey"
                    color: "grey"
                    opacity: 0
                }
                MouseArea
                {
                    id:settingsOverlay
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    onPressed: 
                    {   
                        if(mouse.button == Qt.RightButton) buttonOpenFile.text = "⚙"; 
                        if(mouse.button == Qt.LeftButton) buttonOpenFile.text = "..."; 
                        var componentWidths = [previewSoundModeCheckBox.width, replaceModeCheckBox.width, skipTiedNotesModeCheckBox.width,
                            settingsTitle.width, maximumUndoStepsSpinBoxTitle.width, maximumUndoStepsSpinBox.width];
                        settingsPopup.width = Math.max.apply(Math, componentWidths) + 30; //resize settingPopup's width depends on diff. language's text length.
                        settingsOverlayColor.opacity = 0.2;
                    }
                    onReleased:{
                        buttonOpenFile.clicked();
                        settingsOverlayColor.opacity = 0;
                    }
                    Popup 
                    {
                        id: settingsPopup
                        closePolicy: Popup.NoAutoClose
                        x: -(settingsPopup.width)
                        y: -200
                        width: 215
                        height: 295
                        modal: true
                        focus: true
                        Grid
                        {
                            id: settingsGrid
                            columns: 1
                            rows: 7
                            spacing: 5
                            Text 
                            { 
                                id: settingsTitle
                                text: qsTr("<b style=\"font-size:8vw\">⚙ Plugin Settings:</b>") 
                            }
                            CheckBox { 
                                id: replaceModeCheckBox
                                checked: true;
                                text: qsTr("Replace Mode:\noverwrites existed lyrics")}
                            CheckBox { 
                                id: previewSoundModeCheckBox
                                checked: true;
                                text: qsTr("🔊Preview Note Sounds")}
                            CheckBox { 
                                id: skipTiedNotesModeCheckBox
                                checked: false;
                                readonly property var tiedSymbol: "{\"windows\" : \"♪͜  ♪\", \"osx\" : \"♪͜ ♪\"}"
                                text: (qsTr("Treat tied notes ") + JSON.parse(tiedSymbol)[Qt.platform.os] + qsTr("\nas one note"))}
                            Text { 
                                id: maximumUndoStepsSpinBoxTitle
                                text: qsTr("Maximum Undo Steps:") 
                            }
                            SpinBox{
                                id: maximumUndoStepsSpinBox
                                from: 10
                                value: 50
                                to: 100
                                stepSize: 5
                                validator: IntValidator {
                                    locale: maximumUndoStepsSpinBox.locale.name
                                    bottom: Math.min(maximumUndoStepsSpinBox.from, maximumUndoStepsSpinBox.to)
                                    top: Math.max(maximumUndoStepsSpinBox.from, maximumUndoStepsSpinBox.to)
                                }
                            }
                            Button { 
                                text: qsTr("OK")
                                width: syllableButton*0.5
                                height: syllableButton*0.5
                                onClicked: { 
                                    settingsPopup.close(); 
                                    console.log("replaceMode: " + replaceMode);
                                    console.log("previewSoundMode: " + previewSoundMode);
                                    console.log("skipTiedNotesMode: " + skipTiedNotesMode);
                                    console.log("maximumUndoSteps: " + maximumUndoSteps);
                                    buttonOpenFile.text = "...";
                                    buttonOpenFile.ToolTip.delay = 2000;
                                }
                            }
                        }
                        contentItem: settingsGrid
                    }
                }
                onClicked : 
                {
                    if(buttonOpenFile.text == "...") openLrcDialog.open();
                    if(buttonOpenFile.text == "⚙") settingsPopup.open();
                }
            }
        }
        Grid
        {//For the MouseArea for this grid, see @lyricsLineNumAdjust and @lyricsLineNumScroll
            id: lyricsLineNumIndicatorGrid
            columns: 1; rows: 1; visible: false;
            Text
            {
                id: lyricsLineNumIndicator
                width: inputButtons.width
                height: inputButtons.height / 2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                property var downArrow: convertWhiteSpace("▼          ")
                property var upArrow: convertWhiteSpace("          ▲")
                property var info: qsTr("Lyrics Verse Line: ")
                property var tooltip: ""
                property var indication: [info, String(lyricsLineNum+1), tooltip]
                property var indicationWithTooltips: [downArrow, info, String(lyricsLineNum+1), tooltip, upArrow]
                color: "dimgrey"
                Timer
                {
                    id: lyricsLineNumIndicatorPrompt
                    repeat: false
                    interval: 3000
                    onTriggered: 
                    {
                        lyricsLineNumIndicator.tooltip = ""; 
                        lyricsLineNumIndicator.downArrow = convertWhiteSpace("▼          "); lyricsLineNumIndicator.upArrow = convertWhiteSpace("          ▲");
                        lyricsLineNumIndicator.text = lyricsLineNumIndicator.indication.join('');
                    }
                }
            }
        }

        Grid
        {
            id: inputButtons
            columns: 5
            rows: 1
            spacing: 2
            enabled: false
            Button
            {
                id: lrcStepBackButton
                text: "<font size=\"5\">◀</font>"
                width: syllableButton.width/4
                onClicked:
                {
                    var original = lrcCursor;
                    prevChar();
                    updateDisplay();
                    pushToUndoStack(false, "彁:" + lrcCursorToString(original) + "->" + lrcCursorToString(lrcCursor));
                }
            }
            Button 
            {
                id: syllableButton
                text: qsTr("Add\nSyllable")
                onClicked:
                {   
                    addSyllable(getSelectedCursor());
                }
            }
            Button 
            {
                id: melismaButton
                text: qsTr("Extend\nMelisma")
                onClicked:
                {
                    addMelisma(getSelectedCursor());
                }
            }
            Button 
            {
                id: synalephaButton
                text: qsTr("Concatenate\nSynalepha")
                onClicked:
                {
                    addSynalepha(getSelectedCursor());
                }
            }
            Button
            {
                id: lrcStepForwardButton
                text: "<font size=\"5\">▶</font>"
                width: syllableButton.width/4
                onClicked:
                {   
                    var original = lrcCursor;
                    nextChar();
                    updateDisplay();
                    pushToUndoStack(false, "彁:" + lrcCursorToString(original) + "->" + lrcCursorToString(lrcCursor));
                }
            }
        }
        ScrollView
        {
            id: lrcDisplayScrollView
            width: inputButtons.width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.interactive: true
            height: ((lrcDisplay.height < (inputButtons.height*8)) ? lrcDisplay.height : (inputButtons.height*8))
            clip: true
            Text
            {
                id: lrcDisplay
                text: qsTr("Please load a lyrics file first")
                enabled: true
                visible: true
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                width: lrcDisplayScrollView.width
                MouseArea
                {
                    id: lrcDisplayMouseArea //MouseArea for Clickable Lyrics Function
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    enabled: inputButtons.enabled
                    Timer
                    {   // a timer for recognize double clicking event
                        id: doubleClickTimer
                        interval: 200; repeat: false;
                        onTriggered: {}
                    }
                    onClicked:
                    {
                        if(doubleClickTimer.running) //if it is double clicking, enters the Edit Lyrics
                        {
                            doubleClickTimer.stop();
                            editLyrics.enableLrcEdit();
                        }
                        else //if it is single clicking, select the lyrics
                        {
                            console.log("Mouse clicked at X:" + mouse.x + " Y:" + mouse.y);
                            var original = lrcCursorClone(lrcCursor);
                            var found = findChar(mouse.x, mouse.y);
                            if(found != -1) 
                            {
                                if(lrcCursor.length == 1) lrcCursor[0] = found;
                                else if(lrcCursor.length == 2) expandCharToWord(found);
                                // Also push the lrcCursor change event to the undo_stack, so we can trace lrcCursor's position back
                                // placeholder "彁" is a very edgy Kanji (幽霊文字, Yuureimoji) that has totally unknown etymology 
                                // the choice is a tribute to LeaF's song 《彁》 https://www.youtube.com/watch?v=EsOU0V2kpUI
                                pushToUndoStack(false, "彁:" + lrcCursorToString(original) + "->" + lrcCursorToString(lrcCursor));
                                console.log("------Selected: " + getSelectedLyric() + ", lrcCursor is at: " + lrcCursorToString(lrcCursor) + "-----");
                            }
                            else console.log("given position has no char!");
                            updateDisplay();
                            doubleClickTimer.start();
                        }
                    }
                }
            }
            Popup 
            {
                id: contentReqPopup
                closePolicy: Popup.NoAutoClose
                x: parent.x + 10
                y: parent.y + 5
                height: lrcDisplay.height > lrcDisplayScrollView.height ? lrcDisplayScrollView.height - 10 : lrcDisplay.height - 10
                width: lrcDisplayScrollView.width - 20
                modal: true
                focus: true
                background: Rectangle { anchors.fill: parent; color: "lightgray"; border.color: "lightgray"; opacity: 0.85;}
                Text { id: contentReqPopupText; anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter;}
            }
            Timer // in case of content quest failed due to poor connection or whatever, prompt failed message
            {   
                id: contentReqDelayMsg
                repeat: false
                interval: 1500
                onTriggered: {contentReqPopup.close(); contentReqDelayMsg.interval = 1000; releaseUI();}
            }
            Timer // in case of content quest out time, prompt failed message
            {   
                id: contentReqTimeOutMsg
                repeat: false
                interval: 10000
                onTriggered: { 
                    hyphenation.request.abort();
                    japaneseToKana.request.abort();
                    contentReqPopupText.text = qsTr("❌ Request timed out"); 
                    contentReqDelayMsg.start();
                }
            }
        }
        ScrollView
        {
            id: lrcEditScrollView
            width: inputButtons.width
            enabled: false
            visible: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.interactive: true
            TextArea
            {
                id: lrcEdit
                text: lrc
                focus: true
                persistentSelection: true
                selectByMouse: true
                height: 0
                cursorVisible: true
                mouseSelectionMode: TextEdit.SelectCharacters
                color: "black"
                font.pointSize: 9
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                background: Rectangle {
                    id: lrcEditBg
                    visible: false
                    color: "white"
                    anchors.fill: parent
                    border.color: "white"
                }
                textMargin: 0
                Shortcut 
                {
                    sequence: StandardKey.Copy
                    onActivated: lrcEdit.copy()
                }
                Shortcut 
                {
                    sequence: StandardKey.Cut
                    onActivated: lrcEdit.cut()
                }
                Shortcut 
                {
                    sequence: StandardKey.Paste
                    onActivated: lrcEdit.paste()
                }
            }

        }
        Grid
        {
            id: texteditButtons
            columns: 4
            rows: 1
            spacing: 2
            enabled: false
            visible: false
            function enableLrcDisplay()
            {   //when editing is done, replace lrcEditScrollView with lrcDisplayScrollView
                var pos = lrcEditScrollView.ScrollBar.vertical.position;
                lrcEditScrollView.enabled = false;
                lrcEditScrollView.visible = false;
                lrcEditBg.visible = false;
                lrcDisplayScrollView.visible = true;
                lrcDisplayScrollView.enabled = true;
                lrcDisplayMenuMouseArea.x = lrcDisplayScrollView.x;
                lrcDisplayMenuMouseArea.y = lrcDisplayScrollView.y;
                lrcDisplayMenuMouseArea.height = lrcDisplay.height > lrcDisplayScrollView.height ? lrcDisplayScrollView.height : lrcDisplay.height;
                texteditButtons.visible = false;
                texteditButtons.enabled = false;
                lrcDisplayScrollView.ScrollBar.vertical.position = pos;
                releaseUI();
            }
            Button
            {   //"Cancel" buttons restores everything to its original states
                id: cancelEditButton
                text: qsTr("Cancel")
                onClicked:
                {
                    acceptLyrics(editLyrics.lrcBackup); 
                    texteditButtons.enableLrcDisplay(); 
                    lrcCursor = editLyrics.lrcCursorBackup;
                    updateDisplay();
                }
            }
            Button 
            {   //separator between "cancel" and "save as..." buttons. 
                id: sepButton
                width: lrcDisplayScrollView.width - (cancelEditButton.width + exportButton.width + finishButton.width) - texteditButtons.spacing*2
                enabled: false
                background: Rectangle{opacity: 0}
            }
            Button
            {   //"Save As..." buttons saves the edited lyrics
                id: exportButton
                text: qsTr("Save As...")
                onClicked:
                { 
                    if(lrcExportDialog.getPath(myFileLyrics.source)) lrcExportDialog.folder = lrcExportDialog.getPath(myFileLyrics.source); 
                    lrcExportDialog.open(); 
                }
            }
            Button
            {   //"Finish" button updates the lrcDisplay.text with the edited lyrics
                id: finishButton
                text: qsTr("Finish")
                onClicked: 
                { 
                    var curPos = lrcEdit.cursorPosition;
                    acceptLyrics(lrcEdit.text);
                    texteditButtons.enableLrcDisplay(); 
                    //when user finishes editing lyrics, move lrcCursor to approximately the edit cursor's position:
                    if(lrcCursor.length == 1) lrcCursor = [curPos]; 
                    else if(lrcCursor.length == 2) expandCharToWord(curPos);
                    if(lrcCursor[0] != 0) prevChar();//to avoid '\n' or separator or whitespace selection
                    updateDisplay();
                }
            }
        }

        Text
        {
            id: lrcDisplayDummy
            visible: false
            text: "buffer text"
            font.family: lrcDisplay.font.family
            font.pointSize: lrcDisplay.font.pointSize
        }
        Text
        {
            id: lrcDisplayDummyWrapped
            visible: false
            wrapMode: lrcDisplay.wrapMode
            width: lrcDisplayScrollView.width
            text: "for line vertical increment calculation (because I need to know all the line wrappings, and lrcDisplayDummy is for horizontal position calculation so it cannot do wrappings)"
            font.family: lrcDisplay.font.family
            font.pointSize: lrcDisplay.font.pointSize
        }
    }

    MouseArea
    {
        id: lyricsLineNumScroll
        x: lyricsLineNumIndicatorGrid.x; y: lyricsLineNumIndicatorGrid.y; 
        height: lyricsLineNumIndicatorGrid.height + inputButtons.height; width: lyricsLineNumIndicatorGrid.width + inputButtons.width;
        acceptedButtons: Qt.MiddleButton //only accepts wheel and wheel button
        enabled: false;
        property var wheelIncrement: 0;
        onWheel:
        {
            if (!(wheel.modifiers & Qt.ControlModifier) && inputButtons.enabled)
            {
                if((lyricsLineNum < 11 || wheel.angleDelta.y < 0) && (lyricsLineNum > 0 || wheel.angleDelta.y > 0))
                {
                     wheelIncrement += (wheel.angleDelta.y / 360); //makes mouse scorlling 3 steps as the minimum unit
                     if(Math.floor(wheelIncrement) >= 1 || Math.ceil(wheelIncrement) <= -1)
                     {
                        lyricsLineNum += 1* Math.sign(wheelIncrement);
                        wheelIncrement = 0;
                        lyricsLineNumAdjust.updateLyricsLineDisplay();
                     }
                }
            }
        }
    }
    MouseArea
    {
        id: lyricsLineNumAdjust
        x: lyricsLineNumIndicatorGrid.x; y: lyricsLineNumIndicatorGrid.y; 
        height: lyricsLineNumIndicatorGrid.height; width: lyricsLineNumIndicatorGrid.width;
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true;
        enabled: false;
        property var hovered: false;
        function updateLyricsLineDisplay() 
        { 
            if(hovered) lyricsLineNumIndicator.text = "<div>" + lyricsLineNumIndicator.indicationWithTooltips.join('') + "</div>"; 
            else lyricsLineNumIndicator.text = "<div>" + lyricsLineNumIndicator.indication.join('') + "</div>"; 
        }
        onEntered: {lyricsLineNumIndicator.text = "<div>" + lyricsLineNumIndicator.indicationWithTooltips.join('') + "</div>"; hovered = true;}
        onExited: {lyricsLineNumIndicator.text = "<div>" + lyricsLineNumIndicator.indication.join('') + "</div>"; hovered = false;}
        onPressed:
        {
            if(mouse.x < (lyricsLineNumIndicatorGrid.width / 2)) 
            {
                if(!lyricsLineNumIndicatorPrompt.running) lyricsLineNumIndicator.downArrow = "<font color=\"black\">" + convertWhiteSpace("▼          ") + "</font>";
                updateLyricsLineDisplay();
            }
            if(mouse.x > (lyricsLineNumIndicatorGrid.width / 2)) 
            {
                if(!lyricsLineNumIndicatorPrompt.running) lyricsLineNumIndicator.upArrow = "<font color=\"black\">" + convertWhiteSpace("          ▲") + "</font>";
                updateLyricsLineDisplay();
            }
        }
        onReleased: 
        {
            if(mouse.x < (lyricsLineNumIndicatorGrid.width / 2)) 
            {
                if(!lyricsLineNumIndicatorPrompt.running) lyricsLineNumIndicator.downArrow = "<font color=\"dimgrey\">" + convertWhiteSpace("▼          ") + "</font>";
                if(lyricsLineNum > 0)lyricsLineNum -= 1; 
                updateLyricsLineDisplay();
            }
            if(mouse.x > (lyricsLineNumIndicatorGrid.width / 2)) 
            {
                if(!lyricsLineNumIndicatorPrompt.running) lyricsLineNumIndicator.upArrow = "<font color=\"dimgrey\">" + convertWhiteSpace("          ▲") + "</font>";
                if(lyricsLineNum < 11) lyricsLineNum += 1; 
                updateLyricsLineDisplay();
            }
            
            
        }
    }

    MouseArea
    {   //Right Button Menu for lrcDisplayScrollView. This MouseArea is outside of the main Column because 
        //there're mouse events capturing conflicts between ScrollView & MouseArea objects
        id: lrcDisplayMenuMouseArea
        acceptedButtons: Qt.RightButton
        x: lrcDisplayScrollView.x
        y: lrcDisplayScrollView.y
        height: lrcDisplay.height > lrcDisplayScrollView.height ? lrcDisplayScrollView.height : lrcDisplay.height
        width: inputButtons.width
        onClicked:
        {
            if(lrcDisplayScrollView.enabled)
            {
                lrcDisplayMenu.x = mouse.x-10; lrcDisplayMenu.y = mouse.y-10;
                lrcDisplayMenu.open();
            }
            else if(lrcEditScrollView.enabled)
            {
                lrcEditContextMenu.x = mouse.x-10; lrcEditContextMenu.y = mouse.y-10;
                lrcEditContextMenu.open();
            }
        }
        property var wheelIncrement: 0;
        property var maxPointSize: (Qt.platform.os == "windows") ? 14 : 17;
        property var minPointSize: (Qt.platform.os == "windows") ? 9 : 12;
        onWheel:
        { //Ctrl + Mouse Scroll to zoom in&out the lyrics display
            if ((wheel.modifiers & Qt.ControlModifier) && inputButtons.enabled)
            {
                if((lrcDisplay.font.pointSize < maxPointSize || wheel.angleDelta.y < 0) && (lrcDisplay.font.pointSize > minPointSize || wheel.angleDelta.y > 0))
                {
                     wheelIncrement += (wheel.angleDelta.y / 360); //makes mouse scorlling 3 steps as the minimum unit
                     if(Math.floor(wheelIncrement) >= 1 || Math.ceil(wheelIncrement) <= -1)
                     {
                        lrcDisplay.font.pointSize = lrcDisplay.font.pointSize + (1 * Math.sign(wheelIncrement));
                        //if pointSize's vertical increment not found in the cache, save one otherwise just retrieve it
                        if(verticalIncrementsCache[lrcDisplay.font.pointSize]) retrieveVerticalIncrementCache(lrcDisplay.font.pointSize);
                        else getVerticalIncrement();
                        wheelIncrement = 0;
                     }
                } wheel.accepted=true;
            } 
            else wheel.accepted=false; //aviod conflicts between MouseArea's onWheel and scrollView's scrolling
        }
        Menu
        {
            id: lrcDisplayMenu
            scale: 0.9
            spacing: 0.5
            bottomPadding: 3; leftPadding: 3; topPadding: 3; rightPadding: 3
            MenuItem 
            { 
                id: editLyrics
                text: qsTr("Edit Lyrics")
                property var lrcBackup: "";
                property var lrcCursorBackup: [];
                function enableLrcEdit()
                {
                    lrcBackup = lrc; //take a snapshot of unmodified lyrics for the "cancel" button
                    lrcCursorBackup = lrcCursor;
                    var pos = lrcDisplayScrollView.ScrollBar.vertical.position; //take a snapshot of ScrollBar's position
                    //disable lrcDisplay and replace everything with lrcEdit.
                    lrcDisplayScrollView.visible = false;
                    lrcDisplayScrollView.enabled = false;
                    lrcEditScrollView.visible = true;
                    lrcEditScrollView.enabled = true;
                    lrcEditBg.visible = true;
                    lrcEditScrollView.enabled = true;
                    lrcEdit.text = lrc;
                    lrcEdit.font.pointSize = lrcDisplay.font.pointSize;
                    lrcEditScrollView.ScrollBar.vertical.position = pos;
                    //sync the cursor position in lrcEdit with lrcCursor position in the lrcDisplay.
                    //https://stackoverflow.com/questions/43487731/forceactivefocus-vs-focus-true-in-qml
                    lrcEdit.forceActiveFocus();
                    if(lrcCursorBackup.length == 1) lrcEdit.cursorPosition = lrcCursorBackup[0] + 1;
                    else if(lrcCursorBackup.length == 2) lrcEdit.cursorPosition = lrcCursorBackup[1];
                    //give user the freedom to type lyrics when there is no lyrics loaded:
                    if(lrc != "") lrcEditScrollView.height = ((lrcEdit.height < (inputButtons.height*8)) ? lrcEdit.height : (inputButtons.height*8));
                    //show "cancel", "save as..." and "Finish" buttons
                    texteditButtons.visible = true;
                    texteditButtons.enabled = true;
                    //disable other UI to avoid glitches
                    suspendUI();
                    //resize context menu MouseArea
                    lrcDisplayMenuMouseArea.x = lrcEditScrollView.x;
                    lrcDisplayMenuMouseArea.y = lrcEditScrollView.y;
                    lrcDisplayMenuMouseArea.height = lrcEditScrollView.height ? lrcEditScrollView.height : lrcEdit.height;
                    lrcDisplayMenuMouseArea.enabled = true;
                }
                onTriggered: enableLrcEdit();
            }
            MenuSeparator { }
            MenuItem 
            { 
                id: hyphenatedModeToggle
                checkable: false; checked: checkable;
                enabled: inputButtons.enabled;
                text: qsTr("Hyphenated Mode: ") + (checkable ? "On" : "Off"); 
                function toggleHyphenatedModeON() //this function can only turn the hyphenated mode ON
                {
                    if(!hyphenatedModeToggle.checkable)
                    {
                        separator = [' ', '-']; expandCharToWord(lrcCursor[0]);
                        hyphenatedModeToggle.checkable = !hyphenatedModeToggle.checkable;
                        updateDisplay();
                    }
                }
                onTriggered: { if(!checkable) toggleHyphenatedModeON(); 
                    else {checkable = false; separator = [' ']; lrcCursor = [lrcCursor[0]]; updateDisplay();}}
            }
            MenuItem 
            { 
                id: hyphenation
                property var deafultText: qsTr("English Hyphenation\n(requires Internet connection)")
                property var langNotFoundText: qsTr("English Hyphenation\n(No English Detected)")
                text: deafultText
                enabled: inputButtons.enabled
                //latin alphabet regexp from stackoverflow.com/questions/7258375/latin-charcters-included-in-javascript-regex
                property var latin_regexp: /[A-z\u00C0-\u00ff]+/g;
                function hasLatinAlphabet(s) {return latin_regexp.test(s);} 
                function parseResponse(html)
                {
                    var start = html.indexOf("name=\"inputText\""); if(start == -1) return false;
                    var end = html.lastIndexOf("/textarea"); if(end == -1 || end < start) return false;
                    for(var i = start; i < html.length; i++) if(html.charAt(i) == '>') {start = i + 1; break;}
                    for(var i = end; i > start; i--) if(html.charAt(i) == '<') {end = i; break;}
                    if(end < start) return false;
                    return html.substring(start, end);
                }
                property var request: new XMLHttpRequest();
                onTriggered:
                {
                    var content = "inputText=" + encodeURIComponent(lrc);
                    console.log("request : " + content);
                    hyphenation.request = new XMLHttpRequest();
                    contentReqPopup.open();
                    contentReqPopupText.text = qsTr("Hyphenating Lyrics...\nSending Request to juiciobrennan.com/syllables/...");
                    suspendUI();
                    contentReqTimeOutMsg.start();
                    hyphenation.request.onreadystatechange = function() 
                    {
                        if (hyphenation.request.readyState == XMLHttpRequest.DONE) 
                        {
                            contentReqTimeOutMsg.stop();
                            var response = hyphenation.request.response;
                            if(!response)
                            {
                                contentReqPopupText.text = qsTr("❌ Connection Failed");
                                contentReqDelayMsg.start();
                                return;
                            }
                            console.log("response : " + hyphenation.parseResponse(response));
                            var relativeLrcCursorPos = (lrcCursor[0]/lrc.length); //preserve lrcCursor's position before the conversion
                            acceptLyrics(hyphenation.parseResponse(response)); inputButtons.enabled = false; //avoid misclicking before popup's gone
                            contentReqPopupText.text = qsTr("✔ Hyphenation Completed!");
                            //restore lrcCursor's position:
                            lrcCursor[0] = Math.floor(lrc.length * relativeLrcCursorPos); 
                            if(hyphenatedMode) {expandCharToWord(lrcCursor[0]); updateDisplay();}
                            hyphenatedModeToggle.toggleHyphenatedModeON();
                            contentReqDelayMsg.start();
                        }
                    }
                    hyphenation.request.open("POST", "https://www.juiciobrennan.com/syllables/", true);
                    hyphenation.request.setRequestHeader("content-type", "application/x-www-form-urlencoded");
                    hyphenation.request.send(content);
                }
            }
            MenuItem 
            { 
                id: japaneseToKana
                property var deafultText: qsTr("Japanese Kanji to Kana ▶\n(requires Internet connection)")
                property var langNotFoundText: qsTr("Japanese Kanji to Kana ▶\n(No Japanese Detected)")
                text: deafultText
                //japanese regex from https://stackoverflow.com/questions/15033196/using-javascript-to-check-whether-a-string-contains-japanese-characters-includi
                property var jp_regexp: /[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uff9f\u4e00-\u9faf\u3400-\u4dbf]+/g;
                function hasJapanese(s) {return jp_regexp.test(s);}
                function parseResponse(response) {return JSON.parse(response).result;}
                property var request: new XMLHttpRequest();
                function convertJapaneseTo(to)
                {
                    var content = "{\"str\": \"" + lrc.replace(/\n/g, "\\n") + "\",\"to\": \"" + to + "\", \"mode\": \"normal\",\"romajiSystem\": \"nippon\"}";
                    console.log("request : " + content);
                    japaneseToKana.request = new XMLHttpRequest();
                    contentReqPopup.open();
                    contentReqPopupText.text = qsTr("Converting Kanjis to Kana\nSending Request https://api.kuroshiro.org/convert...");
                    suspendUI();
                    contentReqTimeOutMsg.start();
                    japaneseToKana.request.onreadystatechange = function() 
                    {
                        if (japaneseToKana.request.readyState == XMLHttpRequest.DONE) 
                        {
                            contentReqTimeOutMsg.stop();
                            var response = japaneseToKana.request.response;
                            if(!response)
                            {
                                contentReqPopupText.text = qsTr("❌ Connection Failed");
                                contentReqDelayMsg.start();
                                return;
                            }
                            console.log("response: " + response);
                            separator = [' '];
                            if(!japaneseToKana.parseResponse(response)) 
                            {
                                contentReqPopupText.text = qsTr("❌ Error: lyrics got rejected by kuroshiro.org\nPossibly because of too much non-Japanese characters"); 
                                contentReqDelayMsg.interval = 2500;
                                contentReqDelayMsg.start();
                                return;
                            }
                            acceptLyrics(japaneseToKana.parseResponse(response)); inputButtons.enabled = false; //avoid misclicking before popup's gone
                            revertJPconv.enabled = true;
                            contentReqPopupText.text = qsTr("✔ Convertion Completed!");
                            contentReqDelayMsg.start();
                        }
                    }
                    japaneseToKana.request.open("POST", "https://api.kuroshiro.org/convert", true);
                    japaneseToKana.request.setRequestHeader("content-type", "application/json; charset=UTF-8");
                    japaneseToKana.request.send(content);
                }
                property var lrcBackup: "";
                Menu
                {
                    id: japaneseToKanaModeMenu
                    scale: lrcDisplayMenu.scale
                    spacing: lrcDisplayMenu.spacing
                    bottomPadding: lrcDisplayMenu.bottomPadding; leftPadding:lrcDisplayMenu.leftPadding; topPadding: lrcDisplayMenu.topPadding; rightPadding: lrcDisplayMenu.rightPadding
                    MenuItem { text: qsTr("to Hiragana あ"); onTriggered:{japaneseToKana.convertJapaneseTo("hiragana");}}
                    MenuItem { text: qsTr("to Katakana ア"); onTriggered:{japaneseToKana.convertJapaneseTo("katakana");}}
                    MenuSeparator { }
                    MenuItem { id: revertJPconv; text: qsTr("Revert Conversion"); enabled: false; 
                               onTriggered:{acceptLyrics(japaneseToKana.lrcBackup); revertJPconv.enabled = false;}}
                }
                onTriggered:
                {
                    japaneseToKanaModeMenu.x = editLyrics.x; japaneseToKanaModeMenu.y = editLyrics.y;
                    japaneseToKanaModeMenu.open();
                } 
            }
        }
        Menu 
        {
            id: lrcEditContextMenu
            scale: lrcDisplayMenu.scale
            spacing: lrcDisplayMenu.spacing
            bottomPadding: lrcDisplayMenu.bottomPadding; leftPadding:lrcDisplayMenu.leftPadding; topPadding: lrcDisplayMenu.topPadding; rightPadding: lrcDisplayMenu.rightPadding
            MenuItem 
            {
                text: qsTr("Copy")
                enabled: lrcEdit.selectedText
                onTriggered: lrcEdit.copy()
            }
            MenuItem 
            {
                text: qsTr("Cut")
                enabled: lrcEdit.selectedText
                onTriggered: lrcEdit.cut()
            }
            MenuItem 
            {
                text: qsTr("Paste")
                enabled: lrcEdit.canPaste
                onTriggered: lrcEdit.paste()
            }
        }
    }

    //Button {id: testBTN; text: "test!"; onClicked: {console.log();} }

    //suspend and release UI functions to avoid glitches caused by users clicking around in content requesting process
    //such as English Hyphenation and Japanese Kanji to Kana
    //Why tf QML doesn't support JS's function default value syntax?
    function suspendUI()
    {
        lrcDisplayMenuMouseArea.enabled = false;
        inputButtons.enabled = false;
        fileDrop.enabled = false;
        buttonOpenFile.enabled = false;
        autoReadLyricsMouseArea.enabled = false
        lrcDisplayMouseArea.enabled = false;
        lyricsLineNumScroll.enabled = false;
        lyricsLineNumAdjust.enabled = false;
    }
    function releaseUI()
    {
        lrcDisplayMenuMouseArea.enabled = true;
        inputButtons.enabled = true;
        fileDrop.enabled = true;
        buttonOpenFile.enabled = true;
        autoReadLyricsMouseArea.enabled =true;
        lrcDisplayMouseArea.enabled = true;
        lyricsLineNumScroll.enabled = true;
        lyricsLineNumAdjust.enabled = true;
    }

    Shortcut //addSyllable() shortcut
    {
        id: syllableButtonShortcut
        sequence: "Alt+S"
        context: Qt.ApplicationShortcut
        onActivated: {
            addSyllable(getSelectedCursor());
        }
    }
    Shortcut //addMelisma() shortcut
    {
        id: melismaButtonShortcut
        sequence: "Alt+D"
        context: Qt.ApplicationShortcut
        onActivated: {
            addMelisma(getSelectedCursor());
        }
    }
    Shortcut //addSynalepha() shortcut
    {
        id: synalephaButtonShortcut
        sequence: "Alt+X"
        context: Qt.ApplicationShortcut
        onActivated: {
            addSynalepha(getSelectedCursor());
        }
    }
    Shortcut //autoLoadLyrics() shortcut
    {
        id: autoChangeLyrics
        sequence: "Alt+L"
        context: Qt.ApplicationShortcut
        onActivated: autoLoadLyrics();
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
}
