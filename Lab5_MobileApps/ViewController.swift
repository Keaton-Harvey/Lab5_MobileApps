//
//  ViewController.swift
//  Lab5_Mobile Apps
//
//  Created by Eric Larson
//  Updated 2024 by Sam Skanse, Keaton Harvey
//
//  MARK: Code written assisted with Chat GPT

import UIKit

class ViewController: UIViewController, ClientDelegate {
   
    

    // MARK: - Outlets

    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var serverIPTextField: UITextField!

    // MARK: - Properties

    // Client for server communication
    let client = MlaasModel()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up client delegate and set DSID
        client.delegate = self
        
        if let savedDsid = UserDefaults.standard.value(forKey: "dsid") as? Int {
            client.updateDsid(savedDsid)
            dsidLabel.text = "Current DSID: \(savedDsid)"
        } else {
            client.updateDsid(1) // Set default DSID
            dsidLabel.text = "Current DSID: 1"
        }

        // Dismisses the keyboard when tapped outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            // Update DSID label when backed out from DSIDViewController
        dsidLabel.text = "Current DSID: \(UserDefaults.standard.value(forKey: "dsid") ?? 1)"
        }

    
    // MARK: - Actions

    @IBAction func setIPButton(_ sender: UIButton) {
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
        dsidLabel.text = "Current DSID: \(client.getDsid())"
    }

    @IBAction func trainModelTapped(_ sender: UIButton) {
        client.trainModel()
    }
    
    @IBAction func trainingAccuraciesTapped(_ sender: UIButton) {
        client.accuraciesOfModels()
    }
    
    // MARK: - Helper Methods

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - ClientDelegate Methods

    func updateDsid(_ newDsid: Int) {
        DispatchQueue.main.async {
            self.dsidLabel.text = "Current DSID: \(newDsid)"
            self.client.updateDsid(newDsid)
            // Save the DSID to UserDefaults
            UserDefaults.standard.set(newDsid, forKey: "dsid")
        }
    }

    func receivedPrediction(_ prediction: [String: Any]) {
        // This ViewController doesn't handle predictions
    }

    func receivedTrainingAccuracies(_ accuracies: [String: Any]) {
        DispatchQueue.main.async {
            // Gets accuracies
            if let sklearn = accuracies["sklearn"] as? [String: Any],
               let tensorflow = accuracies["tensorflow"] as? [String: Any],
               let sklearnAccuracy = sklearn["accuracy"] as? Double,
               let tensorflowAccuracy = tensorflow["accuracy"] as? Double {
                
                // Display accuracies in popup
                let message = String(format: "KNN Accuracy: %.2f\nCNN Accuracy: %.2f", sklearnAccuracy, tensorflowAccuracy)
                let alertController = UIAlertController(title: "Training Accuracies", message: message, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    //MARK: Nonused Protocol Methods
    
    func receivedDsids(_ dsids: [Int]) {
        //does nothing here
    }
    
    func dsidDeletionCompleted(success: Bool, dsid: Int) {
        //does nothing here
    }
    
    func showError(message: String) {
        //does nothing here
    }
}
