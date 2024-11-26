//
//  ViewControllerModelSelection.swift
//  Lab5_MobileApps
//
//  Created by Sam Skanse on 11/24/24.
//

import UIKit

class ViewControllerModelSelection: UIViewController {
    
    private var yourDSID = 0
    let client = MlaasModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        yourDSID = client.getDsid()
        

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func neuralNetwork(_ sender: UIButton) {
        client.setModelOnServer(modelType: "tensorflow", dsid: yourDSID)
    }
    
    
    @IBAction func kNearestNeighbor(_ sender: UIButton) {
        client.setModelOnServer(modelType: "sklearn", dsid: yourDSID)
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
