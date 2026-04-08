# reMarkdown, a lightweight Markdown editor for the reMarkable tablet

reMarkdown is a lightweight Markdown editor for the [reMarkable tablet](https://remarkable.com), to be used via [AppLoad](https://github.com/asivery/rm-appload) by asivery. It is an approximate reimplementation of dps's [reMarkable keyWriter](https://github.com/dps/remarkable-keywriter), with a go backend (special credit to StarNumber's [reRadar24](https://github.com/StarNumber12046/reRadar24) from which I got the code for the go-to-AppLoad communication layer).

reMarkdown has been tested on the reMarkable Paper Pro using the Type Folio. In fact, editing this very README file is how reMarkdown was tested.

**Note**: This version of reMarkdown relies on a new feature of AppLoad that is not available in AppLoad release versions <= 0.5.0. You can either build AppLoad from source or wait until a new release is available.

## How to use reMarkdown

When you open reMarkdown, you will see a file selector, which will list all .md files available in the folder `/home/root/reMarkdown`. If the folder does not exist, it will be created. You can either open an existing file via the selector (as you type, the list will filter down to files that have names starting with what you have typed) or creating a new file by typing in a new filename.

The file will open in a plaintext editor, and you can start editing!

If you want to see what the .md file would look like with formatting, hit the meta key (on the Type Folio that is the left side opt key). [gomarkdown/markdown](https://github.com/gomarkdown/markdown) is used to turn the .md file's content into html. Hitting the meta key again or the escape key will return you to the editing view.

In the render view, if you click on a link, reMarkdown will open the link if it deems the link to be reMarkdown-compatible, i.e., if the link target is either `<some-file-name>.md` or `/home/root/<some-file-name>.md`. If the file does not exist, then this will create a new file.

From the editing view, hitting the escape key will save the file and open the selector view. There, you can return to the document or open a different document to edit. Hitting the escape key while in the selector view will exit reMarkdown.

**Note**: Tapping the right edge of the screen will toggle between the editing view and the render view (i.e., same behavior as hitting the opt/alt key). Tapping the left edge of the screen while in the render view will toggle back to the editing view; while in the editing view will save the file and open the selector view; while in the selector view will exit reMarkdown. In other words, tapping on the left edge has the same behavior as hitting the escape key.

### Subfolders

Subfolder support is a WIP.
- By default, the selector shows all .md files in the current folder (filtered by the text box) as well as all subfolders (not filtered). You can toggle the visibility of the subfolders by tapping on the right edge of the screen.
- Through the textbox: typing a folder's relative path from `/home/root/reMarkdown/` including the trailing `/` will open that folder. If the folder does not exist, it will be created for you.
	- e.g. if you type `subfolder/subfolder2/` in the textbox, you will see all .md files in `/home/root/reMarkdown/subfolder/subfolder2/` as well as all subfolders within that folder (assuming subfolder visibility is on).
	- e.g. if you type `subfolder/subfolder2` in the textbox, you will see all .md files in `/home/root/reMardown/subfolder` whose file names start with `subfolder2` as well as any subfolders (regardless of what the name is) within `/home/root/reMardown/subfolder` (assuming subfolder visibility is on).
- Through the selector: the selector will by default show all .md files in the current directory (filtered by the textbox) as well as all subdirectories in the current directory, essentially by typing in the textbox for you.

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