package nasnet

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"path"
	"strings"
	"sync"
	"time"
)

var mediaMu sync.Mutex
var mediaServer *http.Server
var mediaAddress, mediaToken string
var mediaPaths = map[string]string{}
var mediaOrder []string
var mediaSlots = make(chan struct{}, 3)

func randomToken() (string, error) {
	var value [24]byte
	if _, err := rand.Read(value[:]); err != nil {
		return "", err
	}
	return hex.EncodeToString(value[:]), nil
}

// Called with filesMu held. It revokes every playback URL on share/session change.
func stopMediaLocked() {
	mediaMu.Lock()
	defer mediaMu.Unlock()
	if mediaServer != nil {
		mediaServer.Close()
	}
	mediaServer = nil
	mediaPaths = map[string]string{}
	mediaOrder = nil
	mediaAddress, mediaToken = "", ""
}

// MediaURL exposes only one authenticated SMB file to this phone's loopback.
// URLs are random capabilities, contain no credentials, and die on disconnect.
func MediaURL(remotePath string) (string, error) {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return "", errors.New("Chưa kết nối NAS")
	}
	p, err := cleanPath(remotePath, false)
	if err != nil {
		return "", err
	}
	mediaMu.Lock()
	defer mediaMu.Unlock()
	if mediaServer == nil {
		token, err := randomToken()
		if err != nil {
			return "", err
		}
		listener, err := net.Listen("tcp4", "127.0.0.1:0")
		if err != nil {
			return "", err
		}
		mediaToken, mediaAddress = token, listener.Addr().String()
		mediaServer = &http.Server{Handler: http.HandlerFunc(serveMedia), ReadHeaderTimeout: 5 * time.Second,
			IdleTimeout: 15 * time.Second, MaxHeaderBytes: 8192, ErrorLog: log.New(io.Discard, "", 0)}
		server := mediaServer
		go server.Serve(listener)
	}
	id, err := randomToken()
	if err != nil {
		return "", err
	}
	mediaPaths[id] = p
	mediaOrder = append(mediaOrder, id)
	if len(mediaOrder) > 256 {
		delete(mediaPaths, mediaOrder[0])
		mediaOrder = mediaOrder[1:]
	}
	return "http://" + mediaAddress + "/" + mediaToken + "/" + id, nil
}

func serveMedia(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.WriteHeader(405)
		return
	}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/"), "/")
	mediaMu.Lock()
	p, ok := "", false
	if len(parts) == 2 && mediaToken != "" && parts[0] == mediaToken {
		p, ok = mediaPaths[parts[1]]
	}
	mediaMu.Unlock()
	if !ok {
		w.WriteHeader(404)
		return
	}
	if r.Header.Get("X-KhoaNAS-Preview") == "1" {
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
		defer cancel()
		r = r.WithContext(ctx)
	}
	select {
	case mediaSlots <- struct{}{}:
		defer func() { <-mediaSlots }()
	case <-r.Context().Done():
		return
	}
	filesMu.Lock()
	// Recheck after waiting: a logout/mount must not expose the same path in a new share.
	mediaMu.Lock()
	stillCurrent := len(parts) == 2 && mediaToken != "" && parts[0] == mediaToken && mediaPaths[parts[1]] == p
	mediaMu.Unlock()
	if !stillCurrent || share == nil || r.Context().Err() != nil {
		filesMu.Unlock()
		w.WriteHeader(410)
		return
	}
	file, err := share.WithContext(r.Context()).Open(p)
	filesMu.Unlock()
	if err != nil {
		w.WriteHeader(404)
		return
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.IsDir() {
		w.WriteHeader(404)
		return
	}
	// ServeContent supplies HEAD, length and byte-range seeking. Buffering turns
	// tiny player reads into bounded 1 MiB SMB requests without reading past EOF.
	serveMediaContent(w, r, path.Base(p), info.ModTime(), file, info.Size())
}

func serveMediaContent(w http.ResponseWriter, r *http.Request, name string, modified time.Time, source io.ReaderAt, size int64) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	reader := newBufferedSeeker(source, size)
	if r.Header.Get("X-KhoaNAS-Preview") == "1" {
		reader.buffer = bufio.NewReaderSize(reader.section, 64*1024)
	}
	http.ServeContent(w, r, name, modified, reader)
}

type bufferedSeeker struct {
	section *io.SectionReader
	buffer  *bufio.Reader
}

func newBufferedSeeker(source io.ReaderAt, size int64) *bufferedSeeker {
	section := io.NewSectionReader(source, 0, size)
	return &bufferedSeeker{section, bufio.NewReaderSize(section, 1024*1024)}
}
func (b *bufferedSeeker) Read(p []byte) (int, error) { return b.buffer.Read(p) }
func (b *bufferedSeeker) Seek(offset int64, whence int) (int64, error) {
	if whence == io.SeekCurrent {
		offset -= int64(b.buffer.Buffered())
	}
	position, err := b.section.Seek(offset, whence)
	if err == nil {
		b.buffer.Reset(b.section)
	}
	return position, err
}
