//
//  ViewController.swift
//  Face
//
//  Created by Evan Bacon on 7/14/16.
//  Copyright © 2016 Brix. All rights reserved.
//


import UIKit
import CoreImage
import AVFoundation

import UIKit

class ViewController: UIViewController {
    private var faceDetector : FaceDetection?
    private let notificationCenter : NSNotificationCenter = NSNotificationCenter.defaultCenter()
    let label:UILabel = UILabel(frame:
        CGRect(
            x: UIScreen.mainScreen().bounds.origin.x,
            y: UIScreen.mainScreen().bounds.height - 70,
            width: UIScreen.mainScreen().bounds.width,
            height: 70
        ))
    let emojiLabel:UILabel = UILabel(frame: UIScreen.mainScreen().bounds)
    
    var text:String = "" {
        didSet {
                label.text = text

        }
    }
}


extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLabel()
        setupFaceDetector()
    }
    func setupLabel() {
        self.view.addSubview(label)
        label.font = UIFont.systemFontOfSize(50)
        label.textAlignment = .Center
    }
    
    func setupFaceDetector() {
        
        //Setup "Visage" with a camera-position (iSight-Camera (Back), FaceTime-Camera (Front)) and an optimization mode for either better feature-recognition performance (HighPerformance) or better battery-life (BatteryLife)
        faceDetector = FaceDetection(cameraPosition: FaceDetection.CameraDevice.FaceTimeCamera, optimizeFor: FaceDetection.Accuracy.HigherPerformance)
        
        //If you enable "onlyFireNotificationOnStatusChange" you won't get a continuous "stream" of notifications, but only one notification once the status changes.
        faceDetector!.onlyFireNotificatonOnStatusChange = false
        
        //You need to call "beginFaceDetection" to start the detection, but also if you want to use the cameraView.
        faceDetector!.beginFaceDetection()
        
        //This is a very simple cameraView you can use to preview the image that is seen by the camera.
        self.view.addSubview(faceDetector!.faceCameraView)
        
        emojiLabel.text = "😐"
        emojiLabel.font = UIFont.systemFontOfSize(50)
        emojiLabel.textAlignment = .Center
        self.view.addSubview(emojiLabel)
        
        NSNotificationCenter.defaultCenter().addObserverForName("faceFaceDetectedNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
            
            UIView.animateWithDuration(0.5, animations: {
                self.emojiLabel.alpha = 1
            })
            
            
            //Print Positions
            if self.faceDetector?.leftEyePosition != nil {
                let rect =  (self.faceDetector?.leftEyePosition)!
                print(rect)
            }
            
            if self.faceDetector?.rightEyePosition != nil {
                let rect =  (self.faceDetector?.rightEyePosition)!
                print(rect)
            }
            
            
            if (self.faceDetector!.hasSmile == true) {
                //Smile
                
                
                if (self.faceDetector!.isBlinking == true) {
                    self.emojiLabel.text = "😄"
                    
                }
                else if (self.faceDetector!.isWinking == true) {
                    //One Eye Closed
                    if (self.faceDetector!.leftEyeClosed == true) {
                        //Left Eye Closed
                        self.emojiLabel.text = "😉"
                        self.emojiLabel.transform = CGAffineTransformMakeScale(1, 1)
                        
                        print("Right Eye Closed")
                    } else {
                        //Right Eye Closed
                        self.emojiLabel.text = "😉"
                        self.emojiLabel.transform = CGAffineTransformMakeScale(-1, 1)
                        
                        print("Left Eye Closed")
                    }
                }
                else {
                    //Both Eyes Open
                    self.emojiLabel.text = "😃"
                    
                }
            } else {
                //No Smile
                if (self.faceDetector!.isBlinking == true) {
                    self.emojiLabel.text = "😑"
                } else {
                    self.emojiLabel.text = "😐"
                }
            }
        })
        
        //The same thing for the opposite, when no face is detected things are reset.
        NSNotificationCenter.defaultCenter().addObserverForName("faceNoFaceDetectedNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
            
            UIView.animateWithDuration(0.5, animations: {
                self.emojiLabel.alpha = 0.25
            })
        })
        
        
        self.view.addSubview(faceDetector!.faceCameraView)
        self.view.bringSubviewToFront(faceDetector!.faceCameraView)
        self.view.bringSubviewToFront(emojiLabel)
        self.view.bringSubviewToFront(label)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        text += self.emojiLabel.text!
        if (text.characters.count > 5) {
            text = String(text.characters.dropFirst())
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}