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
      let sampleImage = NSBundle.mainBundle().URLForResource("test_image2", withExtension: "svg")!
      svgFile = SVGImage(withContentsOfFile: sampleImage)
    }
    if let context = UIGraphicsGetCurrentContext() {
      svgFile?.drawToContext(context)
    }
  }
}