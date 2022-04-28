import std.stdio;
import std.file;
import std.json;
import std.conv: to;
import std.format;
import std.range;
import std.algorithm;
import std.path;
import std.uni;

string strNoValidPath = `D project at '%s' is not found.
Please init project (dub init) or supply valid path.`;

string strHelp = `Usage: dhelp [args] project-path
    -h, --help              displays this message
    -v, --vscode            init .vscode launch and tasks
`;

string launchJSON = `
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "code-d",
            "request": "launch",
            "name": "Debug D project",
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "build default",
            "program": "./bin/{APPNAME}",
            "args": []
        }
    ]
}
`;

string tasksJSON = `
{
	"version": "2.0.0",
	"tasks": [
        {
            "type": "dub",
            "run": false,
            "cwd": "${workspaceFolder}",
            "compiler": "$current",
            "archType": "$current",
            "buildType": "$current",
            "configuration": "$current",
            "problemMatcher": [
                "$dmd"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "label": "build default",
            "detail": "dub build --compiler=dmd -a=x86_64 -b=debug -c=application"
        }
    ]
}
`;

/*  Return values:
        0 - ok
        1 - Path errors
 
 */

int main(string[] args) {
    char sep = '/';

    version(Windows) {
        sep = '\\';
    }

    if (args.canFind("-h") || args.canFind("--help") || args.length == 1) {
        writeln(strHelp);
        return 0;
    }

    // checking filepath
    string projPath = args[to!int(args.length) - 1];

    if (projPath.startsWith('-') > 0) {
        writeln("Missing project path.");
        return 1;
    }

    projPath = projPath.expandTilde.buildNormalizedPath;

    if (!projPath.exists) {
        writeln("No such path.");
        return 1;
    }

    if (!projPath.isDir) {
        writeln("Path points to file. Please suppy project path.");
        return 1;
    }

    string dubPath = projPath ~ sep ~ "dub.json";

    string appName = "undefined";

    if (dubPath.exists) {
        string dubJSON = readText(dubPath);
        JSONValue jObj = parseJSON(dubJSON);
        jObj.object["targetPath"] = JSONValue("./bin/");
        appName = jObj["name"].str;
        dubJSON = jObj.toString;
        File dub = File(dubPath, "w");
        dub.write(dubJSON);
        dub.close();
    } else {
        writefln(strNoValidPath, projPath);
        return 1;
    }

    if (args.canFind("-v") || args.canFind("--vscode")) {
        string vsPath = projPath ~ sep ~ ".vscode";
        string launchPath = vsPath ~ sep ~ "launch.json";
        string tasksPath = vsPath ~ sep ~ "tasks.json";
        
        version(Posix) {
            launchJSON = launchJSON.replace("{APPNAME}", appName);
        }
        version(Windows) {
            launchJSON = launchJSON.replace("{APPNAME}", appName ~ ".exe");
        }

        if (!vsPath.exists) {
            vsPath.mkdir();
        }

        writeFile(launchPath, launchJSON);
        writeFile(tasksPath, tasksJSON);
    }


    return 0;
}

void writeFile(string filePath, string fileContent) {
    bool pathExists = filePath.exists && filePath.isFile;
    bool doOverride = false;
    if (pathExists) {
        bool canExit = false;
        writef("Do you wish to override existing %s? [y/n] ", filePath.baseName);
        do {
            string line = readln().toLower();
            if (line.startsWith('y')) {
                canExit = true;
                doOverride = true;
            } else
            if (line.startsWith('n')) {
                canExit = true;
            } else {
                write("[y/n] ");
            }
        } while(!canExit);
    }

    if ( (pathExists && doOverride) || !pathExists ) {
        File file = File(filePath, "w");
        file.write(fileContent);
        file.close();
    }
}