/*
 *  @Name:     baldr
 *  
 *  @Author:   Brendan Punsky
 *  @Email:    bpunsky@gmail.com
 *  @Creation: 03-12-2018 09:09:31 UTC-5
 *
 *  @Last By:   Brendan Punsky
 *  @Last Time: 04-12-2018 17:45:48 UTC-5
 *  
 *  @Description:
 *  
 */

package baldr

using import "core:fmt"
import "core:os"
import "core:strings"

when os.OS == "windows" {
    import "core:sys/win32"
}

import "bp:path"
import "bp:process"

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
    println(`__________        .__       .___       `);
    println(`\______   \_____  |  |    __| _/______ `);
    println(` |    |  _/\__  \ |  |   / __ |\_  __ \`);
    println(` |    |   \ / __ \|  |__/ /_/ | |  | \/`);
    println(` |______  /(____  /____/\____ | |__|   `);
    println(`        \/      \/           \/        `);
    println("      A project manager for Odin.      ");
    println();
    println("Usage:");
    println("  build: build project with current settings");
    println("  run:   run project with current settings");
    println("  load:  load settings from file");
    println("  save:  save settings to file");
    println("  set:   set project settings");
}

init :: proc(settings: ^Build_Settings) {
    lib_path := aprintf("%s/%s", path.current(), "lib");
    defer delete(lib_path);

    when os.OS == "windows" {
        win32.create_directory_a(strings.new_cstring(lib_path), nil);
    }

    curr := path.current();
    name := path.name(curr);

    println(curr, name);

    settings^ = Build_Settings {
        project_path = curr,
        out          = name,
        build_mode   = Build_Mode.EXE,
        opt          = 0,
        debug        = false,
        keep_temp    = false,
        bounds_check = false,
        collections  = {
            {"lib", lib_path}
        },
    };
}

main :: proc() {
    if len(os.args) > 1 {
        using settings: Build_Settings;

        if !json.unmarshal_file(settings, tprintf("%s/%s", path.current(), "package.json")) {
            project_path = path.current();
        }
        
        switch os.args[1] {
        case "init": init(&settings);
        case "build", "run":
            buf: String_Buffer;

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
        case "set":
        case "help":  fallthrough;
        case:         usage();
        }

        json.marshal_file(tprintf("%s/%s", path.current(), "package.json"), settings);

        return;
    }

    usage();
}
