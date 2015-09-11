// SimpleSVG Copyright (c) 2015 Nicholas Devenish
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import CoreGraphics
import GLKit

typealias SVGPoint = GLKVector3
typealias SVGMatrix = GLKMatrix3

/// The public face of the module. Loads an SVGFile and has options for rendering
public class SVGImage {
  let svg : SVGContainer
  
  public init(withContentsOfFile file : NSURL) {
    // Read the file
    let data = NSData(contentsOfURL: file)!
    let parser = Parser(data: data)
    svg = parser.parse() as! SVGContainer
  }
  
  public func drawToContext(context : CGContextRef) {
    svg.drawToContext(context)
  }
  
  public func drawIdToContext(context : CGContextRef, id : String) {
    let elem = svg.findWithID(id)
    let boundingBox = elem?.boundingBox
    elem?.drawToContext(context)
  }
}

/// A function that will take an XML attribute entry and convert it
private typealias Converter = (String) -> Any

// MARK: Parser Configuration and which entities are handled

/// Which parsers handle different data types
private let parserMap : [String : Converter] = [
  "<length>": parseLength,
  "<coord>":  parseLength,
  "<paint>":  parsePaint,
  "<path-data>": parsePath,
  "<list-of-points>": parseListOfPoints,
  "<transform>": parseTransform,
]

/// Which attribute names hold which different data types
private let dataTypesForAttributeNames : [String:[String]] = [
  "<paint>": ["fill", "stroke"],
  "<length>": ["width", "height", "rx", "ry", "r", "stroke-width"],
  "<coord>": ["x", "y", "cx", "cy", "x1", "y1", "x2", "y2"],
  "<list-of-points>": ["points"],
  "<path-data>": ["d"],
  "<transform>": ["transform"],
]

/// Which SVG entity to create for a particular XML tag name
private let tagCreationMap : [String : () -> SVGElement] = [
  "svg": { SVGContainer() },
  "g"  : { SVGGroup() },
  "circle": { Circle() },
  "line": { Line() },
  "polygon": { Polygon() },
  "ellipse": { Ellipse() },
  "rect": { Rect() },
  "polyline": { PolyLine() },
  "path": { Path() },
]

/// Get the parser conversion function for a particular element and attribute
private func getParserFor(elem: String, attr : String) -> Converter? {
  for (parsetype, names) in dataTypesForAttributeNames {
    if names.contains(attr) {
      if let fn = parserMap[parsetype] {
        return fn
      }
    }
  }
  return nil
}

