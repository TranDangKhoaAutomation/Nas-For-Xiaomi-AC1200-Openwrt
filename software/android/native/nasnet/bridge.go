// Package nasnet embeds Tailscale and SMB inside the Android app process.
package nasnet

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/hirochachacha/go-smb2"
	"tailscale.com/envknob"
	"tailscale.com/tsnet"
)

var nodeMu sync.Mutex
var node *tsnet.Server
var nodeError string
var filesMu sync.Mutex
var session *smb2.Session
var share *smb2.Share
var socket net.Conn
var activeHost, activeShare, activeRoute string
var transferred atomic.Int64
var transferTotal atomic.Int64
var transferCancelMu sync.Mutex
var transferCancel context.CancelFunc

func encode(v any) string { b, _ := json.Marshal(v); return string(b) }

// Start starts the app's private Tailscale node. It never creates a VPN service.
func Start(directory string) (err error) {
	nodeMu.Lock()
	defer nodeMu.Unlock()
	defer func() {
		if failure := recover(); failure != nil {
			err = fmt.Errorf("Khởi tạo Tailscale: %v", failure)
			nodeError = err.Error()
		}
	}()
	if node != nil {
		return nil
	}
	if directory == "" {
		return errors.New("Thiếu thư mục trạng thái ứng dụng")
	}
	if err := os.MkdirAll(directory, 0700); err != nil {
		return err
	}
	// Android has neither a writable working directory nor a normal HOME/tmp.
	// Tailscale's secondary loggers also consult TS_LOGS_DIR independently of Dir.
	temporary := filepath.Join(directory, "tmp")
	if err := os.MkdirAll(temporary, 0700); err != nil {
		return err
	}
	envknob.SetNoLogsNoSupport()
	envknob.Setenv("TS_LOGS_DIR", directory)
	os.Setenv("TMPDIR", temporary)
	s := &tsnet.Server{Dir: directory, Hostname: "khoa-nas-android", Logf: func(string, ...any) {}, UserLogf: func(string, ...any) {}}
	if err := s.Start(); err != nil {
		nodeError = err.Error()
		return err
	}
	node = s
	nodeError = ""
	return nil
}

