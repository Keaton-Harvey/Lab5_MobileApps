//
//  ViewControllerModelSelection.swift
//  Lab5_MobileApps
//
//  MARK: Code written assisted with Chat GPT
//

import UIKit

class ViewControllerModelSelection: UIViewController {
    
    private var yourDSID = 0
    let client = MlaasModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaults.standard.value(forKey: "dsid") is Int {
            yourDSID = UserDefaults.standard.value(forKey: "dsid") as! Int
        } else {
            client.updateDsid(1) // Set default DSID
        }
    
    }
    
    // MARK: - Actions
    @IBAction func neuralNetwork(_ sender: UIButton) {
        client.setModelOnServer(modelType: "tensorflow", dsid: yourDSID)
    }
    
    @IBAction func kNearestNeighbor(_ sender: UIButton) {
        client.setModelOnServer(modelType: "sklearn", dsid: yourDSID)
    }

}