// SVG Color names
private let svgColorNames = [
  "red":       "rgb(255, 0, 0)",     "lightgray":            "rgb(211, 211, 211)",
  "tan":       "rgb(210, 180, 140)", "lightgrey":            "rgb(211, 211, 211)",
  "aqua":      "rgb( 0, 255, 255)",  "lightpink":            "rgb(255, 182, 193)",
  "blue":      "rgb( 0, 0, 255)",    "limegreen":            "rgb( 50, 205, 50)",
  "cyan":      "rgb( 0, 255, 255)",  "mintcream":            "rgb(245, 255, 250)",
  "gold":      "rgb(255, 215, 0)",   "mistyrose":            "rgb(255, 228, 225)",
  "gray":      "rgb(128, 128, 128)", "olivedrab":            "rgb(107, 142, 35)",
  "grey":      "rgb(128, 128, 128)", "orangered":            "rgb(255, 69, 0)",
  "lime":      "rgb( 0, 255, 0)",    "palegreen":            "rgb(152, 251, 152)",
  "navy":      "rgb( 0, 0, 128)",    "peachpuff":            "rgb(255, 218, 185)",
  "peru":      "rgb(205, 133, 63)",  "rosybrown":            "rgb(188, 143, 143)",
  "pink":      "rgb(255, 192, 203)", "royalblue":            "rgb( 65, 105, 225)",
  "plum":      "rgb(221, 160, 221)", "slateblue":            "rgb(106, 90, 205)",
  "snow":      "rgb(255, 250, 250)", "slategray":            "rgb(112, 128, 144)",
  "teal":      "rgb( 0, 128, 128)",  "slategrey":            "rgb(112, 128, 144)",
  "azure":     "rgb(240, 255, 255)", "steelblue":            "rgb( 70, 130, 180)",
  "beige":     "rgb(245, 245, 220)", "turquoise":            "rgb( 64, 224, 208)",
  "black":     "rgb( 0, 0, 0)",      "aquamarine":           "rgb(127, 255, 212)",
  "brown":     "rgb(165, 42, 42)",   "blueviolet":           "rgb(138, 43, 226)",
  "coral":     "rgb(255, 127, 80)",  "chartreuse":           "rgb(127, 255, 0)",
  "green":     "rgb( 0, 128, 0)",    "darkorange":           "rgb(255, 140, 0)",
  "ivory":     "rgb(255, 255, 240)", "darkorchid":           "rgb(153, 50, 204)",
  "khaki":     "rgb(240, 230, 140)", "darksalmon":           "rgb(233, 150, 122)",
  "linen":     "rgb(250, 240, 230)", "darkviolet":           "rgb(148, 0, 211)",
  "olive":     "rgb(128, 128, 0)",   "dodgerblue":           "rgb( 30, 144, 255)",
  "wheat":     "rgb(245, 222, 179)", "ghostwhite":           "rgb(248, 248, 255)",
  "white":     "rgb(255, 255, 255)", "lightcoral":           "rgb(240, 128, 128)",
  "bisque":    "rgb(255, 228, 196)", "lightgreen":           "rgb(144, 238, 144)",
  "indigo":    "rgb( 75, 0, 130)",   "mediumblue":           "rgb( 0, 0, 205)",
  "maroon":    "rgb(128, 0, 0)",     "papayawhip":           "rgb(255, 239, 213)",
  "orange":    "rgb(255, 165, 0)",   "powderblue":           "rgb(176, 224, 230)",
  "orchid":    "rgb(218, 112, 214)", "sandybrown":           "rgb(244, 164, 96)",
  "purple":    "rgb(128, 0, 128)",   "whitesmoke":           "rgb(245, 245, 245)",
  "salmon":    "rgb(250, 128, 114)", "darkmagenta":          "rgb(139, 0, 139)",
  "sienna":    "rgb(160, 82, 45)",   "deepskyblue":          "rgb( 0, 191, 255)",
  "silver":    "rgb(192, 192, 192)", "floralwhite":          "rgb(255, 250, 240)",
  "tomato":    "rgb(255, 99, 71)",   "forestgreen":          "rgb( 34, 139, 34)",
  "violet":    "rgb(238, 130, 238)", "greenyellow":          "rgb(173, 255, 47)",
  "yellow":    "rgb(255, 255, 0)",   "lightsalmon":          "rgb(255, 160, 122)",
  "crimson":   "rgb(220, 20, 60)",   "lightyellow":          "rgb(255, 255, 224)",
  "darkred":   "rgb(139, 0, 0)",     "navajowhite":          "rgb(255, 222, 173)",
  "dimgray":   "rgb(105, 105, 105)", "saddlebrown":          "rgb(139, 69, 19)",
  "dimgrey":   "rgb(105, 105, 105)", "springgreen":          "rgb( 0, 255, 127)",
  "fuchsia":   "rgb(255, 0, 255)",   "yellowgreen":          "rgb(154, 205, 50)",
  "hotpink":   "rgb(255, 105, 180)", "antiquewhite":         "rgb(250, 235, 215)",
  "magenta":   "rgb(255, 0, 255)",   "darkseagreen":         "rgb(143, 188, 143)",
  "oldlace":   "rgb(253, 245, 230)", "lemonchiffon":         "rgb(255, 250, 205)",
  "skyblue":   "rgb(135, 206, 235)", "lightskyblue":         "rgb(135, 206, 250)",
  "thistle":   "rgb(216, 191, 216)", "mediumorchid":         "rgb(186, 85, 211)",
  "cornsilk":  "rgb(255, 248, 220)", "mediumpurple":         "rgb(147, 112, 219)",
  "darkblue":  "rgb( 0, 0, 139)",    "midnightblue":         "rgb( 25, 25, 112)",
  "darkcyan":  "rgb( 0, 139, 139)",  "darkgoldenrod":        "rgb(184, 134, 11)",
  "darkgray":  "rgb(169, 169, 169)", "darkslateblue":        "rgb( 72, 61, 139)",
  "darkgrey":  "rgb(169, 169, 169)", "darkslategray":        "rgb( 47, 79, 79)",
  "deeppink":  "rgb(255, 20, 147)",  "darkslategrey":        "rgb( 47, 79, 79)",
  "honeydew":  "rgb(240, 255, 240)", "darkturquoise":        "rgb( 0, 206, 209)",
  "lavender":  "rgb(230, 230, 250)", "lavenderblush":        "rgb(255, 240, 245)",
  "moccasin":  "rgb(255, 228, 181)", "lightseagreen":        "rgb( 32, 178, 170)",
  "seagreen":  "rgb( 46, 139, 87)",  "palegoldenrod":        "rgb(238, 232, 170)",
  "seashell":  "rgb(255, 245, 238)", "paleturquoise":        "rgb(175, 238, 238)",
  "aliceblue": "rgb(240, 248, 255)", "palevioletred":        "rgb(219, 112, 147)",
  "burlywood": "rgb(222, 184, 135)", "blanchedalmond":       "rgb(255, 235, 205)",
  "cadetblue": "rgb( 95, 158, 160)", "cornflowerblue":       "rgb(100, 149, 237)",
  "chocolate": "rgb(210, 105, 30)",  "darkolivegreen":       "rgb( 85, 107, 47)",
  "darkgreen": "rgb( 0, 100, 0)",    "lightslategray":       "rgb(119, 136, 153)",
  "darkkhaki": "rgb(189, 183, 107)", "lightslategrey":       "rgb(119, 136, 153)",
  "firebrick": "rgb(178, 34, 34)",   "lightsteelblue":       "rgb(176, 196, 222)",
  "gainsboro": "rgb(220, 220, 220)", "mediumseagreen":       "rgb( 60, 179, 113)",
  "goldenrod": "rgb(218, 165, 32)",  "mediumslateblue":      "rgb(123, 104, 238)",
  "indianred": "rgb(205, 92, 92)",   "mediumturquoise":      "rgb( 72, 209, 204)",
  "lawngreen": "rgb(124, 252, 0)",   "mediumvioletred":      "rgb(199, 21, 133)",
  "lightblue": "rgb(173, 216, 230)", "mediumaquamarine":     "rgb(102, 205, 170)",
  "lightcyan": "rgb(224, 255, 255)", "mediumspringgreen":    "rgb( 0, 250, 154)",
  "lightgoldenrodyellow": "rgb(250, 250, 210)"
]

