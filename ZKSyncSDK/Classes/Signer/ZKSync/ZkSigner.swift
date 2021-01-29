//
//  ZkSigner.swift
//  ZKSyncSDK
//
//  Created by Eugene Belyakov on 11/01/2021.
//

import Foundation
import CryptoSwift
import ZKSyncSDK

enum ZkSignerError: Error {
    case invalidPrivateKey
    case incorrectDataLength
}

public class ZkSigner {
    
    private static let Message = "Access zkSync account.\n\nOnly sign this message for a trusted client!"
    
    let privateKey: ZKPrivateKey
    let publicKey: ZKPackedPublicKey
    public let publicKeyHash: String
    
    public init(privateKey: ZKPrivateKey) throws {
        self.privateKey = privateKey
        
        switch ZKSyncSDK.getPublicKey(privateKey: privateKey) {
        case .success(let key):
            self.publicKey = key
        default:
            throw ZkSignerError.invalidPrivateKey
        }
        
        switch ZKSyncSDK.getPublicKeyHash(publicKey: self.publicKey) {
        case .success(let hash):
            self.publicKeyHash = hash.hexEncodedString().addPubKeyHashPrefix().lowercased()
        default:
            throw ZkSignerError.invalidPrivateKey
        }
    }
    
    public convenience init(seed: Data) throws {
        switch ZKSyncSDK.generatePrivateKey(seed: seed) {
        case .success(let privateKey):
            try self.init(privateKey: privateKey)
        case .error(let error):
            throw error
        }
    }
    
    public convenience init(rawPrivateKey: Data) throws {
        if rawPrivateKey.count != ZKPrivateKey.bytesLength {
            throw ZkSignerError.incorrectDataLength
        }
        try self.init(privateKey: ZKPrivateKey(rawPrivateKey))
    }
    
    public convenience init(ethSigner: EthSigner, chainId: ChainId) throws {
        var message = ZkSigner.Message
        if chainId != .mainnet {
            message = "\(message)\nChain ID: \(chainId.id)."
        }
        let signature = try ethSigner.sign(message: message)
        
        try self.init(seed: Data(hex: signature.signature))
    }
    
    public func sign(message: Data) throws -> Signature {
        switch ZKSyncSDK.signMessage(privateKey: self.privateKey, message: message) {
        case .success(let signature):
            return Signature(pubKey: publicKey.hexEncodedString(),
                             signature: signature.hexEncodedString())
        case .error(let error):
            throw error
        }
    }
    
    public func sign(changePubKey: ChangePubKey) throws -> ChangePubKey {
        let mutableChangePubKey = changePubKey
        var data = Data()
        
        data.append(contentsOf: [0x07])
        data.append(try Utils.accountIdToBytes(changePubKey.accountId))
        data.append(try Utils.addressToBytes(changePubKey.account))
        data.append(try Utils.addressToBytes(changePubKey.newPkHash))
        data.append(try Utils.tokenIdToBytes(changePubKey.feeToken))
        data.append(try Utils.feeToBytes(changePubKey.feeInteger))
        data.append(Utils.nonceToBytes(changePubKey.nonce))
        
        let signature = try self.sign(message: data)
        mutableChangePubKey.signature = signature
        return mutableChangePubKey
    }
    
    public func sign(transfer: Transfer) throws -> Transfer {
        let mutableTransfer = transfer
        var data = Data()
        
        data.append(contentsOf: [0x05])
        data.append(try Utils.accountIdToBytes(transfer.accountId))
        data.append(try Utils.addressToBytes(transfer.from))
        data.append(try Utils.addressToBytes(transfer.to))
        data.append(try Utils.tokenIdToBytes(transfer.token))
        data.append(try Utils.amountPackedToBytes(transfer.amount))
        data.append(try Utils.feeToBytes(transfer.feeInteger))
        data.append(Utils.nonceToBytes(transfer.nonce))
        
        let signature = try self.sign(message: data)
        mutableTransfer.signature = signature
        return mutableTransfer
    }

    public func sign(withdraw: Withdraw) throws -> Withdraw {
        let mutableWithdraw = withdraw
        var data = Data()
        
        data.append(contentsOf: [0x03])
        data.append(try Utils.accountIdToBytes(withdraw.accountId))
        data.append(try Utils.addressToBytes(withdraw.from))
        data.append(try Utils.addressToBytes(withdraw.to))
        data.append(try Utils.tokenIdToBytes(withdraw.token))
        data.append(Utils.amountFullToBytes(withdraw.amount))
        data.append(try Utils.feeToBytes(withdraw.feeInteger))
        data.append(Utils.nonceToBytes(withdraw.nonce))
        
        let signature = try self.sign(message: data)
        mutableWithdraw.signature = signature
        return mutableWithdraw
    }

    public func sign(forcedExit: ForcedExit) throws -> ForcedExit {
        let mutableForcedExit = forcedExit
        var data = Data()
        
        data.append(contentsOf: [0x08])
        data.append(try Utils.accountIdToBytes(forcedExit.initiatorAccountId))
        data.append(try Utils.addressToBytes(forcedExit.target))
        data.append(try Utils.tokenIdToBytes(forcedExit.token))
        data.append(try Utils.feeToBytes(forcedExit.feeInteger))
        data.append(Utils.nonceToBytes(forcedExit.nonce))
        
        let signature = try self.sign(message: data)
        mutableForcedExit.signature = signature
        return mutableForcedExit
    }
}
