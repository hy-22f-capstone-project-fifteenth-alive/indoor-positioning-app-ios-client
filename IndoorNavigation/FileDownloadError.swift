//
//  FileDownloadError.swift
//  IndoorNavigation
//
//  Created by Jongheon Kim on 2023/05/10.
//  Copyright © 2023 Apple. All rights reserved.
//


enum FileDownloadError: Error {
    case serverError
    
    case unzipFail

    case writeError
    
    // Throw in all other cases
    case unexpected(code: Int)
}