/// Converts a string in CSS2 form to a CGColor. See
/// http://www.w3.org/TR/SVG/types.html#DataTypeColor
private func CGColorCreateFromString(string : String) -> CGColor? {     
  // Look in the color string table for an entry for this
  let colorString = svgColorNames[string] == nil ? string : svgColorNames[string]!
  // Handle either "rgb(..." or "#XXX..." strings
  if colorString.substringToIndex(colorString.startIndex.advancedBy(3)) == "rgb" {
    // Remove the prefix and whitespace and brackets
    let dataRange = Range(start: colorString.startIndex.advancedBy(4), end: colorString.endIndex.advancedBy(-1))
    let digits = colorString.substringWithRange(dataRange)
      .componentsSeparatedByString(",")
      .map { Int($0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()))! }
      .map { CGFloat($0) }
    return CGColorCreate(CGColorSpaceCreateDeviceRGB(), digits)
  } else if colorString.characters.first == "#" {
    let hexString = colorString.substringFromIndex(colorString.startIndex.advancedBy(1))
    let hex : CUnsignedLongLong = CUnsignedLongLong(hexString, radix: 16)!
    switch hexString.characters.count {
    case 3:
      let r = CGFloat((hex >> 8) & 0xF)
      let g = CGFloat((hex >> 4) & 0xF)
      let b = CGFloat((hex) & 0xF)
      return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [r/16, g/16, b/16, 1])!
    case 6:
      let r = CGFloat((hex >> 16) & 0xFF)
      let g = CGFloat((hex >> 8) & 0xFF)
      let b = CGFloat((hex) & 0xFF)
      return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [r/255, g/255, b/255, 1])!
    default:
      fatalError()
    }
  }
  return nil
}

// MARK: SVG Element classes

protocol SVGDrawable {
  func drawToContext(context : CGContextRef)
  var boundingBox : CGRect? { get }
}

protocol ContainerElement : SVGDrawable {
  var children : [SVGElement] { get mutating set }
}

extension ContainerElement {
  var boundingBox : CGRect? {
    // Unify all the child bounding boxes
    let xf = (self as? SVGTransformable)?.transform ?? SVGMatrix.Identity
    
    var boundingBox : CGRect? = nil
    for child in children.filter({ $0 is SVGDrawable }).map({ $0 as! SVGDrawable }) {
      guard let childBox = child.boundingBox else {
        continue
      }
      boundingBox = boundingBox ∪? childBox
    }
    return boundingBox
  }
}

protocol PresentationElement {
  // All elements are:
  //‘alignment-baseline’, ‘baseline-shift’, ‘clip’, ‘clip-path’, ‘clip-rule’, ‘color’, ‘color-interpolation’, ‘color-interpolation-filters’, ‘color-profile’, ‘color-rendering’, ‘cursor’, ‘direction’, ‘display’, ‘dominant-baseline’, ‘enable-background’, ‘fill’, ‘fill-opacity’, ‘fill-rule’, ‘filter’, ‘flood-color’, ‘flood-opacity’, ‘font-family’, ‘font-size’, ‘font-size-adjust’, ‘font-stretch’, ‘font-style’, ‘font-variant’, ‘font-weight’, ‘glyph-orientation-horizontal’, ‘glyph-orientation-vertical’, ‘image-rendering’, ‘kerning’, ‘letter-spacing’, ‘lighting-color’, ‘marker-end’, ‘marker-mid’, ‘marker-start’, ‘mask’, ‘opacity’, ‘overflow’, ‘pointer-events’, ‘shape-rendering’, ‘stop-color’, ‘stop-opacity’, ‘stroke’, ‘stroke-dasharray’, ‘stroke-dashoffset’, ‘stroke-linecap’, ‘stroke-linejoin’, ‘stroke-miterlimit’, ‘stroke-opacity’, ‘stroke-width’, ‘text-anchor’, ‘text-decoration’, ‘text-rendering’, ‘unicode-bidi’, ‘visibility’, ‘word-spacing’, ‘writing-mode’
  var fill : Paint? { get }
  var stroke : Paint? { get }
  var strokeWidth : Length { get }
  var miterLimit : Float { get }
}

