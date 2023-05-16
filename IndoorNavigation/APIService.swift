//
//  APIService.swift
//  IndoorNavigation
//
//  Created by Jongheon Kim on 2023/05/10.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import Zip

let baseUrl = "http://localhost:8080"

@available(iOS 15.0, *)
func fetchImdfFileData() async throws -> URL {
    let fileManager: FileManager = FileManager.default
    
    let documentsPath: URL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let directoryPath: URL = documentsPath.appendingPathComponent("IMDFData")
    let destinationFileUrl = directoryPath.appendingPathComponent("temp.zip")
    
    do {
        try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: false, attributes: nil)
    } catch let e {
        print(e.localizedDescription)
    }

    let fileURL = URL(string: "\(baseUrl)/api/v1/venue/1/map")

    let tempUrlSession = URLSession.shared
    let (localURL, response) = try await tempUrlSession.download(from: fileURL!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FileDownloadError.serverError }
    
    do {
        try FileManager.default.copyItem(at: localURL, to: destinationFileUrl)
    } catch (let error) {
        print(error)
    }
    
    do {
        let unzipDirectory = try Zip.quickUnzipFile(destinationFileUrl)
        return unzipDirectory
    } catch (let error) {
        print(error)
        throw FileDownloadError.unzipFail
    }
}


func getBeaconData(major: Int, minor: Int) async throws -> BeaconModel {
    var urlComponent = URLComponents(string: "\(baseUrl)/api/v1/beacon/search")
    let majorParam = URLQueryItem(name: "major", value: String(10001))
    let minorParam = URLQueryItem(name: "minor", value: String(19641))
    urlComponent?.queryItems = [majorParam, minorParam]
    guard let url = urlComponent?.url else { throw FileDownloadError.serverError }
    
    let (data, response) = try await URLSession.shared.data(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FileDownloadError.serverError }
    
    return try JSONDecoder().decode(BeaconModel.self, from: data)
    
}
