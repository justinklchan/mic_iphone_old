//
//  ViewController.swift
//  audio_test
//
//  Created by Justin Kwok Lam CHAN on 4/4/21.
//

import Charts
import UIKit
import AVFoundation
import Accelerate

class ViewController: UIViewController, ChartViewDelegate {

    
    @IBOutlet weak var lineChart: LineChartView!
    var audioSession:AVAudioSession!
    var audioRecorder:AVAudioRecorder!
    var player: AVAudioPlayer?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.lineChart.delegate = self
    }
    
    @IBAction func startButton(_ sender: Any) {
        let timestamp = NSDate().timeIntervalSince1970
        
        let set_a: LineChartDataSet = LineChartDataSet(entries: [ChartDataEntry](), label: "")
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.blue)
        
        self.lineChart.data = LineChartData(dataSets: [set_a])
        
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
            guard let chirpurl = Bundle.main.url(forResource: "tone_1000", withExtension: "wav") else { return }
            
            player = try AVAudioPlayer(contentsOf: chirpurl, fileTypeHint: AVFileType.mp3.rawValue)
            
            // sets the volume, make sure phone is not on silent mode and external volume switch has volume up
            guard let player = player else { return }
            player.volume=0.01
            
            player.play()
            
            // important, need to sleep main thread while speaker is playing, otherwise
            // it will directly execute the next step without waiting for file to finish playing
            sleep(1)
            
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
        let N = n
        let N2 = vDSP_Length(N/2)

        let LOG_N = vDSP_Length(log2(Float(n)));

        let setup = vDSP_create_fftsetupD(LOG_N,2)!;
        
        let num = (sig.count-24000)+1
        var tempSplitComplexReal = [Double](repeating: 0.0, count: num);
        var tempSplitComplexImag = [Double](repeating: 0.0, count: num);
        var counter:Int = 0
        for i in 24000..<sig.count {
            tempSplitComplexReal[counter] = sig[i];
            counter+=1
        }

        var splitComplex: DSPDoubleSplitComplex!

        tempSplitComplexReal.withUnsafeMutableBufferPointer {
            realBP in tempSplitComplexImag.withUnsafeMutableBufferPointer {
                imaginaryBP in splitComplex = DSPDoubleSplitComplex(
                        realp: realBP.baseAddress!,
                        imagp: imaginaryBP.baseAddress!)
                    }
                }

        vDSP_fft_zipD(setup, &splitComplex, 1, LOG_N, FFTDirection(FFT_FORWARD));

        var fftMagnitudes = [Double](repeating: 0.0, count: N/2)
        vDSP_zvmagsD(&splitComplex, 1, &fftMagnitudes, 1, N2);
        vDSP_destroy_fftsetupD(setup);

        print(fftMagnitudes.description)
        
//        if self.lineChart.data!.entryCount > 0 {
//            for i in 0...self.lineChart.data!.entryCount {
//                self.lineChart.data!.remove(i,0)
//            }
//        }
        
        counter=0
        for val in fftMagnitudes {
            self.lineChart.data?.append(ChartDataEntry(x: Double(counter), y: 10*log10(val)) as! ChartDataSetProtocol)
            counter+=1
        }
        
        self.lineChart.notifyDataSetChanged()
        
        return fftMagnitudes
    }
}

