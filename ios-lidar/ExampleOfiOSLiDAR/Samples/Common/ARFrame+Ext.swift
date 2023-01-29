//
//  ARFrame+Ext.swift
//  ExampleOfiOSLiDAR
//
//  Created by TokyoYoshida on 2021/01/14.
//

import ARKit
import UIKit
import Accelerate

extension ARFrame {
    
    func getDepthPixelBuffer() -> Data?
    {
        guard let pixelBuffer = self.sceneDepth?.depthMap else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer);
        let height = CVPixelBufferGetHeight(pixelBuffer);
        let dataSize = CVPixelBufferGetDataSize(pixelBuffer);
        let dataType = CVPixelBufferPoolGetTypeID()
//        print("pixel buffer width: ", width)
//        print("pixel buffer height: ", height)
//        print("pixel buffer size:", dataSize)
//        print("pixel buffer type:", dataType)
//
//        print("pixel buffer type: ", type(of: pixelBuffer))
//        print("pixel buffer", pixelBuffer)
        
//        print(pixelFrom(x:1,y:1, movieFrame:pixelBuffer))
        
        var depthArray = [Float32]()
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer),
                                to: UnsafeMutablePointer<Float32>.self)
                      
            for y in 0...height-1{
                var distancesLine = [Float32]()
                for x in 0...width-1{
                    var distanceAtXYPoint = floatBuffer[y * width + x]
                    depthArray.append(distanceAtXYPoint)
//                    print("Depth in (", x, ",", y, "):", distanceAtXYPoint)
                }
//                depthArray.append(distancesLine)
            }
        
        
        let byteBufferData = Data(buffer: UnsafeBufferPointer(start: &depthArray, count: depthArray.count))
        
        return byteBufferData
    }
    
    struct PointXYZ
    {
        let x: Float32
        let y: Float32
        let z: Float32
    }
    
    private func rectifyDepthData(avDepthData: AVDepthData) -> CVPixelBuffer? {
        guard let distortionLookupTable = avDepthData.cameraCalibrationData?.inverseLensDistortionLookupTable,
                    let distortionCenter = avDepthData.cameraCalibrationData?.lensDistortionCenter else {
                        return nil
                }

                let originalDepthDataMap = avDepthData.depthDataMap
                let width = CVPixelBufferGetWidth(originalDepthDataMap)
                let height = CVPixelBufferGetHeight(originalDepthDataMap)
                let scaledCenter = CGPoint(x: (distortionCenter.x / CGFloat(1920)) * CGFloat(width), y: (distortionCenter.y / CGFloat(1440)) * CGFloat(height))
                CVPixelBufferLockBaseAddress(originalDepthDataMap, CVPixelBufferLockFlags(rawValue: 0))

                var maybePixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferCreate(nil, width, height, avDepthData.depthDataType, nil, &maybePixelBuffer)

                assert(status == kCVReturnSuccess && maybePixelBuffer != nil);

                guard let rectifiedPixelBuffer = maybePixelBuffer else {
                    return nil
                }

                CVPixelBufferLockBaseAddress(rectifiedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                guard let address = CVPixelBufferGetBaseAddress(rectifiedPixelBuffer) else {
                    return nil
                }
                for y in 0 ..< height{
                    let rowData = CVPixelBufferGetBaseAddress(originalDepthDataMap)! + y * CVPixelBufferGetBytesPerRow(originalDepthDataMap)
                    let data = UnsafeBufferPointer(start: rowData.assumingMemoryBound(to: Float32.self), count: width)

                    for x in 0 ..< width{
                        let oldPoint = CGPoint(x: x, y: y)
                        let newPoint = lensDistortionPoint(point: oldPoint, lookupTable: distortionLookupTable, distortionOpticalCenter: scaledCenter, imageSize: CGSize(width: width, height: height) )
                        let val = data[x]

                        let newRow = address + Int(newPoint.y) * CVPixelBufferGetBytesPerRow(rectifiedPixelBuffer)
                        let newData = UnsafeMutableBufferPointer<Float32>(start: newRow.assumingMemoryBound(to: Float32.self), count: width)
                        newData[Int(newPoint.x)] = val
                    }
                }
                CVPixelBufferUnlockBaseAddress(rectifiedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                CVPixelBufferUnlockBaseAddress(originalDepthDataMap, CVPixelBufferLockFlags(rawValue: 0))
                return rectifiedPixelBuffer
    }
    
    func lensDistortionPoint(point: CGPoint, lookupTable: Data, distortionOpticalCenter opticalCenter: CGPoint, imageSize: CGSize) -> CGPoint {
            // The lookup table holds the relative radial magnification for n linearly spaced radii.
            // The first position corresponds to radius = 0
            // The last position corresponds to the largest radius found in the image.
            
            // Determine the maximum radius.
            let delta_ocx_max = Float(max(opticalCenter.x, imageSize.width  - opticalCenter.x))
            let delta_ocy_max = Float(max(opticalCenter.y, imageSize.height - opticalCenter.y))
            let r_max = sqrt(delta_ocx_max * delta_ocx_max + delta_ocy_max * delta_ocy_max)
            
            // Determine the vector from the optical center to the given point.
            let v_point_x = Float(point.x - opticalCenter.x)
            let v_point_y = Float(point.y - opticalCenter.y)
            
            // Determine the radius of the given point.
            let r_point = sqrt(v_point_x * v_point_x + v_point_y * v_point_y)
            
            // Look up the relative radial magnification to apply in the provided lookup table
            let magnification: Float = lookupTable.withUnsafeBytes { (lookupTableValues: UnsafePointer<Float>) in
                let lookupTableCount = lookupTable.count / MemoryLayout<Float>.size
                
                if r_point < r_max {
                    // Linear interpolation
                    let val   = r_point * Float(lookupTableCount - 1) / r_max
                    let idx   = Int(val)
                    let frac  = val - Float(idx)
                    
                    let mag_1 = lookupTableValues[idx]
                    let mag_2 = lookupTableValues[idx + 1]
                    
                    return (1.0 - frac) * mag_1 + frac * mag_2
                } else {
                    return lookupTableValues[lookupTableCount - 1]
                }
            }
            
            // Apply radial magnification
            let new_v_point_x = v_point_x + magnification * v_point_x
            let new_v_point_y = v_point_y + magnification * v_point_y
            
            // Construct output
            return CGPoint(x: opticalCenter.x + CGFloat(new_v_point_x), y: opticalCenter.y + CGFloat(new_v_point_y))
        }
    
    private func getXYZ(avDepthData: AVDepthData)->[PointXYZ]{
//            print(avDepthData.depthDataMap.pixelFormatName())
            let depthData = avDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            guard let intrinsicMatrix = avDepthData.cameraCalibrationData?.intrinsicMatrix,
    //     I am using the inverseDistortionLookupTable here, is this correct?
            let depthDataMap = rectifyDepthData(avDepthData: depthData) else {
                return []
            }

            CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))

            let width = CVPixelBufferGetWidth(depthDataMap)
            let height = CVPixelBufferGetHeight(depthDataMap)

            var points = [PointXYZ]()


            for y in 0 ..< height{
                for x in 0 ..< width{
                    let Z = getDistance(at: CGPoint(x: x, y: y) , depthMap: depthDataMap, depthWidth: width, depthHeight: height)

                    if(Z == nil){
                        continue
                    }

                    // as seen in wwdc video -> https://developer.apple.com/videos/play/wwdc2018/503/?time=1498
                    let X = (Float(x) - intrinsicMatrix[2][0]) * Z! / intrinsicMatrix[0][0]
                    let Y = (Float(y) - intrinsicMatrix[2][1]) * Z! / intrinsicMatrix[1][1]

                    let point = PointXYZ(x: X, y: Y, z: Z!)
                    points.append(point)
                }
            }
            CVPixelBufferUnlockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))

            return points
        }
    
    private func getDistance(at point: CGPoint, depthMap: CVPixelBuffer, depthWidth: Int, depthHeight: Int) -> Float? {
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        let x = Int(point.x)
        let y = Int(point.y)
        
        guard x >= 0, x < depthWidth, y >= 0, y < depthHeight else {
            return nil
        }
        
        let offset = y * bytesPerRow + x * MemoryLayout<Float32>.size
        let depthData = baseAddress?.advanced(by: offset)
        
        return depthData?.load(as: Float32.self)
    }

    
    func depthMapTransformedImage(orientation: UIInterfaceOrientation, viewPort: CGRect) -> UIImage? {
        guard let pixelBuffer = self.sceneDepth?.depthMap else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return UIImage(ciImage: screenTransformed(ciImage: ciImage, orientation: orientation, viewPort: viewPort))
    }

    func ConfidenceMapTransformedImage(orientation: UIInterfaceOrientation, viewPort: CGRect) -> UIImage? {
        guard let pixelBuffer = self.sceneDepth?.confidenceMap,
        let ciImage = confidenceMapToCIImage(pixelBuffer: pixelBuffer) else { return nil }
        return UIImage(ciImage: screenTransformed(ciImage: ciImage, orientation: orientation, viewPort: viewPort))
    }

    func screenTransformed(ciImage: CIImage, orientation: UIInterfaceOrientation, viewPort: CGRect) -> CIImage {
        let transform = screenTransform(orientation: orientation, viewPortSize: viewPort.size, captureSize: ciImage.extent.size)
        return ciImage.transformed(by: transform).cropped(to: viewPort)
    }

    func screenTransform(orientation: UIInterfaceOrientation, viewPortSize: CGSize, captureSize: CGSize) -> CGAffineTransform {
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/captureSize.width, y: 1.0/captureSize.height)
        let flipTransform = (orientation.isPortrait) ? CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity
        let displayTransform = self.displayTransform(for: orientation, viewportSize: viewPortSize)
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        return normalizeTransform.concatenating(flipTransform).concatenating(displayTransform).concatenating(toViewPortTransform)
    }
    
    func confidenceMapToCIImage(pixelBuffer: CVPixelBuffer) -> CIImage? {
        func confienceValueToPixcelValue(confidenceValue: UInt8) -> UInt8 {
            guard confidenceValue <= ARConfidenceLevel.high.rawValue else {return 0}
            return UInt8(floor(Float(confidenceValue) / Float(ARConfidenceLevel.high.rawValue) * 255))
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        for i in stride(from: 0, to: bytesPerRow*height, by: MemoryLayout<UInt8>.stride) {
            let data = base.load(fromByteOffset: i, as: UInt8.self)
            let pixcelValue = confienceValueToPixcelValue(confidenceValue: data)
            base.storeBytes(of: pixcelValue, toByteOffset: i, as: UInt8.self)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return CIImage(cvPixelBuffer: pixelBuffer)
    }
    
    func buildDepthTextures(textureCache: CVMetalTextureCache) -> (depthTexture: CVMetalTexture, confidenceTexture: CVMetalTexture)? {
        guard let depthMap = self.sceneDepth?.depthMap,
            let confidenceMap = self.sceneDepth?.confidenceMap else {
                return nil
        }
        
        guard let depthTexture = createTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0, textureCache: textureCache),
              let confidenceTexture = createTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0, textureCache: textureCache) else {
            return nil
        }
        
        return (depthTexture: depthTexture, confidenceTexture: confidenceTexture)
    }

    fileprivate func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int, textureCache: CVMetalTextureCache) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
