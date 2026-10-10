//
//  Encryption.swift
//  MagpieField
//
//  Data protection and sandbox encryption policies for stored captures (Layer 2, T-702).
//

import Foundation

public struct StorageEncryption {
    /// Applies complete file protection to a specified file URL
    public static func applyCompleteProtection(to url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.complete,
            forKey: .fileProtectionKey
        )
    }

    /// Applies protection unless open to files that the sync background queue reads
    public static func applySyncReadableProtection(to url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.completeUnlessOpen,
            forKey: .fileProtectionKey
        )
    }

    /// Sets default complete protection on a directory
    public static func secureDirectory(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } else {
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
    }
}
