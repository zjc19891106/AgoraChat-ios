//
//  MineContactDetailViewController.swift
//  AgoraChat-Swift
//
//  Created by 朱继超 on 2024/3/19.
//

import UIKit
import chat_uikit
import AgoraChatCallKit
import SwiftFFDBHotFix

final class MineContactDetailViewController: ContactInfoViewController {
    
    override func createHeader() -> DetailInfoHeader {
        super.createHeader()
    }

    override func viewDidLoad() {
        Appearance.contact.detailExtensionActionItems = [
            ContactListHeaderItem(featureIdentify: "Chat", featureName: "Chat".chat.localize, featureIcon: UIImage(named: "chatTo", in: .chatBundle, with: nil)),
            ContactListHeaderItem(featureIdentify: "AudioCall", featureName: "AudioCall".chat.localize, featureIcon: UIImage(named: "voice_call", in: .chatBundle, with: nil)),
            ContactListHeaderItem(featureIdentify: "VideoCall", featureName: "VideoCall".chat.localize, featureIcon: UIImage(named: "video_call", in: .chatBundle, with: nil)),
            ContactListHeaderItem(featureIdentify: "SearchMessages", featureName: "SearchMessages".chat.localize, featureIcon: UIImage(named: "search_history_messages", in: .chatBundle, with: nil))
        ]
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func setup() {
        super.setup()
        
        self.requestInfo()
        self.fetchUserStatus()
    }
    
    @objc func fetchUserStatus() {
        PresenceManager.shared.fetchPresenceStatus(userId: self.profile.id) {  [weak self] presence, error in
            switch PresenceManager.status(with: presence) {
            case .online: self?.updateUserState(state: .online)
            case .offline: self?.updateUserState(state: .offline)
            case .busy:
                self?.header.status.image = nil
                self?.header.status.backgroundColor = Theme.style == .dark ? UIColor.theme.errorColor5:UIColor.theme.errorColor6
                self?.header.status.image(PresenceManager.presenceImagesMap[.busy] as? UIImage)
            case .away:
                self?.header.status.backgroundColor = Theme.style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
                self?.header.status.image(PresenceManager.presenceImagesMap[.away] as? UIImage)
            case .doNotDisturb:
                self?.header.status.backgroundColor = Theme.style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
                self?.header.status.image(PresenceManager.presenceImagesMap[.doNotDisturb] as? UIImage)
            case .custom:
                self?.header.status.backgroundColor = Theme.style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
                self?.header.status.image(PresenceManager.presenceImagesMap[.custom] as? UIImage)
            }
            
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    private func updateHeader() {
        if let user = ChatUIKitContext.shared?.userCache?[self.profile.id] {
            if !user.nickname.isEmpty {
                self.header.nickName.text = user.nickname
            }
            if !user.remark.isEmpty {
                self.header.nickName.text = user.remark
            }
            if !user.avatarURL.isEmpty {
                self.header.avatarURL = user.avatarURL
            }
        }
    }
    
    private func requestInfo() {
        self.updateHeader()
        ChatClient.shared().userInfoManager?.fetchUserInfo(byId: [self.profile.id], type: [0,1],completion: { [weak self] infoMap, error in
            guard let userId = self?.profile.id else { return }
            DispatchQueue.main.async {
                if let info = infoMap?[userId],error == nil {
                    
                    var remark = ChatUIKitContext.shared?.userCache?[userId]?.remark ?? ""
                    if remark.isEmpty {
                        remark = info.nickname ?? userId
                    }
                    if let profiles = EaseChatProfile.select(where: "id = ?",values: [userId]) as? [EaseChatProfile],let profile = profiles.first(where: { $0.id == userId }) {
                        profile.nickname = info.nickname ?? ""
                        profile.avatarURL = info.avatarUrl ?? ""
                        profile.updateFFDB()
                        ChatUIKitContext.shared?.userCache?[userId]?.nickname = info.nickname ?? ""
                        ChatUIKitContext.shared?.userCache?[userId]?.avatarURL = info.avatarUrl ?? ""
                        ChatUIKitContext.shared?.chatCache?[userId]?.nickname = info.nickname ?? ""
                        ChatUIKitContext.shared?.chatCache?[userId]?.avatarURL = info.avatarUrl ?? ""
                    } else {
                        let profile = EaseChatProfile()
                        profile.id = userId
                        profile.nickname = info.nickname ?? ""
                        profile.avatarURL = info.avatarUrl ?? ""
                        profile.insert()
                        if (ChatUIKitContext.shared?.userCache?[userId]) != nil {
                            ChatUIKitContext.shared?.userCache?[userId]?.nickname = info.nickname ?? ""
                            ChatUIKitContext.shared?.userCache?[userId]?.avatarURL = info.avatarUrl ?? ""
                        } else {
                            ChatUIKitContext.shared?.userCache?[userId] = profile
                        }
                        ChatUIKitContext.shared?.chatCache?[userId]?.nickname = info.nickname ?? ""
                        ChatUIKitContext.shared?.chatCache?[userId]?.avatarURL = info.avatarUrl ?? ""
                    }
                    
                    self?.updateHeader()
                } else {
                    self?.showToast(toast: "fetchUserInfo error:\(error?.errorDescription ?? "")")
                }
            }
        })
    }
    
    override func headerActions() {
        super.headerActions()
        if let audioCall = Appearance.contact.detailExtensionActionItems.first(where: { $0.featureIdentify == "AudioCall" }) {
            audioCall.actionClosure = { [weak self] in
                self?.processHeaderActionEvents(item: $0)
            }
        }
        if let videoCall = Appearance.contact.detailExtensionActionItems.first(where: { $0.featureIdentify == "VideoCall" }) {
            videoCall.actionClosure = { [weak self] in
                self?.processHeaderActionEvents(item: $0)
            }
        }
    }

    override func processHeaderActionEvents(item: any ContactListHeaderItemProtocol) {
        switch item.featureIdentify {
        case "Chat": self.alreadyChat()
        case "AudioCall": self.startSingleCall(callType: .type1v1Audio)
        case "VideoCall": self.startSingleCall(callType: .type1v1Video)
        case "SearchMessages": self.searchHistoryMessages()
        default: break
        }
    }
    
    private func startSingleCall(callType: AgoraChatCallType) {
        AgoraChatCallManager.shared().startSingleCall(withUId: self.profile.id, type: callType, ext: nil) { [weak self] callId, callError in
            if callError != nil {
                self?.showToast(toast: "\(callError?.errDescription ?? "")")
            }
        }
    }
    
    override func didSelectRow(indexPath: IndexPath) {
        
        if let info = self.datas[safe: indexPath.row] {
            switch info.title {
            case "contact_details_button_clearchathistory".chat.localize:
                self.showClearChatHistoryAlert()
//            case "contact_details_button_remark".localized():
//                self.editRemark()
            default:
                break
            }
            
        }
        
    }
    
    private func showClearChatHistoryAlert() {
        DialogManager.shared.showAlert(title: "group_details_button_clearchathistory".chat.localize, content: "", showCancel: true, showConfirm: true) { [weak self] _ in
            guard let `self` = self else { return }
            ChatClient.shared().chatManager?.getConversationWithConvId(self.profile.id)?.deleteAllMessages(nil)
            self.showToast(toast: "Clean successful!".localized())
            NotificationCenter.default.post(name: Notification.Name("EaseChatUIKit_clean_history_messages"), object: self.profile.id)
        }
    }
    
    private func editRemark() {
        let vc = MineContactRemarkEditViewController(userId: self.profile.id, rawText: self.profile.remark) { [weak self] remark in
            guard let `self` = self else { return }
            ChatClient.shared().contactManager?.setContactRemark(self.profile.id, remark: remark,completion: { [weak self] contact, error in
                guard let `self` = self else { return }
                if error == nil {
                    self.header.nickName.text = remark
                    self.profile.remark = remark
                    self.datas.first?.detail = remark
                    self.menuList.reloadData()
                    self.updateRemark(remark: remark)
                } else {
                    self.showToast(toast: "modify remark failed:\(error?.errorDescription ?? "")")
                }
            })
            
        }
        vc.navigation.title = "Modify Remark".localized()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func updateRemark(remark: String) {
        if let info = ChatUIKitContext.shared?.userCache?[self.profile.id]  {
            info.remark = remark
            ChatUIKitContext.shared?.updateCache(type: .user, profile: info)
            let dbInfo = EaseChatProfile()
            dbInfo.id = self.profile.id
            dbInfo.nickname = self.profile.nickname
            dbInfo.avatarURL = self.profile.avatarURL
            dbInfo.remark = self.profile.remark
            dbInfo.update()
        } else {
            self.profile.remark = remark
            ChatUIKitContext.shared?.updateCache(type: .user, profile: self.profile)
            let dbInfo = EaseChatProfile()
            dbInfo.id = self.profile.id
            dbInfo.nickname = self.profile.nickname
            dbInfo.avatarURL = self.profile.avatarURL
            dbInfo.remark = self.profile.remark
            dbInfo.insert()
        }
    }
    
    
}
