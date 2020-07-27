//
//  JWTService.swift
//  PlatformKit
//
//  Created by Daniel on 29/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import RxSwift

public protocol JWTServiceAPI: AnyObject {
    var token: Single<String> { get }
}

final class JWTService: JWTServiceAPI {
    
    var token: Single<String> {
        credentialsRepository.credentials
            .flatMap(weak: self) { (self, payload) in
                self.client.requestJWT(guid: payload.guid, sharedKey: payload.sharedKey)
            }
    }
    
    private let client: JWTClientAPI
    private let credentialsRepository: CredentialsRepositoryAPI
    
    init(client: JWTClientAPI = resolve(),
         credentialsRepository: CredentialsRepositoryAPI = resolve()) {
        self.client = client
        self.credentialsRepository = credentialsRepository
    }
}
