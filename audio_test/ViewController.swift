//
//  ViewController.swift
//  audio_test
//
//  Created by Justin Kwok Lam CHAN on 4/4/21.
//

import UIKit
import AVFoundation
import Accelerate

class ViewController: UIViewController {
    
    var audioSession:AVAudioSession!
    var audioRecorder:AVAudioRecorder!
    var player: AVAudioPlayer?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func startButton(_ sender: Any) {
        let timestamp = NSDate().timeIntervalSince1970
        let filename = "audio-\(timestamp).caf"
        label.text=filename
        myrecord(filename: filename)
        myfft(sig: readfile(filename: filename), n: 2048)
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func myrecord(filename: String) {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try
                // play and record allows speaker and mic to be on at the same time
                audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: audioSession.mode, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            
            // creates file path to save audio file
            let url = NSURL(fileURLWithPath: getDocumentsDirectory().absoluteString).appendingPathComponent(filename)
            
            // settings, including the sampling rate of 48khz
            // # channels
            // bit depth (# bits used to encode each sample)
            let recordSettings:[String:Any] = [AVFormatIDKey:kAudioFormatLinearPCM,
                                               AVSampleRateKey:48000.0,
                                               AVNumberOfChannelsKey:1,
                                               AVLinearPCMIsNonInterleaved: true,
                                               AVLinearPCMBitDepthKey: 16]
            
            // initialize audio recorder and session
            try audioRecorder = AVAudioRecorder(url:url!, settings: recordSettings)
            audioRecorder.prepareToRecord()
            
            try audioSession.setActive(true)
            
            audioRecorder.record()
            
            // read audio file to be played
            guard let chirpurl = Bundle.main.url(forResource: "shortchirp", withExtension: "wav") else { return }
            
            player = try AVAudioPlayer(contentsOf: chirpurl, fileTypeHint: AVFileType.mp3.rawValue)
            
            // sets the volume, make sure phone is not on silent mode and external volume switch has volume up
            guard let player = player else { return }
            player.volume=0.02
            
            player.play()
            
            // important, need to sleep main thread while speaker is playing, otherwise
            // it will directly execute the next step without waiting for file to finish playing
            sleep(3)
            
            audioRecorder.stop()
            player.stop()
            try audioSession.setActive(false)
            
        }catch let error {
            print("ERROR")
            print(error.localizedDescription)
        }
    }
    
    func readfile(filename: String) -> Array<Double> {
        var vals = [Double]();
        
        let filePath = NSURL(fileURLWithPath: getDocumentsDirectory().absoluteString).appendingPathComponent(filename)!
        
        print(filePath)
        do {
            if try filePath.checkResourceIsReachable() {
                print(filePath.absoluteString+" exists")
            }
            else {
                print(filePath.absoluteString+" doesn't exists")
            }
            let file = try AVAudioFile.init(forReading: filePath)
            
            let length = AVAudioFrameCount(file.length)
            let processingFormat = file.processingFormat
            
            let buffer = AVAudioPCMBuffer.init(pcmFormat: processingFormat, frameCapacity: length)!
            try file.read(into: buffer)
            
            let channelCount = buffer.format.channelCount
            
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(channelCount))
            let data = UnsafeBufferPointer(start: channels[0], count: Int(length))
            
            for i in 0..<data.count {
                vals.append(Double(data[i]))
            }
        }
        catch let error {
            print (error.localizedDescription)
        }
        return vals;
    }
    
    func myfft(sig: Array<Double>, n: Int) -> Array<Double> {
        let LOG_N = vDSP_Length(log2(Float(n)));
        
        let setup = vDSP_create_fftsetupD(LOG_N,2)!;
        
        var tempSplitComplexReal = [Double](repeating: 0.0, count: sig.count);
        var tempSplitComplexImag = [Double](repeating: 0.0, count: sig.count);
        for i in 0..<sig.count {
            tempSplitComplexReal[i] = sig[i];
        }
        
        var tempSplitComplex = DSPDoubleSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag);
        
        vDSP_fft_zipD(setup, &tempSplitComplex, 1, LOG_N, FFTDirection(FFT_FORWARD));
        
        var fftMagnitudes = [Double](repeating: 0.0, count: n/2)
        vDSP_zvmagsD(&tempSplitComplex, 1, &fftMagnitudes, 1, vDSP_Length(n/2));
        vDSP_destroy_fftsetupD(setup);
        
        return fftMagnitudes
    }
}

