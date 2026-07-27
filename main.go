package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"remarkdown/appload"
	"strings"

	xhtml "golang.org/x/net/html"

	"github.com/yuin/goldmark"
	emoji "github.com/yuin/goldmark-emoji"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/parser"
	"github.com/yuin/goldmark/renderer/html"
)

type MessageType uint32

const (
	MarkDownRequest MessageType = 100
	FolderRequest   MessageType = 300
	XochitlRequest  MessageType = 500
)

type reMarkdownState struct {
}

func mdToHTML(md []byte) []byte {
	gm := goldmark.New(
		goldmark.WithExtensions(extension.GFM, extension.Footnote, extension.Typographer, extension.CJK, emoji.Emoji),
		goldmark.WithParserOptions(
			parser.WithAutoHeadingID(),
		),
		goldmark.WithRendererOptions(
			html.WithHardWraps(),
			html.WithXHTML(),
		),
	)
	var buf bytes.Buffer
	if err := gm.Convert(md, &buf); err != nil {
		return nil
	}
	return buf.Bytes()
}

func (state *reMarkdownState) HandleMessage(replier *appload.BackendReplier, message appload.Message) {
	if message.MsgType == uint32(appload.MsgSystemTerminate) {
		fmt.Println("Termiate request received")
		return
	} else if message.MsgType > 1000 {
		out, _ := exec.Command("bash", "-c", "ls -d /sys/class/input/*/*::capslock 2>/dev/null").Output()
		if string(out) != "" {
			replier.SendMessage(201, "Init, keyboard detected")
		} else {
			replier.SendMessage(200, "Init")
		}
	} else if message.MsgType == uint32(MarkDownRequest) {
		fmt.Println("Received a request for html rendering")
		rendered_text := mdToHTML([]byte(message.Contents))
		if rendered_text == nil {
			fmt.Println("error parsing .md")
			replier.SendMessage(103, ",.md")
			return
		}
		doc, err := xhtml.Parse(strings.NewReader(string(rendered_text)))
		if err != nil {
			fmt.Printf("error parsing HTML: %v", err)
			replier.SendMessage(103, "HTML")
			return
		}
		wordCount := 0
		for n := range doc.Descendants() {
			if n.Type == xhtml.TextNode {
				wordCount += len(strings.Fields(n.Data))
			}
		}
		checked_box := "&#x2705;"
		unchecked_box := "&#x2b1c;"
		checked_html := `<input checked="" disabled="" type="checkbox" />`
		unchecked_html := `<input disabled="" type="checkbox" />`
		res := struct {
			WordCount int    `json:"wc"`
			Text      string `json:"text"`
		}{
			WordCount: wordCount,
			Text:      strings.ReplaceAll(strings.ReplaceAll(string(rendered_text), checked_html, checked_box), unchecked_html, unchecked_box),
		}
		js, err := json.Marshal(res)
		if err != nil {
			fmt.Printf("error parsing json: %v", err)
			replier.SendMessage(103, "JSON")
			return
		}
		replier.SendMessage(101, string(js))
	} else if message.MsgType == uint32(FolderRequest) {
		fmt.Println("Folder request received")
		folderPath := filepath.Clean("/home/root/reMarkdown/" + message.Contents)
		if !strings.HasPrefix(folderPath, "/home/root/reMarkdown") {
			fmt.Println("Attempted to access folder not in /home/root/reMarkdown")
			replier.SendMessage(303, "Path not supported")
		}
		info, err := os.Stat(folderPath)
		if err == nil {
			if info.IsDir() {
				replier.SendMessage(301, "Is a folder")
			} else {
				fmt.Println("folder request received but not a folder")
				replier.SendMessage(304, "Not a folder")
			}
		}
		if errors.Is(err, os.ErrNotExist) {
			err2 := os.MkdirAll(folderPath, os.ModePerm)
			if err2 != nil {
				fmt.Println("error while creating folder")
				replier.SendMessage(305, "Couldn't create folder")
			}
			replier.SendMessage(302, "Created new folder")
		}
	} else if message.MsgType == uint32(XochitlRequest) {
		fmt.Println("xochitl request received")
		var aviaryUrl string
		if info, err := os.Stat("/home/root/reMarkdown/AVIARY"); errors.Is(err, os.ErrNotExist) {
			fmt.Println("no aviary file found")
			replier.SendMessage(505, "Error")
			return
		} else if info.IsDir() {
			fmt.Println("AVIARY is a directory")
			replier.SendMessage(505, "Error")
			return
		} else {
			content, err := os.ReadFile("/home/root/reMarkdown/AVIARY")
			if err != nil {
				fmt.Println("AVIARY can't be read")
				replier.SendMessage(505, "Error")
				return
			} else {
				aviaryUrl = string(content)
				aviaryUrl = strings.TrimRight(aviaryUrl, "\r\n")
				if !strings.HasPrefix(aviaryUrl, "http") {
					fmt.Println("AVIARY is not a proper aviary url")
					replier.SendMessage(505, "Error")
					return
				}
				if !strings.HasSuffix(aviaryUrl, "/") {
					aviaryUrl = aviaryUrl + "/"
				}
			}
		}
		filePath := strings.TrimPrefix(message.Contents, "file://")
		fmt.Println("File being opened: ", filePath)
		file, err := os.Open(filePath)
		if err != nil {
			fmt.Printf("Error opening file: %v\n", err)
			replier.SendMessage(505, "Error")
		} else {
			defer file.Close()
			var body bytes.Buffer
			writer := multipart.NewWriter(&body)
			part, err := writer.CreateFormFile("file", filepath.Base(filePath))
			if err != nil {
				fmt.Printf("Error copying file: %v\n", err)
				replier.SendMessage(505, "Error")
				return
			}
			_, err = io.Copy(part, file)
			if err != nil {
				fmt.Printf("Error copying file: %v\n", err)
				replier.SendMessage(505, "Error")
				return
			} else {
				err = writer.Close()
				if err != nil {
					fmt.Printf("Error closing writer: %v\n", err)
					replier.SendMessage(505, "Error")
					return
				} else {
					url := aviaryUrl + "api/upload"
					req, err := http.NewRequest(http.MethodPost, url, &body)
					if err != nil {
						fmt.Printf("Error creating request: %v\n", err)
						replier.SendMessage(505, "Error")
						return
					} else {
						req.Header.Set("Content-Type", writer.FormDataContentType())
						client := &http.Client{}
						resp, err := client.Do(req)
						if err != nil {
							fmt.Printf("Error sending request: %v\n", err)
							replier.SendMessage(505, "Error")
							return
						} else {
							defer resp.Body.Close()
							replier.SendMessage(501, "Transfer to Xochitl initiated")

						}
					}
				}
			}
		}
	}
}

func main() {
	class := new(reMarkdownState)
	if info, err := os.Stat("/home/root/reMarkdown"); errors.Is(err, os.ErrNotExist) {
		err := os.Mkdir("/home/root/reMarkdown", os.ModePerm)
		if err != nil {
			log.Fatalf("error while creating folder")
		}
	} else if !info.IsDir() {
		log.Fatalf("/home/root/reMarkdown not a folder")
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
