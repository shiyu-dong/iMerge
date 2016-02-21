//
//  ViewController.swift
//  iMerge
//
//  Created by Shiyu Dong on 2/20/16.
//  Copyright © 2016 Shiyu Dong. All rights reserved.
//

import UIKit
import MobileCoreServices
import AssetsLibrary
import MediaPlayer
import CoreMedia
import AVKit
import AVFoundation

class ViewController: UIViewController {
    var firstAsset: AVAsset?
    var secondAsset: AVAsset?
    var loadingAssetOne = false
    var pre_merged = false
    var exporter: AVAssetExportSession? = nil
    
    //@IBOutlet var activityMonitor: UIActivityIndicatorView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loadAssetOne(sender: AnyObject) {
        if savedPhotosAvailable() {
            loadingAssetOne = true
            startMediaBrowserFromViewController(self, usingDelegate: self)
            pre_merged = false;
        }
    }
    @IBAction func previewAssetOne(sender: AnyObject) {
        if (firstAsset == nil) {
            let alert = UIAlertController(title: "Error", message: "Video 1 not loaded", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        }
        else {
            let item = AVPlayerItem(asset: firstAsset!)
            let player = AVPlayer(playerItem: item)
            let playerController = AVPlayerViewController()
            
            playerController.player = player
            presentViewController(playerController, animated: true) { () -> Void in
                player.play()
            }
        }
    }
    @IBAction func previewAssetTwo(sender: AnyObject) {
        if (secondAsset == nil) {
            let alert = UIAlertController(title: "Error", message: "Video 2 not loaded", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        }
        else {
            let item = AVPlayerItem(asset: secondAsset!)
            let player = AVPlayer(playerItem: item)
            let playerController = AVPlayerViewController()
            
            playerController.player = player
            presentViewController(playerController, animated: true) { () -> Void in
                player.play()
            }
        }
    }
    

    
    @IBAction func loadAssetTwo(sender: AnyObject) {
        if savedPhotosAvailable() {
            loadingAssetOne = false
            startMediaBrowserFromViewController(self, usingDelegate: self)
            pre_merged = false
        }
    }
    
    @IBAction func preview() {
        pre_merge(true);
    }
    
    func pre_merge(is_for_preview: Bool) {
        if (firstAsset == nil || secondAsset == nil) {
            var err_msg: String
            if (is_for_preview) {
                err_msg = "previewing"
            }
            else {
                err_msg = "merging"
            }
            let alert = UIAlertController(title: "Error", message: "Must load two videos first before \(err_msg)", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        }
        else if let firstAsset = firstAsset, secondAsset = secondAsset {
            
            // create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
            let mixComposition = AVMutableComposition()
            
            // Create and merge video and audio tracks
            let videoTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            let audioTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration),
                    ofTrack: firstAsset.tracksWithMediaType(AVMediaTypeVideo)[0] ,
                    atTime: kCMTimeZero)
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration),
                    ofTrack: firstAsset.tracksWithMediaType(AVMediaTypeAudio)[0] ,
                    atTime: kCMTimeZero)
            } catch {
                // ...
            }
            
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration),
                    ofTrack: secondAsset.tracksWithMediaType(AVMediaTypeVideo)[0] ,
                    atTime: firstAsset.duration)
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration),
                    ofTrack: secondAsset.tracksWithMediaType(AVMediaTypeAudio)[0] ,
                    atTime: firstAsset.duration)
            } catch {
                // ...
            }
            
            // fix orientation
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration))
            
            let firstInstruction = videoCompositionInstructionForTrack(videoTrack, asset: firstAsset)
            firstInstruction.setOpacity(0.0, atTime: firstAsset.duration)
            let secondInstruction = videoCompositionInstructionForTrack(videoTrack, asset: secondAsset)
            
            mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = [mainInstruction]
            mainComposition.frameDuration = CMTimeMake(1, 30)
            mainComposition.renderSize = CGSize(width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.height)
            
            // get path to export
            let directory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateStyle = .LongStyle
            dateFormatter.timeStyle = .ShortStyle
            let date = dateFormatter.stringFromDate(NSDate())
            let savePath = "\(directory)/mergedVideo-\(date).mp4"
            let url = NSURL(fileURLWithPath: savePath)
            
            // create exporter
            //let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            exporter?.outputURL = url
            exporter?.shouldOptimizeForNetworkUse = true
            exporter!.outputFileType = AVFileTypeQuickTimeMovie
            exporter!.videoComposition = mainComposition
            
            // preview video
            if (is_for_preview) {
                let item = AVPlayerItem(asset: mixComposition)
                item.videoComposition = mainComposition
                let player = AVPlayer(playerItem: item)
                let playerController = AVPlayerViewController()
                
                playerController.player = player
                presentViewController(playerController, animated: true) { () -> Void in
                    player.play()
                }
            }
            pre_merged = true
        }
    }
    
    @IBAction func merge(sender: AnyObject) {
        if (pre_merged == false) {
            pre_merge(false)
        }
        if (exporter != nil) {
            // perform the export
            exporter?.exportAsynchronouslyWithCompletionHandler({ () -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.self.exportDidFinish(self.exporter!)
                })
            })
        }
    }

    func savedPhotosAvailable() -> Bool {
        if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
            let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
    
    func startMediaBrowserFromViewController(viewController: UIViewController!, usingDelegate delegate : protocol<UINavigationControllerDelegate, UIImagePickerControllerDelegate>!) -> Bool {
        
        if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
            return false
        }
        
        let mediaUI = UIImagePickerController()
        mediaUI.sourceType = .SavedPhotosAlbum
        mediaUI.mediaTypes = [kUTTypeMovie as String]
        mediaUI.allowsEditing = true
        mediaUI.delegate = delegate
        presentViewController(mediaUI, animated: true, completion: nil)
        return true
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
        if session.status == AVAssetExportSessionStatus.Completed {
            let outputURL = session.outputURL
            let library = ALAssetsLibrary()
            if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL) {
                library.writeVideoAtPathToSavedPhotosAlbum(outputURL,
                    completionBlock: { (assetURL:NSURL!, error:NSError!) -> Void in
                        var title = ""
                        var message = ""
                        if error != nil {
                            title = "Error"
                            message = "Failed to save video"
                        } else {
                            title = "Success"
                            message = "Video saved"
                        }
                        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                })
            }
        }
        firstAsset = nil
        secondAsset = nil
        pre_merged = false
        exporter = nil
    }
    

    
    
    func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation = UIImageOrientation.Up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .Right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .Left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .Up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .Down
        }
        return (assetOrientation, isPortrait)
    }
    
    func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        let transform = assetTrack.preferredTransform
        let assetInfo = orientationFromTransform(transform)
        
        var scaleToFitRatio = UIScreen.mainScreen().bounds.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            scaleToFitRatio = UIScreen.mainScreen().bounds.width / assetTrack.naturalSize.height
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            instruction.setTransform(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor),
                atTime: kCMTimeZero)
        } else {
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            var concat = CGAffineTransformConcat(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor), CGAffineTransformMakeTranslation(0, UIScreen.mainScreen().bounds.width / 2))
            if assetInfo.orientation == .Down {
                let fixUpsideDown = CGAffineTransformMakeRotation(CGFloat(M_PI))
                let windowBounds = UIScreen.mainScreen().bounds
                let yFix = assetTrack.naturalSize.height + windowBounds.height
                let centerFix = CGAffineTransformMakeTranslation(assetTrack.naturalSize.width, yFix)
                concat = CGAffineTransformConcat(CGAffineTransformConcat(fixUpsideDown, centerFix), scaleFactor)
            }
            instruction.setTransform(concat, atTime: kCMTimeZero)
        }
        return instruction
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        dismissViewControllerAnimated(true, completion: nil)
        if mediaType == kUTTypeMovie {
            let avAsset = AVAsset(URL: info[UIImagePickerControllerMediaURL] as! NSURL)
            var message = ""
            if loadingAssetOne {
                message = "Video one loaded"
                firstAsset = avAsset
            } else {
                message = "Video two loaded"
                secondAsset = avAsset
            }
            let alert = UIAlertController(title: "Asset Loaded", message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        }
    }
}

extension ViewController: UINavigationControllerDelegate {
    
}
