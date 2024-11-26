//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//  Updated 2024

// This example is meant to be run with the python example:
//              fastapi_turicreate.py
//              from the course GitHub repository





import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ClientDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    // MARK: - Outlets

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var digitPickerView: UIPickerView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var serverIPTextField: UITextField!

    // MARK: - Properties

    var capturedImage: UIImage?
    var currentMode: String = "Training" // or "Prediction"

    // Client for server communication
    let client = MlaasModel()

    // Picker view data
    let digitOptions = Array(0...9)
    var selectedDigit: Int = 0 // Default to 0

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initial UI setup
        updateUIForMode()

        // Set up client delegate
        client.delegate = self
        client.updateDsid(1) // Set default DSID

        // Set picker view data source and delegate
        digitPickerView.dataSource = self
        digitPickerView.delegate = self

        // Set initial selected digit
        digitPickerView.selectRow(0, inComponent: 0, animated: false)
        selectedDigit = digitOptions[0]

        // Dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // MARK: - UI Updates

    func updateUIForMode() {
        if currentMode == "Training" {
            digitPickerView.isHidden = false
            uploadButton.isHidden = false
            predictionLabel.isHidden = true
        } else {
            digitPickerView.isHidden = true
            uploadButton.isHidden = true
            predictionLabel.isHidden = false
            predictionLabel.text = "Prediction will appear here."
        }
    }

    // MARK: - Actions

    @IBAction func modeChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            currentMode = "Training"
        } else {
            currentMode = "Prediction"
        }
        updateUIForMode()
    }

    @IBAction func captureImageTapped(_ sender: UIButton) {
        openCamera()
    }

    @IBAction func uploadDataTapped(_ sender: UIButton) {
        uploadLabeledData()
    }
    
    @IBAction func setIPButton(_ sender: Any) {
        self.serverIPTextField.resignFirstResponder()
        let newIp = self.serverIPTextField.text ?? ""
        if newIp.isEmpty {
            return
        }
        if self.client.setServerIp(ip: newIp) {
               print("Server IP set successfully to \(newIp)")
           } else {
               print("Invalid IP address format.")
           }
        
    }


    @IBAction func getDataSetIdTapped(_ sender: UIButton) {
        client.getNewDsid()
    }

    @IBAction func trainModelTapped(_ sender: UIButton) {
        client.trainModel()
    }

    // MARK: - Image Capturing

    func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.cameraDevice = .rear
            imagePicker.allowsEditing = false
            present(imagePicker, animated: true, completion: nil)
        } else {
            // Show alert if camera is not available
            showAlert(title: "Error", message: "Camera not available.")
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage {
            capturedImage = image
            imageView.image = capturedImage
        }
        picker.dismiss(animated: true) {
            if self.currentMode == "Prediction" {
                self.predictDigit()
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    // MARK: - Data Upload and Prediction

    func uploadLabeledData() {
        guard let image = capturedImage else {
            showAlert(title: "Error", message: "No image captured.")
            return
        }

        // Use the selected digit from the picker view
        let label = String(selectedDigit)

        // Preprocess image and convert to base64
        guard let imageBase64 = preprocessImage(image) else { return }

        // Send data to server
        client.sendData(imageBase64, withLabel: label)
    }

    func predictDigit() {
        guard let image = capturedImage else {
            showAlert(title: "Error", message: "No image captured.")
            return
        }

        // Preprocess image and convert to base64
        guard let imageBase64 = preprocessImage(image) else { return }

        // Send image to server for prediction
        client.sendData(imageBase64)
    }

    // MARK: - Image Preprocessing

    func preprocessImage(_ image: UIImage) -> [Double]? {
        // Resize the image to 28x28 pixels
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()

        // Convert resized image to grayscale with 8 bits per pixel
        guard let grayCGImage = convertToGrayscale(image: resizedImage) else { return nil }

        // Now extract pixel data from the grayscale image
        guard let dataProvider = grayCGImage.dataProvider,
              let pixelData = dataProvider.data else { return nil }

        let data = CFDataGetBytePtr(pixelData)!
        let bytesPerRow = grayCGImage.bytesPerRow
        let bitsPerPixel = grayCGImage.bitsPerPixel
        let bitsPerComponent = grayCGImage.bitsPerComponent

        print("bitsPerComponent: \(bitsPerComponent), bitsPerPixel: \(bitsPerPixel), bytesPerRow: \(bytesPerRow)")

        // Ensure the image is in the expected format
        guard bitsPerComponent == 8, bitsPerPixel == 8 else {
            print("Unexpected image format. Expected 8 bits per component and 8 bits per pixel.")
            return nil
        }

        // Now we can iterate over each pixel
        var pixelArray = [Double]()
        let height = grayCGImage.height
        let width = grayCGImage.width

        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + x
                let gray = data[byteIndex]
                let pixelValue = Double(gray) / 255.0  // Normalize to [0.0, 1.0]
                pixelArray.append(pixelValue)
            }
        }

        return pixelArray
    }
    
    func convertToGrayscale(image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)

        guard let ctx = context else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return ctx.makeImage()
    }




    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(inputImage, from: inputImage.extent)
    }

    // MARK: - Helper Methods

    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - ClientDelegate Methods

    func updateDsid(_ newDsid: Int) {
        DispatchQueue.main.async {
            self.dsidLabel.text = "Current DSID: \(newDsid)"
            self.client.updateDsid(newDsid)
        }
    }

    func receivedPrediction(_ prediction: [String: Any]) {
        if let predictedDigit = prediction["prediction"] as? String {
            print(predictedDigit)
            DispatchQueue.main.async {
                self.predictionLabel.text = "Predicted Digit: \(predictedDigit)"
            }
        } else {
            showAlert(title: "Prediction Error", message: "Unknown error occurred.")
        }
    }

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return digitOptions.count
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(digitOptions[row])
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedDigit = digitOptions[row]
    }
}







