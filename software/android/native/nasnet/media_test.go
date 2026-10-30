package nasnet

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestMediaRangesAndSeeking(t *testing.T) {
	data := bytes.Repeat([]byte("0123456789"), 300000)
	for _, c := range []struct {
		method, rng string
		status      int
		want        []byte
	}{
		{"GET", "bytes=100-199", 206, data[100:200]},
		{"GET", "bytes=-20", 206, data[len(data)-20:]},
		{"HEAD", "", 200, nil},
		{"GET", "bytes=9000000-", 416, nil},
	} {
		r := httptest.NewRequest(c.method, "http://127.0.0.1/test", nil)
		if c.rng != "" {
			r.Header.Set("Range", c.rng)
		}
		w := httptest.NewRecorder()
		serveMediaContent(w, r, "clip.mp4", time.Unix(1, 0), bytes.NewReader(data), int64(len(data)))
		if w.Code != c.status {
			t.Fatalf("range %s returned %d", c.rng, w.Code)
		}
		if c.status != 416 && !bytes.Equal(w.Body.Bytes(), c.want) {
			t.Fatal("range returned wrong bytes")
		}
	}
	r := newBufferedSeeker(bytes.NewReader(data), int64(len(data)))
	first := make([]byte, 17)
	io.ReadFull(r, first)
	if pos, err := r.Seek(8, io.SeekCurrent); err != nil || pos != 25 {
		t.Fatal("buffered current offset incorrect")
	}
	got := make([]byte, 12)
	io.ReadFull(r, got)
	if !bytes.Equal(got, data[25:37]) {
		t.Fatal("seek returned wrong bytes")
	}
}

func TestMediaURLsRequireSessionAndAreRevoked(t *testing.T) {
	if _, err := MediaURL("file.mp4"); err == nil {
		t.Fatal("unauthenticated media URL created")
	}
	mediaMu.Lock()
	mediaToken = "test-token"
	mediaPaths = map[string]string{"id": "private.mp4"}
	mediaMu.Unlock()
	defer func() { filesMu.Lock(); stopMediaLocked(); filesMu.Unlock() }()
	for _, requestPath := range []string{"/wrong/id", "/test-token/unknown", "/test-token/../../etc/passwd"} {
		w := httptest.NewRecorder()
		serveMedia(w, httptest.NewRequest(http.MethodGet, "http://127.0.0.1"+requestPath, nil))
		if w.Code != 404 {
			t.Fatal("unauthorized media request was accepted")
		}
	}
	filesMu.Lock()
	stopMediaLocked()
	filesMu.Unlock()
	w := httptest.NewRecorder()
	serveMedia(w, httptest.NewRequest(http.MethodGet, "http://127.0.0.1/test-token/id", nil))
	if w.Code != 404 {
		t.Fatal("old capability still worked")
	}
}
