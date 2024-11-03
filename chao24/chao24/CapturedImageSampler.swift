//
//  CapturedImageSampler.swift
//  ARKitTest
//
//  Created by Joshua Sullivan on 9/22/17.
//  Copyright © 2017 Joshua Sullivan. All rights reserved.
//

import UIKit
import ARKit
import Accelerate
import VideoToolbox

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }

        self.init(cgImage: cgImage)
    }
}

/// This object provides easy color sampling of the `capturedImage` property of an ARFrame.
///
/// - Warning: This class is NOT thread safe. The `rawRGBBuffer` property is shared between instances
///            and will cause a lot of headaches if 2 instances try to simultaneously access it.
///            If you need multi-threading, make the shared buffer an instance property instead.
///            Just remember to release it when you're done with it.
class CapturedImageSampler {
    
    /// This is the format of the pixel buffer included with the ARFrame.
    private static let expectedPixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    
    /// This is the YCbCr to RGB conversion opaque object used by the convert function.
    private static var conversionMatrix: vImage_YpCbCrToARGB = {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 1, CbCrMax: 255, CbCrMin: 0)
        var matrix = vImage_YpCbCrToARGB()
        vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, &matrix, kvImage420Yp8_CbCr8, kvImageARGB8888, UInt32(kvImageNoFlags))
        return matrix
    }()
    
    /// Since we'll generally be dealing with buffers of the same size, save processsing power
    /// by re-using a single, static one, rather than allocating a new buffer each time. This
    /// will be set by the initializer of the first instance of `CapturedImageSampler`.
    private static var rawRGBBuffer: UnsafeMutableRawPointer!
    
    /// Store the size information of the buffer.
    private static var rawBufferSize: CGSize = .zero
    
    /// The errors which can be produced.
    enum PixelError: Error {
        /// The `capturedImage` property's CVPixelBuffer was in an unexpected format.
        case incorrectPixelFormat
        
        /// Failed to allocate space for the conversion buffer.
        case systemFailure
        
        /// The conversion function returned an error.
        case conversionFailure(vImage_Error)
    }
    
    /// Initialize the CapturedImageSampler with an `ARFrame` to sample RGB colors from the
    /// captured image that it contains.
    /// - Parameter frame: An `ARFrame` instance that you wish to sample for RGB colors.
    static func getPixelBuffer(from frame: ARFrame) throws -> CVPixelBuffer {
        
        // Get the image pixel buffer.
        let pixelBuffer = frame.capturedImage
        
        // Double-check that the format hasn't changed unexpectedly.
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == CapturedImageSampler.expectedPixelFormat else {
            NSLog("ERROR: ARFrame.capturedImage had an unexpected pixel format.")
            throw PixelError.incorrectPixelFormat
        }
        
        // Lock the base address for work.
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        // Ensure that we can find both the Y and the CbCr planes.
        guard
            let rawyBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
            let rawcbcrBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
            else {
                print("Unable to find correct planar data in source pixel buffer.")
                throw PixelError.incorrectPixelFormat
        }
        // Note: The Y plane has the same size as our output image. The CbCr plane is 1/2 resolution.
        //       However, the conversion method accounts for this, so we don't need to worry.
        let ySize = BufferDimension(pixelBuffer: pixelBuffer, plane: 0)
        let cSize = BufferDimension(pixelBuffer: pixelBuffer, plane: 1)
        
        // Convert the individual planes to the vImage_Buffer type via a convenience method on the size.
        var yBuffer = ySize.buffer(with: rawyBuffer)
        var cbcrBuffer = cSize.buffer(with: rawcbcrBuffer)
        
        // Check to see if the static RGB buffer is the correct size.
        if ySize.size != CapturedImageSampler.rawBufferSize && CapturedImageSampler.rawRGBBuffer != nil {
            // It's the wrong size. Free it and nil the reference so we can recreate it below.
            free(CapturedImageSampler.rawRGBBuffer)
            CapturedImageSampler.rawRGBBuffer = nil
        }
        
        // Check to see if the static buffer exists.
        if CapturedImageSampler.rawRGBBuffer == nil {
            // If it doesn't exist, create it. Size = width * height * 1 byte per channel (ARGB).
            guard let buffer = malloc(ySize.width * ySize.height * 4) else {
                print("ERROR: Unable to allocate space for RGB buffer.")
                throw PixelError.systemFailure
            }
            CapturedImageSampler.rawRGBBuffer = buffer
            CapturedImageSampler.rawBufferSize = ySize.size
        }
        
        // At this point we know the static buffer exists. Use it to create the target RGB vImage_Buffer.
        var rgbBuffer: vImage_Buffer = vImage_Buffer(data: CapturedImageSampler.rawRGBBuffer, height: ySize.uHeight, width: ySize.uWidth, rowBytes: ySize.width * 4)
        
        // Put everything together to convert the Y and CbCr planes into a single, interleaved ARGB buffer.
        // Note: The declared constants for kvImageFlags are the wrong type: they're all Int, but should be UInt32.
        //       I've filed a radar about it.
        let error = vImageConvert_420Yp8_CbCr8ToARGB8888(&yBuffer, &cbcrBuffer, &rgbBuffer, &CapturedImageSampler.conversionMatrix, nil, 255, UInt32(kvImageNoFlags))
        
        // Check to see that the returned error type was No Error.
        if error != kvImageNoError {
            NSLog("Error converting buffer: \(error)")
            throw PixelError.conversionFailure(error)
        }
        
        // We're done with the original pixel buffer, unlock it.
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        // All we want is a buffer of bytes, we'll do the address math manually.
        
        let options = [kCVPixelBufferWidthKey: ySize.width, kCVPixelBufferHeightKey: ySize.height, kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferIOSurfaceCoreAnimationCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        
        var outPixelBuffer: CVPixelBuffer?
        
        guard CVPixelBufferCreateWithBytes(nil, ySize.width, ySize.height, kCVPixelFormatType_32ARGB, rgbBuffer.data, ySize.width * 4, nil, nil, options, &outPixelBuffer) == kCVReturnSuccess else {
            throw PixelError.incorrectPixelFormat
        }
        
        return outPixelBuffer!
    }
}

