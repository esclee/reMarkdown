package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"remarkdown/appload"

	"github.com/gomarkdown/markdown"
	"github.com/gomarkdown/markdown/html"
	"github.com/gomarkdown/markdown/parser"
)

type MessageType uint32

const (
	FolderRequest   MessageType = 1
	MarkDownRequest MessageType = 100
)

type reMarkdownState struct {
}

func mdToHTML(md []byte) []byte {
	// create markdown parser with extensions
	extensions := parser.CommonExtensions | parser.AutoHeadingIDs | parser.NoEmptyLineBeforeBlock
	p := parser.NewWithExtensions(extensions)
	doc := p.Parse(md)

	// create HTML renderer with extensions
	htmlFlags := html.CommonFlags | html.HrefTargetBlank
	opts := html.RendererOptions{Flags: htmlFlags}
	renderer := html.NewRenderer(opts)

	return markdown.Render(doc, renderer)
}

func (state *reMarkdownState) HandleMessage(replier *appload.BackendReplier, message appload.Message) {
	if message.MsgType == appload.MsgSystemTerminate {
		fmt.Println("Received message to terminate!")
		os.Exit(0)
	}
	if message.MsgType > 1000 {
		replier.SendMessage(200, "Init")
	}
	if message.MsgType == uint32(FolderRequest) {
		fmt.Println("Received message to check for folder")
		if _, err := os.Stat(message.Contents); errors.Is(err, os.ErrNotExist) {
			err := os.Mkdir(message.Contents, os.ModePerm)
			if err != nil {
				log.Fatalf("error while creating folder")
			}
			replier.SendMessage(3, message.Contents)
		} else {
			replier.SendMessage(2, message.Contents)
		}
	}
	if message.MsgType == uint32(MarkDownRequest) {
		fmt.Println("Received a request for html rendering")
		rendered_text := mdToHTML([]byte(message.Contents))
		replier.SendMessage(101, string(rendered_text))
	}
}

func main() {
	class := new(reMarkdownState)
	app, err := appload.NewAppLoad(class)
	if err != nil {
		log.Fatalf("error creating app: %v", err)
	}
	err = app.Run()
	if err != nil {
		log.Fatalf("error running app: %v", err)
	}
}
