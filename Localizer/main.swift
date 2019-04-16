#!/usr/bin/env swift

import Foundation

enum Option: String {
  case path = "p"
  case filename = "f"
  case unknown
  
  init(value: String) {
    switch value {
    case "p":
      self = .path
    case "f":
      self = .filename
    default:
      self = .unknown
    }
  }
  
  func printError() {
    fputs("\u{001B}[0;31m-\(self.rawValue)\(" parameter requires value")\n", stderr)
  }
}

let args = Array(CommandLine.arguments.suffix(from: 1))
var path: String = FileManager.default.currentDirectoryPath
var filename: String?

func getOption(_ option: String) -> (option: Option, value: String) {
  return (Option(value: option), option)
}

func parseArguments(_ args: [String]) {
  for i in 0 ..< args.count {
    let arg = args[i]
    let option = getOption(String(arg[arg.index(arg.startIndex, offsetBy: 1)]))
    
    switch option.option {
    case .path:
      guard args.count >= i + 1 else {
        Option.path.printError()
        
        exit(1)
      }
      
      let nextArg = args[i + 1]
      let value = getOption(String(nextArg[nextArg.index(arg.startIndex, offsetBy: 1)]))
      
      guard value.option == .unknown else {
        Option.path.printError()
        
        exit(1)
      }
      
      path = args[i + 1]
    case .filename:
      guard args.count >= i + 1 else {
        Option.filename.printError()
        
        exit(1)
      }
      
      let nextArg = args[i + 1]
      let value = getOption(String(nextArg[nextArg.index(arg.startIndex, offsetBy: 1)]))
      
      guard value.option == .unknown else {
        Option.filename.printError()
        
        exit(1)
      }
      
      filename = args[i + 1]
    default:
      continue
    }
  }
}

parseArguments(args)

guard let fileName = filename else {
  fputs("\u{001B}[0;31mNo filename provided. Use -f!\n", stderr)
  
  exit(1)
}

func buildURLs() -> (layout: URL, src: URL, replacement: URL) {
  var layoutFileUrl: URL
  var srcStringsFileUrl: URL
  var replacementStringsFileUrl: URL
  
  if FileManager.default.fileExists(atPath: "\(path)/Gymondo/Base.lproj/\(fileName).storyboard") {
    layoutFileUrl = URL(fileURLWithPath: "\(path)/Gymondo/Base.lproj/\(fileName).storyboard")
  } else if FileManager.default.fileExists(atPath: "\(path)/Gymondo/Base.lproj/\(fileName).xib") {
    layoutFileUrl = URL(fileURLWithPath: "\(path)/Gymondo/Base.lproj/\(fileName).xib")
  } else {
    fputs("\u{001B}[0;31m-no layout file found for [\(fileName)] in [\(path)/Gymondo/Base.lproj]\n", stderr)
    
    exit(1)
  }
  
  if FileManager.default.fileExists(atPath: "\(path)/Gymondo/de.lproj/\(fileName).strings") {
    srcStringsFileUrl = URL(fileURLWithPath: "\(path)/Gymondo/de.lproj/\(fileName).strings")
  } else {
    fputs("\u{001B}[0;31m-no localization file found for [\(fileName)] in [\(path)/Gymondo/de.lproj]\n", stderr)
    
    exit(1)
  }
  
  if FileManager.default.fileExists(atPath: "\(path)/Gymondo/ja.lproj/\(fileName).strings") {
    replacementStringsFileUrl = URL(fileURLWithPath: "\(path)/Gymondo/ja.lproj/\(fileName).strings")
  } else {
    fputs("\u{001B}[0;31m-no localization file found for [\(fileName)] in [\(path)/Gymondo/ja.lproj]\n", stderr)
    
    exit(1)
  }
  
  return (layout: layoutFileUrl, src: srcStringsFileUrl, replacement: replacementStringsFileUrl)
}

let urls = buildURLs()

