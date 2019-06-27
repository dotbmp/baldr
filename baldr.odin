/*
 *  @Name:     baldr
 *  
 *  @Author:   Brendan Punsky
 *  @Email:    bpunsky@gmail.com
 *  @Creation: 03-12-2018 09:09:31 UTC-5
 *
 *  @Last By:   Brendan Punsky
 *  @Last Time: 26-06-2019 22:27:29 UTC-5
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

import "shared:path"
import "bp:process"

import json "shared:odin-json"


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
    project_path:   string,
    build_mode:     Build_Mode,
    out:            string,
    opt:            int,
    debug:          bool,
    keep_temp:      bool,
    bounds_check:   bool,
    vetting:        bool,
    lib_collection: Collection,
    collections:    [dynamic]Collection,
    dependencies:   [dynamic]string,
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
    println("  init:   initialize project descriptor");
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
    println("    * vet:          perform source vetting");
    println("  add:    add an element to settings with arbitrary arguments");
    println("    * collection <name> <path>: add a collection");
    println("  remove: remove an element from settings with arbitrary arguments");
    println("    * collection <name>: remove a collection");
    println("  update: update project dependencies");
    println("  help:   show this screen");
}

init :: proc(using settings: ^Build_Settings) {
    lib_path := strings.concatenate({path.current(), path.SEPARATOR_STRING, "lib"}, context.temp_allocator);

    when os.OS == "windows" {
        cpath := strings.clone_to_cstring(lib_path, context.temp_allocator);

        win32.create_directory_a(cpath, nil);
    }

    project_path   = path.current();
    out            = path.name(project_path);
    build_mode     = Build_Mode.EXE;
    opt            = 0;
    debug          = false;
    keep_temp      = false;
    bounds_check   = false;
    vetting        = false;
    lib_collection = {"lib", lib_path};
    collections    = {};
    dependencies   = {};
}

update_dependency :: proc(using settings: ^Build_Settings, dependency: string) {
    name := path.name(dependency);

    dir := strings.concatenate({lib_collection.path, path.SEPARATOR_STRING, name}, context.temp_allocator);
    defer delete(dir);

    if path.is_dir(dir) {
        current := path.current();
        defer delete(current);

        when os.OS == "windows" {
            win32.set_current_directory_a(strings.clone_to_cstring(dir, context.temp_allocator));
        }

        process.create("git stash");
        process.create("git pull");

        when os.OS == "windows" {
            win32.set_current_directory_a(strings.clone_to_cstring(current, context.temp_allocator));
        }
    }
    else {
        current := path.current();
        defer delete(current);

        when os.OS == "windows" {
            win32.set_current_directory_a(strings.clone_to_cstring(lib_collection.path, context.temp_allocator));
        }

        process.create("git clone %s", dependency);

        when os.OS == "windows" {
            win32.set_current_directory_a(strings.clone_to_cstring(current, context.temp_allocator));
        }
    }
}

remove_dependency :: proc(using settings: ^Build_Settings, dependency: string) {
    // @todo(bp): remove dependency directory, recursively deleting files
}

main :: proc() {
    if len(os.args) < 2 {
        usage();
        return;
    }

    using settings: Build_Settings;
    
    switch os.args[1] {
    case "init":
        if path.exists(strings.concatenate({path.current(), path.SEPARATOR_STRING, "package.json"}, context.temp_allocator)) {
            println_err("package.json already exists");
            return;
        } else {
            init(&settings);
            println("Package initialized.");
        }
    case:
        if !json.unmarshal_file(settings, strings.concatenate({path.current(), path.SEPARATOR_STRING, "package.json"}, context.temp_allocator)) {            
            println_err("package.json failed to load.");
            return;
        }
    }

    switch os.args[1] {
    case "init":
    
    case "build", "run":
        buf: strings.Builder;
        defer strings.destroy_builder(&buf);

        if project_path == "" {
            project_path = strings.concatenate({".", path.SEPARATOR_STRING}, context.temp_allocator);
        }

        sbprintf(&buf, `odin build "%s"`, path.rel(project_path));
        sbprintf(&buf, ` -out="%s.%s"`, out, build_mode_string(build_mode));
        if os.args[1] == "build" {
            sbprintf(&buf, ` -build-mode=%s`, build_mode_string(build_mode));
        }
        sbprintf(&buf, ` -opt=%d`, opt);
        if debug         do sbprint(&buf, " -debug");
        if keep_temp     do sbprint(&buf, " -keep-temp-files");
        if !bounds_check do sbprint(&buf, " -no-bounds-check");
        if vetting       do sbprint(&buf, " -vet");

        sbprintf(&buf, ` -collection="%s"="%s"`, lib_collection.name, path.rel(lib_collection.path));

        for collection in collections {
            sbprintf(&buf, ` -collection="%s"="%s"`, collection.name, path.rel(collection.path));
        }

        process.create(strings.to_string(buf));

        switch os.args[1] {
        case "run":
            // @todo(bp): non-exe
            process.create("%s.%s", out, build_mode_string(build_mode));
        }

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
            case: println_err("Invalid argument");
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
                    case "on":    debug = true;
                    case "off":   debug = false;
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
                    case "on":    keep_temp = true;
                    case "off":   keep_temp = false;
                    case:
                        println_err("Invalid boolean argument.");
                        return;
                    }
                }

            case "bounds_check":
                if len(os.args) == 4 {
                    switch os.args[3] {
                    case "true", "on":   bounds_check = true;
                    case "false", "off": bounds_check = false;
                    case:
                        println_err("Invalid boolean argument.");
                        return;
                    }
                }

            case "vet":
                if len(os.args) == 4 {
                    switch os.args[3] {
                    case "true", "on":   vetting = true;
                    case "false", "off": vetting = false;
                    case:
                        println_err("Invalid boolean argument.");
                    }
                }

            case "lib_collection":
                if len(os.args) == 5 {
                    lib_collection.name = os.args[3];
                    lib_collection.path = os.args[4];
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

            case "dependency":
                if len(os.args) == 4 {
                    append(&dependencies, os.args[3]);
                    update_dependency(&settings, os.args[3]);
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
                            unordered_remove(&collections, i);
                            break;
                        }
                    }
                }

            case "dependency":
                if len(os.args) == 4 {
                    for dependency, i in dependencies {
                        if dependency == os.args[3] {
                            unordered_remove(&collections, i);
                            remove_dependency(&settings, dependency);
                            break;
                        }
                    }
                }
            }
        }

    case "update":
        for dependency in dependencies {
            update_dependency(&settings, dependency);
        }

    case "help":  fallthrough;
    case:         usage(); return;
    }

    if !json.marshal_file(strings.concatenate({path.current(), path.SEPARATOR_STRING, "package.json"}, context.temp_allocator), settings) {
        fmt.println_err("package.json failed to write.");
        return;
    }
}