/// This struct stores dimensional information about a buffer, needed to correctly address its
/// consitiuent elements.
struct BufferDimension {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    
    /// The total number of bytes in a buffer with this dimension. Useful for bounds-checking
    /// array access of the buffer's elements.
    var byteCount: Int {
        return width * bytesPerRow * height
    }
    
    /// Convience getter to cast the width as a UInt, which is required by vImage_Buffer.
    var uWidth: UInt {
        return UInt(width)
    }
    
    /// Convience getter to cast the height as a UInt, which is required by vImage_Buffer.
    var uHeight: UInt {
        return UInt(height)
    }
    
    /// Convenience getter to get the size (width, height) of the buffer.
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
    
    /// Initialize the dimension with a CVPixelBuffer and optional plane index.
    /// This will misbehave if you have a multi-planar image and you don't specify a plane,
    /// or if you specify a plane index and it is not planar.
    init(pixelBuffer: CVPixelBuffer, plane: Int?) {
        if let plane = plane {
            self.width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane)
            self.height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            self.bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        } else {
            self.width = CVPixelBufferGetWidth(pixelBuffer)
            self.height = CVPixelBufferGetHeight(pixelBuffer)
            self.bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        }
    }
    
    /// Alternative initializer for directly setting dimension values.
    init(width: Int, height: Int, bytesPerRow: Int) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
    }
    
    /// Create and return a `vImage_Buffer` using the dimensions and a supplied buffer.
    func buffer(with data: UnsafeMutableRawPointer) -> vImage_Buffer {
        return vImage_Buffer(data: data, height: uHeight, width: uWidth, rowBytes: bytesPerRow)
    }
}
