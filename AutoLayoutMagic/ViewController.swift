//
//  ViewController.swift
//  AutoLayoutMagic
//
//  Created by Matt Cielecki on 5/3/16.
//  Copyright © 2016 Matt Cielecki. All rights reserved.
//
//  https://github.com/akordadev/AutoLayoutMagic/

import Cocoa
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


struct Rectangle {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

//Class because structs don't allow recursive pointers (View -> View)
class View {
    let id: String
    var usingAspectRatio: Bool = false
    var rect: Rectangle?
    //Watch out for circular references
    var childViews: [View] = []
    var parentView: View?
    
    init(id: String) {
        self.id = id
    }
}

class ViewController: NSViewController, XMLParserDelegate {

    @IBOutlet weak var filePathTextField: NSTextField!
    @IBOutlet weak var aspectRatioCheckBox: NSButton!
    @IBOutlet weak var widthRadioButton: NSButton!
    @IBOutlet weak var heightRadioButton: NSButton!
    
    //Used to assign a new parent, when encountering a </subviews>
    var currentView: View? = nil
    //might not need parent, consider refactoring???
    var parentView: View? = nil
    var currentNode = XMLElement(name: "document")
    var outputXml: XMLDocument!
    var parser = XMLParser()
    var aspectRatioHeight = true
    
    let supportedViews = ["view", "imageView", "label", "button"]
    
    fileprivate func beginParsing() {
        
        outputXml = XMLDocument()
        outputXml.version = "1.0"
        outputXml.characterEncoding = "UTF-8"
        
        guard let filePath = filePathTextField.accessibilityValue() else {
            return
        }
        guard let xmlFile = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            let alert = NSAlert()
            alert.alertStyle = NSAlertStyle.critical
            alert.messageText = "File not found"
            alert.addButton(withTitle: "Let me double check")
            alert.runModal()
            return
        }
        parser = XMLParser(data: xmlFile)
        parser.delegate = self
        parser.parse()
        
        let prettyOutput = outputXml.xmlString(withOptions: Int(XMLNode.Options.nodePrettyPrint.rawValue))
        
        //create file
        let fileManager = FileManager()
        fileManager.createFile(atPath: filePath, contents: prettyOutput.data(using: String.Encoding.utf8), attributes: nil)
    }
    
    // MARK: IBActions
    
    @IBAction func aspectRatioCheck(_ sender: NSButton) {
        widthRadioButton.isEnabled = aspectRatioCheckBox.state == NSOnState
        heightRadioButton.isEnabled = aspectRatioCheckBox.state == NSOnState
    }
    
    @IBAction func generateLayoutButtonPressed(_ sender: NSButton) {
        beginParsing()
    }
    
    @IBAction func heightRadioSelected(_ sender: NSButton) {
        widthRadioButton.state = NSOffState
        heightRadioButton.state = NSOnState
        aspectRatioHeight = true
    }
    
    @IBAction func widthRadioSelected(_ sender: NSButton) {
        widthRadioButton.state = NSOnState
        heightRadioButton.state = NSOffState
        aspectRatioHeight = false
    }
    
    fileprivate func generateConstraints(_ currentView: View, constraintParentNode: XMLElement) {
        // 4 constraints per child view
        for index in 1...4 {
            let constraintChild = XMLElement(name: "constraint")
            var attributeData: [String : String] = [:]
            //width
            switch index {
            case 1:
                //WIDTH
                if !currentView.usingAspectRatio || !aspectRatioHeight {
                    attributeData["firstItem"] = currentView.id
                    attributeData["firstAttribute"] = "width"
                    attributeData["secondItem"] = currentView.parentView?.id
                    attributeData["secondAttribute"] = "width"
                    attributeData["multiplier"] = "\(currentView.rect!.width)/\(currentView.parentView!.rect!.width)"
                    attributeData["id"] = generateGUID()
                }
                else {
                    continue
                }
            case 2:
                //HEIGHT
                if !currentView.usingAspectRatio || aspectRatioHeight {
                    attributeData["firstItem"] = currentView.id
                    attributeData["firstAttribute"] = "height"
                    attributeData["secondItem"] = currentView.parentView?.id
                    attributeData["secondAttribute"] = "height"
                    attributeData["multiplier"] = "\(currentView.rect!.height)/\(currentView.parentView!.rect!.height)"
                    attributeData["id"] = generateGUID()
                }
                else {
                    continue
                }
            case 3:
                //TRAILING
                if currentView.rect?.x <= 0 {
                    //<constraint firstItem="CHILD ID" firstAttribute="leading" secondItem="PARENT ID" secondAttribute="leading" id="yx8-GH-Noo"/>
                    attributeData["firstItem"] = currentView.id
                    attributeData["firstAttribute"] = "leading"
                    attributeData["secondItem"] = currentView.parentView?.id
                    attributeData["secondAttribute"] = "leading"
                    attributeData["id"] = generateGUID()
                }
                else {
                    attributeData["firstAttribute"] = "trailing"
                    attributeData["secondItem"] = currentView.id
                    attributeData["secondAttribute"] = "leading"
                    //Using ! due to string output being "Optional(132)" instead of "132"
                    attributeData["multiplier"] = "\(currentView.parentView!.rect!.width)/\(currentView.rect!.x)"
                    attributeData["id"] = generateGUID()
                }
            case 4:
                //BOTTOM
                if currentView.rect?.y <= 0 {
                    attributeData["firstItem"] = currentView.id
                    attributeData["firstAttribute"] = "top"
                    attributeData["secondItem"] = currentView.parentView?.id
                    attributeData["secondAttribute"] = "top"
                    attributeData["id"] = generateGUID()
                }
                else {
                    attributeData["firstAttribute"] = "bottom"
                    attributeData["secondItem"] = currentView.id
                    attributeData["secondAttribute"] = "top"
                    attributeData["multiplier"] = "\(currentView.parentView!.rect!.height)/\(currentView.rect!.y)"
                    attributeData["id"] = generateGUID()
                }
            default:
                assert(true, "shouldn't be any other case other than 1...4")
            }
            for attribute in attributeData {
                let XMLattribute = XMLNode(kind: .attribute)
                XMLattribute.name = attribute.0
                XMLattribute.stringValue = attribute.1
                constraintChild.addAttribute(XMLattribute)
            }
            constraintParentNode.addChild(constraintChild)
            attributeData = [:]
        }
    }
    
