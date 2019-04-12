#!/usr/bin/env swift

import Foundation

let args = CommandLine.arguments

guard args.count > 2 else {
  dump("filePath missing")
  
  exit(1)
}

// read .strings file
func parseFile(at path: URL) -> [String:String] {
  do {
    let content = try String(contentsOf: path, encoding: .utf8)
    let pattern = #"^".*?"\s*=\s*"(.|\v)*?";$"#
    let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    let matches = regex.matches(in: content, range: NSMakeRange(0, content.utf16.count))
    
    let results = matches.reduce([String:String]()) { dict, match -> [String:String] in
      var dict = dict
      let result = (content as NSString).substring(with: match.range)
      let kv = result.split(separator: "=").map { String($0).trimmingCharacters(in: .whitespaces) }
      
      dict[kv.first!] = kv.last!
      
      return dict
    }
    
    return results
  } catch {
    dump(error)
    
    return [:]
  }
}

// copy
func copyContent(_ content: [String:String], to replacement: [String:String]) -> [String:String] {
  let sanitized = Dictionary(uniqueKeysWithValues: replacement.map { kv -> (key: String, value: String) in
    if let srcValue = content[kv.key] {
      return (kv.key, srcValue)
    }
    
    return (kv.key, "\(kv.value) // TODO: check this")
  })
  
  return sanitized
}

// write .strings file
func writeContent(_ content: [String:String], to path: URL) {
  
}

let destinationFilePath = URL(fileURLWithPath: args[1])
let destDict = parseFile(at: destinationFilePath) // japanese
let srcDict = parseFile(at: URL(fileURLWithPath: args[2])) // german

let sanitized = copyContent(srcDict, to: destDict)

//let possibleUnused = srcDict.filter { !destDict.keys.contains($0.key) }

// german file has 27 additional KV pairs
// japanese file has 21 elements without pre-exising KV pairs