// Basic SVG Protocols
protocol SVGTransformable {
  var transform : SVGMatrix { get }
}
extension Path : SVGTransformable {
  var transform : SVGMatrix { return attributes["transform"] as? SVGMatrix ?? SVGMatrix.Identity }
}
extension SVGGroup : SVGTransformable {
  var transform : SVGMatrix { return attributes["transform"] as? SVGMatrix ?? SVGMatrix.Identity }
}
// Transformable: ‘circle’ ‘ellipse’,‘line’, ‘path’, ‘polygon’, ‘polyline’, ‘rect’, ‘g’,
//‘a’, ‘clipPath’, ‘defs’, ‘foreignObject’, ‘image’,  ‘switch’, ‘text’, ‘use’

// The base class for any physical elements
class SVGElement {
  var id : String? { return attributes["id"] as? String }
  var attributes : [String : Any] = [:]
  var sourceLine : UInt = 0
}

/// Used for unknown elements encountered whilst parsing
class SVGUnknownElement : SVGElement {
  var tag : String
  init(name : String) {
    tag = name
  }
}

extension SVGMatrix : CustomStringConvertible, CustomDebugStringConvertible {
  static var Identity : SVGMatrix { return GLKMatrix3Identity }
  
  public var description : String { return NSStringFromGLKMatrix3(self) }
  public var debugDescription : String { return description }
  
  init(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float) {
    self = GLKMatrix3Make(a, b, 0, c, d, 0, e, f, 1)
  }
  init(data : [Float]) {
    self = GLKMatrix3Make(data[0], data[1], 0, data[2], data[3], 0, data[4], data[5], 1)
  }
  init(translation : CGPoint) {
    ///  [1 0 0 1 tx ty]
    self.init(a: 1, b: 0, c: 0, d: 1, e: Float(translation.x), f: Float(translation.y))
  }
  init(scale: CGPoint) {
    self.init(a: Float(scale.x), b: 0, c: 0, d: Float(scale.y), e: 0, f: 0)
  }
  init(rotation r: Float) {
    self.init(a: cos(r), b: sin(r), c: -sin(r), d: cos(r), e: 0, f: 0)
  }
  init(skewX s : Float) {
    self.init(a: 1, b: 0, c: tan(s), d: 1, e: 0, f: 0)
  }
  init(skewY s : Float) {
    self.init(a: 1, b: tan(s), c: 0, d: 1, e: 0, f: 0)
  }
  var affine : CGAffineTransform {
    return CGAffineTransformMake(CGFloat(m00), CGFloat(m01), CGFloat(m10), CGFloat(m11), CGFloat(m20), CGFloat(m21))
  }
}
func *(left: SVGMatrix, right: SVGMatrix) -> SVGMatrix {
  return GLKMatrix3Multiply(left, right)
}
func *(left: SVGMatrix, right: GLKVector3) -> GLKVector3 {
  return GLKMatrix3MultiplyVector3(left, right)
}
func *(left: SVGMatrix, right: CGPoint) -> CGPoint {
  let v3 = GLKVector3Make(Float(right.x), Float(right.y), 1)
  let tx = GLKMatrix3MultiplyVector3(left, v3)
  return CGPointMake(CGFloat(tx.x), CGFloat(tx.y))
}
func *=(inout left: SVGMatrix, right: SVGMatrix) {
  left = left * right
}

/// An SVG element that can contain other SVG elements. For e.g. svg, g, defs
class SVGGroup : SVGElement, ContainerElement, SVGDrawable {
  var children : [SVGElement] = []
  var display : String { return (attributes["display"] ?? "") as? String ?? "inline" }
  var drawableChildren : [SVGDrawable] {
    return children.filter({ $0 is SVGDrawable }).map({ $0 as! SVGDrawable })
  }
  func drawToContext(context: CGContextRef) {
    if display == "none" { return }
    
    // Loop over all children and draw
    for child in drawableChildren {
      if let pres = child as? PresentationElement {
        if pres.isInvisible() { continue }
      }
      CGContextSaveGState(context)
      if let xf = child as? SVGTransformable {
        CGContextConcatCTM(context, xf.transform.affine)
      }
      child.drawToContext(context)
      CGContextRestoreGState(context)
    }
  }
}

/// The root element of any SVG file
class SVGContainer : SVGElement, ContainerElement {
  var children : [SVGElement] = []
  private var idMap : [String : SVGElement] = [:]
  
  var width : Length {  return attributes["width"] as! Length }
  var height : Length { return attributes["height"] as! Length }
  
  override init() {
    super.init()
    attributes["width"]  = Length(value: 100, unit: .pc)
    attributes["height"] = Length(value: 100, unit: .pc)
  }
  
  func drawToContext(context: CGContextRef) {
    // Loop over all children and draw
    for child in children.filter({ $0 is SVGDrawable }).map({ $0 as! SVGDrawable }) {
      if let pres = child as? PresentationElement {
        if pres.isInvisible() { continue }
      }
      CGContextSaveGState(context)
      if let xf = child as? SVGTransformable {
        CGContextConcatCTM(context, xf.transform.affine)
      }
      child.drawToContext(context)
      CGContextRestoreGState(context)
    }
  }
  
