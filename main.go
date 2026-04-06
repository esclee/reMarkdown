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
	MarkDownRequest MessageType = 100
)

type reMarkdownState struct {
}

func mdToHTML(md []byte) []byte {
	// create markdown parser with extensions
	extensions := parser.CommonExtensions | parser.AutoHeadingIDs | parser.NoEmptyLineBeforeBlock | parser.Strikethrough | parser.Footnotes
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
		return
	}
	if message.MsgType > 1000 {
		replier.SendMessage(200, "Init")
	}
	if message.MsgType == uint32(MarkDownRequest) {
		fmt.Println("Received a request for html rendering")
		rendered_text := mdToHTML([]byte(message.Contents))
		replier.SendMessage(101, string(rendered_text))
	}
}

func main() {
	class := new(reMarkdownState)
	if _, err := os.Stat("/home/root/reMarkdown"); errors.Is(err, os.ErrNotExist) {
		err := os.Mkdir("/home/root/reMarkdown", os.ModePerm)
		if err != nil {
			log.Fatalf("error while creating folder")
		}
	}
	app, err := appload.NewAppLoad(class)
	if err != nil {
		log.Fatalf("error creating app: %v", err)
	}
	err = app.Run()
	if err != nil {
		log.Fatalf("error running app: %v", err)
	}
}
