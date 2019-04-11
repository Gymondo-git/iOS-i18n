#!/usr/bin/env swift

import Foundation

let args = CommandLine.arguments

guard args.count > 2 else {
  dump("filePath missing")
  
  exit(1)
}

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

let destDict = parseFile(at: URL(fileURLWithPath: args[1])) // japanese
let srcDict = parseFile(at: URL(fileURLWithPath: args[2])) // german

let sanitized = destDict.map { arg -> (key: String, value: String) in
  if let srcValue = srcDict[arg.key] {
    return (arg.key, srcValue)
  }
  
  return (arg.key, "\(arg.value) // TODO: check this")
}

let possibleUnused = srcDict.filter { !destDict.keys.contains($0.key) }

// german file has 27 additional KV pairs
// japanese file has 21 elements without pre-exising KV pairs

print(sanitized.filter({ $0.value.contains("TODO: check this") }))
