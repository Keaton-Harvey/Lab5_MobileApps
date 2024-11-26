//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Eric Cooper Larson on 6/5/24.
//  Updated 2024

import UIKit

protocol ClientDelegate {
    func updateDsid(_ newDsid: Int)
    func receivedPrediction(_ prediction: [String: Any])
    func receivedTrainingAccuracies(_ accuracies: [String: Any])
    func receivedDsids(_ dsids: [Int])
    func dsidDeletionCompleted(success: Bool, dsid: Int)
    func showError(message: String)
}

class MlaasModel: NSObject, URLSessionDelegate {

    // MARK: - Properties

    private let operationQueue = OperationQueue()
    var server_ip = "192.168.1.79" // Default IP, change if necessary
    var delegate: ClientDelegate?
    private var dsid: Int = 1

    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral

        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1

        let tmp = URLSession(configuration: sessionConfig,
                             delegate: self,
                             delegateQueue: self.operationQueue)

        return tmp
    }()

    // MARK: - DSID Management

    func updateDsid(_ newDsid: Int) {
        dsid = newDsid
    }

    func getDsid() -> Int {
        return dsid
    }

    // MARK: - Server IP Management

    func setServerIp(ip: String) -> Bool {
        // Validate IP address format
        if matchIp(for: "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.|$)){4}", in: ip) || ip == "localhost" {
            server_ip = ip
            return true
        } else {
            return false
        }
    }

    // MARK: - Data Transmission

    func sendData(_ array:[Double], withLabel label:String){
        let baseURL = "http://\(server_ip):8000/labeled_data/"
        let postUrl = URL(string: "\(baseURL)")

        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)

        // utility method to use from below
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "label":"\(label)",
            "dsid":self.dsid])

        // The Type of the request is given here
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
            //TODO: notify delegate?
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)

                print(jsonDictionary["feature"]!)
                print(jsonDictionary["label"]!)
            }
        })
        postTask.resume() // start the task
    }

    // post data without a label
    func sendData(_ array:[Double]){
        let baseURL = "http://\(server_ip):8000/predict/"
        let postUrl = URL(string: "\(baseURL)")

        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)

        // utility method to use from below
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "dsid":self.dsid])

        // The Type of the request is given here
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in

            if(error != nil){
                print("Error from server")
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{

                if let delegate = self.delegate {
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    delegate.receivedPrediction(jsonDictionary)
                }
            }
        })

        postTask.resume() // start the task
    }

    func setModelOnServer(modelType: String, dsid: Int) {
        // Prepare the URL
        guard let url = URL(string: "http://\(server_ip):8000/set_model/") else {
            print("Invalid URL")
            return
        }

        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the JSON payload
        let json: [String: Any] = [
            "model_type": modelType,
            "dsid": dsid
        ]

        // Convert JSON to Data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            print("Error converting JSON to Data")
            return
        }

        // Set the request body
        request.httpBody = jsonData

        // Create the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                print("Error sending POST request: \(error)")
                return
            }

            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("Model set successfully to \(modelType)")
                } else {
                    print("Server returned status code \(httpResponse.statusCode)")
                }
            }

            // Optionally handle response data
            if let data = data {
                if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) {
                    print("Response JSON: \(responseJSON)")
                } else {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Response String: \(responseString ?? "")")
                }
            }
        }

        // Start the data task
        task.resume()
    }

    func getNewDsid() {
        let baseURL = "http://\(server_ip):8000/max_dsid/"
        guard let getUrl = URL(string: baseURL) else { return }

        var request = URLRequest(url: getUrl)
        request.httpMethod = "GET"

        let getTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting new DSID: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let dsid = jsonDictionary["dsid"] as? Int {
                    let newDsid = dsid + 1
                    self.dsid = newDsid
                    if let delegate = self.delegate {
                        delegate.updateDsid(newDsid)
                    }
                }
            }
        }
        getTask.resume()
    }

   

    func accuraciesOfModels() {
        let baseURL = "http://\(server_ip):8000/train_models/\(dsid)"
        guard let getUrl = URL(string: baseURL) else { return }

        var request = URLRequest(url: getUrl)
        request.httpMethod = "GET"

        let getTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training models: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let delegate = self.delegate {
                    delegate.receivedTrainingAccuracies(jsonDictionary)
                }
            }
        }
        getTask.resume()
    }
    
    func trainModel() {
        let baseURL = "http://\(server_ip):8000/train_model/\(dsid)"
        guard let getUrl = URL(string: baseURL) else { return }

        var request = URLRequest(url: getUrl)
        request.httpMethod = "GET"

        let getTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training models: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let delegate = self.delegate {
                    delegate.receivedTrainingAccuracies(jsonDictionary)
                }
            }
        }
        getTask.resume()
    }
    
    
    func getAllDsids() {
        let baseURL = "http://\(server_ip):8000/dsids/"
        guard let url = URL(string: baseURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting DSIDs: \(error.localizedDescription)")
                self.delegate?.showError(message: "Error getting DSIDs: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let dsids = jsonDictionary["dsids"] as? [Int] {
                    self.delegate?.receivedDsids(dsids)
                } else {
                    print("DSIDs not found in response")
                    self.delegate?.showError(message: "DSIDs not found in server response.")
                }
            }
        }
        task.resume()
        
    }
    
    func deleteDsid(_ dsid: Int) {
            let baseURL = "http://\(server_ip):8000/labeled_data/\(dsid)"
            guard let deleteUrl = URL(string: baseURL) else { return }

            var request = URLRequest(url: deleteUrl)
            request.httpMethod = "DELETE"

            let deleteTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error deleting DSID: \(error.localizedDescription)")
                    self.delegate?.dsidDeletionCompleted(success: false, dsid: dsid)
                } else if let data = data {
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    if let numDeleted = jsonDictionary["num_deleted_results"] as? Int, numDeleted > 0 {
                        self.delegate?.dsidDeletionCompleted(success: true, dsid: dsid)
                    } else {
                        self.delegate?.dsidDeletionCompleted(success: false, dsid: dsid)
                    }
                } else {
                    self.delegate?.dsidDeletionCompleted(success: false, dsid: dsid)
                }
            }
            deleteTask.resume()
        }


    // MARK: - Utility Functions

    private func matchIp(for regex: String, in text: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.count > 0
        } catch {
            return false
        }
    }

    private func convertDataToDictionary(with data: Data?) -> [String: Any] {
        guard let data = data else { return [:] }
        do {
            let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return jsonDictionary ?? [:]
        } catch {
            print("JSON error: \(error.localizedDescription)")
            return [:]
        }
    }
}
