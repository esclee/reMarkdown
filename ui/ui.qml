// Substantial portions of this code were taken/inspired from https://github.com/dps/remarkable-keywriter.

// MIT License

// Copyright (c) 2019 David Singleton

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtQuick.Controls
import QtQuick.Layouts
import net.asivery.AppLoad 1.0
import net.asivery.ApploadUtils

Rectangle {
    id: root
    visible: true
    width: parent.width
    height: parent.height

    property string doc: ""
    property string docHTML: ""
    property bool editState: false
    property int cursorPosition: 0
    property real curY: 0.0
    property bool metaDown: false
    property bool selector: true
    property string folder: "/home/root/reMarkdown/"
    property string file: ""
    property string selectorText: ""
    property var lastType: -1
    property int foldercheck: -1
    property string curFilePath: ""
    property string currentFolder: "/home/root/reMarkdown/"
    property string stub: ""
    property bool closeViaAppload: true

    signal close
    function unloading() {
        if (!selector) {
            saveFile();
        }
        if (closeViaAppload){
            closeViaAppload = false;
            appload.terminate();
        }
        console.log("We're unloading!");
    }

    AppLoad {
        id: appload
        applicationID: "reMarkdown"
        onMessageReceived: (type, contents) => {
            console.log("Appload received message " + type);
            if (type == 200) {
                console.log("init");
                folderModel.folder = "file://" + root.folder;
                return;
            }
            switch (type) {
                case 101:
                    console.log("rendered HTML returned.");
                    docHTML = contents;
                    renderer.text = docHTML;
                    break;
                case 201:
                    root.closeViaAppload = false;
                    appload.terminate();
                    break;
                case 301:
                case 302:
                    foldercheck = 1;
                    break;
            }
        }

    }

    Keys.onPressed: (event) => {
        if (selector) {
            selectorTextEdit.forceActiveFocus();
        }
        else if (editState) {
            editor.forceActiveFocus();
        }
        else {
            renderer.forceActiveFocus();
        }
        event.accepted = true;
    }

    function toggleView() {
        if (editState) {
            console.log("Toggling to rendered view");
            cursorPosition = editor.cursorPosition;
            curY = flick.contentY;
            root.doc = editor.text;
            editState = false;
            if (editor.text.length > 0) {
                appload.sendMessage(100, doc);
            }
            else {
                docHTML = "";
                renderer.text = "";
            }
        } else {
            console.log("Toggling to edit view");
            editState = true;
            editor.text = root.doc;
            editor.cursorPosition = cursorPosition;
            flick.contentY = curY;
        }
    }
    function newFile(fileName) {
        console.log("Create new file " + fileName);
        var fileUrl = ""
        if (fileName.endsWith(".md")) {
            fileUrl = fileName;
        }
        else {
            fileUrl = fileName + ".md";
        }
        var request = new XMLHttpRequest();
        request.open("PUT", fileUrl, false);
        request.send("");
        console.log("save -> " + request.status + " " + request.statusText);
        return request.status;
    }
    function loadFile(fileName) {
        console.log("Loading file " + fileName);
        var fileUrl = "";
        if (fileName.endsWith(".md")) {
            fileUrl = fileName;
        }
        else {
            fileUrl = fileName + ".md";
        }
        if (fileUrl != file) {
            cursorPosition = 0;
        }
        root.currentFolder = fileUrl.slice("file://".length, fileUrl.lastIndexOf("/") + 1);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", fileUrl);
        xhr.onreadystatechange = function () {
            if (xhr.readyState == XMLHttpRequest.DONE) {
                let res = xhr.responseText;
                selectorTextEdit.text = root.currentFolder.slice(root.folder.length);
                selector = false;
                editState = true;
                file = fileUrl;
                doc = res;
                editor.text = doc;
            }
        };
        docHTML = "";
        stub = "";
        xhr.send();
    }
    function saveFile() {
        doc = editor.text;
        console.log("Saving " + file);
        var fileUrl = file;
        var request = new XMLHttpRequest();
        request.open("PUT", fileUrl);
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE) {
                console.log("Save completed");
            }
        };
        request.send(doc);
    }
    function handleKeyEvent(event){
        if (event.key == Qt.Key_Escape) {
            if (selector) {
                root.closeViaAppload = false;
                appload.terminate();
                return;
            }
            else if (editState) {
                saveFile();
                selector = true;
            }
            else {
                toggleView();
            }
        }
        else if (event.key == Qt.Key_Meta || event.key == Qt.Key_Alt) {
            toggleView();
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + root.folder
        rootFolder: "file://" + root.folder
        nameFilters: ["*.md"]
        caseSensitive: false
        sortField: FolderListModel.Type
        showDirs: true
        showDotAndDotDot: true
    }

    Component.onCompleted: {
        selector = true;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (Date.now() - lastType < 1000) {
                dm.displayMethod = DisplayMethodArea.Animate;
                return;
            }
            dm.displayMethod = DisplayMethodArea.Content;
        }
    }
    Rectangle {
        width: parent.width * 0.025
        height: parent.height
        anchors.left: parent.left
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (selector) {
                    closeViaAppload = false;
                    appload.terminate();
                }
                else if (!editState) {
                    toggleView();
                }
                else {
                    saveFile();
                    selector = true;
                }
            }
        }
    }

    Rectangle {
        width: parent.width * 0.025
        height: parent.height
        anchors.right: parent.right
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!selector) {
                    toggleView();
                }
                else {
                    folderModel.showDirs = !folderModel.showDirs;
                }
            }
        }
    }
    
    Flickable {
	id: flick
	width: parent.width * 0.95
	height: parent.height * 0.95
        anchors.centerIn: parent
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: editState? editor.paintedWidth : renderer.paintedWidth
        bottomMargin: parent.height /2
        contentHeight:editState? editor.height : renderer.height
        clip: true
        function scrollUp() {
            contentY -= 400;
            if (contentY < 0) contentY = 0;
        }
        function scrollDown() {
            if (renderer.height > root.height * 0.9 && contentY <= renderer.height - root.height / 2 - 400) {
                contentY += 400;
            }
            else if (renderer.height > root.height * 0.9){
                contentY = renderer.height - root.height / 2;
            }
        }
        function ensureVisible(r) {
            if (contentX >= r.x) {
                contentX = r.x;
            }
            else if (contentX + width <= r.x + r.width) {
                contentX = r.x + r.width - width;
            }
            if (contentY > r.y) {
                contentY = r.y;
            }
            else if (contentY + height <= r.y + r.height) {
                contentY = r.y + r.height - height;
            }
        }
        Keys.onPressed: (event) => {
            switch(event.key){
                case Qt.Key_Down:
                    if (!editState) {
                        flick.scrollDown();
                        event.accepted = true;
                    } else {
                        if (editor.cursorPosition >= editor.text.length || editor.cursorRectangle.y > editor.contentHeight - 2 * editor.cursorRectangle.height) {
                            editor.cursorPosition = editor.text.length;
                            event.accepted = true;
                        }
                    }
                    break;
                case Qt.Key_Up:
                    if (!editState) {
                        flick.scrollUp();
                        event.accepted = true;
                    } else {
                        if (editor.cursorPosition <= 0 || editor.cursorRectangle.y < editor.cursorRectangle.height) {
                            editor.cursorPosition = 0;
                            event.accepted = true;
                        }
                    }
                    break;
                case Qt.Key_Left:
                    if (editState) {
                        if (editor.cursorPosition <= 0) {
                            editor.cursorPosition = 0;
                            event.accepted = true;
                        }
                    }
                    else event.accepted = true;
                    break;
                case Qt.Key_Right:
                    if (editState) {
                        if (editor.cursorPosition >= editor.text.length) {
                            editor.cursorPosition = editor.text.length;
                            event.accepted = true;
                        }
                    }
                    else event.accepted = true;
                    break;
                case Qt.Key_PageUp:
                    editor.cursorPosition -= 100;
                    if (editor.cursorPosition <= 0) {
                        editor.cursorPosition = 0;
                    }
                    event.accepted = true;
                    break;
                case Qt.key_PageDown:
                    editor.cursorPosition += 100;
                    if (editor.cursorPosition >= editor.text.length) {
                        editor.cursorPosition = text.length;
                    }
                    event.accepted = true;
                    break;
                default:
                    break;
            }
            event.accepted = true;
        }

        TextArea {

            id: editor
            width: flick.width
            Keys.enabled: true
            wrapMode: TextEdit.Wrap
            textMargin: 12
            visible: editState && !selector
            textFormat: TextEdit.PlainText
            font.family: editState ? "Noto Mono" : "Noto Sans"
            text: doc
            focus: (selector || !editState) ? false : true
            renderType: Text.NativeRendering
            readOnly: false
            font.pointSize: 28

            property bool leftP: false
            property bool rightP: false

            DisplayMethodArea {
                id: dm
                anchors.fill: parent
                displayMethod: DisplayMethodArea.Content
            }

            onTextChanged: {
                root.lastType = Date.now();
            }

            Keys.onReleased: (event) => {
                handleKeyEvent(event);
                if (event.key == Qt.Key_Escape || event.key == Qt.Key_Meta || Qt.Key_Alt) {
                    return;
                }
                if (editState) {
		            doc = editor.text;
		            let cY = flick.contentY;
                    if (event.text === "(") {
                        leftP = !leftP;
                        if (!leftP) {
                            let cp = editor.cursorPosition;
                            let frontString = doc.slice(0, cp);
                            let backString = doc.slice(cp);
                            if (frontString.slice(cp - 2) === "(("); {
                                editor.text = frontString.slice(0, cp - 2) + "[" + backString;
                                editor.cursorPosition = cp - 1;
				                doc = editor.text;
				                flick.contentY = cY;
                            }
                        }
                    }
                    else if (event.text === ")") {
                        leftP = false;
                        rightP = !rightP;
                        if (!rightP) {
                            let cp = editor.cursorPosition;
                            let frontString = doc.slice(0, cp);
                            let backString = doc.slice(cp);
                            if (frontString.slice(cp - 2) === "))"); {
                                editor.text = frontString.slice(0, cp - 2) + "]" + backString;
                                editor.cursorPosition = cp - 1;
				                doc = editor.text;
				                flick.contentY = cY;
                            }
                        }
                    }
                    else {
                        leftP = false;
                        rightP = false;
                    }
                }
            }

            onCursorRectangleChanged: {
                flick.ensureVisible(cursorRectangle);
            }
        }

        TextArea {
            id: renderer
            width: flick.width
            Keys.enabled: true
            wrapMode: TextEdit.Wrap
            textMargin: 12
            visible: !editState
            textFormat: TextEdit.RichText
            font.family: "Noto Sans"
            text: docHTML
            focus: (selector || editState) ? false : true
            renderType: Text.NativeRendering
            readOnly: true
            font.pointSize: 28

            onLinkActivated: (link) => {
                console.log("Link activated: " + link);
                let fileName = link;
                if (fileName.endsWith(".md") && !(fileName.includes("/"))) {
                    let xhr = new XMLHttpRequest();
                    xhr.open('GET', "file://" + root.currentFolder + fileName, false);
                    xhr.send();
                    if (xhr.status === 200 || xhr.status === 0) {
                        console.log(link + " is a .md file in " + root.currentFolder + ", loading.");
                        saveFile();
                        loadFile("file://" + root.currentFolder + fileName);
                        return;
                    }
                }
                else if (link.startsWith(root.folder) && fileName.endsWith(".md")) {
                    let linkedFileFolder = link.slice(root.folder.length, link.lastIndexOf("/") + 1);
                    if (linkedFileFolder.length > 0) {
                        appload.sendMessage(300, linkedFileFolder);
                    }
                    let xhr = new XMLHttpRequest();
                    xhr.open('GET', "file://" + fileName, false);
                    xhr.send();
                    if (xhr.status === 200 || xhr.status === 0) {
                        console.log(link + " is a .md file in " + root.folder +", loading.");
                        saveFile();
                        loadFile("file://" + fileName);
                        return;
                    }
                }
                console.log(link + " is not a .md file in " + root.folder + ", ignoring.");
            }

            Keys.onReleased: (event) => {
                handleKeyEvent(event);
                if (event.key == Qt.Key_Escape || event.key == Qt.Key_Meta) {
                    return;
                }
            }

            onCursorRectangleChanged: {
                flick.ensureVisible(cursorRectangle);
            }
        }
    }

    Rectangle {
        id: selectorBox
        anchors.centerIn: parent
        width: parent.width * 0.6
        height: parent.height * 0.6
        color: "white"
        visible: selector
        radius: 20
        border.width: 5
        border.color: "black"
        TextArea {
            id: selectorTextEdit
            text: selectorText
            textFormat: TextEdit.PlainText
            width: parent.width - 10
            color: "black"
            visible: selector
            font.pointSize: 24
            font.family: "Noto Mono"
            focus: selector ? true : false
            Keys.enabled: true
            Component.onCompleted: {
                selectorTextEdit.forceActiveFocus();
            }
            onTextChanged: {
                selectorText = selectorTextEdit.text;
                let folderPath = "";
                let lastPart = selectorText.slice(selectorText.lastIndexOf("/") + 1);
                root.stub = lastPart;
                if (selectorText.lastIndexOf("/") > 0) {
                    folderPath = selectorText.slice(0, selectorText.lastIndexOf("/") + 1);
                    if ("file://" + root.folder + folderPath != folderModel.folder) {
                        appload.sendMessage(300, folderPath);
                        folderModel.folder = "file://" + root.folder + folderPath;
                    }
                    if (selectorText.slice(-1) == "/") {
                        selectorTextEdit.cursorPosition = selectorTextEdit.text.length;
                    }
                }
                else {
                    folderModel.folder = "file://" + root.folder;
                }
                if (lastPart.endsWith(".md")) {
                    lastPart = lastPart.slice(0, lastPart.length - ".md".length);
                }
                else if (lastPart.endsWith(".m")) {
                    lastPart = lastPart.slice(0, lastPart.length - ".m".length);
                }
                else if (lastPart.endsWith(".")) {
                    lastPart = lastPart.slice(0, lastPart.length - ".".length);
                }
                folderModel.nameFilters = [lastPart + "*.md"];
                let noItemStartsWith = true;
                for (var i = 0; i < selectorList.count; i++) {
                    if (selectorList.itemAtIndex(i).text.toLowerCase().startsWith(lastPart.toLowerCase())) {
                        selectorList.currentIndex = i;
                        noItemStartsWith = false;
                        break;
                    }
                }
                if (noItemStartsWith) {
                    selectorList.currentIndex = -1;
                }
                if (selectorTextEdit.text == "" || selectorTextEdit.text.endsWith("/")) {
                    selectorList.currentIndex = -1;
                }
            }
            Keys.onPressed: (event) => {
                if (event.key == Qt.Key_Enter || event.key == Qt.Key_Return){
                    if (!selectorList.currentItem) {
                        newFile("file://" + root.folder + selectorText);
                        loadFile("file://" + root.folder + selectorText);
                    }
                    else {
                        if (selectorList.currentItem.text.endsWith(".md")) {
                            loadFile(folderModel.folder + selectorList.currentItem.text);
                        }
                        else {
                            if (selectorList.currentItem.text == ".") {
                                selectorTextEdit.text = folderModel.folder.toString().slice(("file://" + root.folder).length);
                                selectorList.currentIndex = -1;
                            }
                            else if (selectorList.currentItem.text == ".." && folderModel.folder.toString() != folderModel.rootFolder.toString()) {
                                let currentFolderNoSlash = folderModel.folder.toString().slice(0, -1);
                                let secondToLastIndex = currentFolderNoSlash.lastIndexOf("/");
                                selectorTextEdit.text = folderModel.folder.toString().slice(folderModel.rootFolder.toString().length, secondToLastIndex + 1);
                                selectorList.currentIndex = -1;
                            }
                            else {
                                selectorTextEdit.text = folderModel.folder.toString().slice(("file://" + root.folder).length) + selectorList.currentItem.text.slice(0, selectorList.currentItem.text.length - " (D)".length) + "/";
                            }
                            selectorTextEdit.cursorPosition = selectorTextEdit.text.length;
                            event.accepted = true;
                            return;
                        }
                    }
                    selector = false;
                    event.accepted = true;
                    selectorText = "";
                    editState = true;
                    return;
                }
                handleKeyEvent(event);
            }
            Keys.onReleased: (event) => {
                handleKeyEvent(event);
            }
            Keys.forwardTo: selectorList
        }
        ListView {
            id: selectorList
            anchors.top: selectorTextEdit.bottom
            anchors.bottom: parent.bottom
            width: parent.width - 10
            anchors.horizontalCenter: parent.horizontalCenter
            highlightResizeDuration: 0
            currentIndex: -1
            highlight: Rectangle {
                color: "transparent"
                border.width: 5
                border.color: "black"
                radius: 5
                width: ListView.view.width
                z: 2
            }
            onCountChanged: {
                let noItemStartsWith = true;
                let lastPart = selectorTextEdit.text.slice(selectorTextEdit.text.lastIndexOf("/") + 1);
                for (var i = 0; i < selectorList.count; i++) {
                    if (selectorList.itemAtIndex(i).text.toLowerCase().startsWith(lastPart.toLowerCase())) {
                        selectorList.currentIndex = i;
                        noItemStartsWith = false;
                        break;
                    }
                }
                if (noItemStartsWith) {
                    selectorList.currentIndex = -1;
                }
                if (selectorTextEdit.text == "" || selectorTextEdit.text.endsWith("/")) {
                    selectorList.currentIndex = -1;
                }
            }
            model: folderModel
            delegate: ItemDelegate {
                width: ListView.view.width
                text: fileIsDir && fileName != "." && fileName != ".." ? fileName + " (D)" : fileName
                palette.text: "black"
                font.pointSize: 24
                onClicked: {
                    if (fileName.endsWith(".md")) {
                        loadFile(folderModel.folder + fileName);
                    }
                    else {
                        if (fileName == ".") {
                            selectorTextEdit.text = folderModel.folder.toString().slice(folderModel.rootFolder.toString().length);
                            selectorList.currentIndex = -1;
                        }
                        else if (fileName == "..") {
                            let currentFolderNoSlash = folderModel.folder.toString().slice(0, -1);
                            let secondToLastIndex = currentFolderNoSlash.lastIndexOf("/");
                            selectorTextEdit.text = folderModel.folder.toString().slice(folderModel.rootFolder.toString().length, secondToLastIndex + 1);
                            selectorList.currentIndex = -1;
                        }
                        else {
                            selectorTextEdit.text = folderModel.folder.toString().slice(("file://" + root.folder).length) + fileName + "/";
                        }
                    }
                }
            } 
        }
    }
}
