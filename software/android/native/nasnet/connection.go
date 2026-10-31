package nasnet

import (
	"context"
	"errors"
	"net"
	"sync"
	"time"
)

// Cancellation never waits for filesMu: it must also interrupt a stuck dial,
// SMB negotiation or a mount currently holding that mutex.
type connectionOperation struct {
	ctx    context.Context
	cancel context.CancelFunc
	mu     sync.Mutex
	conn   net.Conn
}

var connectionOpMu sync.Mutex
var currentConnectionOp *connectionOperation

func beginConnectionOperation(timeout time.Duration) *connectionOperation {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	op := &connectionOperation{ctx: ctx, cancel: cancel}
	connectionOpMu.Lock()
	previous := currentConnectionOp
	currentConnectionOp = op
	connectionOpMu.Unlock()
	if previous != nil {
		previous.cancel()
	}
	context.AfterFunc(ctx, func() {
		op.mu.Lock()
		defer op.mu.Unlock()
		if op.conn != nil {
			op.conn.Close()
		}
	})
	return op
}

func (op *connectionOperation) bind(conn net.Conn) error {
	op.mu.Lock()
	defer op.mu.Unlock()
	if err := op.ctx.Err(); err != nil {
		conn.Close()
		return err
	}
	op.conn = conn
	deadline, _ := op.ctx.Deadline()
	return conn.SetDeadline(deadline)
}

func (op *connectionOperation) preserve() error {
	op.mu.Lock()
	defer op.mu.Unlock()
	if err := op.ctx.Err(); err != nil {
		return err
	}
	if op.conn != nil {
		op.conn.SetDeadline(time.Time{})
	}
	op.conn = nil
	return nil
}

func (op *connectionOperation) finish() {
	connectionOpMu.Lock()
	if currentConnectionOp == op {
		currentConnectionOp = nil
	}
	connectionOpMu.Unlock()
	op.cancel()
}

func CancelConnection() {
	connectionOpMu.Lock()
	op := currentConnectionOp
	connectionOpMu.Unlock()
	if op != nil {
		op.cancel()
	}
}

func lockConnection(ctx context.Context) error {
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		if filesMu.TryLock() {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(20 * time.Millisecond):
		}
	}
}

func connectionError(ctx context.Context, err error) error {
	var network net.Error
	if errors.Is(ctx.Err(), context.DeadlineExceeded) || errors.As(err, &network) && network.Timeout() {
		return errors.New("NAS không phản hồi. Kiểm tra router, kết nối Tailscale và dịch vụ SMB; chưa thể xác định lỗi mật khẩu")
	}
	if errors.Is(ctx.Err(), context.Canceled) {
		return errors.New("Đã hủy kết nối NAS")
	}
	return err
}