    fileprivate func generateGUID() -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for index in (1...10) {
            if index == 4 || index == 7 {
                randomString += "-"
            }
            else {
                let randomNum = Int(arc4random_uniform(allowedCharsCount))
                let newCharacter = allowedChars[allowedChars.characters.index(allowedChars.startIndex, offsetBy: randomNum)]
                randomString += String(newCharacter)
            }
        }
        return randomString
    }
    
    // MARK:  NSXMLParserDelegate Functions
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {

        let newChild = XMLElement(name: elementName)
        
        for (key, value) in attributeDict {
            if elementName == "label" && (key == "baselineAdjustment" || key == "adjustsFontSizeToFit") {
                continue
            }
            let attribute = XMLNode(kind: .attribute)
            attribute.name = key
            attribute.stringValue = value
            newChild.addAttribute(attribute)
        }
        // Add child to correct element node
        if elementName == "document" {
            outputXml.addChild(newChild)
        }
        else {
            currentNode.addChild(newChild)
        }
        
        // encountering a <view> or <imageView> etc...
        if supportedViews.contains(elementName) {
            if let id = attributeDict["id"] {
                let view = View(id: id)
                if let parentView = parentView {
                    parentView.childViews.append(view)
                }
                currentView = view
                currentView?.parentView = parentView
                if elementName == "label" {
                    let XMLattribute = XMLNode(kind: .attribute)
                    XMLattribute.name = "minimumScaleFactor"
                    XMLattribute.stringValue = "0.4"
                    newChild.addAttribute(XMLattribute)
                    if aspectRatioCheckBox.state == NSOnState {
                        currentView?.usingAspectRatio = true
                    }
                }
            }
        }
        else if elementName == "subviews" {
            //we are going deeper in the tree
            parentView = currentView
        }
        //should be next element right after "view"
        else if elementName == "rect" {
            if let parent = newChild.parent,
                    let parentName = parent.name, supportedViews.contains(parentName)
            {
                //Float cast due to "0.0" in some X,Y coords in .storyboard file
                if let x = Float(attributeDict["x"]!),
                        let y = Float(attributeDict["y"]!),
                        let width = Int(attributeDict["width"]!),
                        let height = Int(attributeDict["height"]!)
                {
                    let rect = Rectangle(x: Int(x), y: Int(y), width: width, height: height)
                    currentView?.rect = rect
                }
            }
        }
        
        // for determining if buttons have a BG image, therefore should use aspect ratio
        else if elementName == "state" {
            if let parent = newChild.parent,
                let parentName = parent.name, parentName == "button"
            {
                if let _ = attributeDict["image"] {
                    currentView?.usingAspectRatio = true
                }
            }
        }
        
        currentNode = newChild
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        if supportedViews.contains(elementName) {
            if let currentView = currentView, currentView.childViews.count > 0 {
                //add constraints
                let constraintParent = XMLElement(name: "constraints")
                currentNode.addChild(constraintParent)
                for childView in currentView.childViews {
                    generateConstraints(childView, constraintParentNode: constraintParent)
                }
            }
            
            //aspect ratio
            else {
                // <constraint firstAttribute="width" secondItem="Xf3-5x-I0k" secondAttribute="height" multiplier="5:2" id="LdZ-O7-Tcn"/>
                if let currentView = currentView, currentView.usingAspectRatio {
                    let constraintParent = XMLElement(name: "constraints")
                    currentNode.addChild(constraintParent)
                    let constraintChild = XMLElement(name: "constraint")
                    var attributeData: [String : String] = [:]
                    attributeData["firstAttribute"] = "width"
                    attributeData["secondItem"] = currentView.id
                    attributeData["secondAttribute"] = "height"
                    attributeData["multiplier"] = "\(currentView.rect!.width):\(currentView.rect!.height)"
                    attributeData["id"] = generateGUID()
                    
                    for attribute in attributeData {
                        let XMLattribute = XMLNode(kind: .attribute)
                        XMLattribute.name = attribute.0
                        XMLattribute.stringValue = attribute.1
                        constraintChild.addAttribute(XMLattribute)
                    }
                    constraintParent.addChild(constraintChild)
                }
            }
        }
        if elementName == "subviews" {
            //we are going up in the tree
            currentView = currentView?.parentView
            parentView = currentView?.parentView
            
        }
        if let parent = currentNode.parent as? XMLElement {
            currentNode = parent
        }
    }
}

