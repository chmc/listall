import Foundation
import IndexStoreWrapper

@main
struct CallGraphPrototype {
    static func main() throws {
        print("=== Index Store Call Graph Prototype ===\n")

        // Find the Xcode index store
        let derivedDataBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let fm = FileManager.default

        // Find the DerivedData dir that has an index
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataBase.path) else {
            print("ERROR: Could not read DerivedData directory")
            return
        }

        var indexStorePath: URL?
        for dir in contents where dir.hasPrefix("ListAll-") {
            let candidate = derivedDataBase
                .appendingPathComponent(dir)
                .appendingPathComponent("Index.noindex/DataStore")
            if fm.fileExists(atPath: candidate.appendingPathComponent("v5").path) {
                indexStorePath = candidate
                break
            }
        }

        guard let indexStorePath else {
            print("ERROR: Could not find ListAll index store")
            return
        }

        print("Index store: \(indexStorePath.path)")

        let store = try IndexStore(path: indexStorePath.path)

        // Count units
        var unitCount = 0
        var swiftUnits = 0
        for unit in store.units {
            unitCount += 1
            if unit.mainFile.hasSuffix(".swift") { swiftUnits += 1 }
        }
        print("Total units: \(unitCount), Swift units: \(swiftUnits)\n")

        // Test 1: Find addList function definitions and references
        print("--- Test 1: Find addList references ---")
        var addListDefs: [(file: String, line: Int, name: String)] = []
        var addListRefs: [(file: String, line: Int, name: String, roles: String)] = []

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            let reader = try RecordReader(indexStore: store, recordName: recordName)
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.name.contains("addList(name:)") else { return }

                if occurrence.roles.contains(.definition) {
                    addListDefs.append((file: shortFile, line: occurrence.location.line, name: sym.name))
                }
                if occurrence.roles.contains(.reference) {
                    let roleStr = describeRoles(occurrence.roles)
                    addListRefs.append((file: shortFile, line: occurrence.location.line, name: sym.name, roles: roleStr))
                }
            })
        }

        print("  Definitions: \(addListDefs.count)")
        for def in addListDefs.prefix(5) {
            print("    DEF: \(def.name) at \(def.file):\(def.line)")
        }
        print("  References: \(addListRefs.count)")
        for ref in addListRefs.prefix(10) {
            print("    REF [\(ref.roles)]: at \(ref.file):\(ref.line)")
        }
        print()

        // Test 2: Find callers of addList using relations
        print("--- Test 2: Call relations for addList ---")
        for unit in store.units {
            guard unit.mainFile.contains("MainViewModel.swift"),
                  let recordName = unit.recordName else { continue }
            let reader = try RecordReader(indexStore: store, recordName: recordName)

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.name.contains("addList(name:)"),
                      occurrence.roles.contains(.definition) else { return }

                print("  Definition: \(sym.name) (kind: \(sym.kind), usr: \(sym.usr))")

                var relCount = 0
                occurrence.forEach(relation: { relSym, relRoles in
                    relCount += 1
                    print("    Relation: \(relSym.name) [\(describeRoles(relRoles))]")
                })
                if relCount == 0 {
                    print("    No relations on definition")
                }
            })
        }
        print()

        // Test 3: Find all call-site references with their containing functions
        print("--- Test 3: Who calls addList? (via containedBy relations) ---")
        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            let reader = try RecordReader(indexStore: store, recordName: recordName)
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.name.contains("addList(name:)"),
                      occurrence.roles.contains(.call) || occurrence.roles.contains(.reference) else { return }

                var callerName = "?"
                occurrence.forEach(relation: { relSym, relRoles in
                    if relRoles.contains(.calledBy) || relRoles.contains(.containedBy) {
                        callerName = relSym.name
                    }
                })

                print("  CALL: \(sym.name) at \(shortFile):\(occurrence.location.line) from \(callerName)")
            })
        }
        print()

        // Test 4: Outgoing calls from addList
        print("--- Test 4: What does addList call? ---")
        for unit in store.units {
            guard unit.mainFile.contains("MainViewModel.swift"),
                  let recordName = unit.recordName else { continue }
            let reader = try RecordReader(indexStore: store, recordName: recordName)

            // Find all call-type occurrences that have a calledBy relation to addList
            reader.forEach(occurrence: { occurrence in
                guard occurrence.roles.contains(.call) else { return }

                occurrence.forEach(relation: { relSym, relRoles in
                    if relRoles.contains(.calledBy) && relSym.name.contains("addList(name:)") {
                        print("  CALLS: \(occurrence.symbol.name) at line \(occurrence.location.line)")
                    }
                })
            })
        }
        print()

        // Test 5: Available role combinations
        print("--- Test 5: Unique role combinations in MainViewModel ---")
        var allRoles: Set<String> = []
        for unit in store.units {
            guard unit.mainFile.contains("MainViewModel.swift"),
                  let recordName = unit.recordName else { continue }
            let reader = try RecordReader(indexStore: store, recordName: recordName)
            reader.forEach(occurrence: { occurrence in
                allRoles.insert(describeRoles(occurrence.roles))
            })
            break
        }
        for role in allRoles.sorted() {
            print("  \(role)")
        }

        print("\n=== Done ===")
    }
}

func describeRoles(_ roles: SymbolRoles) -> String {
    var parts: [String] = []
    if roles.contains(.declaration) { parts.append("declaration") }
    if roles.contains(.definition) { parts.append("definition") }
    if roles.contains(.reference) { parts.append("reference") }
    if roles.contains(.read) { parts.append("read") }
    if roles.contains(.write) { parts.append("write") }
    if roles.contains(.call) { parts.append("call") }
    if roles.contains(.dynamic) { parts.append("dynamic") }
    if roles.contains(.addressOf) { parts.append("addressOf") }
    if roles.contains(.implicit) { parts.append("implicit") }
    if roles.contains(.childOf) { parts.append("childOf") }
    if roles.contains(.baseOf) { parts.append("baseOf") }
    if roles.contains(.overrideOf) { parts.append("overrideOf") }
    if roles.contains(.receivedBy) { parts.append("receivedBy") }
    if roles.contains(.calledBy) { parts.append("calledBy") }
    if roles.contains(.extendedBy) { parts.append("extendedBy") }
    if roles.contains(.accessorOf) { parts.append("accessorOf") }
    if roles.contains(.containedBy) { parts.append("containedBy") }
    if roles.contains(.specializationOf) { parts.append("specializationOf") }
    if parts.isEmpty { return "none(\(roles.rawValue))" }
    return parts.joined(separator: ",")
}