/*

import UIKit
import CoreMotion

class ViewController: UIViewController, ClientDelegate {
    
    // MARK: Class Properties
    
    // interacting with server
    let client = MlaasModel() // how we will interact with the server
    
    // operation queues
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    // motion data properties
    var ringBuffer = RingBuffer()
    let motion = CMMotionManager()
    var magThreshold = 0.1
    
    // state variables
    var isCalibrating = false
    var isWaitingForMotionData = false
    
    // User Interface properties
    let animation = CATransition()
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var upArrow: UILabel!
    @IBOutlet weak var rightArrow: UILabel!
    @IBOutlet weak var downArrow: UILabel!
    @IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    @IBOutlet weak var settableIP: UITextField!
    
    @IBAction func setIPButton(_ sender: Any) {
        self.settableIP.resignFirstResponder()
        let newIp = self.settableIP.text ?? ""
        if newIp.isEmpty {
            return
        }
        if self.client.setServerIp(ip: newIp) {
               print("Server IP set successfully to \(newIp)")
           } else {
               print("Invalid IP address format.")
           }
        
    }

    
    // MARK: Class Properties with Observers
    enum CalibrationStage:String {
        case notCalibrating = "notCalibrating"
        case up = "up"
        case right = "right"
        case down = "down"
        case left = "left"
    }
    
    var calibrationStage:CalibrationStage = .notCalibrating {
        didSet{
            self.setInterfaceForCalibrationStage()
        }
    }
        
    @IBAction func magnitudeChanged(_ sender: UISlider) {
        self.magThreshold = Double(sender.value)
    }
       
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.fade
        animation.duration = 0.5
        
        // setup core motion handlers
        startMotionUpdates()
        
        // use delegation for interacting with client 
        client.delegate = self
        client.updateDsid(5) // set default dsid to start with

    }
    
    //MARK: UI Buttons
    @IBAction func getDataSetId(_ sender: AnyObject) {
        client.getNewDsid() // protocol used to update dsid
    }
    
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage() // kick off the calibration stages
        
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
        client.trainModel()
    }

}

//MARK: Protocol Required Functions
extension ViewController {
    func updateDsid(_ newDsid:Int){
        // delegate function completion handler
        DispatchQueue.main.async{
            // update label when set
            self.dsidLabel.layer.add(self.animation, forKey: nil)
            self.dsidLabel.text = "Current DSID: \(newDsid)"
        }
    }
    
    func receivedPrediction(_ prediction:[String:Any]){
        if let labelResponse = prediction["prediction"] as? String{
            print(labelResponse)
            self.displayLabelResponse(labelResponse)
        }
        else{
            print("Received prediction data without label.")
        }
    }
}


//MARK: Motion Extension Functions
extension ViewController {
    // Core Motion Updates
    func startMotionUpdates(){
        // some internal inconsistency here: we need to ask the device manager for device
        
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 1.0/200
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
        }
    }
    
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
            
            DispatchQueue.main.async{
                //show magnitude via indicator
                self.largeMotionMagnitude.progress = Float(mag)/0.2
            }
            
            if mag > self.magThreshold {
                // buffer up a bit more data and then notify of occurrence
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                    self.calibrationOperationQueue.addOperation {
                        // something large enough happened to warrant
                        self.largeMotionEventOccurred()
                    }
                })
            }
        }
    }
    
    // Calibration event has occurred, send to server
    func largeMotionEventOccurred(){
        if(self.isCalibrating){
            //send a labeled example
            if(self.calibrationStage != .notCalibrating && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                
                // send data to the server with label
                self.client.sendData(self.ringBuffer.getDataAsVector(),
                                     withLabel: self.calibrationStage.rawValue)
                
                self.nextCalibrationStage()
            }
        }
        else
        {
            if(self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                //predict a label
                self.client.sendData(self.ringBuffer.getDataAsVector())
                // dont predict again for a bit
                setDelayedWaitingToTrue(2.0)
                
            }
        }
    }
}

//MARK: Calibration UI Functions
extension ViewController {
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    
    // blink the UILabel
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['up']","up":
            blinkLabel(upArrow)
            break
        case "['down']","down":
            blinkLabel(downArrow)
            break
        case "['left']","left":
            blinkLabel(leftArrow)
            break
        case "['right']","right":
            blinkLabel(rightArrow)
            break
        default:
            print("Unknown")
            break
        }
    }
    
    func setInterfaceForCalibrationStage(){
        switch calibrationStage {
        case .up:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsCalibrating(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .left:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsCalibrating(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .down:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsCalibrating(self.downArrow)
            }
            break
            
        case .right:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsCalibrating(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .notCalibrating:
            self.isCalibrating = false
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        }
    }
    
    func nextCalibrationStage(){
        switch self.calibrationStage {
        case .notCalibrating:
            //start with up arrow
            self.calibrationStage = .up
            setDelayedWaitingToTrue(1.0)
            break
        case .up:
            //go to right arrow
            self.calibrationStage = .right
            setDelayedWaitingToTrue(1.0)
            break
        case .right:
            //go to down arrow
            self.calibrationStage = .down
            setDelayedWaitingToTrue(1.0)
            break
        case .down:
            //go to left arrow
            self.calibrationStage = .left
            setDelayedWaitingToTrue(1.0)
            break
            
        case .left:
            //end calibration
            self.calibrationStage = .notCalibrating
            setDelayedWaitingToTrue(1.0)
            break
        }
    }
    
    
}

*/
