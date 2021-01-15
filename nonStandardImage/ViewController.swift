//
//  ViewController.swift
//  nonStandardImage
//
//  Created by Fernando on 6/1/2021.
//

import UIKit
enum MyError: Error{
    case xmlTagNotFound
    case fileNotFound
}


struct DataReader {
    enum DataReaderError: Error {
        case insufficientData
    }
    var data: Data
    var currentPosition: Int
    
    init(data: Data) {
        self.data = data
        self.currentPosition = 0
    }
    
    mutating func skipBytes(_ n: Int) {
        currentPosition += n
    }
    
    mutating func readUnsignedByte() throws -> Int {
        guard currentPosition < data.count else {
            throw DataReaderError.insufficientData
        }
        let byte = data[currentPosition]
        currentPosition += 1
        return Int(byte)
    }
    
    mutating func readBytes(_ n: Int) throws -> Data {
        guard currentPosition + n <= data.count else {
            throw DataReaderError.insufficientData
        }
        let subdata = data[currentPosition ..< currentPosition+n]
        currentPosition += n
        return subdata
    }
    
    
    var isAtEnd: Bool {
        return currentPosition == data.count
    }
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do{
            if let fileData = try getFileData(){
                try printData(data: fileData)
                if let bitmapData = try extractBitmapData(data: fileData),
                   let image = renderImage(data: bitmapData){
                    let imageView = UIImageView(image: image)
                    imageView.frame.origin.x = 200
                    imageView.frame.origin.y = 200
                    imageView.tag = 0
                    self.view.addSubview(imageView)
                }
            }
        }catch{
            print (error.localizedDescription)
            
        }
    }
    
    private func renderImage(data: Data) -> UIImage?{
        let numChineseCharacters = data.count / 72
        let width = numChineseCharacters * 24
        let height = 24
        
        let numComponents = 1
        let numBytes = height * width * numComponents
        
        let white: UInt8 = 0
        let black: UInt8  = 255
        
        var pixelData = [UInt8](repeating: white, count: numBytes) //Create a "fixed size array", prefill it
        
        var pixel : UInt8
        var pixelX : Int
        var pixelY : Int
        
        for (n, d) in data.enumerated(){
            pixelX = (n) / 3
            pixelY = (n % 3) * 8
            pixel = (d & 0b10000000 != 0) ? white : black
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b01000000 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b00100000 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b00010000 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b00001000 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b00000100 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            
            pixel = (d & 0b00000010 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
            pixel = (d & 0b00000001 != 0) ? white : black
            pixelY = pixelY + 1
            pixelData[ pixelY * width +  pixelX] = pixel
        }
        
        let colorspace = CGColorSpaceCreateDeviceGray()
        let rgbData = CFDataCreate(nil, pixelData, numBytes)!
        let provider = CGDataProvider(data: rgbData)!
        let rgbImageRef = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 8 ,
                                  bytesPerRow: width,
                                  space: colorspace,
                                  bitmapInfo:  CGBitmapInfo.byteOrderMask,//  CGBitmapInfo(rawValue: 0),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: CGColorRenderingIntent.defaultIntent)!
        // Do something with rgbImageRef, or for UIImage:
        let outputImage = UIImage(cgImage: rgbImageRef)
        return outputImage
    }
    
    private func extractBitmapData(data: Data) throws -> Data?{
        //define two constant variables for checking
        let charLT = 0x3C
        let charGT = 0x3E
        
        var dataReader = DataReader(data: data)
        
        var readXmlTagName = false //control whether
        var tempXmlTagNameData : [UInt8] = [] //buffer for checking xml tag name
        
        var startingPosOfPCNameData : Int = -1
        var lenOfImageData = -1
        var pcNameTagFound = false
        
        while !dataReader.isAtEnd{
            
            let unsignedByte = try dataReader.readUnsignedByte()
            
            //keep track of cursor position in <PCNAME>...</PCNAME>
            let isLT = unsignedByte == charLT
            let isGT = unsignedByte == charGT
            
            
            if isLT || isGT{
                readXmlTagName = isLT //sets a flag to indicate if we are reading content of XML tag
            }
            
            if isLT{
                continue
            }
            
            if readXmlTagName{
                tempXmlTagNameData.append( UInt8(unsignedByte))
            }
            
            if !readXmlTagName{ //
                let tagName = String(bytes: tempXmlTagNameData, encoding: .utf8) ?? ""
                if tagName == "PCNAME"{
                    //Find length of image data according to specification
                    //length of [image data] is calculated as len1 X 256 + len2
                    let len1 = try dataReader.readUnsignedByte()
                    let len2 = try dataReader.readUnsignedByte()
                    
                    startingPosOfPCNameData = dataReader.currentPosition //DataPointer is now at the head of image data
                    
                    lenOfImageData =  len1 * 256 + len2
                    pcNameTagFound = true
                    break
                }
                tempXmlTagNameData = []
            }
        }
        
        if pcNameTagFound{
            //Copy a subset of the Data and return it
            var returnData = Data()
            for index  in startingPosOfPCNameData ..< startingPosOfPCNameData +  lenOfImageData{
                let intIndex = Int(index)
                let datapoint = data[intIndex]
                returnData.append(datapoint)
                
            }
            return returnData
        }else{
            throw MyError.xmlTagNotFound
        }
    }
    
    
    
    //Print Content of data to debug console
    private func printData(data: Data) throws {
        var dataReader = DataReader(data: data)
        
        print ("Number of bytes read: \(dataReader.data.count)")
        while !dataReader.isAtEnd{
            let byteRead = try dataReader.readUnsignedByte()
            
            let char = String(bytes: [UInt8(byteRead)], encoding: .utf8) ?? ""
            print ("\(String (byteRead, radix: 16))  \(char)"  )
        }
    }
    
    private func getFileData() throws -> Data?{
        if let filepath = Bundle.main.url(forResource: "imageData", withExtension: "txt") {
            let data = try Data(contentsOf: filepath)
            return data
        } else {
            throw MyError.fileNotFound
        }
    }
}

