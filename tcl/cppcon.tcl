#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

# C++ console applet
#
# Copyright (C) 2011 by poddav <at> gmail <dot> com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this  software (the "Software"),  to deal in the Software  without
# restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#

package require Tk

if {[tk windowingsystem] == "win32"} {
    proc cc_cmd {src exe} { return "g++ -x c++ -std=c++0x -Wl,--enable-auto-import -o $exe $src" }
#    proc cc_cmd {src exe} { return "cl $src /nologo /TP /EHsc /GR /Fo$src.obj /Fe$exe" }
} else {
    proc cc_cmd {src exe} { return "g++ -x c++ -std=c++0x -o $exe $src" }
}

if {[catch {package require fileutil}]} {
    set message "C++ console requires tcllib to run."
    if {$tcl_platform(os) == "Linux"} {
	append message "\nUse 'sudo apt-get install tcllib' to intall it."
    }
    append message "\n\nApplication will now exit."
    tk_messageBox -icon error -parent . -title "Fatal error" -type ok \
	 -message $message
    exit 0
}

set have_ttk    [expr $tk_version >= 8.5]
set have_ctext  [expr ![catch {package require ctext}]]
set text_font   [expr {[font metrics Consolas -fixed] ? "Consolas" : "TkFixedFont"}]
set text_widget [expr {$have_ctext ? "ctext" : "text"}] 
set widget_lib  [expr {$have_ttk ? "ttk::" : ""}]

wm title . "C++ console"
wm minsize . 220 220

${widget_lib}frame .console -borderwidth 1
if {[tk windowingsystem] == "win32"} {
    $text_widget .console.text -yscrollcommand ".console.scroll set" -bd 2 -font $text_font
} else {
    $text_widget .console.text -yscrollcommand ".console.scroll set" -bd 2
}
${widget_lib}scrollbar .console.scroll -command ".console.text yview"
pack .console.scroll -side right -fill y
pack .console.text   -expand yes -fill both

${widget_lib}frame .output -borderwidth 1
if {[tk windowingsystem] == "win32"} {
    text .output.text -yscrollcommand ".output.scroll set" -bd 2 -height 6 -font $text_font
} else {
    text .output.text -yscrollcommand ".output.scroll set" -bd 2 -height 6
}
${widget_lib}scrollbar .output.scroll -command ".output.text yview"
pack .output.scroll -side right -fill y
pack .output.text   -expand yes -fill x

${widget_lib}frame .bottom
${widget_lib}button .bottom.compile -text "Compile" -command compile_button
${widget_lib}button .bottom.run -text "Run" -command execute
${widget_lib}label .bottom.text -text "Status OK" -relief sunken -font "TkDefaultFont 10"
pack .bottom.run -side right
pack .bottom.compile -side right
pack .bottom.text -expand yes -anchor w -fill x -padx 2

pack .bottom  -side bottom -fill x -anchor se
pack .output  -side bottom -fill both
pack .console -fill both -expand yes

.console.text tag configure highlight -background yellow
.output.text tag configure service -foreground #808080
.output.text tag configure output  -foreground black
.output.text tag configure failure -foreground red
.output.text insert end "Type C++ program text in the above window\nPress CTRL-Enter to compile & run\nPress ESC to exit\n" service
.output.text configure -state disabled

