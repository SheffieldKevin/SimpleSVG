//
//  SVGView.swift
//  
//  A very simple UIView that simply draws an SVG to a context
//

import UIKit

class SVGView : UIView {
  var svgFile : SVGImage?
  
  override func drawRect(rect: CGRect) {
    if svgFile == nil {
      let sampleImage = NSBundle.mainBundle().URLForResource("RPM_NavBall_Overlay", withExtension: "svg")!
      svgFile = SVGImage(withContentsOfFile: sampleImage)
    }
    if let context = UIGraphicsGetCurrentContext() {
      svgFile?.drawToContext(context)
    }
  }
  
  var steps : Int = 0
  
  override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    steps += 1
    print ("Moving to step ", steps)
    setNeedsDisplay()
  }
}