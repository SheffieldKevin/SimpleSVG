SimpleSVG
=========

A VERY minimalist SVG parser, for swift, in a single source file.
 Written because it seemed easier than spending several more hours trying to 
 work out how to get SVGKit working via a framework in a swift application.

It currently supports only a very minimal set of SVG features, mostly so that
I can use it for my other applications:

  * Path objects with cubic Bézier curves
  * Line, Circle, Rect, Polygon
  * Solid fills and paths

And can currently only draw the existing SVG onto a provided CGContextRef.
This should be enough to be able to e.g. convert an SVG into a texture for
rendering with OpenGL.

Usage
-----

Simple add `SimpleSVG.swift` to your existing project, and instantiate
the `SVGImage` class. You can then use `drawToContext` to render the image.
Example:

    let svgFile = SVGImage(withContentsOfFile: sampleImage)
    if let context = UIGraphicsGetCurrentContext() {
      svgFile.drawToContext(context)
    }