  func findWithID(id : String) -> SVGDrawable? {
    return idMap[id] as? SVGDrawable
  }
}

/// Generic base class for handling path objects
class Path : SVGElement, SVGDrawable, PresentationElement {
  var fill : Paint? { return attributes["fill"] as? Paint }
  var stroke : Paint? { return attributes["stroke"] as? Paint }
  var strokeWidth : Length { return attributes["stroke-width"] as? Length ?? 1}
  var miterLimit : Float { return Float(attributes["stroke-miterlimit"] as? String ?? "4")! }
  
  var d : [PathInstruction] {
    return attributes["d"] as? [PathInstruction] ?? []
  }
  
  func drawToContext(context : CGContextRef)
  {
//    let subState = state.applyTransform(self.transform)

    guard d.count > 0 else {
      print("Warning: Path with no data from line \(sourceLine)")
      return
    }
    
    for command in d {
      switch command {
      case .MoveTo(let to):
        CGContextMoveToPoint(context, to.x, to.y)
      case .LineTo(let to):
        CGContextAddLineToPoint(context, to.x, to.y)
      case .CurveTo(let to, let controlStart, let controlEnd):
        CGContextAddCurveToPoint(context, controlStart.x, controlStart.y,
          controlEnd.x, controlEnd.y, to.x, to.y)
      case .ClosePath:
        CGContextClosePath(context)
      default:
        fatalError("Unrecognised path instruction: \(command)")
      }
    }
    handleStrokeAndFill(context)
  }
  
  var boundingBox : CGRect? {
    var box : CGRect? = nil
    for command in d {
      switch command {
      case .MoveTo(let to):
        box = box ∪? to
      case .LineTo(let to):
        box = box ∪? to
      case .CurveTo(let to, let controlStart, let controlEnd):
        box = box ∪? to ∪? controlStart ∪? controlEnd
      case .EllipticalArc(let data):
        box = box ∪? data.to
      case .ClosePath:
        break
      default:
        fatalError()
      }
    }
    return box
  }
}

/// Represents a circle element in the SVG file
class Circle : Path {
  var radius : CGFloat { return CGFloat((attributes["r"] as? Length)?.value ?? 0) }
  var center : CGPoint {
    let x = attributes["cx"] as? Length
    let y = attributes["cy"] as? Length
    return CGPointMake(CGFloat(x?.value ?? 0), CGFloat(y?.value ?? 0))
  }
  
  override func drawToContext(context: CGContextRef) {
    CGContextAddEllipseInRect(context,
      CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    return CGRectMake(center.x-radius, center.y-radius, 2*radius, 2*radius)
  }
}

class Line : Path {
  var start : CGPoint {
    let x = attributes["x1"] as? Length
    let y = attributes["y1"] as? Length
    return CGPoint(x: x?.value ?? 0, y: y?.value ?? 0)
  }
  var end : CGPoint {
    let x = attributes["x2"] as? Length
    let y = attributes["y2"] as? Length
    return CGPoint(x: x?.value ?? 0, y: y?.value ?? 0)
  }
  
  override func drawToContext(context: CGContextRef) {
    var points = [start, end]
    CGContextAddLines(context, &points, 2)
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    return CGRectMake(start.x, start.y, 0, 0) ∪ end
  }
}

class Polygon : Path {
  var points : [CGPoint] {
    return attributes["points"] as? [CGPoint] ?? []
  }
  override func drawToContext(context: CGContextRef) {
    var pts = points
    CGContextAddLines(context, &pts, pts.count)
    CGContextClosePath(context)
    handleStrokeAndFill(context)
  }
  
  override var boundingBox : CGRect? {
    let start = CGRectMake(points[0].x, points[0].y, 0, 0)
    return points.reduce(start, combine: { $0 ∪ $1 })
  }
}

class Rect : Path {
  var rect : CGRect {
    let x = attributes["x"] as? Length
    let y = attributes["y"] as? Length
    let width = attributes["width"] as? Length
    let height = attributes["height"] as? Length
    return CGRect(x: x?.value ?? 0, y: y?.value ?? 0, width: width?.value ?? 0, height: height?.value ?? 0)
  }
  
  override func drawToContext(context: CGContextRef) {
    CGContextAddRect(context, rect)
    handleStrokeAndFill(context)
  }

  override var boundingBox : CGRect? {
    return rect
  }
}

class Ellipse : Path {
  override func drawToContext(context: CGContextRef) {
    fatalError()
  }
  override var boundingBox : CGRect? {
    fatalError()
  }
}

class PolyLine : Path {
  var points : [CGPoint] {
    return attributes["points"] as? [CGPoint] ?? []
  }
  override func drawToContext(context: CGContextRef) {
    var pts = points
    CGContextAddLines(context, &pts, pts.count)
    handleStrokeAndFill(context)
  }

