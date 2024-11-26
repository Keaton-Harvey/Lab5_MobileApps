//
//  ImageViewController.swift
//  Lab5_MobileApps
//
//  MARK: Code written assisted with Chat GPT
//

import UIKit

class ImageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ClientDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
   
    

    // MARK: - Outlets

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var digitPickerView: UIPickerView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var labelImagePrompt: UILabel!
    // MARK: - Properties

    var capturedImage: UIImage?
    var currentMode: String = "Training" // or mode "Prediction"

    let client = MlaasModel()

    // Picker view data 1 to 9 with default 1
    let digitOptions = Array(1...9)
    var selectedDigit: Int = 1

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initial setup
        updateUIForMode()
        client.delegate = self

        // Retrieve DSID and server IP from UserDefaults
        if let dsid = UserDefaults.standard.value(forKey: "dsid") as? Int {
            client.updateDsid(dsid)
        } else {
            client.updateDsid(1) // Default DSID
        }

        if let serverIP = UserDefaults.standard.string(forKey: "serverIP") {
            if client.setServerIp(ip: serverIP) {
                print("Server IP set to \(serverIP)")
            } else {
                print("Invalid server IP format.")
            }
        }

        digitPickerView.dataSource = self
        digitPickerView.delegate = self

        digitPickerView.selectRow(0, inComponent: 0, animated: false)
        selectedDigit = digitOptions[0]
    }

    // MARK: - UI Updates

    func updateUIForMode() {
        if currentMode == "Training" {
            digitPickerView.isHidden = false
            uploadButton.isHidden = false
            predictionLabel.isHidden = true
            labelImagePrompt.isHidden = false
        } else {
            digitPickerView.isHidden = true
            uploadButton.isHidden = true
            predictionLabel.isHidden = false
            predictionLabel.text = "Prediction will appear here."
            labelImagePrompt.isHidden = true
    
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

        // Preprocess image
        guard let pixelValues = preprocessImage(image) else { return }

        // Send to server
        client.sendData(pixelValues, withLabel: label)
    }

    func predictDigit() {
        guard let image = capturedImage else {
            showAlert(title: "Error", message: "No image captured.")
            return
        }

        // Preprocess image
        guard let pixelValues = preprocessImage(image) else { return }

        // Send image to server for prediction
        client.sendData(pixelValues)
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

    // MARK: - Helper Methods

    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - ClientDelegate Methods

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

    // MARK: Nonused protocol methods
    func updateDsid(_ newDsid: Int) {
        // does nothing here
    }
    
    func receivedDsids(_ dsids: [Int]) {
        //does nothing here
    }
    
    func dsidDeletionCompleted(success: Bool, dsid: Int) {
        //does nothing here
    }
    
    func showError(message: String) {
        //does nothing here
    }
    
    func receivedTrainingAccuracies(_ accuracies: [String : Any]) {
        //doesn't do anything in here
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
