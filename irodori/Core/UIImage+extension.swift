//
//  UIImage+extension.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/03.
//

import UIKit

extension UIImage {

    var correctOrientation: UIImage {
        let ciContext = CIContext()
        var newImage = UIImage()
        switch self.imageOrientation.rawValue {
         case 1:
            guard let orientedCIImage = CIImage(image: self)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return self}
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: self)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return self}
           newImage = UIImage(cgImage: cgImage)
        default:
           newImage = self
        }
        return newImage
    }
}