if {$have_ctext} {
    ::ctext::addHighlightClass .console.text cType blue \
	[list int char wchar_t bool long unsigned float double]
    ::ctext::addHighlightClass .console.text cStatement blue \
	[list for while return break continue catch throw typedef using namespace class struct enum]
    ::ctext::addHighlightClass .console.text cPreproc red [list #define #include]
    ::ctext::addHighlightClassForSpecialChars .console.text cPunct #000090 "()<>;./+-*&=?:"
    ::ctext::addHighlightClassForSpecialChars .console.text cNumber #00a020 "0123456789"
    ::ctext::addHighlightClassForRegexp .console.text cString  #00a000 {"[^"]*"}
    ::ctext::addHighlightClassForRegexp .console.text cComment gray {//.*$}
}

bind . <Escape> { exit 0 }
bind .console.text <Control-Return> { # execute
    execute
    break
}
bind .console.text <Control-a> { # select all
    %W tag add sel 1.0 end
    break
}

if {$have_ctext} {
    focus -force .console.text.t
} else {
    focus -force .console.text
}

proc execute {} {
    set exe_name [compile]
    if {[string length $exe_name]} {
	.bottom.text configure -text "Executing..."
	update
    	.output.text configure -state normal
	if {[catch { exec -keepnewline -- $exe_name 2>@1 } output]} {
	    set msg "child process exited abnormally"
    	    set output [string map [list $msg ""] $output]
	    if {[string length $output]} {
		.output.text insert end $output output
	    }
	    if {[lindex $::errorCode 0] eq "CHILDSTATUS"} {
		set errcode [lindex $::errorCode 2]
    		.output.text insert end "Program returned $errcode\n" failure
	    } else {
    		.output.text insert end "Program execution failed ($::errorCode)\n" failure
	    }
	} else {
	    if {[string length $output]} {
		.output.text insert end $output output
	    } else {
		.output.text insert end "Program compiled & run OK\n" service
	    }
	}
    	.output.text configure -state disabled
    	file delete $exe_name
	.bottom.text configure -text "Status OK"
    }
}

proc compile_button {} {
    set exe_name [compile]
    if {[string length $exe_name]} {
	file delete $exe_name
    }
}

proc compile {} {
    set text [.console.text get 1.0 end]
    set src_name [fileutil::tempfile]
    set src [open $src_name w]

    if {$::have_ttk} { ttk::setCursor . busy }
    .bottom.text configure -text "Compiling..."
    update

    if {![regexp {\mmain\M} $text]} {
	cpp_preformat $src $text
    } else {
    	puts $src $text
    }
    close $src
    set exe_name "${src_name}.exe"
    set base_name [file tail $src_name]
    set command [cc_cmd $src_name $exe_name]

    .output.text configure -state normal
    .output.text delete 1.0 end
    set msg "child process exited abnormally"
    set status [catch { eval exec -keepnewline -- $command 2>@1 } output];
    set output [string map [list $src_name <input> $base_name <input> $msg ""] $output]
    if {!$status} {
    	.bottom.text configure -text "Program compiled OK"
	if {[string length $output]} {
    	    .output.text insert end $output service
	}
    } else {
    	.bottom.text configure -text "Program compilation failed"
	.output.text insert end "Compilation failed\n" failure
	.output.text insert end $output service
	set exe_name ""
    }
    .output.text configure -state disabled
    file delete -- $src_name ${src_name}.obj ${src_name}.o
    if {$::have_ttk} { ttk::setCursor . standard }
    return $exe_name
}

proc cs_preformat {out text} {
    puts $out "using System;"
    puts $out "using System.IO;"
    puts $out "class TestApp"
    puts $out "\{"
    puts $out "    public void Main()"
    puts $out "    \{"
    puts $out "#line 1"
    puts $out $text
    puts $out "    \}"
    puts $out "\}"
}

proc cpp_preformat {out text} {
	puts $out "#include <exception>"
	puts $out "#include <iostream>"
	if {[string first vector $text] >= 0} { puts $out "#include <vector>" }
	if {[regexp "\mmap\M" $text]} { puts $out "#include <map>" }
	if {[regexp "\mw?string\M" $text]} { puts $out "#include <string>" }
	if {[string first printf "$text"] >= 0} { puts $out "#include <cstdio>" }
    	set program_text ""
	set line_count 0
	set first_line 1
	foreach line [split $text "\n"] {
	    incr line_count
	    if {[regexp "^#" $line]} {
		puts $out $line
	    } else {
		if {![string length $program_text]} {
		    set first_line $line_count
		}
		append program_text $line "\n"
	    }
	}
	puts $out "int main (int argc, char* argv\[\])"
	puts $out "try \{"
	puts $out "using namespace std;"
	puts $out "#line $first_line"
    	puts $out $program_text
	puts $out ";return 0;"
	puts $out "\} catch (std::exception& X) \{"
	puts $out "  std::cerr << \"Exception: \" << X.what() << std::endl;"
	puts $out "  return 1; \}"
}
