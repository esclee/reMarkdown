# reMarkdown, a lightweight Markdown editor for the reMarkable tablet

reMarkdown is a lightweight Markdown editor for the [reMarkable tablet](https://remarkable.com), to be used via [AppLoad](https://github.com/asivery/rm-appload) by asivery. It is an approximate reimplementation of dps's [reMarkable keyWriter](https://github.com/dps/remarkable-keywriter) with a go backend (special credit to StarNumber's [reRadar24](https://github.com/StarNumber12046/reRadar24) from which I got the code for the go-to-AppLoad communication layer).

reMarkdown has been tested on the reMarkable Paper Pro using the Type Folio. In fact, editing this very README file is how reMarkdown was tested.

## How to install

**Note**: This version of reMarkdown relies on a new feature of AppLoad that is not available in AppLoad release versions <= 0.5.0. You can either build AppLoad from source or wait until a new release is available.

AppLoad must be installed on your reMarkable tablet, and your build environment should have qt6 and go.

- Clone this repo and enter the folder.
- Ensure build.sh is executable (`chmod +x build.sh`).
- Run `build.sh`.
- Copy the resulting `rmd` folder to your tablet's appload location (`scp -rp rmd root@10.11.99.1:~/xovi/exthome/appload`) and reload appload.

If you have an rM2, then instead of `build.sh`, use `build-rm2.sh`. But note that reMarkdown is not tested on rM2.

## How to use reMarkdown

When you open reMarkdown, you will see a file selector, which will list all `.md` files available in the folder `/home/root/reMarkdown`. If the folder does not exist, it will be created. You can either open an existing file via the selector (as you type, the list will filter down to files that have names starting with what you have typed) or creating a new file by typing in a new filename.

The file will open in a plaintext editor, and you can start editing!

If you want to see what the `.md` file would look like with formatting, hit the meta key (on the Type Folio that is the left side opt key). [gomarkdown/markdown](https://github.com/gomarkdown/markdown) is used to turn the `.md` file's content into html. Hitting the meta key again or the escape key will return you to the editing view.

In the render view, if you click on a link, reMarkdown will open the link if it deems the link to be reMarkdown-compatible, i.e., if the link target is either `<some-file-name>.md` or `/home/root/<some-file-name>.md`. If the file does not exist, then this will create a new file.

From the editing view, hitting the escape key will save the file and open the selector view. There, you can return to the document or open a different document to edit. Hitting the escape key while in the selector view will exit reMarkdown.

**Note**: Tapping the right edge of the screen will toggle between the editing view and the render view (i.e., same behavior as hitting the opt/alt key). Tapping the bottom 90% of the left edge (see [External keyboard](#external-keyboard)) of the screen while in the render view will toggle back to the editing view; while in the editing view will save the file and open the selector view; while in the selector view will exit reMarkdown. In other words, tapping on the left edge has the same behavior as hitting the escape key.

### Subfolders

Subfolder support is a WIP.
- By default, the selector shows all `.md` files in the current folder as well as all subfolders. Subfolders marked by (D) after the folder name. You can enter a subfolder by selecting the subfolder via the selector or typing the name of the subfolder followed by a `/`. If the subfolder you specified does not exist, it will be created for you. You can toggle the visibility of the subfolders by tapping on the right edge of the screen.

**Note**: due to how QML's [FolderListModel](https://doc.qt.io/qt-6/qml-qt-labs-folderlistmodel-folderlistmodel.html) is implemented, subfolders are not filtered. For instance, if your `/home/root/reMarkdown/` folder has two markdown files--`markdown.md` and `textfile.md`--as well as a subfolder `subfolder`, when you open reMarkdown, you will see all three listed in the selector. Once you type `m`, `textfile.md` will no longer be visible since it is an `.md` file that does not start with an `m`, but `subfolder` will still be visible since subfolders are not filtered.

### External keyboard

When the tablet does not detect a connected Type Folio, a virtual keyboard shows up when you are in text edit mode (i.e., in selector view or editor view). But if you are using an external keyboard, you may wish to hide the virtual keyboard. There are two ways to do it:
- Entering F1 via your external keyboard.
- Tapping the top 10% of the left edge of the screen.

If you disconnect your external keyboard and want to make the virtual keyboard visible again, simply tap the top 10% of the left edge of the screen again. 

## Why not stick with the stock reMarkable notebooks?

It is true that you can type into reMarkable notebook, and it supports some amount of Markdown syntax when typing. But the problem is that it's not _saved_ in the Markdown format; rather, everything is saved in the proprietary .rm files, making it hard to easily grab the typed content. The goal of reMarkdown is to have a true Markdown editor for the reMarkable tablet--distraction-free writing but producing files that any other Markdown editor/renderer can work with.

## Why did you need to reimplement reMarkable keyWriter?

reMarkable keyWriter was not designed to work alongside xochitl (reMarkable tablet's stock application), so in order to use keyWriter, you needed to stop xochitl first. With AppLoad, you can run applications on top of xochitl, so I decided to port reMarkable keyWriter to be an AppLoad app.

The qml code for the UI is very, very similar to that of the reMarkable keyWriter. But there are some minor changes I made along the way, such as making component names more intuitive for myself, updating the qml code to no longer rely on deprecated conventions, and not relying on a starter `scratch.md` file already being in place.

## Known issues

This is a personal side project/proof-of-concept, not a polished product. Naturally, it domes with some limitations.
- Square brackets: xochitl has some quirks when it comes to keyboard inputs, which makes it hard to type some characters using a keyboard. Unfortunately for Markdown enthusiasts, square brackets fall in this category if using the en-US layout. To get around that, typing `((` without letting go of the shift key will type `[`, and  typing `))` without letting go of the shift key will type `]`.
	- More information about xochitl's keymapping can be found in their [epaper-qpa](https://github.com/remarkable/epaper-qpa) repo.
	- If you built a custom qpa for yourself that doesn't reassign square brackets to something else you wouldn't need this workaround, but I implemented this workaround with an eye towards making the tablet a usable markdown editor with the Type Folio and not too much messing around.
- When the app doesn't know what to do with a keypress (e.g., because you tried to move the cursor beyond the end of the text using the arrow keys), keypress bubbles up, all the way to xochitl. Most of this should be caught but I might have missed things here and there. Tapping on the text makes reMarkdown regain focus.
- Closing reMarkdown sometimes (rarely, in my experience, but it does happen) crashes the tablet.