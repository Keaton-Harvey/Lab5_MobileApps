//
//  DSIDViewController.swift
//  Lab5_MobileApps
//
//  Created by Sam Skanse on 11/25/24.
//

import UIKit

class DSIDViewController: UIViewController, ClientDelegate {

    // MARK: - Outlets

    @IBOutlet weak var dsidListLabel: UILabel!
    @IBOutlet weak var dsidToDeleteTextField: UITextField!
    @IBOutlet weak var dsidToSelectTextField: UITextField!
    @IBOutlet weak var currentDsidLabel: UILabel!

    // MARK: - Properties

    let client = MlaasModel()
    var dsidArray: [Int] = []

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure client is not nil
//        if client == nil {
//            fatalError("Client is nil. Make sure it is passed from the previous view controller.")
//        }

        // Set up client delegate
        client.delegate = self

        // Display current DSID
        if let savedDsid = UserDefaults.standard.value(forKey: "dsid") as? Int {
            client.updateDsid(savedDsid)
            currentDsidLabel.text = "Current DSID: \(savedDsid)"
        } else {
            client.updateDsid(1) // Set default DSID
            currentDsidLabel.text = "Current DSID: 1"
        }

        // Fetch all DSIDs
        client.getAllDsids()
    }

    // MARK: - Actions

    @IBAction func deleteDsidButtonTapped(_ sender: UIButton) {
        guard let dsidText = dsidToDeleteTextField.text, let dsid = Int(dsidText) else {
            showAlert(title: "Invalid Input", message: "Please enter a valid DSID to delete.")
            return
        }

        client.deleteDsid(dsid)
    }

    @IBAction func selectDsidButtonTapped(_ sender: UIButton) {
        guard let dsidText = dsidToSelectTextField.text, let dsid = Int(dsidText) else {
            showAlert(title: "Invalid Input", message: "Please enter a valid DSID to select.")
            return
        }

        if dsidArray.contains(dsid) {
            updateDsid(dsid)
            showAlert(title: "Success", message: "DSID \(dsid) is now set as current.")
        } else {
            showAlert(title: "Error", message: "DSID \(dsid) does not exist.")
        }
    }

    // MARK: - ClientDelegate Methods

    func updateDsid(_ newDsid: Int) {
        DispatchQueue.main.async {
            self.client.updateDsid(newDsid)
            self.currentDsidLabel.text = "Current DSID: \(newDsid)"
            // Save DSID to UserDefaults
            UserDefaults.standard.set(newDsid, forKey: "dsid")
        }
    }

    func receivedDsids(_ dsids: [Int]) {
        DispatchQueue.main.async {
            self.dsidArray = dsids.sorted()
            self.dsidListLabel.text = "Available DSIDs: \(self.dsidArray.map { String($0) }.joined(separator: ", "))"
        }
    }

    func dsidDeletionCompleted(success: Bool, dsid: Int) {
        DispatchQueue.main.async {
            if success {
                self.showAlert(title: "Success", message: "DSID \(dsid) has been deleted.")
                // Remove DSID from dsidArray
                if let index = self.dsidArray.firstIndex(of: dsid) {
                    self.dsidArray.remove(at: index)
                }
                self.dsidListLabel.text = "Available DSIDs: \(self.dsidArray.map { String($0) }.joined(separator: ", "))"
                // If the deleted DSID was the current DSID, update the current DSID
                if self.client.getDsid() == dsid {
                    self.updateDsid(1)
                }
            } else {
                self.showAlert(title: "Error", message: "Failed to delete DSID \(dsid).")
            }
        }
    }

    func receivedPrediction(_ prediction: [String : Any]) {
        // Not used in this view controller
    }

    func receivedTrainingAccuracies(_ accuracies: [String : Any]) {
        // Not used in this view controller
    }

    func showError(message: String) {
        showAlert(title: "Error", message: message)
    }

    // MARK: - Helper Methods

    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default) { _ in
            // Dismiss keyboard if any
            self.view.endEditing(true)
        }
        alertController.addAction(alertAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
