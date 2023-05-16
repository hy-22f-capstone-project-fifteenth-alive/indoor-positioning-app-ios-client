//
//  BeaconModel.swift
//  IndoorNavigation
//
//  Created by Jongheon Kim on 2023/05/16.
//  Copyright © 2023 Apple. All rights reserved.
//

struct BeaconModel: Codable {
    let id, major, minor: Int
    let floor: String
    let venue: VenueModel
}
