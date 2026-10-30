//go:build tools

package tools

// Keep the binding generator's matching runtime dependency reproducible.
import _ "golang.org/x/mobile/bind"
