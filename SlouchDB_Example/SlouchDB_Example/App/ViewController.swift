//
//  ViewController.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/5/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    private var _document: Document?
    var document: Document? {
        get {
            if _document == nil {
                _document = self.view.window?.windowController?.document as? Document
                
                setupNotifications()
            }
            return _document
        }
    }
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var folderButton: NSButton!
    
    var remoteFolder: URL?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupNotifications() {
        guard let document = _document else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(didInsertPeople(_:)), name: .didInsertPeople, object: document.databaseController)
        NotificationCenter.default.addObserver(self, selector: #selector(didModifyPeople(_:)), name: .didModifyPeople, object: document.databaseController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        tableView.reloadData()
    }
    
    @IBAction func didTapAddPerson(sender: Any) {
        guard let document = document else { return }
        
        let randomNames = ["Alice", "Bob", "Carol", "Eve", "Frank"]
        let name = randomNames[ Int(arc4random()) % randomNames.count ]
        let weight = Int(arc4random() % 100) + 100
        let age = Int(arc4random() % 30) + 10

        let person = Person(identifier: UUID().uuidString, name: name, weight: weight, age: age)
        document.add(person: person)
    }

    @IBAction func didTapSync(sender: Any) {
        guard let document = document else { return }
        
        if let remoteFolder = remoteFolder {
            document.sync(remoteFolderURL: remoteFolder)
        }
    }

    @IBAction func didTapSelectFolder(sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.begin(completionHandler: { result in
            if result.rawValue == NSFileHandlingPanelOKButton {
                
                let remoteURL = openPanel.urls.first
                self.remoteFolder = remoteURL
                
                DispatchQueue.main.async {
                    self.folderButton.title = remoteURL?.path ?? "Select Folder"
                }
            }
        })
    }
    
    @IBAction func didTapCycle(sender: Any) {
        guard let document = document else { return }
        
        document.cycleLocalIdentifier()
    }
}

extension ViewController: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        guard let document = document else { return 0 }

        return document.people.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let document = document else { return nil }
        
        let person = document.people[row]
        if tableColumn!.identifier.rawValue == Person.namePropertyKey {
            return person.name
        } else if tableColumn!.identifier.rawValue == Person.weightPropertyKey {
            return person.weight
        } else if tableColumn!.identifier.rawValue == Person.agePropertyKey {
            return person.age
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let document = document else { return }

        var person = document.people[row]
        if let value = object as? String {
            if tableColumn!.identifier.rawValue == Person.namePropertyKey {
                person.name = value
                
                document.modifyPerson(identifier: person.identifier, properties: [Person.namePropertyKey : value])
            } else if tableColumn!.identifier.rawValue == Person.weightPropertyKey {
                if let weight = Int(value) {
                    person.weight = weight
                    document.modifyPerson(identifier: person.identifier, properties: [Person.weightPropertyKey : "\(weight)"])
                }
            } else if tableColumn!.identifier.rawValue == Person.agePropertyKey {
                if let age = Int(value) {
                    person.age = age
                    document.modifyPerson(identifier: person.identifier, properties: [Person.agePropertyKey : "\(age)"])
                }
            }
        }
    }
}

extension ViewController {
    @objc func didInsertPerson(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let index = userInfo["index"] as! Int
            let indexSet = IndexSet(integer: index)
            tableView.beginUpdates()
            tableView.insertRows(at: indexSet, withAnimation: .slideDown)
            tableView.endUpdates()
        }
    }

    @objc func didModifyPerson(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let index = userInfo["index"] as! Int
            let indexSet = IndexSet(integer: index)
            
            let allColumns = IndexSet(integersIn: 0...2)

            tableView.beginUpdates()
            tableView.reloadData(forRowIndexes: indexSet, columnIndexes: allColumns)
            tableView.endUpdates()
        }
    }

    @objc func didInsertPeople(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let range = userInfo["range"] as! Range<Int>
            let indexSet = IndexSet(integersIn: range)
            
            tableView.beginUpdates()
            tableView.insertRows(at: indexSet, withAnimation: .slideDown)
            tableView.endUpdates()
        }
    }

    @objc func didModifyPeople(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            // Which properties were modified for each row
            let modifiedProperties = userInfo["properties"] as! [ [String] ]
            let columnIndexMap: [String : Int] = [Person.namePropertyKey   : 0,
                                                  Person.weightPropertyKey : 1,
                                                  Person.agePropertyKey    : 2]
            let rows = userInfo["indexes"] as! [Int]

            
            tableView.beginUpdates()
            
            for i in 0..<rows.count {
                let row = rows[i]
                var indexSet = IndexSet()
                indexSet.insert(row)

                let modifiedPropertiesForRow = modifiedProperties[i]
                let columnIndexes = modifiedPropertiesForRow.map { columnIndexMap[$0] }.filter { $0 != nil } as! [Int]
                
                var columnIndexSet = IndexSet()
                for columnIndex in columnIndexes {
                    columnIndexSet.insert(columnIndex)
                }

                tableView.reloadData(forRowIndexes: indexSet, columnIndexes: columnIndexSet)
            }
            
            tableView.endUpdates()
        }
    }
}
