//
//  ViewController.swift
//  AutoLayoutMagic
//
//  Created by Matt Cielecki on 5/3/16.
//  Copyright © 2016 Matt Cielecki. All rights reserved.
//

// THIS DOES NOT WORK FOR VIEWS THAT HAVE NEGATIVE COORDS

// Coming features
//    Support negative coords
//    Auto set min font size, and Align centers, for labels

import Cocoa

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

class ViewController: NSViewController, NSXMLParserDelegate {

    @IBOutlet weak var filePathTextField: NSTextField!
    @IBOutlet weak var viewTextField: NSTextField!
    
    //Used to assign a new parent, when encountering a </subviews>
    var currentView: View? = nil
    //might not need parent, consider refactoring???
    var parentView: View? = nil
    var currentNode = NSXMLElement(name: "document")
    var outputXml: NSXMLDocument!
    var parser = NSXMLParser()
    
    let supportedViews = ["view", "imageView", "label", "button"]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outputXml = NSXMLDocument()
        outputXml.version = "1.0"
        outputXml.characterEncoding = "UTF-8"
        // Do any additional setup after loading the view.
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    private func beginParsing() {
        let filePath = "/Users/mcielecki/Code/storybots-ios/Storybots/Base.lproj/Test.storyboard"
        let xmlFile = NSData(contentsOfFile: filePath)
        parser = NSXMLParser(data: xmlFile!)
        parser.delegate = self
        parser.parse()
        
        //pretty print XML for debug
        let prettyOutput = outputXml.XMLStringWithOptions(Int(NSXMLNodePrettyPrint))
        print(prettyOutput)
        
        //create file
        let fileManager = NSFileManager()
        fileManager.createFileAtPath("/Users/mcielecki/Code/storybots-ios/Storybots/Base.lproj/MCTest.storyboard", contents: prettyOutput.dataUsingEncoding(NSUTF8StringEncoding), attributes: nil)
    }
    
    @IBAction func generateLayoutButtonPressed(sender: AnyObject) {
        beginParsing()
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {

        let newChild = NSXMLElement(name: elementName)
        
        for (key, value) in attributeDict {
            let attribute = NSXMLNode(kind: .AttributeKind)
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
                if elementName == "imageView" {
                    currentView?.usingAspectRatio = true
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
                    parentName = parent.name where supportedViews.contains(parentName)
            {
                //Float cast due to "0.0" in some X,Y coords in .storyboard file
                if let x = Float(attributeDict["x"]!),
                        y = Float(attributeDict["y"]!),
                        width = Int(attributeDict["width"]!),
                        height = Int(attributeDict["height"]!)
                {
                    let rect = Rectangle(x: Int(x), y: Int(y), width: width, height: height)
                    currentView?.rect = rect
                }
            }
        }
        
        // for determining if buttons have a BG image, therefore should use aspect ratio
        else if elementName == "state" {
            if let parent = newChild.parent,
                parentName = parent.name where parentName == "button"
            {
                if let _ = attributeDict["image"] {
                    currentView?.usingAspectRatio = true
                }
            }
        }
        
        currentNode = newChild
    }

    // didEndElement
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        if supportedViews.contains(elementName) {
            if let currentView = currentView where currentView.childViews.count > 0 {
                //add constraints
                let constraintParent = NSXMLElement(name: "constraints")
                currentNode.addChild(constraintParent)
                for childView in currentView.childViews {
                    generateConstraints(childView, constraintParentNode: constraintParent)
                }
            }
            
            //aspect ratio
            else {
                // <constraint firstAttribute="width" secondItem="Xf3-5x-I0k" secondAttribute="height" multiplier="5:2" id="LdZ-O7-Tcn"/>
                if let currentView = currentView where currentView.usingAspectRatio {
                    let constraintParent = NSXMLElement(name: "constraints")
                    currentNode.addChild(constraintParent)
                    let constraintChild = NSXMLElement(name: "constraint")
                    var attributeData: [String : String] = [:]
                    attributeData["firstAttribute"] = "width"
                    attributeData["secondItem"] = currentView.id
                    attributeData["secondAttribute"] = "height"
                    attributeData["multiplier"] = "\(currentView.rect!.width):\(currentView.rect!.height)"
                    attributeData["id"] = generateGUID()
                    
                    for attribute in attributeData {
                        let XMLattribute = NSXMLNode(kind: .AttributeKind)
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
        if let parent = currentNode.parent as? NSXMLElement {
            currentNode = parent
        }
    }
    
    private func generateConstraints(currentView: View, constraintParentNode: NSXMLElement) {
        // 4 constraints per child view
        for index in 1...4 {
            let constraintChild = NSXMLElement(name: "constraint")
            var attributeData: [String : String] = [:]
            //width
            switch index {
            case 1:
                //WIDTH
                // only if not using aspect ratio
                if !currentView.usingAspectRatio {
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
                attributeData["firstItem"] = currentView.id
                attributeData["firstAttribute"] = "height"
                attributeData["secondItem"] = currentView.parentView?.id
                attributeData["secondAttribute"] = "height"
                attributeData["multiplier"] = "\(currentView.rect!.height)/\(currentView.parentView!.rect!.height)"
                attributeData["id"] = generateGUID()
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
                if currentView.rect?.y == 0 {
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
                let XMLattribute = NSXMLNode(kind: .AttributeKind)
                XMLattribute.name = attribute.0
                XMLattribute.stringValue = attribute.1
                constraintChild.addAttribute(XMLattribute)
            }
            constraintParentNode.addChild(constraintChild)
            attributeData = [:]
        }
    }
    
    private func generateGUID() -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for index in (1...10) {
            if index == 4 || index == 7 {
                randomString += "-"
            }
            else {
                let randomNum = Int(arc4random_uniform(allowedCharsCount))
                let newCharacter = allowedChars[allowedChars.startIndex.advancedBy(randomNum)]
                randomString += String(newCharacter)
            }
        }
        return randomString
    }
}

