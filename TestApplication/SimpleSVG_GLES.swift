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
//
// SimpleSVG_GLES
//
// OpenGL-related extensions to SimpleSVG
//

import Foundation
import GLKit


//protocol SVGTriangleRenderer {
//  func emitTriangle(pointA : CGPoint, pointB : CGPoint, pointC : CGPoint)
//  func emitColorChange(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)
//}

extension SVGImage
{
  func renderToTexture(textureSize size: CGSize, flip: Bool = true) throws -> GLKTextureInfo {
    let size = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    // Scale the SVG size to the full area
    let svgSize = CGSizeMake(CGFloat(self.svg.width.value), CGFloat(self.svg.height.value))
    let svgScale = CGSizeMake(size.width / svgSize.width, size.height / svgSize.height)
    
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
    let context = UIGraphicsGetCurrentContext()
    if flip {
      CGContextTranslateCTM (context, 0, size.height);
      CGContextScaleCTM(context, svgScale.width, -svgScale.height)
    } else {
      CGContextScaleCTM(context, svgScale.width, svgScale.height)
    }
    
    drawToContext(context!)
    
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    let texture = try GLKTextureLoader.textureWithCGImage(image, options: nil)
    return texture
  }

  typealias Triangle = (GLKVector2, GLKVector2, GLKVector2)
  typealias SimplePolygon = [CGPoint]
  
  func renderToTriangles() -> [Triangle] {
    // Loop over all elements in the SVG, returning
    return renderToTriangles(self.svg)
  }
  
  private func renderToTriangles(element : SVGElement) -> [Triangle] {
    var triList : [Triangle] = []
    
    // For containers, run over every entry
    switch element {
    case let elem as ContainerElement:
      for child in elem.children {
        triList.appendContentsOf(renderToTriangles(child))
      }
    case let elem as Path:
      let instructions : [PathInstruction]
      switch elem {
      case let elem as Circle:
        let startPoint = CGPointMake(elem.center.x+elem.radius, elem.center.y)
        instructions = [
          .MoveTo(startPoint),
          .EllipticalArc(to: startPoint, radius: CGPointMake(elem.radius, elem.radius), xAxisRotation: 0, largeArc: true, sweep: false)
        ]
      case let elem as Line:
        instructions = [.MoveTo(elem.start), .LineTo(elem.end)]
      case let elem as Rect:
        let r = elem.rect
        instructions = [.MoveTo(r.origin), .LineTo(CGPointMake(r.maxX, r.minY)),
        .LineTo(CGPointMake(r.maxX, r.maxY)), .LineTo(CGPointMake(r.minX, r.maxY)),
        .ClosePath]
      case let elem as Polygon:
        var cmds : [PathInstruction] = [.MoveTo(elem.points.first!)]
        cmds.appendContentsOf(elem.points.suffixFrom(1).map({ .LineTo($0) }))
        cmds.append(.ClosePath)
        instructions = cmds
      case let elem as PolyLine:
        var cmds : [PathInstruction] = [.MoveTo(elem.points.first!)]
        cmds.appendContentsOf(elem.points.suffixFrom(1).map({ .LineTo($0) }))
        instructions = cmds
      case is Ellipse:
        fatalError()
      default:
        instructions = elem.d
      }
      // Build a stroke path for these instructions
      if elem.hasStroke {
        triList.appendContentsOf(renderPathToTriangles(instructions,
          strokeWidth: CGFloat(elem.strokeWidth.value), miterLimit: CGFloat(elem.miterLimit)))
      }
    default:
      fatalError()
    }
    return triList
  }
  
  func renderPathToTriangles(path : [PathInstruction], strokeWidth: CGFloat, miterLimit: CGFloat) -> [Triangle] {
    // Firstly, convert all of the path instructions to LineTos
    let lines = reducePathInstructionsToLines(path)
    // Now, build a list of polygons. These will be merged together
    var polygons : [SimplePolygon] = []
    // This will now have nothing but moveto, lineto, closePath instructions
    var currentPoint = CGPointMake(0, 0)
    var firstLine : (from: CGPoint, to: CGPoint)? = nil
    var previousLine : (from: CGPoint, to: CGPoint)? = nil
    for cmd in lines {
      switch cmd {
      case .MoveTo(let to):
        currentPoint = to
        firstLine = nil
        previousLine = nil
      case .LineTo(let to):
        // If we had a line before this one, then build the join
        if let previous = previousLine {
          // Generate the intersection between the previous line and this one
          polygons.append(generateLineIntersection(previous.from, apex: currentPoint, to: to, thickness: strokeWidth, miterLimit: miterLimit))
        }
        // Add a polygon for the current line
        let lineVector = CGPointMake(to.x-currentPoint.x, to.y-currentPoint.y)
        let lineOffset = CGPointNormalize(CGPointMake(-lineVector.y * (strokeWidth/2), lineVector.x * (strokeWidth/2)))
        polygons.append([
          currentPoint + lineOffset,
          to           + lineOffset,
          to           - lineOffset,
          currentPoint - lineOffset])
        // Now set this as the previous line
        previousLine = (currentPoint, to)
        currentPoint = to
        if firstLine == nil {
          firstLine = previousLine
        }
      case .ClosePath:
        fatalError()
      default:
        fatalError()
      }
    }
    
    fatalError()
  }
  
