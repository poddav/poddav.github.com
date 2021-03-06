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

set cppcon_version 1.2

if {$tcl_platform(platform) eq "windows"} {
    proc cc_cmd {src exe} { return "g++ -x c++ -std=c++11 -Wl,--enable-auto-import -o $exe $src" }
#    proc cc_cmd {src exe} { return "cl $src /nologo /TP /EHsc /GR /Fo$src.obj /Fe$exe" }
} else {
    proc cc_cmd {src exe} { return "g++ -x c++ -std=c++0x -o $exe $src" }
}
proc csc_cmd {src exe} { return [FindCSC $src $exe] }

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
set text_font   [expr {[font metrics Consolas -fixed] ? "Consolas 10" : "TkFixedFont"}]
set text_widget [expr {$have_ctext ? "ctext" : "text"}] 
set widget_lib  [expr {$have_ttk ? "ttk::" : ""}]

wm title . "C++ console v$cppcon_version"
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
${widget_lib}button .bottom.run -text "Run" -command execute_button
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
.output.text insert end "Type C++ program text in the above window\nPress CTRL-Enter to compile & run as C++ program\n" service
if {$tcl_platform(platform) eq "windows"} {
    .output.text insert end "Press Shift-Enter to run as C# program\n" service
}
.output.text insert end "Press ESC to exit\n" service
.output.text configure -state disabled

if {$have_ctext} {
    ::ctext::addHighlightClass .console.text cType blue \
	[list int char wchar_t bool long unsigned float double]
    ::ctext::addHighlightClass .console.text cStatement blue \
	[list for while return break continue catch throw typedef using namespace class struct enum public private protected]
    ::ctext::addHighlightClass .console.text cPreproc red [list #define #include]
    ::ctext::addHighlightClassForSpecialChars .console.text cPunct #000090 "()<>;./+-*&=?:"
    ::ctext::addHighlightClassForSpecialChars .console.text cNumber #00a020 "0123456789"
    ::ctext::addHighlightClassForRegexp .console.text cString  #00a000 {"[^"]*"}
    ::ctext::addHighlightClassForRegexp .console.text cComment gray {//.*$}
}

bind . <Escape> { exit 0 }
bind .console.text <Control-Return> { # execute
    execute_button
    break
}
bind .console.text <Shift-Return> {
    execute cs_preformat csc_cmd
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

proc compile_button {} {
    set exe_name [compile cpp_preformat cc_cmd]
    if {[string length $exe_name]} {
	file delete $exe_name
    }
}

proc execute_button {} {
    execute cpp_preformat cc_cmd
}

proc execute {preformat compiler} {
    set exe_name [compile $preformat $compiler]
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

proc compile {preformat compiler} {
    set text [.console.text get 1.0 end]
    set src_name [fileutil::tempfile]
    set exe_name "${src_name}.exe"
    set command [string map {\\ \\\\} [$compiler $src_name $exe_name]]

    if {![string length $command]} {
	return ""
    }

    set src [open $src_name w]

    if {$::have_ttk} { ttk::setCursor . busy }
    .bottom.text configure -text "Compiling..."
    update

    if {![regexp {\m[mM]ain\M} $text]} {
	$preformat $src $text
    } else {
    	puts $src $text
    }
    close $src

    set base_name [file tail $src_name]
    .output.text configure -state normal
    .output.text delete 1.0 end

    set msg "child process exited abnormally"
    set status [catch { eval exec -keepnewline -- $command 2>@1 } output]
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
    set program_text ""
    set line_count 0
    foreach line [split $text "\n"] {
	incr line_count
	if {[regexp "^using" $line]} {
	    puts $out $line
	} else {
	    if {![string length $program_text]} {
		append program_text "#line $line_count\n"
	    }
	    append program_text $line "\n"
	}
    }
    puts $out "class TestApp"
    puts $out "\{"
    puts $out "    public static void Main()"
    puts $out "    \{"
    puts $out $program_text
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
    foreach line [split $text "\n"] {
	incr line_count
	if {[regexp "^#" $line]} {
	    puts $out $line
	} else {
	    if {![string length $program_text]} {
		append program_text "#line $line_count\n"
	    }
	    append program_text $line "\n"
	}
    }
    puts $out "int main (int argc, char* argv\[\])"
    puts $out "try \{"
    puts $out "using namespace std;"
    puts $out $program_text
    puts $out ";return 0;"
    puts $out "\} catch (std::exception& X) \{"
    puts $out "  std::cerr << \"Exception: \" << X.what() << std::endl;"
    puts $out "  return 1; \}"
}

if {$tcl_platform(platform) eq "windows"} {
    package require registry

    proc get_vc7_key {key} {
	set path_list {
	    HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VC7
	    HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VC7
	    HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\VisualStudio\\SxS\\VC7
	    HKEY_CURRENT_USER\\SOFTWARE\\Wow6432Node\\Microsoft\\VisualStudio\\SxS\\VC7
	}
	foreach path $path_list {
	    if {![catch { set value [registry get $path $key] }]} {
		return $value
	    }
	}
	return ""
    }

    proc FindCSC {src exe} {
	if {[string first x86 [platform::identify]] != -1} {
	    set cpu 32
	} else {
	    set cpu 64
	}
	set fw_base [get_vc7_key FrameworkDir$cpu]
	set fw_ver  [get_vc7_key FrameworkVer$cpu]
	if {[string length $fw_base] == 0 || [string length $fw_ver] == 0} {
	    error "C# compiler not found"
	}
	set CSC_COMMAND [string map {\\ \\\\} "${fw_base}${fw_ver}\\csc"]
	eval "proc csc_cmd {src exe} { return \"" $CSC_COMMAND " /nologo /out:\[string map {/ \\\\} \"\$exe \$src\"]\" }"
	return [csc_cmd $src $exe]
    }
} else {
    proc FindCSC {src exe} {
	option add *Dialog.msg.font {Helvetica 12}
	tk_messageBox -message "C# compiler not available on this platform" -parent . -title Error -type ok -icon error
       	return "" 
    }
}