// State returns connection metadata. Auth URLs are requested separately.
func State() string {
	nodeMu.Lock()
	s, last := node, nodeError
	nodeMu.Unlock()
	if s == nil {
		return encode(map[string]any{"state": "Stopped", "error": last})
	}
	lc, err := s.LocalClient()
	if err != nil {
		return encode(map[string]any{"state": "Error", "error": err.Error()})
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	st, err := lc.StatusWithoutPeers(ctx)
	if err != nil {
		return encode(map[string]any{"state": "Error", "error": err.Error()})
	}
	ips := []string{}
	for _, ip := range st.TailscaleIPs {
		ips = append(ips, ip.String())
	}
	return encode(map[string]any{"state": st.BackendState, "ips": ips})
}

// LoginURL starts interactive authentication; callers must never log this URL.
func LoginURL() (string, error) {
	nodeMu.Lock()
	s := node
	nodeMu.Unlock()
	if s == nil {
		return "", errors.New("Hãy bật kết nối từ xa trước")
	}
	lc, err := s.LocalClient()
	if err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if st, e := lc.StatusWithoutPeers(ctx); e == nil && st.BackendState == "Running" {
		return "", nil
	}
	if err = lc.StartLoginInteractive(ctx); err != nil {
		return "", err
	}
	for range 30 {
		st, e := lc.StatusWithoutPeers(ctx)
		if e == nil && st.AuthURL != "" {
			return st.AuthURL, nil
		}
		if e == nil && st.BackendState == "Running" {
			return "", nil
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(250 * time.Millisecond):
		}
	}
	return "", errors.New("Chưa lấy được trang đăng nhập Tailscale")
}

func Logout() error {
	Disconnect()
	nodeMu.Lock()
	s := node
	node = nil
	nodeMu.Unlock()
	if s == nil {
		return nil
	}
	lc, err := s.LocalClient()
	if err == nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err = lc.Logout(ctx)
		cancel()
	}
	closeErr := s.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func validateHost(host string) (string, error) {
	ip, err := netip.ParseAddr(strings.TrimSpace(host))
	if err != nil || !ip.Is4() {
		return "", errors.New("Nhập địa chỉ IPv4 LAN hoặc Tailscale")
	}
	tail := netip.MustParsePrefix("100.64.0.0/10").Contains(ip)
	if !ip.IsPrivate() && !tail {
		return "", errors.New("Chỉ dùng địa chỉ LAN hoặc Tailscale")
	}
	return ip.String(), nil
}

func dial(ctx context.Context, host string, port string, remote bool) (net.Conn, error) {
	h, err := validateHost(host)
	if err != nil {
		return nil, err
	}
	target := net.JoinHostPort(h, port)
	if !remote {
		return (&net.Dialer{Timeout: 15 * time.Second}).DialContext(ctx, "tcp", target)
	}
	nodeMu.Lock()
	s := node
	nodeMu.Unlock()
	if s == nil {
		return nil, errors.New("Tailscale trong ứng dụng chưa được kết nối")
	}
	lc, err := s.LocalClient()
	if err != nil {
		return nil, err
	}
	state, err := lc.StatusWithoutPeers(ctx)
	if err != nil {
		return nil, err
	}
	if state.BackendState != "Running" {
		return nil, errors.New("Hãy đăng nhập Tailscale trong ứng dụng trước")
	}
	destination := netip.MustParseAddr(h)
	d := s.Sys().Dialer.Get()
	if d.UseNetstackForIP == nil || !d.UseNetstackForIP(destination) || d.NetstackDialTCP == nil {
		return nil, errors.New("Router chưa có đường kết nối trong mạng Tailscale này")
	}
	// tsnet.Dial can use the OS for destinations without a tailnet route. Call
	// its configured userspace TCP dialer directly so remote mode cannot leak
	// SMB or router credentials onto an unrelated system/LAN/VPN route.
	endpoint, err := netip.ParseAddrPort(target)
	if err != nil {
		return nil, err
	}
	return d.NetstackDialTCP(ctx, endpoint)
}

func disconnectLocked() {
	if socket != nil {
		socket.SetDeadline(time.Now().Add(3 * time.Second))
	}
	if share != nil {
		share.Umount()
		share = nil
	}
	if session != nil {
		session.Logoff()
		session = nil
	}
	if socket != nil {
		socket.Close()
		socket = nil
	}
	activeShare = ""
	activeHost = ""
	activeRoute = ""
}
func Disconnect() { CancelTransfer(); filesMu.Lock(); defer filesMu.Unlock(); disconnectLocked() }

// Connect authenticates SMB and discovers actual shares. Password is not saved here.
func Connect(host, user, password, domain string, remote bool) (string, error) {
	filesMu.Lock()
	defer filesMu.Unlock()
	disconnectLocked()
	if strings.TrimSpace(user) == "" {
		return "", errors.New("Nhập tài khoản SMB")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	conn, err := dial(ctx, host, "445", remote)
	if err != nil {
		return "", err
	}
	conn.SetDeadline(time.Now().Add(25 * time.Second))
	// Require verified signatures. Remote traffic also travels inside the app's
	// encrypted Tailscale transport. Negotiate the highest supported SMB dialect.
	d := &smb2.Dialer{Negotiator: smb2.Negotiator{RequireMessageSigning: true}, Initiator: &smb2.NTLMInitiator{User: strings.TrimSpace(user), Password: password, Domain: strings.TrimSpace(domain)}}
	ss, err := d.DialContext(ctx, conn)
	password = ""
	if err != nil {
		conn.Close()
		return "", errors.New("Không đăng nhập được SMB. Kiểm tra tài khoản và mật khẩu.")
	}
	conn.SetDeadline(time.Time{})
	names, err := ss.WithContext(ctx).ListSharenames()
	if err != nil {
		ss.WithContext(ctx).Logoff()
		conn.Close()
		return "", err
	}
	out := []string{}
	for _, n := range names {
		if !strings.HasSuffix(n, "$") {
			out = append(out, n)
		}
	}
	sort.Strings(out)
	session = ss
	socket = conn
	activeHost = strings.TrimSpace(host)
	activeRoute = "lan"
	if remote {
		activeRoute = "embedded"
	}
	return encode(map[string]any{"shares": out, "route": activeRoute}), nil
}

func Mount(name string) (string, error) {
	filesMu.Lock()
	defer filesMu.Unlock()
	if session == nil {
		return "", errors.New("Chưa kết nối SMB")
	}
	if name == "" || strings.ContainsAny(name, "\\/\x00") {
		return "", errors.New("Tên thư mục chia sẻ không hợp lệ")
	}
	if share != nil {
		share.Umount()
		share = nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	fs, err := session.WithContext(ctx).Mount(name)
	if err != nil {
		return "", err
	}
	share = fs.WithContext(context.Background())
	activeShare = name
	return listLocked("", ctx)
}

func cleanPath(p string, rootAllowed bool) (string, error) {
	p = strings.ReplaceAll(p, "\\", "/")
	if strings.ContainsRune(p, 0) || strings.HasPrefix(p, "/") {
		return "", errors.New("Đường dẫn không hợp lệ")
	}
	for _, part := range strings.Split(p, "/") {
		if part == ".." {
			return "", errors.New("Đường dẫn vượt ngoài thư mục chia sẻ")
		}
	}
	p = path.Clean(p)
	if p == "." {
		p = ""
	}
	if p == "" && !rootAllowed {
		return "", errors.New("Không thao tác trên gốc thư mục chia sẻ")
	}
	return strings.ReplaceAll(p, "/", "\\"), nil
}

func listLocked(p string, ctx context.Context) (string, error) {
	if share == nil {
		return "", errors.New("Chưa chọn thư mục chia sẻ")
	}
	p, err := cleanPath(p, true)
	if err != nil {
		return "", err
	}
	fs := share.WithContext(ctx)
	items, err := fs.ReadDir(p)
	if err != nil {
		return "", err
	}
	entries := []map[string]any{}
	for _, item := range items {
		if item.Name() == "." || item.Name() == ".." {
			continue
		}
		entries = append(entries, map[string]any{"name": item.Name(), "directory": item.IsDir(), "size": item.Size(), "modified": item.ModTime().Unix()})
	}
	sort.Slice(entries, func(i, j int) bool {
		a, b := entries[i], entries[j]
		if a["directory"] != b["directory"] {
			return a["directory"].(bool)
		}
		return strings.ToLower(a["name"].(string)) < strings.ToLower(b["name"].(string))
	})
	result := map[string]any{"entries": entries, "share": activeShare, "host": activeHost, "route": activeRoute}
	if space, e := fs.Statfs(""); e == nil {
		allocationSize := space.FragmentSize() * space.BlockSize()
		result["total"] = space.TotalBlockCount() * allocationSize
		result["available"] = space.AvailableBlockCount() * allocationSize
	}
	return encode(result), nil
}
func List(p string) (string, error) {
	filesMu.Lock()
	defer filesMu.Unlock()
	ctx, c := context.WithTimeout(context.Background(), 20*time.Second)
	defer c()
	return listLocked(p, ctx)
}

func Mkdir(p string) error {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return errors.New("Chưa kết nối NAS")
	}
	p, err := cleanPath(p, false)
	if err != nil {
		return err
	}
	ctx, c := context.WithTimeout(context.Background(), 20*time.Second)
	defer c()
	return share.WithContext(ctx).Mkdir(p, 0700)
}
func Rename(from, to string) error {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return errors.New("Chưa kết nối NAS")
	}
	a, err := cleanPath(from, false)
	if err != nil {
		return err
	}
	b, err := cleanPath(to, false)
	if err != nil {
		return err
	}
	ctx, c := context.WithTimeout(context.Background(), 20*time.Second)
	defer c()
	return share.WithContext(ctx).Rename(a, b)
}
func Remove(p string) error {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return errors.New("Chưa kết nối NAS")
	}
	p, err := cleanPath(p, false)
	if err != nil {
		return err
	}
	ctx, c := context.WithTimeout(context.Background(), 20*time.Second)
	defer c()
	return share.WithContext(ctx).Remove(p) // no recursive deletion
}

