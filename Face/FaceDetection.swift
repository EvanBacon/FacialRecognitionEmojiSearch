//
//  FaceDetection.swift
//  Face
//
//  Created by Evan Bacon on 7/14/16.
//  Copyright © 2016 Brix. All rights reserved.
//

import Foundation
import UIKit

import CoreImage
import AVFoundation
import ImageIO

class FaceDetection: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum Accuracy {
        case BatterySaving
        case HigherPerformance
    }
    
    enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }
    
    var onlyFireNotificatonOnStatusChange : Bool = true
    var faceCameraView : UIView = UIView()
    
    //Private properties of the detected face that can be accessed (read-only) by other classes.
    private(set) var faceDetected : Bool?
    private(set) var faceBounds : CGRect?
    private(set) var faceAngle : CGFloat?
    private(set) var faceAngleDifference : CGFloat?
    private(set) var leftEyePosition : CGPoint?
    private(set) var rightEyePosition : CGPoint?
    
    private(set) var mouthPosition : CGPoint?
    private(set) var hasSmile : Bool?
    private(set) var isBlinking : Bool?
    private(set) var isWinking : Bool?
    private(set) var leftEyeClosed : Bool?
    private(set) var rightEyeClosed : Bool?
    
    //Notifications you can subscribe to for reacting to changes in the detected properties.
    private let faceNoFaceDetectedNotification = NSNotification(name: "faceNoFaceDetectedNotification", object: nil)
    private let faceFaceDetectedNotification = NSNotification(name: "faceFaceDetectedNotification", object: nil)
    private let faceSmilingNotification = NSNotification(name: "faceHasSmileNotification", object: nil)
    private let faceNotSmilingNotification = NSNotification(name: "faceHasNoSmileNotification", object: nil)
    private let faceBlinkingNotification = NSNotification(name: "faceBlinkingNotification", object: nil)
    private let faceNotBlinkingNotification = NSNotification(name: "faceNotBlinkingNotification", object: nil)
    private let faceWinkingNotification = NSNotification(name: "faceWinkingNotification", object: nil)
    private let faceNotWinkingNotification = NSNotification(name: "faceNotWinkingNotification", object: nil)
    private let faceLeftEyeClosedNotification = NSNotification(name: "faceLeftEyeClosedNotification", object: nil)
    private let faceLeftEyeOpenNotification = NSNotification(name: "faceLeftEyeOpenNotification", object: nil)
    private let faceRightEyeClosedNotification = NSNotification(name: "faceRightEyeClosedNotification", object: nil)
    private let faceRightEyeOpenNotification = NSNotification(name: "faceRightEyeOpenNotification", object: nil)
    
    //Private variables that cannot be accessed by other classes in any way.
    private var faceDetector : CIDetector?
    private var videoDataOutput : AVCaptureVideoDataOutput?
    private var videoDataOutputQueue : dispatch_queue_t?
    private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    private var captureSession : AVCaptureSession = AVCaptureSession()
    private let notificationCenter : NSNotificationCenter = NSNotificationCenter.defaultCenter()
    private var currentOrientation : Int?
    
    var options : [String : AnyObject]?
    init(cameraPosition : CameraDevice, optimizeFor : Accuracy) {
        super.init()
        
        currentOrientation = convertOrientation(UIDevice.currentDevice().orientation)
        
        switch cameraPosition {
        case .FaceTimeCamera : self.captureSetup(AVCaptureDevicePosition.Front)
        case .ISightCamera : self.captureSetup(AVCaptureDevicePosition.Back)
        }
        
        var faceDetectorOptions : [String : AnyObject]?
        
        switch optimizeFor {
        case .BatterySaving : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyLow]
        case .HigherPerformance : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh]
        }
        
        
        
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: CIContext(), options: faceDetectorOptions)
    }
    
}

extension FaceDetection {
    
    
    //MARK: SETUP OF VIDEOCAPTURE
    func beginFaceDetection() {
        self.captureSession.startRunning()
    }
    
    func endFaceDetection() {
        self.captureSession.stopRunning()
    }
    
    private func captureSetup (position : AVCaptureDevicePosition) {
        var captureDevice : AVCaptureDevice!
        
        for testedDevice in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo){
            if (testedDevice.position == position) {
                captureDevice = testedDevice as! AVCaptureDevice
            }
        }
        
        if (captureDevice == nil) {
            captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        }
        
