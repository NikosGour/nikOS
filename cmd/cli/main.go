package main

import (
	log "github.com/NikosGour/logging/log"
	"github.com/NikosGour/nikOS/build"
)

func main() {
	log.Debug("DEBUG_MODE = %t\n", build.DEBUG_MODE)
}