  override var boundingBox : CGRect? {
    let start = CGRectMake(points[0].x, points[0].y, 0, 0)
    return points.reduce(start, combine: { $0 ∪ $1 })
  }
}

/// Extension to handle stroke and fill for any PresentationElement objects
extension PresentationElement {
  var hasStroke : Bool {
    return (stroke ?? .None)  != .None && strokeWidth.value != 0
  }
  var hasFill : Bool {
    return (fill ?? .Inherit) != .None
  }
  
  func isInvisible() -> Bool {
//    let hasStroke = (stroke ?? .None)  != .None && strokeWidth.value != 0
//    let hasFill =   (fill ?? .Inherit) != .None
//    
    if hasStroke || hasFill {
      return false
    }
    return true
  }
  
  /// Handles generic stroke and fill for this element
  func handleStrokeAndFill(context : CGContextRef) {
    var mode : CGPathDrawingMode? = nil
    // Handle stroke
    if strokeWidth.value > 0 {
      CGContextSetLineWidth(context, CGFloat(strokeWidth.value))
      switch stroke ?? .None {
      case .None:
        break
      case .Color(let color):
        CGContextSetStrokeColorWithColor(context, color)
        mode = .Stroke
      default:
        fatalError()
      }
    }
    // And, handle fill
    switch fill ?? .Color(CGColor.Black) {
    case .None:
      break
    case .Color(let color):
      CGContextSetFillColorWithColor(context, color)
      mode = (mode == .Stroke ? .FillStroke : .Fill)
    default:
      fatalError()
    }
    if let m = mode {
      CGContextDrawPath(context, m)
    }
  }
}

// MARK: General XML parsing functions

/// Handles information about an SVG length elements
struct Length : FloatLiteralConvertible, IntegerLiteralConvertible {
  enum LengthUnit : String {
    case Unspecified
    case em = "em"
    case ex = "ex"
    case px = "px"
    case inches = "in"
    case cm = "cm"
    case mm = "mm"
    case pt = "pt"
    case pc = "pc"
  }
  var value : Float
  var unit : LengthUnit = .Unspecified
  
  init(value: Float, unit: LengthUnit) {
    self.value = value
    self.unit = unit
  }
  init(floatLiteral value: FloatLiteralType) {
    self.value = Float(value)
  }
  init(integerLiteral value: IntegerLiteralType) {
    self.value = Float(value)
  }
}

/// Handles entries for a painting entry type
enum Paint : Equatable {
  case None
  case CurrentColor
  case Color(CGColor)
  case Inherit
}

func ==(a : Paint, b : Paint) -> Bool {
  switch (a, b) {
  case (.None, .None):
    return true
  case (.CurrentColor, .CurrentColor):
    return true
  case (.Inherit, .Inherit):
    return true
  case (.Color(let a), .Color(let b)):
    return CGColorEqualToColor(a, b)
  default: return false
  }
}

/// Parse a <length> entry
func parseLength(entry : String) -> Any {
  if entry.startIndex.distanceTo(entry.endIndex) >= 2 {
    let unitPos = entry.endIndex.advancedBy(-2)
    if let unit = Length.LengthUnit(rawValue: entry.substringFromIndex(unitPos)) {
      return Length(value: Float(entry.substringToIndex(unitPos))!, unit: unit)
    }
  }
  return Length(value: Float(entry)!, unit: .Unspecified)
}

// Parse an SVG <paint> type
func parsePaint(entry : String) -> Any {
  switch entry {
  case "none":
    return Paint.None
  case "currentColor":
    return Paint.CurrentColor
  case "inherit":
    return Paint.Inherit
  default:
    // No simple implementation. Must be a color!
    return Paint.Color(CGColorCreateFromString(entry)!)
  }
}

/// Parse the list of points from a polygon/polyline entry
func parseListOfPoints(entry : String) -> Any {
  // Split by all commas and whitespace, then group into coords of two floats
  let entry = entry.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
  let separating = NSMutableCharacterSet.whitespaceAndNewlineCharacterSet()
  separating.addCharactersInString(",")
  let parts = entry.componentsSeparatedByCharactersInSet(separating).filter { !$0.isEmpty }
  return floatsToPoints(parts.map({Float($0)!}))
}


let transformFunction = Regex(pattern: "\\s*(\\w+)\\s*\\(([^)]*)\\)\\s*,?\\s*")
let transformArgumentSplitter = Regex(pattern: "\\s*([^\\s),]+)")

func parseTransform(entry: String) -> Any {
  if entry.isEmpty {
    return SVGMatrix.Identity
  }
  var current = SVGMatrix.Identity
  
  for match in transformFunction.matchesInString(entry) {
    let function = match.groups[0]
    let args = transformArgumentSplitter.matchesInString(match.groups[1]).map({Float($0.groups[0])!})
    switch function {
    case "matrix":
      guard args.count == 6 else {
        fatalError()
      }
      current *= SVGMatrix(data: args)
    case "translate":
      guard args.count == 1 || args.count == 2 else {
        fatalError()
      }
      let tx = CGPointMake(CGFloat(args[0]), args.count == 2 ? CGFloat(args[1]) : 0)
      current *= SVGMatrix(translation: tx)
    case "scale":
      guard args.count == 1 || args.count == 2 else {
        fatalError()
      }
      let sc = CGPointMake(CGFloat(args[0]), args.count == 2 ? CGFloat(args[1]) : 0)
      current *= SVGMatrix(scale: sc)
    case "rotate":
      guard args.count == 1 || args.count == 3 else {
        fatalError()
      }
      let offset = args.count == 3
        ? CGPointMake(CGFloat(args[1]), CGFloat(args[2]))
        : CGPointMake(0, 0)
      current *= SVGMatrix(translation: offset)
        * SVGMatrix(rotation: args[0])
        * SVGMatrix(translation: CGPointMake(-offset.x, -offset.y))
    case "skewX":
      guard args.count == 1 else {
        fatalError()
      }
      current *= SVGMatrix(skewX: args[0])
    case "skewY":
      guard args.count == 1 else {
        fatalError()
      }
      current *= SVGMatrix(skewY: args[0])
    default:
      fatalError()
    }
  }
  return current
}

/// Main XML Parser
class Parser : NSObject, NSXMLParserDelegate {
  
