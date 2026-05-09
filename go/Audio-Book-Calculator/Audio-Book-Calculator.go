/*
Copyright (C) 2026 zfbx

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
*/
package main

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/tcolgate/mp3"
	"golang.org/x/term"
)

var totals = make(map[string]float64)

func find(root, ext string) []string {
	var a []string
	filepath.WalkDir(root, func(s string, d fs.DirEntry, e error) error {
		if e != nil {
			return e
		}
		if filepath.Ext(d.Name()) == ext {
			a = append(a, s)
		}
		return nil
	})
	return a
}

func parsemp3(file string, name string) {
	t := 0.0
	r, err := os.Open(file)
	if err != nil {
		fmt.Println(err)
		return
	}

	d := mp3.NewDecoder(r)
	var f mp3.Frame
	skipped := 0

	for {
		if err := d.Decode(&f, &skipped); err != nil {
			if err == io.EOF {
				break
			}
			fmt.Println(err)
			return
		}
		t = t + f.Duration().Seconds()
	}
	totals[name] += t
	fmt.Println("File:", file, "Time:", t, "seconds.")
	r.Close()
}

func main() {
	fmt.Println("Audio Book Calculator - zfbx")

	for _, s := range find("./", ".mp3") {
		filename := strings.Split(s, "\\")
		isbn := strings.Split(filename[len(filename)-1], "_")
		parsemp3(s, isbn[0])
	}

	for key, element := range totals {
		s := fmt.Sprintf("ISBN: %s => Total Secs: %.3f | Total Mins: %.3f", key, element, element/60)
		fmt.Println(s)
	}

	// pause closing of window if not piped
	if term.IsTerminal(int(os.Stdout.Fd())) {
		var input string
		fmt.Scanln(&input)
	}

}
