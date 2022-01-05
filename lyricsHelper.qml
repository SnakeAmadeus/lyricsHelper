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

    //@replaceMode indicates whether replacing the existed lyrics when encountering a lyrics conflict. 0 = OFF, 1 = ON.
    property var replaceMode : 1;
    //@previewSoundMode decides whether preview note's sound when cursor advances
    property var previewSoundMode: 1;
    //@maximumUndoStep decides the max amount of actions that is done by lyricsHelper can be undone.
    property var maximumUndoSteps: 50;

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
            acceptFile(filename);
        }
    }
    
    function acceptFile(filename) //helper function that reads a file for widget fileDialog and fileDrop
    {
        if(filename)
        {
            //console.log("You chose: " + filename)
            myFileLyrics.source = filename;
            //behaviors after reading the text file
            lyricSource.text = qsTr("Current File:") + myFileLyrics.source.slice(8); //trim path name for better view
            lyricSource.horizontalAlignment = Text.AlignLeft;
            lrc = myFileLyrics.read(); //file selection pop-up
            lrcDisplay.text = lrc; //update lyrics text to displayer
            lrcCursor = 0; //reset @lrcCursor
            inputButtons.enabled = true; //recover input buttons' availability
            updateDisplay();
            //resize the pannel
            controls.height = lyricSourceControl.height + inputButtons.height + lrcDisplay.height;
            lrcDisplayScrollView.height = inputButtons.height * 8
            getVerticalIncrement();
            undo_stack = [];
        }
    }

    //Functionality: click on lyricSource to auto load a text file to the lyricsHelper
    //that contains the current score's name, in the same path as the current score
    property var curScorePath : "";
    property var curScoreFileName : "";
    property var curScoreName : "";
    function autoLoadLyrics(scorePath)
    {
        myFileScore.source = "file:///" + curScore.path;
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
        onError: console.log(msg + "  Filename = " + myFileScore.source);
    }
    FolderListModel //FolderListModel assists autoLoadLyrics() to search .txt files in the specified folder
    {
        id: searchTxtFolderListModel
        function searchTxt()
        {
            for(var i = 0; i < searchTxtFolderListModel.count; i++)
                  if(searchTxtFolderListModel.get(i, "fileName").split('.').pop() == "txt")
                        if (searchTxtFolderListModel.get(i, "fileName").includes(curScoreName)) 
                              {acceptFile(searchTxtFolderListModel.get(i, "fileURL")); return true;}
            //in case nothing was found:
            lyricSource.text = qsTr("Couldn't find any .txt file contains\nthe Current Score's name in the same path."); 
            autoReadLyricsFailedMessage.start();
        }
    }
    
    //Functionality: Drag&Drop lyrics text file to the plugin
    //workarounds for DropArea validates file extensions because the DropArea.keys were not functioning properly
    //Special Thanks to https://stackoverflow.com/a/28800328
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
                if(cursor.element.lyrics.length == 1) //if there already been lyrcis on the next element, do nothing and deselect
                {
                    console.log("addSyllable(): EOF detected, you can't add more lyrics");
                    curScore.selection.clear();
                    curScore.endCmd();
                    return false;
                }
                else //if no lyrics on the current note, add it but no future cursor is forwarded.
                {
                    var character = lrc.charAt(lrcCursor);
                    var fill = newElement(Element.LYRICS);
                    fill.text = character;
                    fill.voice = cursor.voice;
                    curScore.startCmd();
                        console.log("addSyllable(): current character = " + fill.text);
                        cursor.element.add(fill);
                        pushToUndoStack(cursor, "addSyllable()");
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
                console.log("addSyllable(): current character = " + fill.text);
                var tempTick = cursor.tick;
                if(cursor.element.lyrics.length > 0) //if replaceMode is ON, replace the existed character
                {
                    console.log("addSyllable(): conflicted lyrics detected!");
                    if(replaceMode == 1)
                    {
                        removeElement(cursor.element.lyrics[0]);
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
                        }while(durationTo64(cursor.element.lyrics[0].lyricTicks) == 0) 
                        cursor.element.lyrics[0].lyricTicks = fraction(checkLength, 64);
                    }
                    else
                    {
                        curScore.endCmd();
                        return false;
                    }
                }
                cursor.rewindToTick(tempTick);
                if(cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) //if selected note is inside a tie, jump to the begining of the tie
                {
                    curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                    cursor = getSelectedCursor();
                }
                cursor.element.add(fill);
                pushToUndoStack(cursor, "addSyllable()")
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
                                if(cursor.element.lyrics.length > 1) removeElement(cursor.element.lyrics[1]);
                                curScore.selection.clear();
                                curScore.endCmd();
                                return false;//encounters the EOF, immediately shut down
                            }
                        }
                    }
                }
                var nextNote = cursor.element.notes[0];
                //if the next note is a tied note
                if(nextNote.tieBack != null)
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

    function addMelisma(cursor)
    {
        if(cursor)
        {
            console.log("-----------addMelisma() start----------");
            //MuseScore's Lyrics' Melisma was manipulated by the lyrics.lyricTicks property, which is a property of Ms::PluginAPI::Element
            //Because the lyrics Object was wrapped in Ms::PluginAPI::Element, so the cursor.element.lyrics[0]'s type is actually Ms::PluginAPI::Element, instead of a lyrics object
            //There is no direct access to the object of Lyrics' members as shown in the libmscore/lyrics.h
            //The definition of this lyrics.lyricTicks is the sum of note values from *begining* of the first note to the *begining* of the last note.
            //So the calculation rule of the length of Melisma line will be from the selected note to the last note that has lyrics under it.
            //Move the cursor backward, Add up the note value of [start note, end note); if rests are other wack occurred, abort the operation.
            var tempTick = cursor.tick; //backup cursor's original position
            var endHasLyrics = (cursor.element.lyrics.length > 0);
            var melismaLength = 0;
            //things need to be checked for the current selected note to avoid glitches
            //check if the selected note is in the middle of the tie that has lyric on the first tied note, it will be meaningless to add melisma in this case
            if(cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) 
            {
                curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                cursor = getSelectedCursor();
                if(cursor.element.lyrics.length >= 1)
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
            if(cursor.element.lyrics.length != 0)
            {
                if(replaceMode == 1)//depends on whether replace mode is ON or OFF. If ON, current lyrics will be dropped and become melisma line
                {
                    console.log("addMelisma(): Lyrics conflict detected, drop existed lyrics");
                    removeElement(cursor.element.lyrics[0]);
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
            if(cursor.element.lyrics.length != 0 && endHasLyrics)//if the prev note has lyrics AND the selected note also has, adding melisma line will be notationally meaningless, abort the operation
            {
                console.log("addMelisma(): Current note and prev note have lyrics back to back detected, do nothing"); return false;
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
            } while(cursor.element.lyrics.length == 0)
            melismaLength = fraction(melismaLength, 64); //64 to duration
            curScore.startCmd();
                cursor.element.lyrics[0].lyricTicks = melismaLength;
                console.log("addMelisma(): Final Melisma Length: " + cursor.element.lyrics[0].lyricTicks.str);
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

    function addSynalepha(cursor)
    {
        if (cursor) 
        {
            var tempTick = cursor.tick;
            var character = lrc.charAt(lrcCursor);
            //if current notes has lyrics already, concatenate the character to the original one right away.
            if(cursor.element.lyrics.length == 1)
            {
                curScore.startCmd();
                    console.log("addSynalepha(): character to be added: " + character);
                    var concatenated = cursor.element.lyrics[0].text + character;
                    cursor.element.lyrics[0].text = concatenated;
                    nextChar();
                    updateDisplay();
                    pushToUndoStack(cursor, "addSynalepha()");
                curScore.endCmd();
                return true;
            }
            //in the case of current selected note has no lyrics but the pervious has lyrics (MOST LIKELY it's in the middle of the editing),
            //add Synalepha to the previous character
            if(cursor.element.lyrics.length == 0)
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
                if(cursor.element.lyrics.length == 1)
                {
                    curScore.startCmd();
                        console.log("addSynalepha(): character to be added: " + character);
                        var concatenated = cursor.element.lyrics[0].text + character;
                        cursor.element.lyrics[0].text = concatenated;
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
                        while(durationTo64(cursor.element.lyrics[0].lyricTicks) == 0) {cursor.prev();}
                        curScore.startCmd();
                            console.log("addSynalepha(): Note inside a melisma line detected, character to be added at the begining of melisma line: " + character);
                            var concatenated = cursor.element.lyrics[0].text + character;
                            cursor.element.lyrics[0].text = concatenated;
                            pushToUndoStack(cursor, "addSynalepha()");
                            nextChar();
                            updateDisplay();
                        curScore.endCmd();
                        return true;
                    }
                    //if that note is inside a tied note, dump the character to the begining of the tie
                    cursor.rewindToTick(tempTick2);
                    if(cursor.element.notes[0].tieBack != null || cursor.element.notes[0].tieForward != null) 
                    {
                        curScore.startCmd();
                            curScore.selection.select(cursor.element.notes[0].firstTiedNote);
                            cursor = getSelectedCursor();
                            if(cursor.element.lyrics.length == 0)
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
                                var concatenated = cursor.element.lyrics[0].text + character;
                                cursor.element.lyrics[0].text = concatenated;
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
        } while(cursor.element.lyrics.length == 0)
        var melismaLength = durationTo64(cursor.element.lyrics[0].lyricTicks)
        if(melismaLength == 0) return false;
        if(melismaLength < checkLength) return false;
        return true;
    }

    function durationTo64(duration) { return 64 * duration.numerator / duration.denominator;} //helper function for converting duration to 64 for addMelisma()

    function convertLineBreak(x) { return x.replace(/\n/g, "<br />"); } //special thanks to @Jack-Works for wrapping linebreaks in HTML

    function updateDisplay() //update display to lrcDisplay.text
    {
        if(lrcCursor == 0)
        {
            lrcDisplay.text = convertLineBreak("<b>" + lrc.slice(0,1) + "</b>" + "<font color=\"grey\">" + lrc.slice(1) + "</font>");
        }
        else if(lrcCursor == lrc.length - 1)
        {
            lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0, lrcCursor) + "</font>" + "<b>" + lrc.slice(lrcCursor) + "</b>");
        }
        else
        {
             lrcDisplay.text = convertLineBreak("<font color=\"grey\">" + lrc.slice(0,lrcCursor) + "</font>" + "<b>" + lrc.slice(lrcCursor, lrcCursor + 1) + "</b>" + "<font color=\"grey\">" + lrc.slice(lrcCursor + 1) + "</font>");
        }
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

    function nextChar() //advancing the @lrcCursor forward by a char
    {
        var next = lrcCursor + 1;
        if(next >= lrc.length) //loops back to the begining if the @lrcCursor reaches EOF.
        { 
            lrcCursor = 0; 
            if(lrc.charAt(lrcCursor) == '\n' || lrc.charAt(lrcCursor) == ' ') nextChar();
            return false;
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
        if(prev < 0) //loops back to the begining if the @lrcCursor reaches begining.
        { 
            lrcCursor = lrc.length - 1; 
            if(lrc.charAt(lrcCursor) == '\n' || lrc.charAt(lrcCursor) == ' ') prevChar(); //avoid selecting EOF
            return false;
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

    //verticalIncrement and whitespaceIncrement indicate how many pixels of a line & a whitespace on user's deivce screen.
    //use getVerticalIncrement() to forcefully resize the invisible lrcDisplayDummy and use its width to calculate the pixel increments.
    //This is a very cheesy solution but worked pretty well.
    property var verticalIncrement: 0;
    property var whitespaceIncrement: 0;
    function getVerticalIncrement()
    {
        lrcDisplayDummy.text = convertLineBreak("1");
        verticalIncrement = lrcDisplayDummy.height;
        whitespaceIncrement = lrcDisplayDummy.width;
        lrcDisplayDummy.text = convertLineBreak("1 ");
        whitespaceIncrement = lrcDisplayDummy.width - whitespaceIncrement;
        lrcDisplayDummy.text = convertLineBreak("1\n1");
        verticalIncrement = lrcDisplayDummy.height - verticalIncrement;
        console.log("vertical line increment: " + verticalIncrement);
    }

    function findChar(posX, posY) //finds char in the given X, Y in lrcDisplay. @return: lrcCursor index of found character
    {
        var targetRow = Math.ceil(posY / verticalIncrement); //target row
        //console.log("target row: " + targetRow);
        var txt = lrc; //buffer the lyrics
        var findRow = 1; //cursor row, start with 1
        lrcDisplayDummy.text = ""; 
        for(var i = 0; i < txt.length; i++)
        {
            //console.log("current checking character: " + txt.charAt(i) + ", at index " + i)
            if(txt.charAt(i) == '\n') 
            {
                findRow++; 
                lrcDisplayDummy.text = ""; 
                //console.log("go to new line")
            }
            if(findRow == targetRow)
            {
                //forcefully calculate the horizontal size of lyrics by append characters to the invisible lrcDisplayDummy
                //THIS IS SUCH A DIRTY WORKAROUND
                //trim trailing spaces and wrap line breaks to avoid problems, because HTML doesn't wrap here idk why :
                lrcDisplayDummy.text = convertLineBreak(lrcDisplayDummy.text + String(txt.charAt(i))).replace(/\s+$/gm, ' '); 
                //console.log("buffered text: " + lrcDisplayDummy.text)
                if(posX < lrcDisplayDummy.width) 
                {
                    if(txt.charAt(i) == ' ') //if user selects a whitespace, jump to the nearest character
                    {
                        if(i == 0 || i == txt.length - 1) return -1; //if the whitespace is the head or tail of the lyrics, ignore to avoid outOfIndex error
                        if(txt.charAt(i-1) == '\n' && txt.charAt(i+1) == '\n' ) return -1;
                        if(txt.charAt(i-1) == '\n' && txt.charAt(i+1) != '\n' ) return i + 1;
                        if(txt.charAt(i-1) != '\n' && txt.charAt(i+1) == '\n' ) return i - 1;
                        return posX - (lrcDisplayDummy.width - whitespaceIncrement) < lrcDisplayDummy.width - posX ? i-1 : i+1;
                    }    
                    return i;
                }
            }
            if(findRow > targetRow) return -1;
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
            undo_stack.push(cursor.element.lyrics[0].text);
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
                        lrcCursor = parse[1].split('->')[0];
                        console.log("Lyrics Selection history detected, roll lrcCursor back to " + lrcCursor);
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
                var tempLrcCursor = lrcCursor;
                prevChar(); //get last lrcCursor position but skip all the whitespaces and \n.
                var current_lyrics = lrc.charAt(lrcCursor);
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
                lrcCursor = tempLrcCursor; //also roll back the lrcCursor
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
                width: inputButtons.width - (syllableButton.width/4)
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
                Timer // in case of autoLoadLyrics() not finding any matched .txt files, prompt failed message and roll back the lyrics
                {   
                    id: autoReadLyricsFailedMessage
                    repeat: false
                    interval: 1000
                    onTriggered: {
                        if(myFileLyrics.source) acceptFile(myFileLyrics.source);
                        else {lyricSource.horizontalAlignment = Text.AlignRight; lyricSource.text = qsTr("Click \"...\" to open a .txt file→");}
                    } 
                }
            }
            Button 
            {
                id : buttonOpenFile
                width: syllableButton.width/4
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
                        switch(Qt.locale().name.substring(0,2))
                        {
                            case "zh": 
                                settingsPopup.width = 175;
                                break;
                            default: //default case is English
                                settingsPopup.width = 215;
                                //: Please check settingsPopup.width at this message's line in lyricsHelper.qml. You will find a switch() then add your language's case.
                                console.log(qsTr("This is not a text for translation but just a notice: you may also need to change settingsPopup.width to adapt to your language's text space."))
                                break;
                        }
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
                        height: 250
                        modal: true
                        focus: true
                        Grid
                        {
                            id: settingsGrid
                            columns: 1
                            rows: 6
                            spacing: 5
                            Text 
                            { 
                                id: settingsTitle
                                text: qsTr("<b style=\"font-size:8vw\">⚙ Plugin Settings:</b>") 
                            }
                            CheckBox { 
                                id: replaceModeCheckBox
                                checked: replaceMode 
                                text: qsTr("Replace Mode:\noverwrites existed lyrics")}
                            CheckBox { 
                                id: previewSoundModeCheckBox
                                checked: previewSoundMode 
                                text: qsTr("🔊Preview Note Sounds")}
                            Text 
                            { 
                                id: maximumUndoStepsSpinBoxTitle
                                text: qsTr("Maximum Undo Steps:") 
                            }
                            SpinBox{
                                id: maximumUndoStepsSpinBox
                                from: 10
                                value: maximumUndoSteps
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
                                    replaceMode = replaceModeCheckBox.checked;
                                    previewSoundMode = previewSoundModeCheckBox.checked;
                                    maximumUndoSteps = maximumUndoStepsSpinBox.value;
                                    settingsPopup.close(); 
                                    console.log("replaceMode: " + replaceMode);
                                    console.log("previewSoundMode: " + previewSoundMode);
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
                    if(buttonOpenFile.text == "...") fileDialog.open();
                    if(buttonOpenFile.text == "⚙") settingsPopup.open();
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
                    pushToUndoStack(false, "彁:" + original.toString() + "->" + lrcCursor.toString());
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
                    pushToUndoStack(false, "彁:" + original.toString() + "->" + lrcCursor.toString());
                }
            }
        }
        ScrollView
        {
            id: lrcDisplayScrollView
            width: inputButtons.width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.interactive: true
            clip: true
            Text
            {
                id: lrcDisplay
                text: qsTr("Please load a lyrics file first")
                MouseArea
                {
                    id: lrcDisplayMouseArea //MouseArea for Clickable Lyrics Function
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    enabled: inputButtons.enabled
                    onClicked:
                    {
                        console.log("Mouse clicked at X:" + mouse.x + " Y:" + mouse.y);
                        var original = lrcCursor;
                        var found = findChar(mouse.x, mouse.y);
                        if(found != -1) 
                        {
                            console.log("------Selected: " + lrc.charAt(found) + ", lrcCursor is at: " + found + "-----");
                            lrcCursor = found;
                            // Also push the lrcCursor change event to the undo_stack, so we can trace lrcCursor's position back
                            // placeholder "彁" is a very edgy Kanji (幽霊文字, Yuureimoji) that has totally unknown etymology 
                            // the choice is a tribute to LeaF's song 《彁》 https://www.youtube.com/watch?v=EsOU0V2kpUI
                            pushToUndoStack(false, "彁:" + original.toString() + "->" + lrcCursor.toString())
                        }
                        else console.log("given position has no char!");
                        updateDisplay();
                    }
                }
            }
        }

        Text
        {
            id: lrcDisplayDummy
            visible: false
            text: "buffer text"
            Timer { 
                id: searchTxtDelayRunning // for autoLoadLyrics()
                repeat: false
                interval: 250
                onTriggered: searchTxtFolderListModel.searchTxt()
            } 
        }
    }
    
    MouseArea
    {   //Right Button Menu for lrcDisplayScrollView. This MouseArea is outside of the main Column because 
        //there're mouse events capturing conflicts between ScrollView & MouseArea objects
        id: lrcDisplayMenuMouseArea
        x: lrcDisplayScrollView.x
        y: lrcDisplayScrollView.y
        height: lrcDisplay.height > lrcDisplayScrollView.height ? lrcDisplayScrollView.height : lrcDisplay.height
        width: lrcDisplayScrollView.width
        acceptedButtons: Qt.RightButton
        onClicked:
        {
            lrcDisplayMenu.x = mouse.x-10; lrcDisplayMenu.y = mouse.y-10;
            lrcDisplayMenu.open();
        }
        Menu
        {
            id: lrcDisplayMenu
            scale: 0.9
            spacing: 0.5
            bottomPadding: 3
            leftPadding: 3
            topPadding: 3
            rightPadding: 3
            MenuItem { text: "Copy to Clip Board"}
            MenuItem { text: "Edit Lyrics"}
            MenuSeparator { }
            MenuItem { text: "Japanese Kanji to Furigana\n(requires Internet connection)"}
            MenuItem { text: "English Hyphenation\n(requires Internet connection)"}
        }
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