//    func downsamplePixelBuffer(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
//
//    }
//    func downsamplePixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
//      CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//      defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
//
//      let sourceImage = vImage_Buffer(data: CVPixelBufferGetBaseAddress(pixelBuffer), height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)), width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)), rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer))
//
//      let destImage = vImage_Buffer(width: Int(sourceImage.width) / 2, height: Int(sourceImage.height) / 2, bitsPerPixel: )
//      vImageDownsample_ARGB8888(&sourceImage, &destImage, nil, vImage_Flags(kvImageNoFlags))
//
//      let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
//        if let ptr = ptr {
//          free(UnsafeMutableRawPointer(mutating: ptr))
//        }
//      }
//
//      var downsampledPixelBuffer: CVPixelBuffer?
//      CVPixelBufferCreateWithBytes(nil, destImage.width, destImage.height, kCVPixelFormatType_32ARGB, destImage.data, destImage.rowBytes, releaseCallback, nil, nil, &downsampledPixelBuffer)
//      return downsampledPixelBuffer
//    }
    
    func buildCapturedImageTextures(textureCache: CVMetalTextureCache) -> (textureY: CVMetalTexture, textureCbCr: CVMetalTexture)? {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        var pixelBuffer = self.capturedImage
        
        let width = CVPixelBufferGetWidth(pixelBuffer);
        let height = CVPixelBufferGetHeight(pixelBuffer);
//        print("photo width: ", width)
//        print("photo height: ", height)
        
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return nil
        }
        
        guard let capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0, textureCache: textureCache),
              let capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1, textureCache: textureCache) else {
            return nil
        }
        
        return (textureY: capturedImageTextureY, textureCbCr: capturedImageTextureCbCr)
    }

}
