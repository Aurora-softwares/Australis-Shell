public class Program {
    private static int ArgumentOffset(byte[] arguments, int ordinal) {
        int cursor = 1; int index = 0;
        while (index < ordinal && cursor < arguments.Length) {
            while (cursor < arguments.Length && arguments[cursor] != 0) {
                cursor = cursor + 1;
            }
            cursor = cursor + 1; index = index + 1;
        }
        return cursor;
    }

    private static int ArgumentLength(byte[] arguments, int offset) {
        int length = 0;
        while (offset + length < arguments.Length && arguments[offset + length] != 0) {
            length = length + 1;
        }
        return length;
    }

    private static bool ValidVariableName(byte[] source, int offset, int length) {
        if (length < 1 || length > 31) { return false; }
        int i = 0;
        while (i < length) {
            int c = source[offset + i];
            bool letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
            bool digit = c >= 48 && c <= 57;
            if (!letter && c != 95 && (i == 0 || !digit)) { return false; }
            i = i + 1;
        }
        return true;
    }

    private static int VariableSlot(byte[] table, byte[] name, int offset, int length) {
        int slot = 0;
        while (slot < 12) {
            int slotOffset = slot * 128;
            if (table[slotOffset] == length) {
                int i = 0;
                while (i < length && table[slotOffset + 3 + i] == name[offset + i]) {
                    i = i + 1;
                }
                if (i == length) { return slot; }
            }
            slot = slot + 1;
        }
        return -1;
    }

    private static bool SetVariable(byte[] table, byte[] source, int nameOffset,
        int nameLength, int valueOffset, int valueLength) {
        if (!ValidVariableName(source, nameOffset, nameLength) ||
            valueLength > 92) { return false; }
        int slot = VariableSlot(table, source, nameOffset, nameLength);
        if (slot < 0) {
            slot = 0;
            while (slot < 12 && table[slot * 128] != 0) { slot = slot + 1; }
            if (slot == 12) { return false; }
            table[slot * 128 + 2] = 0;
        }
        int slotOffset = slot * 128;
        table[slotOffset] = (byte)nameLength;
        table[slotOffset + 1] = (byte)valueLength;
        int i = 0;
        while (i < nameLength) {
            table[slotOffset + 3 + i] = source[nameOffset + i]; i = i + 1;
        }
        i = 0;
        while (i < valueLength) {
            table[slotOffset + 35 + i] = source[valueOffset + i]; i = i + 1;
        }
        return true;
    }

    private static bool ChildContext(byte[] table, byte[] path, int pathLength,
        byte[] cwd, int cwdLength, byte[] context) {
        int count = 0; int length = 2 + cwdLength;
        if (pathLength > 0) { count = 1; length = length + 5 + pathLength + 1; }
        int slot = 0;
        while (slot < 12) {
            int slotOffset = slot * 128;
            if (table[slotOffset] > 0 && table[slotOffset + 2] == 1) {
                count = count + 1;
                length = length + table[slotOffset] + 1 + table[slotOffset + 1] + 1;
            }
            slot = slot + 1;
        }
        if (count > 16 || length > 1400 || length > context.Length) { return false; }
        context[0] = (byte)count; context[1] = (byte)cwdLength;
        int cursor = 2; int i = 0;
        while (i < cwdLength) { context[cursor] = cwd[i]; cursor = cursor + 1; i = i + 1; }
        if (pathLength > 0) {
            context[cursor] = 80; context[cursor + 1] = 65;
            context[cursor + 2] = 84; context[cursor + 3] = 72;
            context[cursor + 4] = 61; cursor = cursor + 5;
            i = 0;
            while (i < pathLength) {
                context[cursor] = path[i]; cursor = cursor + 1; i = i + 1;
            }
            context[cursor] = 0; cursor = cursor + 1;
        }
        slot = 0;
        while (slot < 12) {
            int base2 = slot * 128;
            if (table[base2] > 0 && table[base2 + 2] == 1) {
                i = 0;
                while (i < table[base2]) {
                    context[cursor] = table[base2 + 3 + i];
                    cursor = cursor + 1; i = i + 1;
                }
                context[cursor] = 61; cursor = cursor + 1;
                i = 0;
                while (i < table[base2 + 1]) {
                    context[cursor] = table[base2 + 35 + i];
                    cursor = cursor + 1; i = i + 1;
                }
                context[cursor] = 0; cursor = cursor + 1;
            }
            slot = slot + 1;
        }
        return true;
    }

    private static bool PathCommand(string name) {
        return name == "cd" || name == "cat" || name == "ls" ||
            name == "tree" || name == "mkdir" || name == "touch" ||
            name == "cp" || name == "mv" || name == "rm" ||
            name == "edit" || name == "hexedit";
    }

    // Append an absolute, canonical path and its NUL terminator.
    private static int Path(byte[] raw, int length, byte[] cwd, int cwdLength,
        byte[] output, int start) {
        int end = start;
        if (length > 0 && raw[0] == 47) {
            if (end >= output.Length) { return -1; }
            output[end] = 47; end = end + 1;
        } else {
            int n = 0;
            while (n < cwdLength) {
                if (end >= output.Length) { return -1; }
                output[end] = cwd[n]; end = end + 1; n = n + 1;
            }
        }
        int i = 0;
        while (i < length) {
            while (i < length && raw[i] == 47) { i = i + 1; }
            int first = i;
            while (i < length && raw[i] != 47) { i = i + 1; }
            int size = i - first;
            if (size == 0 || (size == 1 && raw[first] == 46)) {
                // Skip empty and dot components.
            } else if (size == 2 && raw[first] == 46 && raw[first + 1] == 46) {
                if (end > start + 1) {
                    end = end - 1;
                    while (end > start + 1 && output[end - 1] != 47) { end = end - 1; }
                    if (end > start + 1) { end = end - 1; }
                }
            } else {
                if (end > start + 1) {
                    if (end >= output.Length) { return -1; }
                    output[end] = 47; end = end + 1;
                }
                int n2 = 0;
                while (n2 < size) {
                    if (end >= output.Length) { return -1; }
                    output[end] = raw[first + n2]; end = end + 1; n2 = n2 + 1;
                }
            }
        }
        if (end - start > 255 || end >= output.Length) { return -1; }
        output[end] = 0; return end + 1;
    }

    private static bool ValidSearchPath(byte[] value, int offset, int length,
        byte[] segment) {
        if (length < 1 || length > 255) { return false; }
        int start = 0;
        while (start < length) {
            int end = start;
            while (end < length && value[offset + end] != 58) { end = end + 1; }
            if (end == start || value[offset + start] != 47) { return false; }
            int n = 0;
            while (start + n < end) {
                segment[n] = value[offset + start + n]; n = n + 1;
            }
            string directory = System.Australis.Text.FromBytes(segment, n);
            if (System.Australis.Files.StatKind(directory) != 2) { return false; }
            start = end + 1;
            if (end < length && start == length) { return false; }
        }
        return true;
    }

    private static void Help() {
        System.Console.WriteLine("Built-ins: help cd pwd path set export unset history exit");
        System.Console.WriteLine("path [absolute:directories] shows or changes this shell's PATH.");
        System.Console.WriteLine("Use /data for writes; run /path/program.exec [args] runs an explicit executable.");
        System.Console.WriteLine("Installed programs in /System/Bin:");
        int count = System.Australis.Files.DirectoryCount("/System/Bin");
        if (count < 0) {
            System.Console.WriteLine("  program list unavailable");
            return;
        }
        int index = 0;
        while (index < count) {
            if (System.Australis.Files.DirectoryName("/System/Bin", index) > 0) {
                System.Console.Write("  ");
                System.Australis.Files.WriteResult();
                System.Console.WriteLine();
            }
            index = index + 1;
        }
    }

    public static int Main(string[] args) {
        byte[] word = new byte[256];
        byte[] commandBytes = new byte[64];
        byte[] arguments = new byte[256];
        byte[] program = new byte[256];
        byte[] cwd = new byte[256];
        cwd[0] = 47; cwd[1] = 0;
        int cwdLength = 1;
        byte[] searchPath = new byte[256];
        byte[] variableTable = new byte[1536];
        byte[] context = new byte[2048];
        string initialPath = "/System/Bin";
        int searchPathLength = initialPath.Length;
        int pathIndex = 0;
        while (pathIndex < searchPathLength) {
            searchPath[pathIndex] = (byte)System.Australis.Text.ByteAt(initialPath, pathIndex);
            pathIndex = pathIndex + 1;
        }
        string inheritedDirectory = System.Australis.Process.WorkingDirectory();
        if (inheritedDirectory.Length > 0 && inheritedDirectory.Length <= 255 &&
            System.Australis.Files.StatKind(inheritedDirectory) == 2) {
            cwdLength = inheritedDirectory.Length;
            int directoryIndex = 0;
            while (directoryIndex < cwdLength) {
                cwd[directoryIndex] = (byte)System.Australis.Text.ByteAt(
                    inheritedDirectory, directoryIndex);
                directoryIndex = directoryIndex + 1;
            }
            cwd[cwdLength] = 0;
        }
        byte[] imported = new byte[256];
        int importedCount = System.Australis.Process.EnvironmentCount();
        int importedIndex = 0;
        while (importedIndex < importedCount) {
            string entry = System.Australis.Process.EnvironmentEntry(importedIndex);
            int entryLength = entry.Length;
            if (entryLength > 0 && entryLength <= 255) {
                int equal = 0; int j = 0;
                while (j < entryLength) {
                    imported[j] = (byte)System.Australis.Text.ByteAt(entry, j);
                    if (imported[j] == 61 && equal == 0) { equal = j; }
                    j = j + 1;
                }
                if (equal > 0 && ValidVariableName(imported, 0, equal)) {
                    if (equal == 4 && imported[0] == 80 && imported[1] == 65 &&
                        imported[2] == 84 && imported[3] == 72) {
                        int importedPathLength = entryLength - equal - 1;
                        if (ValidSearchPath(imported, equal + 1,
                            importedPathLength, program)) {
                            searchPathLength = importedPathLength;
                            j = 0;
                            while (j < searchPathLength) {
                                searchPath[j] = imported[equal + 1 + j]; j = j + 1;
                            }
                        }
                    } else if (SetVariable(variableTable, imported, 0, equal,
                        equal + 1, entryLength - equal - 1)) {
                        int slot = VariableSlot(variableTable, imported, 0, equal);
                        if (slot >= 0) { variableTable[slot * 128 + 2] = 1; }
                    }
                }
            }
            importedIndex = importedIndex + 1;
        }
        string h0 = ""; string h1 = ""; string h2 = ""; string h3 = "";
        string h4 = ""; string h5 = ""; string h6 = ""; string h7 = "";
        System.Console.WriteLine("Australis command shell");
        System.Console.WriteLine("Type help for commands.");
        int readyStatus = System.Australis.Process.Ready();
        while (true) {
            System.Console.Write("australis> ");
            string line = System.Console.ReadLine();
            int size = line.Length;
            if (System.Australis.Terminal.EndOfInput()) {
                System.Console.WriteLine(); return 0;
            }
            if (size == 0) { continue; }
            h0 = h1; h1 = h2; h2 = h3; h3 = h4;
            h4 = h5; h5 = h6; h6 = h7; h7 = line;
            int i = 0; int wordLength = 0; int argEnd = 1; int argc = 0;
            int commandLength = 0; int programLength = 0; int quote = 0;
            bool escape = false; bool started = false; bool bad = false;
            string command = "";
            while (i <= size && !bad) {
                int c = 32;
                if (i < size) { c = System.Australis.Text.ByteAt(line, i); }
                bool separator = i == size ||
                    ((c == 32 || c == 9) && quote == 0 && !escape);
                if (separator) {
                    if (started) {
                        if (commandLength == 0) {
                            if (wordLength == 0 || wordLength >= commandBytes.Length) { bad = true; }
                            else {
                                int x = 0;
                                while (x < wordLength) {
                                    commandBytes[x] = word[x]; x = x + 1;
                                }
                                commandLength = wordLength;
                                command = System.Australis.Text.FromBytes(commandBytes,
                                    commandLength);
                            }
                        } else if (command == "run" && programLength == 0) {
                            int next = Path(word, wordLength, cwd, cwdLength, program, 0);
                            if (next < 0) { bad = true; }
                            else { programLength = next - 1; }
                        } else if (argc == 16) { bad = true; }
                        else {
                            int next2 = argEnd;
                            if (PathCommand(command)) {
                                next2 = Path(word, wordLength, cwd, cwdLength,
                                    arguments, argEnd);
                            } else {
                                int x2 = 0;
                                while (x2 < wordLength && next2 < arguments.Length - 1) {
                                    arguments[next2] = word[x2]; x2 = x2 + 1;
                                    next2 = next2 + 1;
                                }
                                if (x2 != wordLength) { next2 = -1; }
                                else { arguments[next2] = 0; next2 = next2 + 1; }
                            }
                            if (next2 < 0) { bad = true; }
                            else { argEnd = next2; argc = argc + 1; }
                        }
                        wordLength = 0; started = false;
                    }
                } else if (escape) {
                    if (wordLength == 255) { bad = true; }
                    else { word[wordLength] = (byte)c; wordLength = wordLength + 1; }
                    started = true; escape = false;
                } else if (c == 92 && quote != 39) {
                    escape = true; started = true;
                } else if (quote != 0 && c == quote) {
                    quote = 0;
                } else if (quote == 0 && (c == 34 || c == 39)) {
                    quote = c; started = true;
                } else {
                    if (wordLength == 255) { bad = true; }
                    else { word[wordLength] = (byte)c; wordLength = wordLength + 1; }
                    started = true;
                }
                i = i + 1;
            }
            if (bad || quote != 0 || escape) {
                System.Console.WriteLine("shell: invalid or too-long command line");
                continue;
            }
            if (commandLength == 0) { continue; }
            arguments[0] = (byte)argc;
            if (command == "exit") {
                if (argc == 0) { return 0; }
                System.Console.WriteLine("Usage: exit");
            } else if (command == "help") {
                Help();
            } else if (command == "history") {
                if (h0 != "") { System.Console.WriteLine(h0); }
                if (h1 != "") { System.Console.WriteLine(h1); }
                if (h2 != "") { System.Console.WriteLine(h2); }
                if (h3 != "") { System.Console.WriteLine(h3); }
                if (h4 != "") { System.Console.WriteLine(h4); }
                if (h5 != "") { System.Console.WriteLine(h5); }
                if (h6 != "") { System.Console.WriteLine(h6); }
                if (h7 != "") { System.Console.WriteLine(h7); }
            } else if (command == "pwd") {
                if (argc != 0) { System.Console.WriteLine("Usage: pwd"); }
                else { System.Console.WriteLine(System.Australis.Text.FromBytes(cwd,
                    cwdLength)); }
            } else if (command == "path") {
                if (argc == 0) {
                    System.Console.Write("PATH=");
                    System.Console.WriteLine(System.Australis.Text.FromBytes(searchPath,
                        searchPathLength));
                } else if (argc != 1 ||
                    !ValidSearchPath(arguments, 1, argEnd - 2, program)) {
                    System.Console.WriteLine("Usage: path /System/Bin[:/other/directory]");
                } else {
                    int newLength = argEnd - 2; int p = 0;
                    while (p < newLength) {
                        searchPath[p] = arguments[p + 1]; p = p + 1;
                    }
                    searchPathLength = newLength;
                    System.Console.Write("PATH=");
                    System.Console.WriteLine(System.Australis.Text.FromBytes(searchPath,
                        searchPathLength));
                }
            } else if (command == "set") {
                if (argc != 2) {
                    System.Console.WriteLine("Usage: set NAME VALUE");
                } else {
                    int nameOffset = ArgumentOffset(arguments, 0);
                    int nameLength = ArgumentLength(arguments, nameOffset);
                    int valueOffset = ArgumentOffset(arguments, 1);
                    int valueLength = ArgumentLength(arguments, valueOffset);
                    if (!ValidVariableName(arguments, nameOffset, nameLength)) {
                        System.Console.WriteLine("set: invalid variable name");
                    } else if (nameLength == 4 &&
                        arguments[nameOffset] == 80 && arguments[nameOffset + 1] == 65 &&
                        arguments[nameOffset + 2] == 84 && arguments[nameOffset + 3] == 72) {
                        if (!ValidSearchPath(arguments, valueOffset, valueLength, program)) {
                            System.Console.WriteLine("set: PATH requires existing absolute directories");
                        } else {
                            int n = 0;
                            while (n < valueLength) {
                                searchPath[n] = arguments[valueOffset + n]; n = n + 1;
                            }
                            searchPathLength = valueLength;
                        }
                    } else if (!SetVariable(variableTable, arguments, nameOffset,
                        nameLength, valueOffset, valueLength)) {
                        System.Console.WriteLine("set: value too long or variable table full");
                    }
                }
            } else if (command == "export") {
                if (argc != 1) { System.Console.WriteLine("Usage: export NAME"); }
                else {
                    int nameOffset2 = ArgumentOffset(arguments, 0);
                    int nameLength2 = ArgumentLength(arguments, nameOffset2);
                    int slot = VariableSlot(variableTable, arguments,
                        nameOffset2, nameLength2);
                    bool isPath = nameLength2 == 4 && arguments[nameOffset2] == 80 &&
                        arguments[nameOffset2 + 1] == 65 &&
                        arguments[nameOffset2 + 2] == 84 &&
                        arguments[nameOffset2 + 3] == 72;
                    if (slot >= 0) { variableTable[slot * 128 + 2] = 1; }
                    else if (!isPath || searchPathLength == 0) {
                        System.Console.WriteLine("export: variable not found");
                    }
                }
            } else if (command == "unset") {
                if (argc != 1) { System.Console.WriteLine("Usage: unset NAME"); }
                else {
                    int nameOffset3 = ArgumentOffset(arguments, 0);
                    int nameLength3 = ArgumentLength(arguments, nameOffset3);
                    int slot2 = VariableSlot(variableTable, arguments,
                        nameOffset3, nameLength3);
                    if (slot2 >= 0) { variableTable[slot2 * 128] = 0; }
                    if (nameLength3 == 4 && arguments[nameOffset3] == 80 &&
                        arguments[nameOffset3 + 1] == 65 &&
                        arguments[nameOffset3 + 2] == 84 &&
                        arguments[nameOffset3 + 3] == 72) {
                        searchPathLength = 0;
                    }
                }
            } else if (command == "cd") {
                if (argc > 1) { System.Console.WriteLine("Usage: cd [directory]"); }
                else {
                    int targetLength = 1; string target = "/";
                    if (argc == 1) {
                        targetLength = argEnd - 2;
                        int x3 = 0;
                        while (x3 < targetLength) {
                            program[x3] = arguments[x3 + 1]; x3 = x3 + 1;
                        }
                        target = System.Australis.Text.FromBytes(program,
                            targetLength);
                    }
                    if (System.Australis.Files.StatKind(target) != 2) {
                        System.Console.WriteLine("cd: directory not found");
                    } else {
                        if (argc == 0) { cwd[0] = 47; cwdLength = 1; }
                        else {
                            int x4 = 0;
                            while (x4 < targetLength) {
                                cwd[x4] = program[x4]; x4 = x4 + 1;
                            }
                            cwdLength = targetLength;
                        }
                        cwd[cwdLength] = 0;
                    }
                }
            } else {
                if (command == "run") {
                    if (programLength == 0) {
                        System.Console.WriteLine("Usage: run <program.exec> [args]");
                        continue;
                    }
                } else {
                    int part = 0;
                    while (part < searchPathLength && programLength == 0) {
                        int end = part;
                        while (end < searchPathLength && searchPath[end] != 58) {
                            end = end + 1;
                        }
                        int dirLength = end - part;
                        int usedDirectory = dirLength;
                        if (usedDirectory > 0 && searchPath[end - 1] == 47) {
                            usedDirectory = usedDirectory - 1;
                        }
                        int candidateLength = usedDirectory + commandLength + 6;
                        if (candidateLength <= 255) {
                            int x5 = 0;
                            while (x5 < dirLength) {
                                program[x5] = searchPath[part + x5]; x5 = x5 + 1;
                            }
                            if (x5 > 0 && program[x5 - 1] == 47) { x5 = x5 - 1; }
                            program[x5] = 47; x5 = x5 + 1;
                            int x6 = 0;
                            while (x6 < commandLength) {
                                program[x5] = commandBytes[x6]; x5 = x5 + 1;
                                x6 = x6 + 1;
                            }
                            program[x5] = 46; x5 = x5 + 1;
                            program[x5] = 101; x5 = x5 + 1;
                            program[x5] = 120; x5 = x5 + 1;
                            program[x5] = 101; x5 = x5 + 1;
                            program[x5] = 99; x5 = x5 + 1;
                            string candidate = System.Australis.Text.FromBytes(program, x5);
                            if (System.Australis.Files.StatKind(candidate) == 1) {
                                programLength = x5;
                            }
                        }
                        part = end + 1;
                    }
                }
                if (programLength == 0) {
                    System.Console.WriteLine("shell: command not found");
                    continue;
                }
                string executable = System.Australis.Text.FromBytes(program,
                    programLength);
                if (!ChildContext(variableTable, searchPath, searchPathLength,
                    cwd, cwdLength, context)) {
                    System.Console.WriteLine("shell: child context too large");
                    continue;
                }
                int status = System.Australis.Process.Run(executable, arguments,
                    context);
                if (status == -1) {
                    System.Console.WriteLine("shell: executable not found");
                } else if (status == -2) {
                    System.Console.WriteLine("shell: invalid executable image");
                } else if (status == -3) {
                    System.Console.WriteLine("shell: execution denied");
                } else if (status == -4) {
                    System.Console.WriteLine("shell: invalid launch request");
                } else if (status < 0) {
                    System.Console.Write("shell: program fault: ");
                    System.Console.WriteLine(status);
                } else if (status != 0) {
                    System.Console.Write("shell: exit status ");
                    System.Console.WriteLine(status);
                }
            }
        }
        return 0;
    }
}