// read .strings file
func parseFile(at path: URL) -> [String:String] {
  do {
    let content = try String(contentsOf: path, encoding: .utf8)
    let pattern = #"^".*?"\s*=\s*"(.|\v)*?";$"#
    let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    let matches = regex.matches(in: content, range: NSMakeRange(0, content.utf16.count))
    
    let results = matches.reduce([String:String]()) { dict, match -> [String:String] in
      var dict = dict
      let result = (content as NSString).substring(with: match.range).replacingOccurrences(of: "\u{000A}", with: "\\n")
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

func copyContent(_ content: [String:String], to replacement: [String:String]) -> [String:String] {
  let sanitized = replacement.map({ kv -> (key: String, value: String) in
    
    var tempKV = kv
    var hasTranslation = false
    
    if let srcValue = content[kv.key] {
      tempKV.value = srcValue
      hasTranslation = true
    }
    
    return getValueName(by: tempKV, hasTranslation: hasTranslation)
  })
  
  return Dictionary(uniqueKeysWithValues: sanitized)
}

func getValueName(by keyValue: (key: String, value: String), hasTranslation: Bool) -> (String, String) {
  let objectId = String(keyValue.key.split(separator: "\"").first!.split(separator: ".").first!)
  var finalKV = keyValue
  var comment = ""
  
  if let outlet = findIBOutlet(by: objectId) {
    let priority = hasTranslation ? "(?)" : "(!)"
    
    comment = " // TODO: \(priority) translation: \(hasTranslation), outlet: \(outlet)"
  } else {
    comment = hasTranslation ? "" : " // TODO: (!) translation: false, outlet: none"
  }
  
  finalKV.value = keyValue.value + comment
  
  return finalKV
}

// TODO: - adjust regex, return outlet name as String
func findIBOutlet(by id: String) -> String? {
  do {
    let content = try String(contentsOf: urls.layout, encoding: .utf8)
    let pattern = #"(<outlet).*(destination="\#(id)").*/>"#
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    
    guard let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count)) else {
      return nil
    }
    
    let outletString = (content as NSString).substring(with: match.range)
    
    return findProperty(by: outletString)
  } catch {
    return nil
  }
}

func findProperty(by outlet: String) -> String? {
  do {
    let pattern = #"(?<=property=").*?(?=")"#
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    
    guard let match = regex.firstMatch(in: outlet, range: NSRange(location: 0, length: outlet.utf16.count)) else {
      return nil
    }
    
    return (outlet as NSString).substring(with: match.range)
  } catch {
    return nil
  }
}

// write .strings file
func writeContent(_ content: [String:String]) {
  var fileContent: [String] = []
  
  let allContent = content.map { (key, value) -> String in
    return "\(key) = \(value)"
  }.sorted { lhs, rhs -> Bool in
    let orderLhs = lhs.contains("// TODO: (!)") ? 1 : lhs.contains("// TODO: (?)") ? 2 : 0
    let orderRhs = rhs.contains("// TODO: (!)") ? 1 : rhs.contains("// TODO: (?)") ? 2 : 0
    
    return orderLhs < orderRhs
  }
    
  var filtered = allContent.filter { !$0.contains("// TODO:")}
  
  fileContent.append(contentsOf: filtered)
  
  filtered = allContent.filter { $0.contains("// TODO: (?)") }
  
  if !filtered.isEmpty {
    fileContent.append("\n/* Translation and Outlet */")
    fileContent.append(contentsOf: filtered)
  }
  
  filtered = allContent.filter { $0.contains("// TODO: (!)") && !$0.contains("outlet: none") }
  
  if !filtered.isEmpty {
    fileContent.append("\n/* no Translation but Outlet */")
    fileContent.append(contentsOf: filtered)
  }
  
  filtered = allContent.filter { $0.contains("// TODO: (!)") && $0.contains("outlet: none") }
  
  if !filtered.isEmpty {
    fileContent.append("\n/* no Translation no Outlet */")
    fileContent.append(contentsOf: filtered)
  }
  
  do {
    try fileContent.joined(separator: "\n").write(to: urls.replacement, atomically: true, encoding: .utf8)
  } catch {
    dump(error)
    
    exit(1)
  }
}

let destDict = parseFile(at: urls.replacement) // japanese
let srcDict = parseFile(at: urls.src) // german
let sanitized = copyContent(srcDict, to: destDict)

writeContent(sanitized)