  var parser : NSXMLParser
  var elements : [SVGElement] = []
  private var idObjects : [String : SVGElement] = [:]
  
  init(data : NSData) {
    parser = NSXMLParser(data: data)
    super.init()
    parser.delegate = self
  }
  
  func parse() -> SVGElement {
    idObjects = [:]
    parser.parse()
    if let elem = lastElementToRemove as? SVGContainer {
      elem.idMap = idObjects
    }
    return lastElementToRemove!
  }
  
  var lastElementToRemove : SVGElement?
  
  func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])
  {
    let element : SVGElement
    if let creator = tagCreationMap[elementName] {
      element = creator()
    } else {
      element = SVGUnknownElement(name: elementName)
    }
    element.sourceLine = UInt(parser.lineNumber)
    
    for (key, value) in attributeDict {
      if let parser = getParserFor(elementName, attr: key) {
        element.attributes[key] = parser(value)
      } else {
        element.attributes[key] = value
      }
    }
    if var ce = elements.last as? ContainerElement {
      ce.children.append(element)
    }
    
    if let id = element.id {
      idObjects[id] = element
    }
    elements.append(element)
  }
  
  func parser(parser: NSXMLParser, didEndElement elementName: String,
    namespaceURI: String?, qualifiedName qName: String?)
  {
    let removed = elements.removeLast()

    // Remember the last element we removed, so we don't discard the end result
    lastElementToRemove = removed
  }
}

// MARK: Path parsing

let pathSplitter = Regex(pattern: "([a-zA-z])([^a-df-zA-DF-Z]*)")
let pathArgSplitter = Regex(pattern: "([+-]?\\d*\\.?\\d*(?:[eE][+-]?\\d+)?)\\s*,?\\s*")

enum PathInstruction {
  case ClosePath
  case MoveTo(CGPoint)
  case LineTo(CGPoint)
  case HLineTo(CGFloat)
  case VLineTo(CGFloat)
  case CurveTo(to: CGPoint, controlStart: CGPoint, controlEnd: CGPoint)
  case SmoothCurveTo(to: CGPoint, controlEnd: CGPoint)
  case QuadraticBezier(to: CGPoint, control: CGPoint)
  case SmoothQuadraticBezier(to: CGPoint)
  case EllipticalArc(to: CGPoint, radius: CGPoint, xAxisRotation: Float, largeArc: Bool, sweep: Bool)
}

/// Convert an even list of floats to CGPoints
func floatsToPoints(data: [Float]) -> [CGPoint] {
  guard data.count % 2 == 0 else {
    fatalError()
  }
  var out : [CGPoint] = []
  for var i = 0; i < data.count-1; i += 2 {
    out.append(CGPointMake(CGFloat(data[i]), CGFloat(data[i+1])))
  }
  return out
}

