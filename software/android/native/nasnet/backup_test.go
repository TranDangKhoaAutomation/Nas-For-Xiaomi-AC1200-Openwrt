package nasnet

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type diskBackupFS struct {
	root string
	fail bool
}

func (f *diskBackupFS) p(p string) string {
	return filepath.Join(f.root, strings.ReplaceAll(p, "\\", "/"))
}
func (f *diskBackupFS) Stat(p string) (os.FileInfo, error)     { return os.Stat(f.p(p)) }
func (f *diskBackupFS) MkdirAll(p string, m os.FileMode) error { return os.MkdirAll(f.p(p), m) }
func (f *diskBackupFS) OpenFile(p string, flags int, m os.FileMode) (backupFile, error) {
	file, e := os.OpenFile(f.p(p), flags, m)
	if e != nil {
		return nil, e
	}
	if f.fail {
		f.fail = false
		return &interruptedFile{File: file}, nil
	}
	return file, nil
}
func (f *diskBackupFS) Rename(a, b string) error {
	if _, e := os.Stat(f.p(b)); e == nil {
		return os.ErrExist
	}
	return os.Rename(f.p(a), f.p(b))
}

type interruptedFile struct {
	*os.File
	written bool
}

func (f *interruptedFile) Write(p []byte) (int, error) {
	if f.written {
		return 0, errors.New("simulated connection lost")
	}
	f.written = true
	n := len(p)
	if n > 65536 {
		n = 65536
	}
	return f.File.Write(p[:n])
}

func TestBackupResumesInterruptedFileWithoutDuplicatingBytes(t *testing.T) {
	data := bytes.Repeat([]byte("photo-video-fixture"), 200000)
	sourcePath := filepath.Join(t.TempDir(), "fixture.jpg")
	if e := os.WriteFile(sourcePath, data, 0600); e != nil {
		t.Fatal(e)
	}
	source, e := os.Open(sourcePath)
	if e != nil {
		t.Fatal(e)
	}
	defer source.Close()
	fs := &diskBackupFS{root: t.TempDir(), fail: true}
	b := &backupSession{fs: fs}
	target := "Photos/2026/10/image_version.jpg"
	if _, e = uploadBackupSource(b, source, target, int64(len(data))); e == nil {
		t.Fatal("expected interruption")
	}
	if _, e = os.Stat(fs.p(target)); !os.IsNotExist(e) {
		t.Fatal("incomplete file exposed as finished")
	}
	if _, e = uploadBackupSource(b, source, target, int64(len(data))); e != nil {
		t.Fatal(e)
	}
	actual, e := os.ReadFile(fs.p(target))
	if e != nil || !bytes.Equal(actual, data) {
		t.Fatal("resumed content differs", e)
	}
	if b.done.Load() != int64(len(data)) {
		t.Fatal("incorrect progress")
	}
	result, e := uploadBackupSource(b, source, target, int64(len(data)))
	if e != nil || !strings.Contains(result, "true") {
		t.Fatal("duplicate not skipped", e)
	}
	if e = os.WriteFile(fs.p(target), []byte("existing user data"), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e = uploadBackupSource(b, source, target, int64(len(data))); e == nil {
		t.Fatal("must refuse different existing file")
	}
	actual, _ = os.ReadFile(fs.p(target))
	if string(actual) != "existing user data" {
		t.Fatal("overwrote existing file")
	}
	actual, _ = os.ReadFile(sourcePath)
	if !bytes.Equal(actual, data) {
		t.Fatal("changed phone original")
	}
}

func TestBackupRejectsTraversalAndChangedSourceSize(t *testing.T) {
	source, e := os.CreateTemp(t.TempDir(), "source")
	if e != nil {
		t.Fatal(e)
	}
	defer source.Close()
	b := &backupSession{fs: &diskBackupFS{root: t.TempDir()}}
	for _, p := range []string{"../outside.jpg", "/absolute.jpg", ""} {
		if _, e := uploadBackupSource(b, source, p, 0); e == nil {
			t.Fatal("accepted path", p)
		}
	}
	if _, e := uploadBackupSource(b, source, "photo.jpg", 123); e == nil {
		t.Fatal("accepted stale source size")
	}
}
