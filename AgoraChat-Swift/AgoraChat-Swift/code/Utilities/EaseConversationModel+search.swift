//
//  EaseConversationModel+search.swift
//  AgoraChat-Swift
//
//  Created by 冯钊 on 2022/10/27.
//

import Foundation

extension EaseConversationModel: IAgoraRealtimeSearch {
    var searchKey: String {
        return self.showName
    }
}
