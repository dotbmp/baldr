/*
 *  @Name:     baldr
 *  
 *  @Author:   Brendan Punsky
 *  @Email:    bpunsky@gmail.com
 *  @Creation: 03-12-2018 09:09:31 UTC-5
 *
 *  @Last By:   Brendan Punsky
 *  @Last Time: 04-12-2018 23:50:57 UTC-5
 *  
 *  @Description:
 *  
 */

package baldr

using import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

when os.OS == "windows" {
    import "core:sys/win32"
}

import "bp:path"
import "bp:process"
using import "bp:remove"

import "shared:odin-json"


Collection :: struct {
    name: string,
    path: string,
}

Build_Mode :: enum {
    EXE,
    DLL,
}

build_mode_string :: proc(mode: Build_Mode) -> string {
    switch mode {
    case Build_Mode.EXE: return "exe";
    case Build_Mode.DLL: return "dll";
    }

    return "";
}

Build_Settings :: struct {
    project_path: string,
    build_mode:   Build_Mode,
    out:          string,
    opt:          int,
    debug:        bool,
    keep_temp:    bool,
    bounds_check: bool,
    collections:  [dynamic]Collection,
}


usage :: proc() {
    println(`   __________        .__       .___          `);
    println(`   \______   \_____  |  |    __| _/______    `);
    println(`    |    |  _/\__  \ |  |   / __ |\_  __ \   `);
    println(`    |    |   \ / __ \|  |__/ /_/ | |  | \/   `);
    println(`    |______  /(____  /____/\____ | |__|      `);
    println(`           \/      \/           \/           `);
    println("         A project manager for Odin.         ");
    println();
    println("Usage:");
    println("  build:  build project with current settings");
    println("  run:    run project with current settings");
    println("  load:   load settings from file");
    println("  save:   save settings to file");
    println("  toggle: toggle boolean project settings");
    println("    * debug:        use debug symbols");
    println("    * keep_temp:    keep temporary files");
    println("    * bounds_check: perform bounds checking");
    println("  set:    set project settings");
    println("    * project_path: the root path of the project in relation to the project.json");
    println("    * out:          the name of the output file (sans extension) relative to the project.json");
    println("    * build_mode:   the type of file to build (currently \"dll\" or \"exe\")");
    println("    * debug:        use debug symbols");
    println("    * keep_temp:    keep temporary files");
    println("    * bounds_check: perform bounds checking");
    println("  add:    add an element to settings with arbitrary arguments");
    println("    * collection <name> <path>: add a collection");
    println("  remove: remove an element from settings with arbitrary arguments");
    println("    * collection <name>: remove a collection");
    println("  help:   show this screen");
}

init :: proc(using settings: ^Build_Settings) {
    lib_path := concat(path.current(), path.SEPARATOR_STRING, "lib");
    defer delete(lib_path);

    when os.OS == "windows" {
        cpath := strings.new_cstring(lib_path);
        defer delete(cpath);

        win32.create_directory_a(cpath, nil);
    }

    project_path = path.current();
    out          = path.name(project_path);
    build_mode   = Build_Mode.EXE;
    opt          = 0;
    debug        = false;
    keep_temp    = false;
    bounds_check = false;
    collections  = {
        {"lib", lib_path}
    };
}

concat :: proc(strs: ..string) -> string #no_bounds_check {
    inline assert(len(strs) != 0);

    length := 0;
    for str in strs {
        length += len(str);
    }
    
    buf := make([]byte, length);
    
    length = 0;
    for _, i in strs {
        str := strs[i];
        mem.copy(&buf[length], &str[0], len(str));
        length += len(str);
    }

    return string(buf);
}

main :: proc() {
    if len(os.args) > 1 {
        using settings: Build_Settings;

        if !json.unmarshal_file(settings, concat(path.current(), path.SEPARATOR_STRING, "package.json")) {
            project_path = path.current();
        }
 
        switch os.args[1] {
        case "init": init(&settings);
        case "build", "run":
            buf: String_Buffer;
            defer delete(buf);

            if project_path == "" {
                project_path = path.current();
            }

            sbprintf(&buf, `odin %s "%s"`, os.args[1], path.rel(project_path));
            sbprintf(&buf, ` -out="%s.%s"`, out, build_mode_string(build_mode));
            sbprintf(&buf, " -build-mode=%s", build_mode_string(build_mode));
            sbprintf(&buf, ` -opt=%d`, opt);
            if debug         do sbprint(&buf, " -debug");
            if keep_temp     do sbprint(&buf, " -keep_temp_files");
            if !bounds_check do sbprint(&buf, " -no-bounds-check");

            for collection in collections {
                sbprintf(&buf, ` -collection="%s"="%s"`, collection.name, path.rel(collection.path));
            }

            process.create(to_string(buf));

        case "load":
            if len(os.args) > 2 {
                json.unmarshal_file(settings, os.args[2]);
            }
        case "save":
            if len(os.args) > 2 {
                json.marshal_file(os.args[2], settings);
            }
        case "toggle":
            if len(os.args) == 3 {
                switch os.args[2] {
                case "debug":        debug        = !debug;
                case "keep_temp":    keep_temp    = !keep_temp;
                case "bounds_check": bounds_check = !bounds_check;
                }
            }

        case "set":
            if len(os.args) > 2 {
                switch os.args[2] {
                case "project_path":
                    if len(os.args) == 4 {
                        project_path = os.args[3];
                    }

                case "build_mode":
                    if len(os.args) == 4 {
                        switch os.args[3] {
                        case "exe": build_mode = Build_Mode.EXE;
                        case "dll": build_mode = Build_Mode.DLL;
                        case:
                            println_err("Invalid build mode.");
                            return;
                        }
                    }

                case "out":
                    if len(os.args) == 4 {
                        out = os.args[3];
                    }

                case "opt":
                    if len(os.args) == 4 {
                        switch os.args[3] {
                        case "0": opt = 0;
                        case "1": opt = 1;
                        case "2": opt = 2;
                        case "3": opt = 3;
                        case:
                            println_err("Invalid optimization level.");
                            return;
                        }
                    }

                case "debug":
                    if len(os.args) == 4 {
                        switch os.args[3] {
                        case "true":  debug = true;
                        case "false": debug = false;
                        case:
                            println_err("Invalid boolean argument.");
                            return;
                        }
                    }

                case "keep_temp":
                    if len(os.args) == 4 {
                        switch os.args[3] {
                        case "true":  keep_temp = true;
                        case "false": keep_temp = false;
                        case:
                            println_err("Invalid boolean argument.");
                            return;
                        }
                    }

                case "bounds_check":
                    if len(os.args) == 4 {
                        switch os.args[3] {
                        case "true":  bounds_check = true;
                        case "false": bounds_check = false;
                        case:
                            println_err("Invalid boolean argument.");
                            return;
                        }
                    }
                }
            }

        case "add":
            if len(os.args) > 2 {
                switch os.args[2] {
                case "collection":
                    if len(os.args) == 5 {
                        append(&collections, Collection{os.args[3], os.args[4]});
                    }
                }
            }

        case "remove":
            if len(os.args) > 2 {
                switch os.args[2] {
                case "collection":
                    if len(os.args) == 4 {
                        for collection, i in collections {
                            if collection.name == os.args[3] {
                                remove_unordered(&collections, i);
                                break;
                            }
                        }
                    }
                }
            }

        case "help":  fallthrough;
        case:         usage();
        }

        json.marshal_file(concat(path.current(), path.SEPARATOR_STRING, "package.json"), settings);

        return;
    }

    usage();
}