  func generateLineIntersection(from: CGPoint, apex: CGPoint, to: CGPoint, thickness: CGFloat, miterLimit: CGFloat) -> SimplePolygon {
    // Calculate the inner and outer intersection points
    let vA = apex - from
    let offA = CGPointNormalize(vA⟂) * (thickness/2) // CGPointMake(-vA.y * (thickness/2), vA.x * (thickness/2))
    let vB = to - apex
    let offB = CGPointNormalize(vB⟂) * (thickness/2) //CGPointMake(-vB.y * (thickness/2), vB.x * (thickness/2))
    
    let intersectAd = calculateIntersection(a: (origin: from+offA, vector: vA), b: (origin: to+offB, vector: vB))
    let intersectBd = calculateIntersection(a: (origin: from-offA, vector: vA), b: (origin: to-offB, vector: vB))
    
    // Only do the outer intersection - the inner will be dealt with by merging polygons
//    let outer
    
    return []
  }
  
  func calculateIntersection(a a: (origin: CGPoint, vector: CGPoint), b: (origin: CGPoint, vector: CGPoint)) -> CGFloat {
//    Oax + d * Vax = Obx + l*Vbx
//    Oay + d * Vay = Oby + l*Vby
//    Vby(Oax + d * Vax - Obx) =  l*Vbx*Vby
//    Vbx(Oay + d * Vay - Oby) =  l*Vby*Vbx
//    Vby(Oax + d * Vax - Obx) - Vbx(Oay + d * Vay - Oby) = 0
//    Vby(Oax - Obx) - Vbx(Oay - Oby) = d(Vbx * Vay - Vby*Vax)
//    perpDot(Vb, Oa-Ob) = d*perpDot(Va, Vb)
    let perpOrigDiff = (a.origin-b.origin)⟂
    let d = (b.vector • perpOrigDiff) / (a.vector • (b.vector⟂))
    return d
    
    
//    (a) - (b)
//    
//    
//    Vby*Oax + Vby * d * Vax - Obx*Vby - Vbx*Oay - Vbx*d*Vay + Oby*Vbx = 0
//    d*(Vby * Vax - Vbx*Vay) - Obx*Vby - Vbx*Oay + Oby*Vbx + Vby*Oax = 0

    
  }
  
  func reducePathInstructionsToLines(path: [PathInstruction]) -> [PathInstruction]
  {
    var instructions : [PathInstruction] = []
    var subPathStart = CGPointMake(0, 0)
    var currentPoint = CGPointMake(0, 0)
    for cmd in path {
      switch cmd {
      case .LineTo(let to):
        instructions.append(cmd)
        currentPoint = to
      case .MoveTo(let to):
        instructions.append(cmd)
        currentPoint = to
        subPathStart = to
      case .ClosePath:
        instructions.append(cmd)
        currentPoint = subPathStart
      case .EllipticalArc(let to, let radius, let xAxisRotation, let largeArc, let sweep):
        instructions.appendContentsOf(ellipticalArcToLines(currentPoint, to: to, radius: radius, xAxisRotation: xAxisRotation, largeArc: largeArc, sweep: sweep))
      case .CurveTo(let to, let controlStart, let controlEnd):
        instructions.appendContentsOf(curveToToLines(currentPoint, to: to, controlStart: controlStart, controlEnd: controlEnd))
      default:
        fatalError()
      }
    }
    return instructions
  }
  
  // Expand an elliptical arc to lines
  func ellipticalArcToLines(from: CGPoint, to: CGPoint, radius: CGPoint, xAxisRotation: Float, largeArc: Bool, sweep: Bool) -> [PathInstruction]
  {
    return [.LineTo(to)]
  }
  
  func curveToToLines(from: CGPoint, to: CGPoint, controlStart: CGPoint, controlEnd: CGPoint) -> [PathInstruction]
  {
    return [.LineTo(to)]
  }
  
}

func *(left: CGPoint, right: CGFloat) -> CGPoint {
  return CGPointMake(left.x*right, left.y*right)
}
func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPointMake(left.x-right.x, left.y-right.y)
}
infix operator • {}

postfix operator ⟂ {}

func •(left: CGPoint, right: CGPoint) -> CGFloat {
  return left.x*right.x + left.y*right.y
}

func CGPointPerpendicular(of: CGPoint) -> CGPoint {
  return CGPointMake(of.y, -of.x)
}

postfix func ⟂(of: CGPoint) -> CGPoint {
  return CGPointMake(of.y, -of.x)
}

func CGPointNormalize(pt: CGPoint) -> CGPoint {
  return CGPointMake(pt.x / sqrt(pt•pt), pt.y / sqrt(pt•pt))
}
//
//extension PresentationElement {
//  var strokeColor : SVGColor? {
//    get {
//      guard let stroke = self.stroke else {
//        return nil
//      }
//      switch stroke {
//      case .Color(let col):
//        return SVGColor(color: col)
//      default:
//        return nil
//      }
//    }
//  }
//}
//struct SVGColor : Hashable, Equatable {
//  let r : CGFloat
//  let g : CGFloat
//  let b : CGFloat
//  let a : CGFloat
//  var hashValue : Int { return r.hashValue + g.hashValue*2 + b.hashValue*3 + a.hashValue*5 }
//  init(color: CGColor) {
//    let num = CGColorGetNumberOfComponents(color)
//    let comp = CGColorGetComponents(color)
//    r = comp[0]
//    g = comp[1]
//    b = comp[2]
//    a = num == 4 ? comp[3] : 1
//  }
//}
//
//func ==(left: SVGColor, right: SVGColor) -> Bool {
//  return left.r == right.r && left.g == right.g && left.b == right.b && left.a == right.a
//}
  