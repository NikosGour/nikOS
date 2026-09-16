package projectpath

import (
	"path"
	"path/filepath"
	"runtime"
)

var (
	_, b, _, _ = runtime.Caller(0)

	// Root folder of this project
	Root = filepath.Join(filepath.Dir(b), "../..")
)

func RootFile(filepath string) string {
	return path.Join(Root, filepath)
}

