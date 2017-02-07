#!/usr/bin/swift

/**
 *  SwiftPlate
 *
 *  Copyright (c) 2017 Håvard Fossli.
 *  Copyright (c) 2016 John Sundell. 
 *
 *  Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

extension Process {
    @discardableResult func launchBash(withCommand command: String) throws -> String? {
        launchPath = "/bin/bash"
        arguments = ["-c", command]
        
        let pipe = Pipe()
        standardOutput = pipe
        
        // Silent errors by assigning a dummy pipe to the error output
        standardError = Pipe()
        
        launch()
        waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8)?.nonEmpty
    }
    
    func gitConfigValue(forKey key: String) throws -> String? {
        return try launchBash(withCommand: "git config --global --get \(key)")?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var nonEmpty: String? {
        guard characters.count > 0 else {
            return nil
        }
        
        return self
    }
    
    func withoutSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else {
            return self
        }
        
        let startIndex = index(endIndex, offsetBy: -suffix.characters.count)
        return replacingCharacters(in: startIndex..<endIndex, with: "")
    }
}

extension FileManager {
    func isFolder(atPath path: String) -> Bool {
        var objCBool: ObjCBool = false
        guard fileExists(atPath: path, isDirectory: &objCBool) else {
            return false
        }
        return objCBool.boolValue
    }
}

extension Array {
    func element(after index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        
        return self[index + 1]
    } 
}

extension CommandLine {
    static func options() throws -> [String:String] {
        var options: [String:String] = [:]
        for (index, argument) in self.arguments.enumerated() {
            if argument == "--no-force" {
                options["force"] = "no"
            } else if argument == "--force" {
                options["force"] = "yes"
            } else if argument.hasPrefix("--") {
                let name = argument.substring(from: argument.index(argument.startIndex, offsetBy: 2))
                guard let value = arguments.element(after: index) else {
                    throw "Expecting value after option \"\(argument)\""
                }
                guard !value.hasPrefix("--") else {
                    throw "Expecting value after option \"\(argument)\", but received another option \"\(value)\""
                }
                options[name] = value
            }
        }
        return options
    }
}

extension String: Error {}

extension String {
    var asBool: Bool? {
        if self == "n" || self == "false" || self == "no" {
            return false
        }
        if self == "y" || self == "true" || self == "yes" {
            return true
        }
        return nil
    }
}

struct StringReplacer {
    let replacements: [String:String]
    
    func process(string: String) -> String {
        var result = string
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }
    
    func process(filesInFolderWithPath folderPath: String) throws {
        let fileManager = FileManager.default
        
        for itemName in try fileManager.contentsOfDirectory(atPath: folderPath) {
            
            if itemName == ".DS_Store" {
                continue
            }
            
            let itemPath = folderPath + "/" + itemName
            let newItemPath = folderPath + "/" + process(string: itemName)
            
            if fileManager.isFolder(atPath: itemPath) {
                try process(filesInFolderWithPath: itemPath)
                try fileManager.moveItem(atPath: itemPath, toPath: newItemPath)
                continue
            }
            
            if let fileContents = try? String(contentsOfFile: itemPath, encoding: .utf8) {
                try process(string: fileContents).write(toFile: newItemPath, atomically: false, encoding: .utf8)
                if newItemPath != itemPath {
                    try fileManager.removeItem(atPath: itemPath)
                }
            }
        }
    }
}

struct Config {
    
    let entries: [Entry]
    
    struct Entry {
        let name: String
        let find: String
        let description: String
        let suggestion: String?
        let hidden: Bool
        let optional: Bool
    }
    
    init(entries: [Entry]) {
        self.entries = entries
    }
    
    init(file: String) throws {
        let data = try NSData(contentsOfFile: file) as Data
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String:Any] else {
            throw "Expecting format of json to be { ... } in file \"\(file)\"."
        }
        guard let replace = dict["replace"] as? [Any] else {
            throw "Expecting format of \"replace\" to be [ ... ] in file \"\(file)\"."
        }
        self.entries = try Config.entriesFromJson(replace)
    }
    
    func resolvedSuggestions(_ suggestionConstants: [String:String]) -> Config {
        var entries: [Entry] = []
        for entry in self.entries {
            let resolvedSuggestion: String?
            if let suggestionKey = entry.suggestion, let resolved = suggestionConstants[suggestionKey] {
                resolvedSuggestion = resolved
            } else {
                resolvedSuggestion = entry.suggestion
            }
            let resolvedEntry = Entry(name: entry.name, find: entry.find, description: entry.description, suggestion: resolvedSuggestion, hidden: entry.hidden, optional: entry.optional)
            entries.append(resolvedEntry)
        }
        return Config(entries: entries)
    }
    
    static func entriesFromJson(_ json: [Any]) throws -> [Entry] {
        
        var entries: [Entry] = []
        for (index, value) in json.enumerated() {
            guard let attributes = value as? [String:Any] else {
                throw "Expecting format of \(value) to be a dictionary with \n- field (required string)\n- description (required string)\n- optional (optional bool)\n- suggestion (optional string)\n- hidden (optional bool)."
            }
            guard let find = attributes["find"] as? String else {
                throw "Missing required attribute \"find\" at index \(index) in array with value \(value)"
            }
            guard let description = attributes["description"] as? String else {
                throw "Missing required attribute \"description\" for key \"\(find)\" array with value \(value)"
            }
            let suggestion = attributes["suggestion"] as? String
            let hidden = attributes["hidden"] as? Bool ?? false
            let optional = attributes["optional"] as? Bool ?? false
            let rangeOfFirstTwoCharacters = Range(uncheckedBounds: (find.startIndex, find.index(find.startIndex, offsetBy: 2)))
            
            let name = attributes["name"] as? String ?? find
                .replacingOccurrences(of: "S-", with: "", range: rangeOfFirstTwoCharacters)
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            let entry = Entry(name: name, find: find, description: description, suggestion: suggestion, hidden: hidden, optional: optional)
            entries.append(entry)
        }
        return entries
    }
}

protocol OptionsSolver {
    func option(_ name: String, description: String, required: Bool, suggestion: String?) -> String?
}

struct CommandLineOptionsSolver: OptionsSolver {
    
    let options: [String:String]
    let force: Bool
    
    init() throws {
        options = try CommandLine.options()
        force = options["force"]?.asBool ?? false
    }
    
    func option(_ name: String, description: String, required: Bool, suggestion: String?) -> String? {
        if let value = options[name] {
            return value
        }
        if !force {
            if let suggestion = suggestion {
                print("\(name.capitalized): \(description). Leave blank to use \"\(suggestion)\"")
            } else {
                print("\(name.capitalized): \(description)")
            }
            if let value = readLine()?.nonEmpty {
                print(" ")
                return value
            }
            print(" ")
            if let suggestion = suggestion {
                return suggestion
            }
            if required {
                print("Invalid value. Try again.")
                return option(name, description: description, required: required, suggestion: suggestion)
            }
            return nil
        }
        return nil
    }
}

struct Program {
    
    let options: OptionsSolver
    
    func run() throws {
        
        guard let destination = options.option("destination",
                                               description: "Where do you want to create the project?",
                                               required: true,
                                               suggestion: nil) else
        {
            throw "Missing argument destination"
        }
        
        guard let template = options.option("template",
                                            description: "Which template do you want to use?",
                                            required: true,
                                            suggestion: nil) else
        {
            throw "Missing argument template"
        }
        
        let suggestionConstants = constants(folderName: (destination as NSString).lastPathComponent)
        let config = try cloneTemplate(template, to: destination)
        let resolvedConfig = config.resolvedSuggestions(suggestionConstants)
        
        var replacements: [String:String] = [:]
        
        for entry in resolvedConfig.entries {
            let replacement: String?
            if entry.hidden {
                guard let suggestion = entry.suggestion else {
                    throw "Was supposed to replace \(entry.name), but the suggested value (\(entry.suggestion)) is not known"
                }
                replacement = suggestion
            } else {
                replacement = options.option(entry.name, description: entry.description, required: !entry.optional, suggestion: entry.suggestion)
            }
            if let replacement = replacement {
                replacements[entry.find] = replacement
                replacements[entry.find.replacingOccurrences(of: "-", with: "_")] = replacement
                replacements[entry.find.replacingOccurrences(of: "_", with: "-")] = replacement
            }
        }
        
        let replacer = StringReplacer(replacements: replacements)
        try replacer.process(filesInFolderWithPath: destination)
    }
    
    private func prepareDestinationFolder(_ destination: String) throws {
        var destinationIsDirectory: ObjCBool = false
        if FileManager().fileExists(atPath: destination, isDirectory: &destinationIsDirectory) {
            guard destinationIsDirectory.boolValue else {
                throw "Destination (\(destination)) already exists and is a file not a directory."
            }
            var contents = (try? FileManager().contentsOfDirectory(atPath: destination)) ?? []
            contents = contents.filter { $0 != ".DS_Store" }
            guard contents.count == 0 else {
                throw "Destination (\(destination)) folder already exist and contains files already. Contains: \(contents)"
            }
        } else {
            do {
                try FileManager().createDirectory(atPath: destination, withIntermediateDirectories: true)
            } catch {
                throw "Could not create folder at \(destination)"
            }
        }
    }
    
    private func cloneTemplate(_ template: String, to destination: String) throws -> Config {
        
        try prepareDestinationFolder(destination)
        
        if template.hasPrefix("http") {
            return try cloneZipUrl(template, to: destination)
        } else if FileManager().fileExists(atPath: template) {
            return try cloneTemplateFolder(template, to: destination)
        } else if template.components(separatedBy: "/").count == 2 {
            let githubZip = "https://github.com/\(template)/archive/master.zip"
            return try cloneZipUrl(githubZip, to: destination)
        } else {
            throw "Template is not a local folder, url (zip) nor a github repo."
        }
    }
    
    private func cloneZipUrl(_ url: String, to destination: String) throws -> Config {
        let temporaryFolder = "\(destination.withoutSuffix("/"))_swiftplate_download"
        try? FileManager().removeItem(atPath: temporaryFolder)
        try prepareDestinationFolder(temporaryFolder)
        try performCommand(description: "Downloading template \(url)") {
            let result = try Process().launchBash(withCommand: "curl -L \"\(url)\" | tar zx -C \"\(temporaryFolder)\"")
            if let result = result {
                print(result)
            }
        }
        guard let contents = try FileManager().contentsOfDirectory(atPath: temporaryFolder).first else {
            try? FileManager().removeItem(atPath: temporaryFolder)
            throw "After unzipping contents of \(url) we expected to find a folder"
        }
        let template = (temporaryFolder as NSString).appendingPathComponent(contents)
        let result = try cloneTemplateFolder(template, to: destination)
        try? FileManager().removeItem(atPath: temporaryFolder)
        return result
    }
    
    private func cloneTemplateFolder(_ template: String, to destination: String) throws -> Config {
        
        var templateIsDirectory: ObjCBool = false
        guard FileManager().fileExists(atPath: template, isDirectory: &templateIsDirectory) else {
            throw "Internal error"
        }
        
        let jsonPath: String
        let templateDirectory: String
        
        if templateIsDirectory.boolValue {
            templateDirectory = template
            jsonPath = (templateDirectory as NSString).appendingPathComponent("swiftplate.json")
        } else {
            jsonPath = template
            templateDirectory = (jsonPath as NSString).deletingLastPathComponent
        }
        
        guard FileManager().fileExists(atPath: jsonPath) else {
            throw "Template is missing swiftplate.json file. Should be located at \(jsonPath)"
        }
        
        let config = try Config(file: jsonPath)
        
        try? FileManager().removeItem(atPath: (destination as NSString).appendingPathComponent(".DS_Store"))
        try FileManager().removeItem(atPath: destination)
        try FileManager().copyItem(atPath: templateDirectory, toPath: destination)
        try? FileManager().removeItem(atPath: (destination as NSString).appendingPathComponent("swiftplate.json"))
        return config
    }
    
    private func performCommand(description: String, command: () throws -> Void) rethrows {
        print("👉  \(description)...", terminator: "")
        try command()
        print("done")
    }
    
    private func constants(folderName: String) -> [String:String] {
        var consts: [String:String] = [:]
        consts["git.user.name"] = try? Process().gitConfigValue(forKey: "user.name") ?? ""
        consts["git.user.email"] = try? Process().gitConfigValue(forKey: "user.email") ?? ""
        consts["date.year"] = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYY"
            return dateFormatter.string(from: Date())
        }()
        consts["folder.name"] = folderName
        return consts
    }
}

do {
    print("Welcome to the SwiftPlate project generator 🐣")
    let options = try CommandLineOptionsSolver()
    let program = Program(options: options)
    try program.run()
    print("All done! 🎉 Good luck with your project! 🚀")
} catch {
    print("An error was encountered 🙁")
    print("Error: \(error)")
}

