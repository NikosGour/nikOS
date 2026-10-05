package kernel

import "terminal"

func Main() {
	terminal.Init()                      // Initialize terminal
	terminal.Color = terminal.MakeColor( // Set color to..
		terminal.White, // White text...
		terminal.Blue)  // on a blue background
	terminal.Clear() // Clear screen

	// Center the text a little
	terminal.Row = 11
	terminal.Column = 30

	// Print our Hello, World!
	terminal.Print("Hello, Kernel World!\n")
}
