// This code comes from https://github.com/StarNumber12046/reRadar24.

// MIT License

// Copyright (c) 2026 StarNumber

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

package appload

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"sync"
	"syscall"
)

const (
	MaxPackageSize          = 10485760
	MsgSystemTerminate      = 0xFFFFFFFF
	MsgSystemNewCoordinator = 0xFFFFFFFE
)

// MessageHeader represents the header of a message
type MessageHeader struct {
	MsgType uint32
	Length  uint32
}

// Message represents a complete message with type and contents
type Message struct {
	MsgType  uint32
	Contents string
}

// BackendReplier handles sending messages back to the frontend
type BackendReplier struct {
	conn         *net.UnixConn
	locked       bool
	internalChan chan Message
	mu           sync.Mutex
}

// SendMessage sends a message to the frontend
func (br *BackendReplier) SendMessage(msgType uint32, contents string) error {
	br.mu.Lock()
	defer br.mu.Unlock()

	if br.locked {
		return errors.New("cannot send back data to a terminating frontend")
	}
	return sendMessage(br.conn, msgType, contents)
}

// SendInternal sends a message to the internal channel
func (br *BackendReplier) SendInternal(msgType uint32, contents string) {
	br.internalChan <- Message{
		MsgType:  msgType,
		Contents: contents,
	}
}

// Lock prevents further messages from being sent
func (br *BackendReplier) Lock() {
	br.mu.Lock()
	defer br.mu.Unlock()
	br.locked = true
}

// AppLoadBackend is the interface for backend implementations
type AppLoadBackend interface {
	HandleMessage(replier *BackendReplier, message Message)
}

// AppLoad manages the connection and message processing
type AppLoad struct {
	backend      AppLoadBackend
	conn         *net.UnixConn
	internalChan chan Message
}

// NewAppLoad creates a new AppLoad instance
func NewAppLoad(backend AppLoadBackend) (*AppLoad, error) {
	if len(os.Args) < 2 {
		return nil, errors.New("missing socket path argument")
	}
	socketPath := os.Args[1]

	// Create a Unix domain socket
	addr, err := net.ResolveUnixAddr("unixpacket", socketPath)
	if err != nil {
		return nil, err
	}

	conn, err := net.DialUnix("unixpacket", nil, addr)
	if err != nil {
		return nil, err
	}

	internalChan := make(chan Message, 100)
	return &AppLoad{
		backend:      backend,
		conn:         conn,
		internalChan: internalChan,
	}, nil
}

// CreateReplier creates a new BackendReplier
func (al *AppLoad) CreateReplier() *BackendReplier {
	return &BackendReplier{
		conn:         al.conn,
		locked:       false,
		internalChan: al.internalChan,
	}
}

// Run starts the message processing loop
func (al *AppLoad) Run() error {
	headerBuf := make([]byte, 8) // Size of MessageHeader
	dataBuf := make([]byte, MaxPackageSize)
	replier := al.CreateReplier()

	for {
		// Read header
		n, err := al.conn.Read(headerBuf)
		if err != nil || n != 8 {
			if errors.Is(err, net.ErrClosed) || errors.Is(err, syscall.ECONNRESET) || errors.Is(err, io.EOF) {
				break
			}
			return fmt.Errorf("error reading header: %w", err)
		}

		// Parse header
		msgType := binary.LittleEndian.Uint32(headerBuf[0:4])
		length := binary.LittleEndian.Uint32(headerBuf[4:8])

		if length > MaxPackageSize {
			return errors.New("message exceeds protocol spec")
		}

		// Read message content
		contents := ""
		if length > 0 {
			n, err := al.conn.Read(dataBuf[:length])
			if err != nil || uint32(n) != length {
				return fmt.Errorf("error reading message: %w", err)
			}
			contents = string(dataBuf[:length])
		}

		// Process message
		message := Message{
			MsgType:  msgType,
			Contents: contents,
		}
		al.backend.HandleMessage(replier, message)

		// Process any internal messages
		select {
		case internalMsg := <-al.internalChan:
			al.backend.HandleMessage(replier, internalMsg)
		default:
			// No internal messages to process
		}
	}

	// Handle termination
	replier.Lock()
	al.backend.HandleMessage(replier, Message{
		MsgType:  MsgSystemTerminate,
		Contents: "",
	})

	return nil
}

// sendMessage sends a message through the connection
func sendMessage(conn *net.UnixConn, msgType uint32, data string) error {
	headerBuf := make([]byte, 8)
	binary.LittleEndian.PutUint32(headerBuf[0:4], msgType)
	binary.LittleEndian.PutUint32(headerBuf[4:8], uint32(len(data)))

	// Send header
	_, err := conn.Write(headerBuf)
	if err != nil {
		return err
	}

	// Send data if any
	if len(data) > 0 {
		_, err = conn.Write([]byte(data))
		if err != nil {
			return err
		}
	}

	return nil
}
