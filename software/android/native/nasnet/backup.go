package nasnet

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"net"
	"os"
	"path"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/hirochachacha/go-smb2"
)

// Background backup owns a separate authenticated session. It never replaces
// the foreground browser's share, media server or transfer cancellation state.
type backupSession struct {
	conn   net.Conn
	fs     backupFilesystem
	cancel context.CancelFunc
	done   atomic.Int64
	total  atomic.Int64
	mu     sync.Mutex
}

var backupMu sync.Mutex
var backups = map[string]*backupSession{}

func BackupStart(host, user, password, shareName string, remote bool) (string, error) {
	if strings.TrimSpace(user) == "" || shareName == "" || strings.ContainsAny(shareName, "/\\\x00") {
		return "", errors.New("Thiếu tài khoản hoặc thư mục chia sẻ sao lưu")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Minute)
	conn, err := dial(ctx, host, "445", remote)
	if err != nil {
		cancel()
		return "", err
	}
	conn.SetDeadline(time.Now().Add(25 * time.Second))
	d := &smb2.Dialer{Negotiator: smb2.Negotiator{RequireMessageSigning: true}, Initiator: &smb2.NTLMInitiator{User: strings.TrimSpace(user), Password: password}}
	ss, err := d.DialContext(ctx, conn)
	password = ""
	if err != nil {
		cancel()
		conn.Close()
		return "", errors.New("Không đăng nhập được SMB để sao lưu")
	}
	fs, err := ss.WithContext(ctx).Mount(shareName)
	if err != nil {
		cancel()
		conn.Close()
		return "", err
	}
	conn.SetDeadline(time.Now().Add(8 * time.Minute))
	b := &backupSession{conn: conn, fs: smbBackupFilesystem{fs.WithContext(ctx)}, cancel: cancel}
	// IDs identify in-process sessions only, and contain no credentials.
	id, err := randomToken()
	if err != nil {
		cancel()
		conn.Close()
		return "", err
	}
	backupMu.Lock()
	backups[id] = b
	backupMu.Unlock()
	go func() { <-ctx.Done(); conn.Close() }()
	return id, nil
}

func BackupStop(id string) {
	backupMu.Lock()
	b := backups[id]
	delete(backups, id)
	backupMu.Unlock()
	if b != nil {
		b.cancel()
		b.conn.Close()
	}
}

func BackupProgress(id string) string {
	backupMu.Lock()
	b := backups[id]
	backupMu.Unlock()
	if b == nil {
		return "{}"
	}
	return encode(map[string]any{"done": b.done.Load(), "total": b.total.Load()})
}

// BackupUploadFD consumes ownership of a duplicated Android read-only FD.
// Hidden partial files survive interruption; a completed file is never replaced.
func BackupUploadFD(id string, fd int64, target string, size int64) (string, error) {
	source := os.NewFile(uintptr(fd), "backup-source")
	if source == nil {
		return "", errors.New("Không mở được ảnh/video nguồn")
	}
	defer source.Close()
	backupMu.Lock()
	b := backups[id]
	backupMu.Unlock()
	if b == nil {
		return "", errors.New("Phiên sao lưu đã dừng")
	}
	return uploadBackupSource(b, source, target, size)
}

func uploadBackupSource(b *backupSession, source *os.File, target string, size int64) (string, error) {
	target, err := cleanPath(target, false)
	if err != nil || size < 0 {
		return "", errors.New("Đích sao lưu không hợp lệ")
	}
	before, err := source.Stat()
	if err != nil {
		return "", err
	}
	if before.Size() != size {
		return "", errors.New("Ảnh nguồn đã thay đổi kích thước")
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.done.Store(0)
	b.total.Store(size)
	if info, e := b.fs.Stat(target); e == nil {
		if !info.IsDir() && info.Size() == size {
			b.done.Store(size)
			return encode(map[string]any{"skipped": true}), nil
		}
		return "", errors.New("Tệp đích đã tồn tại với kích thước khác; không ghi đè")
	} else if !os.IsNotExist(e) {
		return "", e
	}
	normalized := strings.ReplaceAll(target, "\\", "/")
	directory := path.Dir(normalized)
	if directory != "." {
		if e := b.fs.MkdirAll(strings.ReplaceAll(directory, "/", "\\"), 0700); e != nil {
			return "", e
		}
	}
	hash := sha256.Sum256([]byte(target))
	partial := strings.ReplaceAll(path.Join(directory, ".khoanas-"+hex.EncodeToString(hash[:16])+".part"), "/", "\\")
	destination, err := b.fs.OpenFile(partial, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return "", err
	}
	closed := false
	defer func() {
		if !closed {
			destination.Close()
		}
	}()
	info, err := destination.Stat()
	if err != nil {
		return "", err
	}
	offset := info.Size()
	if offset > size {
		return "", errors.New("Tệp tạm lớn hơn nguồn; cần kiểm tra thư mục sao lưu")
	}
	if _, err = source.Seek(offset, io.SeekStart); err != nil {
		return "", errors.New("Thư mục nguồn không hỗ trợ đọc tiếp; hãy chọn bộ nhớ thiết bị")
	}
	if _, err = destination.Seek(offset, io.SeekStart); err != nil {
		return "", err
	}
	b.done.Store(offset)
	count, err := io.CopyBuffer(backupWriter{destination}, &backupReader{reader: io.LimitReader(source, size-offset), done: &b.done}, make([]byte, 1024*1024))
	if err != nil {
		return "", err
	}
	if count != size-offset {
		return "", io.ErrUnexpectedEOF
	}
	after, e := source.Stat()
	if e != nil {
		return "", e
	}
	if after.Size() != before.Size() || !after.ModTime().Equal(before.ModTime()) {
		return "", errors.New("Ảnh nguồn đang được sửa; thử lại với phiên bản mới")
	}
	if err = destination.Sync(); err != nil {
		return "", err
	}
	err = destination.Close()
	closed = true
	if err != nil {
		return "", err
	}
	// go-smb2 Rename uses ReplaceIfExists=0, including the check/rename race.
	if err = b.fs.Rename(partial, target); err != nil {
		return "", err
	}
	return encode(map[string]any{"skipped": false}), nil
}

type backupReader struct {
	reader io.Reader
	done   *atomic.Int64
}

type backupWriter struct{ io.Writer }

func (r *backupReader) Read(p []byte) (int, error) {
	n, e := r.reader.Read(p)
	r.done.Add(int64(n))
	return n, e
}

// Small filesystem boundary lets offline tests exercise interruption/resume
// against real files without replacing SMB authentication or transport tests.
type backupFile interface {
	io.Writer
	io.Seeker
	Stat() (os.FileInfo, error)
	Sync() error
	Close() error
}
type backupFilesystem interface {
	Stat(string) (os.FileInfo, error)
	MkdirAll(string, os.FileMode) error
	OpenFile(string, int, os.FileMode) (backupFile, error)
	Rename(string, string) error
}
type smbBackupFilesystem struct{ *smb2.Share }

func (s smbBackupFilesystem) OpenFile(p string, f int, m os.FileMode) (backupFile, error) {
	return s.Share.OpenFile(p, f, m)
}
