package nasnet

import (
	"context"
	"net"
	"testing"
	"time"
)

func TestConnectionCancelInterruptsMutexWait(t *testing.T) {
	filesMu.Lock()
	op := beginConnectionOperation(time.Second)
	done := make(chan error, 1)
	go func() {
		err := lockConnection(op.ctx)
		if err == nil {
			filesMu.Unlock()
		}
		done <- err
	}()
	CancelConnection()
	select {
	case err := <-done:
		if err != context.Canceled {
			t.Fatal(err)
		}
	case <-time.After(300 * time.Millisecond):
		t.Fatal("cancel waits on files mutex")
	}
	filesMu.Unlock()
	op.finish()
}

func TestConnectionCancelClosesPendingSocket(t *testing.T) {
	a, b := net.Pipe()
	defer a.Close()
	defer b.Close()
	op := beginConnectionOperation(time.Second)
	defer op.finish()
	if err := op.bind(a); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { _, err := a.Read(make([]byte, 1)); done <- err }()
	CancelConnection()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("read did not fail")
		}
	case <-time.After(300 * time.Millisecond):
		t.Fatal("pending socket not canceled")
	}
}

func TestConnectionSuccessfulSocketSurvivesOperationAndOldFinish(t *testing.T) {
	old := beginConnectionOperation(time.Second)
	current := beginConnectionOperation(time.Second)
	old.finish()
	a, b := net.Pipe()
	defer a.Close()
	defer b.Close()
	if err := current.bind(a); err != nil {
		t.Fatal(err)
	}
	if err := current.preserve(); err != nil {
		t.Fatal(err)
	}
	current.finish()
	done := make(chan error, 1)
	go func() { _, err := b.Write([]byte{7}); done <- err }()
	a.SetReadDeadline(time.Now().Add(time.Second))
	data := make([]byte, 1)
	if _, err := a.Read(data); err != nil || data[0] != 7 {
		t.Fatal("successful connection was closed", err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}