type counterWriter struct{ writer io.Writer }

func (w counterWriter) Write(p []byte) (int, error) {
	n, e := w.writer.Write(p)
	transferred.Add(int64(n))
	return n, e
}
func beginTransfer() (context.Context, context.CancelFunc) {
	transferred.Store(0)
	transferTotal.Store(0)
	ctx, cancel := context.WithCancel(context.Background())
	transferCancelMu.Lock()
	transferCancel = cancel
	transferCancelMu.Unlock()
	return ctx, func() { cancel(); transferCancelMu.Lock(); transferCancel = nil; transferCancelMu.Unlock() }
}
func TransferState() string {
	return encode(map[string]int64{"done": transferred.Load(), "total": transferTotal.Load()})
}
func CancelTransfer() {
	transferCancelMu.Lock()
	c := transferCancel
	transferCancelMu.Unlock()
	if c != nil {
		c()
	}
}

func Download(remotePath, destination string) error {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return errors.New("Chưa kết nối NAS")
	}
	p, err := cleanPath(remotePath, false)
	if err != nil {
		return err
	}
	ctx, cancel := beginTransfer()
	defer cancel()
	in, err := share.WithContext(ctx).Open(p)
	if err != nil {
		return err
	}
	defer in.Close()
	stat, err := in.Stat()
	if err != nil {
		return err
	}
	transferTotal.Store(stat.Size())
	out, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	// Bound reads to the file-size snapshot and hide File.WriteTo, which would
	// otherwise bypass our streaming buffer and request multi-megabyte reads.
	copied, copyErr := io.CopyBuffer(counterWriter{out}, io.LimitReader(in, stat.Size()), make([]byte, 128*1024))
	if copyErr == nil && copied != stat.Size() {
		copyErr = io.ErrUnexpectedEOF
	}
	closeErr := out.Close()
	if copyErr != nil {
		os.Remove(destination)
		return copyErr
	}
	return closeErr
}
func Upload(source, remotePath string) error {
	filesMu.Lock()
	defer filesMu.Unlock()
	if share == nil {
		return errors.New("Chưa kết nối NAS")
	}
	p, err := cleanPath(remotePath, false)
	if err != nil {
		return err
	}
	in, err := os.Open(source)
	if err != nil {
		return err
	}
	defer in.Close()
	ctx, cancel := beginTransfer()
	defer cancel()
	if stat, e := in.Stat(); e == nil {
		transferTotal.Store(stat.Size())
	}
	out, err := share.WithContext(ctx).OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	_, copyErr := io.CopyBuffer(counterWriter{out}, in, make([]byte, 128*1024))
	closeErr := out.Close()
	if copyErr != nil {
		return fmt.Errorf("Tải lên chưa hoàn tất, tệp có thể còn một phần: %w", copyErr)
	}
	return closeErr
}

// RouterRequest only calls the configured router's ubus endpoint, without redirects.
func RouterRequest(host, body string, remote bool) (string, error) {
	h, err := validateHost(host)
	if err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	transport := &http.Transport{DialContext: func(c context.Context, network, addr string) (net.Conn, error) { return dial(c, h, "80", remote) }}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error {
		return errors.New("Không theo chuyển hướng đăng nhập")
	}}
	request, err := http.NewRequestWithContext(ctx, "POST", "http://"+h+"/ubus", strings.NewReader(body))
	if err != nil {
		return "", err
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, 4*1024*1024))
	if err != nil {
		return "", err
	}
	if response.StatusCode != 200 {
		return "", fmt.Errorf("Router trả HTTP %d", response.StatusCode)
	}
	return string(data), nil
}
