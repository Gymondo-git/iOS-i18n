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
// TODO: - adjust regex, return outlet name as String
func findIBOutlet(by id: String, in storyboard: URL) -> Bool {
  do {
    let content = try String(contentsOf: storyboard, encoding: .utf8)
    let pattern = #"(<outlet).*(destination="\#(id)")"#
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count))
    
    return match != nil
  } catch {
    return false
  }
}

func copyContent(_ content: [String:String], to replacement: [String:String]) -> [String:String] {
  let sanitized = replacement.map({ kv -> (key: String, value: String) in
    if let srcValue = content[kv.key] {
      return (kv.key, srcValue)
    }
    
    let ibID = String(kv.key.split(separator: ".").first!)
    
    // TODO: get outlet name from following function
//    let outlet = findIBOutlet(by: ibID, in: URL())
    
    // TODO: if outlet != nil, add name to comment
    return (kv.key, "\(kv.value) // TODO: check this")
  })
  
  return Dictionary(uniqueKeysWithValues: sanitized)
}

// write .strings file
func writeContent(_ content: [String:String], to path: URL) {
  let fileContent = content.map { (key, value) -> String in
    return "\(key) = \(value)"
  }.sorted { lhs, rhs -> Bool in
    let orderLhs = lhs.contains("// TODO: check this") ? 1 : 0
    let orderRhs = rhs.contains("// TODO: check this") ? 1 : 0
    
    return orderLhs < orderRhs
  }.joined(separator: "\n")
  
  do {
    try fileContent.write(to: path, atomically: true, encoding: .utf8)
  } catch {
    dump(error)
    
    exit(1)
  }
}

let destinationFilePath = URL(fileURLWithPath: args[1])
let destDict = parseFile(at: destinationFilePath) // japanese
let srcDict = parseFile(at: URL(fileURLWithPath: args[2])) // german
let sanitized = copyContent(srcDict, to: destDict)

writeContent(sanitized, to: destinationFilePath)
