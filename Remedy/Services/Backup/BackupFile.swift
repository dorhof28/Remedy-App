//
//  BackupFile.swift
//  Remedy
//
//  locks a backup with the patient's password and opens it again
//  layout: magic, file version, rounds, salt, then aes-gcm nonce + ciphertext + tag
//

import Foundation
import CryptoKit
import CommonCrypto

// why a backup could not be locked or opened
nonisolated enum BackupError: Error, Equatable, LocalizedError {
    case notABackup
    case wrongPassword
    case newerVersion
    case couldNotLock

    var errorDescription: String? {
        switch self {
        case .notABackup:
            return "This file is not a Remedy backup, or it is damaged."
        case .wrongPassword:
            return "That password does not open this backup. Check it and try again."
        case .newerVersion:
            return "This backup was made by a newer Remedy. Update Remedy, then try again."
        case .couldNotLock:
            return "Remedy could not make the backup. Please try again."
        }
    }
}

// locks and opens backup files with the patient's password
nonisolated enum BackupFile {

    // key stretching so guessing passwords is slow
    static let rounds = 600_000
    static let fileExtension = "remedybackup"

    private static let magic = Data("REMEDYBACKUP".utf8)
    private static let fileVersion: UInt8 = 1
    private static let saltLength = 16
    private static let headerLength = 12 + 1 + 4 + 16
    // refuses silly round counts from a damaged or made up file
    private static let allowedRounds = 200_000...10_000_000

    // a name like "Remedy backup 2026-11-06.remedybackup"
    static func fileName(on date: Date) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        return "Remedy backup \(day).\(fileExtension)"
    }

    // MARK: - Lock

    // json, then aes-gcm with a key stretched from the password
    static func seal(_ snapshot: BackupSnapshot, password: String) throws -> Data {
        guard !password.isEmpty else { throw BackupError.couldNotLock }
        var salt = Data(count: saltLength)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!) }
        guard status == errSecSuccess else { throw BackupError.couldNotLock }

        var header = magic
        header.append(fileVersion)
        withUnsafeBytes(of: UInt32(rounds).bigEndian) { header.append(contentsOf: $0) }
        header.append(salt)

        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        let plain = try JSONEncoder().encode(snapshot)
        // the header is checked too so nobody can swap the salt or rounds
        guard let sealed = try? AES.GCM.seal(plain, using: key, authenticating: header).combined else {
            throw BackupError.couldNotLock
        }
        return header + sealed
    }

    // MARK: - Open

    // checks the header, rebuilds the key and opens the box, a wrong password fails the tag
    static func open(_ data: Data, password: String) throws -> BackupSnapshot {
        let data = Data(data)   // starts at index 0
        // nonce 12 and tag 16 come after the header
        guard data.count > headerLength + 28, data.prefix(magic.count) == magic else { throw BackupError.notABackup }
        let version = data[magic.count]
        guard version <= fileVersion else { throw BackupError.newerVersion }
        guard version == fileVersion else { throw BackupError.notABackup }

        let roundBytes = data[(magic.count + 1)..<(magic.count + 5)]
        let fileRounds = Int(roundBytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard allowedRounds.contains(fileRounds) else { throw BackupError.notABackup }
        guard !password.isEmpty else { throw BackupError.wrongPassword }
        let salt = data[(magic.count + 5)..<headerLength]
        let header = data.prefix(headerLength)

        let key = try deriveKey(password: password, salt: Data(salt), rounds: fileRounds)
        guard let box = try? AES.GCM.SealedBox(combined: data.suffix(from: headerLength)) else {
            throw BackupError.notABackup
        }
        // a wrong password fails the lock check, so does a changed file
        guard let plain = try? AES.GCM.open(box, using: key, authenticating: header) else {
            throw BackupError.wrongPassword
        }

        // check the format before reading the rest
        struct Format: Decodable { let formatVersion: Int }
        guard let format = try? JSONDecoder().decode(Format.self, from: plain) else { throw BackupError.notABackup }
        guard format.formatVersion <= BackupSnapshot.currentFormat else { throw BackupError.newerVersion }
        guard let snapshot = try? JSONDecoder().decode(BackupSnapshot.self, from: plain) else {
            throw BackupError.notABackup
        }
        return snapshot
    }

    // MARK: - Key

    // pbkdf2 sha256 to a 256 bit key
    private static func deriveKey(password: String, salt: Data, rounds: Int) throws -> SymmetricKey {
        // the same letters typed on another keyboard give the same key
        let passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        var key = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBuffer in
            passwordBytes.withUnsafeBufferPointer { passwordBuffer in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     passwordBuffer.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                                     passwordBytes.count,
                                     saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(rounds),
                                     &key, key.count)
            }
        }
        guard status == CCCryptorStatus(kCCSuccess) else { throw BackupError.couldNotLock }
        return SymmetricKey(data: key)
    }
}
