//
//  NMOutlineView.swift
//
//  Created by Greg Kopel on 11/05/2017.
//  Copyright © 2017 Netmedia. All rights reserved.
//

import UIKit
import os

@objc protocol NMOutlineViewDatasource {
    func outlineView(_ outlineView: NMOutlineView, numberOfChildrenOfCell parentCell: NMOutlineViewCell?) -> Int
    func outlineView(_ outlineView: NMOutlineView, isCellExpandable cell: NMOutlineViewCell) -> Bool
    func outlineView(_ outlineView: NMOutlineView, childCell index: Int, ofParentAtIndexPath parentIndexPath: IndexPath?) -> NMOutlineViewCell
    func outlineView(_ outlineView: NMOutlineView, didSelectCell cell: NMOutlineViewCell);
}


// MARK: -
@IBDesignable @objcMembers class NMOutlineView: UIView {
    
    // MARK: Properties
    
    // Indentation width
    static let nmIndentationWidth = CGFloat(30.0)
    
    // Expand / collapse button settings
    static let buttonSize = CGSize(width:28.0, height: 26.0)
    //    static let buttonLabel = "▷"
    static let buttonColor = UIColor.secondaryLabel
    static let buttonImage = UIImage(systemName: "arrowtriangle.right.fill")
    static let buttonExpandedImage = UIImage(systemName: "arrowtriangle.down.fill")
    
    // Datasource for internal tableview
    @IBOutlet weak var datasource: NMOutlineViewDatasource? {
        didSet {
            // Setup initial state
            if let datasource = datasource {
                let rootItemsCount = datasource.outlineView(self, numberOfChildrenOfCell: nil)
                for index in 0 ..< rootItemsCount {
                    let item = NMItem(withIndexPath: IndexPath(index:index))
                    tableViewDatasource.append(item)
                }
            }
        }
    }
    
    
    // Private properties
    static let cellIdentifier = "CellIdentifier"
    @IBOutlet var tableView: UITableView!
    var tableViewDatasource = [NMItem]()
    
    
    // MARK: Initializers
    
    func sharedInit() {
        self.tableView = UITableView()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .none
        tableView.register(NMOutlineViewCell.self, forCellReuseIdentifier: NMOutlineView.cellIdentifier)
        self.addSubview(tableView)
        self.tableView.separatorInset = .zero
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    
    // MARK: Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.tableView?.frame = bounds
    }
    
    
    // MARK: NMOutlineView methods
    
    public func dequeReusableCell(withIdentifier identifier: String, style: UITableViewCell.CellStyle) -> NMOutlineViewCell {
        if let cell = self.tableView.dequeueReusableCell(withIdentifier: identifier) as? NMOutlineViewCell {
            return cell
        } else {
            let cell = NMOutlineViewCell(style: style, reuseIdentifier: identifier)
            return cell
        }
    }
    
    
    func toggleChildCellsOf(_ cell: NMOutlineViewCell, atIndex index: Int) {
        
        guard let datasource = self.datasource else {
            return
        }
        
        let cellItem = tableViewDatasource[index]
        
        if cellItem.isExpanded {
            // Collapse
            let childrenCount = datasource.outlineView(self, numberOfChildrenOfCell:cell)
            if childrenCount > 0 {
                cellItem.isExpanded = false
                
                while tableViewDatasource.count > index + 1 && tableViewDatasource[index+1].indexPath.count > cellItem.indexPath.count  {
                    tableViewDatasource.remove(at: index+1)
                    let tableViewIndexPath = IndexPath(row: index+1, section: 0)
                    self.tableView.beginUpdates()
                    self.tableView.deleteRows(at: [tableViewIndexPath], with: .fade)
                    self.tableView.endUpdates()
                }
            } else {
                os_log("ERROR: NMOutlineView cell is NOT collapsable")
            }
        } else {
            // Expand
            if datasource.outlineView(self, isCellExpandable: cell) {
                cellItem.isExpanded = true
                let childrenCount = datasource.outlineView(self, numberOfChildrenOfCell:cell)
                let cellItemIndexPath = cellItem.indexPath
                for childIndex in 0..<childrenCount {
                    var itemIndexPath = IndexPath(indexes: cellItemIndexPath)
                    itemIndexPath.append(childIndex)
                    let item = NMItem(withIndexPath: itemIndexPath)
                    tableViewDatasource.insert(item, at: index + childIndex + 1)
                    let tableViewIndexPath = IndexPath(row: index + childIndex + 1, section: 0)
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [tableViewIndexPath], with: .fade)
                    self.tableView.endUpdates()
                }
            } else {
                os_log("ERROR: NMOutlineView cell is NOT expandable")
            }
        }
    }
    
    // Single item in the collection
    public final class NMItem {
        var indexPath: IndexPath
        var isExpanded = false
        
        public init(withIndexPath indexPath: IndexPath) {
            self.indexPath = indexPath
        }
    }
}


// MARK: - Internal TableView datasource/delegate

extension NMOutlineView: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewDatasource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let datasource = self.datasource else {
            os_log("ERROR: no NMOutlineView datasource defined.")
            return NMOutlineViewCell(style: .default, reuseIdentifier: "ErrorCell")
        }
        
        let item = tableViewDatasource[indexPath.row]
        var theCell: NMOutlineViewCell
        if item.indexPath.count > 1, let childIndex = item.indexPath.last {
            // Cell that has a parent
            let parentIndexPath = item.indexPath.dropLast()
            theCell = datasource.outlineView(self, childCell: childIndex, ofParentAtIndexPath: parentIndexPath)
            
        } else if let rootIndex = item.indexPath.first {
            // Root level cell
            theCell = datasource.outlineView(self, childCell: rootIndex, ofParentAtIndexPath: nil)
        } else {
            // Shouldn't get there
            os_log("ERROR: no NMOutlineView cell found")
            theCell = NMOutlineViewCell(style: .default, reuseIdentifier: "ErrorCell")
        }
        
        theCell.indentationLevel = item.indexPath.count - 1
        theCell.toggleButton.isHidden = !datasource.outlineView(self, isCellExpandable: theCell)
        theCell.updateState(item.isExpanded, animated: false)
        
        theCell.onToggle = { (sender) in
            if let toggledCellPath = self.tableView.indexPath(for: theCell) {
                self.toggleChildCellsOf(theCell, atIndex: toggledCellPath.row)
            } else {
                os_log("ERROR: NMOutlineView cell path is nil")
            }
        }
        
        return theCell
        
    }
     
    func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
         let item = tableViewDatasource[indexPath.row]
         return item.indexPath.count - 1
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let datasource = self.datasource else {
            os_log("ERROR: no NMOutlineView datasource defined.")
            return
        }
        
        if let cell = tableView.cellForRow(at: indexPath) as? NMOutlineViewCell {
            datasource.outlineView(self, didSelectCell: cell)
        }
        
    }
}