func parsePath(data: String) -> Any { // -> [PathInstruction]
  var commands : [PathInstruction] = []
  // The point for the start of the current subpath
  var currentSubpathStart : CGPoint = CGPoint(x: 0, y: 0)
  // The current working point
  var currentPoint : CGPoint = CGPoint(x: 0, y: 0)
  // Now process the path
  for match in pathSplitter.matchesInString(data) {
    let command = match.groups[0]
    // Split the arguments, if we have any
    let args = pathArgSplitter.matchesInString(match.groups[1])
      .filter({ !$0.groups[0].isEmpty })
      .map { Float($0.groups[0])! }
    // Absolute or relative?
    let relative = command == command.lowercaseString
    // Handle the commands
    switch command.lowercaseString {
    case "m":
      for (i, point) in floatsToPoints(args).enumerate() {
        currentPoint = relative ? currentPoint + point : point
        if i == 0 {
          currentSubpathStart = currentPoint
          commands.append(.MoveTo(currentPoint))
        } else {
          commands.append(.LineTo(currentPoint))
        }
      }
    case "l":
      for point in floatsToPoints(args) {
        currentPoint = relative ? currentPoint + point : point
        commands.append(.LineTo(currentPoint))
      }
    case "h":
      for point in args {
        currentPoint = CGPointMake((relative ? currentPoint.x : 0) + CGFloat(point), currentPoint.y)
        commands.append(.LineTo(currentPoint))
      }
    case "v":
      for point in args {
        currentPoint = CGPointMake(currentPoint.x, (relative ? currentPoint.y : 0) + CGFloat(point))
        commands.append(.LineTo(currentPoint))
      }
    case "c":
      for args in floatsToPoints(args).groupByStride(3) {
        let controlA = relative ? currentPoint + args[0] : args[0]
        let controlB = relative ? currentPoint + args[1] : args[1]
        currentPoint = relative ? currentPoint + args[2] : args[2]
        commands.append(.CurveTo(to: currentPoint, controlStart: controlA, controlEnd: controlB))
      }
    case "z":
      commands.append(.ClosePath)
      currentPoint = currentSubpathStart
    case "a":
      for args in args.groupByStride(7) {
        let plainTo = CGPointMake(CGFloat(args[5]), CGFloat(args[6]))
        let to = relative ? currentPoint + plainTo : plainTo
        let radius = CGPointMake(CGFloat(args[0]), CGFloat(args[1]))
        let largeArcFlag = args[3] != 0
        let sweepFlag = args[4] != 0
        commands.append(.EllipticalArc(to: to, radius: radius, xAxisRotation: args[2], largeArc: largeArcFlag, sweep: sweepFlag))
      }
      
      //      (rx ry x-axis-rotation large-arc-flag sweep-flag x y)+
    default:
      fatalError()
    }
  }
  return commands
}


// MARK: Various Errata and extensions

extension Array {
  func groupByStride(stride : Int) -> [[Generator.Element]] {
    var grouped : [[Generator.Element]] = []
    for var i = 0; i <= self.count-stride; i += stride {
      grouped.append(Array(self[i...i+stride-1]))
    }
    return grouped
  }
}

// Easy references to common colors
private extension CGColor {
  static var Black : CGColor { return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [0,0,0,1])! }
}

extension CGRect {
  init(x : Float, y: Float, width: Float, height: Float) {
    self.init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
  }
}

infix operator ∪ { associativity left }
infix operator ∪? { associativity left }

func ∪(left: CGRect, right: CGRect) -> CGRect {
  return CGRectUnion(left, right)
}
func ∪(left: CGRect, right: CGPoint) -> CGRect {
  return CGRectUnion(left, CGRectMake(right.x, right.y, 0, 0))
}
func ∪(right: CGPoint, left: CGRect) -> CGRect {
  return CGRectUnion(left, CGRectMake(right.x, right.y, 0, 0))
}
func ∪?(left: CGRect?, right: CGRect?) -> CGRect? {
  guard left != nil || right != nil else {
    return nil
  }
  return CGRectUnion(left ?? right!, right ?? left!)
}
func ∪?(left: CGRect?, right: CGPoint) -> CGRect? {
  let rRect = CGRectMake(right.x, right.y, 0, 0)
  guard let l = left else {
    return rRect
  }
  return CGRectUnion(l, rRect)
}
func ∪?(right: CGPoint, left: CGRect?) -> CGRect? {
  let rRect = CGRectMake(right.x, right.y, 0, 0)
  guard let l = left else {
    return rRect
  }
  return CGRectUnion(l, rRect)
}


extension CGPoint {
  init(x: Float, y: Float) {
    self.init(x: CGFloat(x), y: CGFloat(y))
  }
}

func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPointMake(left.x + right.x, left.y + right.y)
}


struct Match {
  var groups : [String]
  var result : NSTextCheckingResult
  
  init(string: String, result : NSTextCheckingResult) {
    self.result = result
    var groups : [String] = []
    for i in 1..<result.numberOfRanges {
      let range = result.rangeAtIndex(i)
      if range.location == NSNotFound {
        groups.append("")
      } else {
        groups.append(string.substringWithRange(range))
      }
    }
    self.groups = groups
  }
  
  var range : NSRange { return result.range }
}

class Regex {
  let re : NSRegularExpression
  init(pattern: String) {
    re = try! NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions())
  }
  func firstMatchInString(string : String) -> Match? {
    let nss = string as NSString
    if let tr = re.firstMatchInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nss.length)) {
      return Match(string: string, result: tr)
    }
    return nil
  }
  func matchesInString(string : String) -> [Match] {
    let nsS = string as NSString
    return re.matchesInString(string, options: NSMatchingOptions(), range: NSRange(location: 0, length: nsS.length)).map { Match(string: string, result: $0) }
  }
}

extension String {
  func substringWithRange(range : NSRange) -> String {
    let nss = self as NSString
    return nss.substringWithRange(range)
  }
}

