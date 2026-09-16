package main

import (
	"github.com/NikosGour/nikOS/build"
	log "github.com/NikosGour/logging/log"
)

func main(){
	log.Debug("DEBUG_MODE = %t\n",build.DEBUG_MODE)
}