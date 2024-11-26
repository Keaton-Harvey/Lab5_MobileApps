//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Eric Cooper Larson on 6/5/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//




/// This model uses delegation to interact with the main controller. The two functions below are for notifying the user that an update was completed successfully on the server. They must be implemented.





import UIKit

protocol ClientDelegate {
    func updateDsid(_ newDsid: Int)
    func receivedPrediction(_ prediction: [String: Any])
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

    

//    func sendData(_ imageBase64: String) {
//        let baseURL = "http://\(server_ip):8000/predict/"
//        guard let postUrl = URL(string: baseURL) else { return }
//
//        // Create a custom HTTP POST request
//        var request = URLRequest(url: postUrl)
//
//        // Request body
//        let requestBody: [String: Any] = [
//            "image_data": imageBase64,
//            "dsid": dsid
//        ]
//
//        // Configure request
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
//
//        let postTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Error predicting digit: \(error.localizedDescription)")
//            } else if let data = data {
//                if let delegate = self.delegate {
//                    let jsonDictionary = self.convertDataToDictionary(with: data)
//                    delegate.receivedPrediction(jsonDictionary)
//                }
//            }
//        }
//        postTask.resume()
//    }

    func getNewDsid() {
        let baseURL = "http://\(server_ip):8000/get_new_dsid/"
        guard let getUrl = URL(string: baseURL) else { return }

        var request = URLRequest(url: getUrl)
        request.httpMethod = "GET"

        let getTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting new DSID: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let dsid = jsonDictionary["dsid"] as? Int {
                    if let delegate = self.delegate {
                        delegate.updateDsid(dsid)
                    }
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
                print("Error training model: \(error.localizedDescription)")
            } else if let data = data {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if let summary = jsonDictionary["summary"] as? String {
                    print("Model training summary: \(summary)")
                }
            }
        }
        getTask.resume()
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




/*
 
 protocol ClientDelegate{
 func updateDsid(_ newDsid:Int) // if the delegate needs to update UI
 func receivedPrediction(_ prediction:[String:Any])
 }
 
 enum RequestEnum:String {
 case get = "GET"
 case put = "PUT"
 case post = "POST"
 case delete = "DELETE"
 }
 
 import UIKit
 
 class MlaasModel: NSObject, URLSessionDelegate{
 
 //MARK: Properties and Delegation
 private let operationQueue = OperationQueue()
 // default ip, if you are unsure try: ifconfig |grep "inet "
 // to see what your public facing IP address is
 var server_ip = "192.168.1.80"
 //"10.9.166.123" // this will be the default ip
 // create a delegate for using the protocol
 var delegate:ClientDelegate?
 private var dsid:Int = 5
 
 // public access methods
 func updateDsid(_ newDsid:Int){
 dsid = newDsid
 }
 func getDsid()->(Int){
 return dsid
 }
 
 lazy var session = {
 let sessionConfig = URLSessionConfiguration.ephemeral
 
 sessionConfig.timeoutIntervalForRequest = 5.0
 sessionConfig.timeoutIntervalForResource = 8.0
 sessionConfig.httpMaximumConnectionsPerHost = 1
 
 let tmp = URLSession(configuration: sessionConfig,
 delegate: self,
 delegateQueue:self.operationQueue)
 
 return tmp
 
 }()
 
 //MARK: Setters and Getters
 func setServerIp(ip:String)->(Bool){
 // user is trying to set ip: make sure that it is valid ip address
 if matchIp(for:"((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.|$)){4}", in: ip){
 server_ip = ip
 // return success
 return true
 }else{
 return false
 }
 }
 
 
 //MARK: Main Functions
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
 let baseURL = "http://\(server_ip):8000/predict_sklearn/"
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
 
 // get and store a new DSID
 func getNewDsid(){
 let baseURL = "http://\(server_ip):8000/max_dsid/"
 let postUrl = URL(string: "\(baseURL)")
 
 // create a custom HTTP POST request
 var request = URLRequest(url: postUrl!)
 
 request.httpMethod = "GET"
 request.setValue("application/json", forHTTPHeaderField: "Content-Type")
 
 let getTask : URLSessionDataTask = self.session.dataTask(with: request,
 completionHandler:{(data, response, error) in
 // TODO: handle error!
 let jsonDictionary = self.convertDataToDictionary(with: data)
 
 if let delegate = self.delegate,
 let resp=response,
 let dsid = jsonDictionary["dsid"] as? Int {
 // tell delegate to update interface for the Dsid
 self.dsid = dsid+1
 delegate.updateDsid(self.dsid)
 
 print(resp)
 }
 
 })
 
 getTask.resume() // start the task
 
 }
 
 func trainModel(){
 let baseURL = "http://\(server_ip):8000/train_model_sklearn/\(dsid)"
 let postUrl = URL(string: "\(baseURL)")
 
 // create a custom HTTP POST request
 var request = URLRequest(url: postUrl!)
 
 request.httpMethod = "GET"
 request.setValue("application/json", forHTTPHeaderField: "Content-Type")
 
 let getTask : URLSessionDataTask = self.session.dataTask(with: request,
 completionHandler:{(data, response, error) in
 // TODO: handle error!
 let jsonDictionary = self.convertDataToDictionary(with: data)
 
 if let summary = jsonDictionary["summary"] as? String {
 // tell delegate to update interface for the Dsid
 print(summary)
 }
 
 })
 
 getTask.resume() // start the task
 
 }
 
 //MARK: Utility Functions
 private func matchIp(for regex:String, in text:String)->(Bool){
 do {
 let regex = try NSRegularExpression(pattern: regex)
 let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
 if results.count > 0{return true}
 
 } catch _{
 return false
 }
 return false
 }
 
 private func convertDataToDictionary(with data:Data?)->[String:Any]{
 // convenience function for getting Dictionary from server data
 do { // try to parse JSON and deal with errors using do/catch block
 let jsonDictionary: [String:Any] =
 try JSONSerialization.jsonObject(with: data!,
 options: JSONSerialization.ReadingOptions.mutableContainers) as! [String : Any]
 
 return jsonDictionary
 
 } catch {
 print("json error: \(error.localizedDescription)")
 if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
 print("printing JSON received as string: "+strData)
 }
 return [String:Any]() // just return empty
 }
 }
 
 }
 
 */