        var deviceInput : AVCaptureDeviceInput!
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
        }
        
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if (captureSession.canAddInput(deviceInput)) {
            captureSession.addInput(deviceInput)
        }
        
        self.videoDataOutput = AVCaptureVideoDataOutput()
        //            self.videoDataOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        self.videoDataOutput!.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)
        self.videoDataOutput!.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue!)
        
        if (captureSession.canAddOutput(self.videoDataOutput)) {
            captureSession.addOutput(self.videoDataOutput)
        }
        
        
        faceCameraView.frame = UIScreen.mainScreen().bounds
        
        let previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        //        let previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer.layerWithSession(captureSession) as AVCaptureVideoPreviewLayer
        previewLayer.frame = UIScreen.mainScreen().bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        faceCameraView.layer.addSublayer(previewLayer)
    }
    
    
    //MARK: CAPTURE-OUTPUT/ANALYSIS OF FACIAL-FEATURES
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        let sourceImage = CIImage(CVPixelBuffer: pixelBuffer, options: nil)
        options = [CIDetectorSmile : true, CIDetectorEyeBlink: true, CIDetectorImageOrientation : 6]
        
        let features = self.faceDetector!.featuresInImage(sourceImage, options: options)
        
        if (features.count != 0) {
            
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == false) {
                    notificationCenter.postNotification(faceFaceDetectedNotification)
                }
            } else {
                notificationCenter.postNotification(faceFaceDetectedNotification)
            }
            
            self.faceDetected = true
            
            for feature in features as! [CIFaceFeature] {
                faceBounds = feature.bounds
                
                if (feature.hasFaceAngle) {
                    
                    if (faceAngle != nil) {
                        faceAngleDifference = CGFloat(feature.faceAngle) - faceAngle!
                    } else {
                        faceAngleDifference = CGFloat(feature.faceAngle)
                    }
                    
                    faceAngle = CGFloat(feature.faceAngle)
                }
                
                if (feature.hasLeftEyePosition) {
                    leftEyePosition = feature.leftEyePosition
                }
                
                if (feature.hasRightEyePosition) {
                    rightEyePosition = feature.rightEyePosition
                }
                
                if (feature.hasMouthPosition) {
                    mouthPosition = feature.mouthPosition
                }
                
                
                if (feature.hasSmile) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == false) {
                            notificationCenter.postNotification(faceSmilingNotification)
                        }
                    } else {
                        notificationCenter.postNotification(faceSmilingNotification)
                    }
                    
                    hasSmile = feature.hasSmile
                    
                } else {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == true) {
                            notificationCenter.postNotification(faceNotSmilingNotification)
                        }
                    } else {
                        notificationCenter.postNotification(faceNotSmilingNotification)
                    }
                    
                    
                    hasSmile = feature.hasSmile
                }
                
                if (feature.leftEyeClosed || feature.rightEyeClosed) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isWinking == false) {
                            notificationCenter.postNotification(faceWinkingNotification)
                        }
                    } else {
                        notificationCenter.postNotification(faceWinkingNotification)
                    }
                    
                    isWinking = true
                    
                    if (feature.leftEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.leftEyeClosed == false) {
                                notificationCenter.postNotification(faceLeftEyeClosedNotification)
                            }
                        } else {
                            notificationCenter.postNotification(faceLeftEyeClosedNotification)
                        }
                        
                        leftEyeClosed = feature.leftEyeClosed
                    }
                    if (feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.rightEyeClosed == false) {
                                notificationCenter.postNotification(faceRightEyeClosedNotification)
                            }
                        } else {
                            notificationCenter.postNotification(faceRightEyeClosedNotification)
                        }
                        
                        rightEyeClosed = feature.rightEyeClosed
                    }
                    
                    if (feature.leftEyeClosed && feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.isBlinking == false) {
                                notificationCenter.postNotification(faceBlinkingNotification)
                            }
                        } else {
                            notificationCenter.postNotification(faceBlinkingNotification)
                        }
                        
                        isBlinking = true
                    }
                } else {
                    
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isBlinking == true) {
                            notificationCenter.postNotification(faceNotBlinkingNotification)
                        }
                        if (self.isWinking == true) {
                            notificationCenter.postNotification(faceNotWinkingNotification)
                        }
                        if (self.leftEyeClosed == true) {
                            notificationCenter.postNotification(faceLeftEyeOpenNotification)
                        }
                        if (self.rightEyeClosed == true) {
                            notificationCenter.postNotification(faceRightEyeOpenNotification)
                        }
                    } else {
                        notificationCenter.postNotification(faceNotBlinkingNotification)
                        notificationCenter.postNotification(faceNotWinkingNotification)
                        notificationCenter.postNotification(faceLeftEyeOpenNotification)
                        notificationCenter.postNotification(faceRightEyeOpenNotification)
                    }
                    
                    isBlinking = false
                    isWinking = false
                    leftEyeClosed = feature.leftEyeClosed
                    rightEyeClosed = feature.rightEyeClosed
                }
            }
        } else {
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == true) {
                    notificationCenter.postNotification(faceNoFaceDetectedNotification)
                }
            } else {
                notificationCenter.postNotification(faceNoFaceDetectedNotification)
            }
            
            self.faceDetected = false
        }
    }
    private func convertOrientation(deviceOrientation: UIDeviceOrientation) -> Int {
        //        var orientation: Int = 0
        //        switch deviceOrientation {
        //        case .Portrait:
        //            orientation = 6
        //        case .PortraitUpsideDown:
        //            orientation = 2
        //        case .LandscapeLeft:
        //            orientation = 3
        //        case .LandscapeRight:
        //            orientation = 4
        //        default : orientation = 1
        //        }
        return 6
    }
    
}