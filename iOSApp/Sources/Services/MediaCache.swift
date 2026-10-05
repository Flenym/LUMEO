// Lumeo — Sources/Services/MediaCache.swift
// Кэш медиа чатов: image / video thumbnails / GIF + лимиты размера.
// Память — NSCache, диск — Caches/com.lumeo.app.media. Лимиты жёсткие:
// превышение → downscale (фото) или отказ с MediaCacheError.tooLarge (видео/GIF).

import Foundation
import SwiftUI
import UIKit

// MARK: - MediaCacheError

enum MediaCacheError: Error, Equatable {
    case tooLarge(limitBytes: Int)
    case unsupported
    case expired
}

// MARK: - MediaCache

/// Кэш вложений чата. Один инстанс (shared). Actor: изоляция вместо ручных локов
/// (Swift 6 concurrency-safe; NSCache потокобезопасен сам по себе).
actor MediaCache {
    static let shared = MediaCache()
    private init() {}

    // MARK: Limits

    /// Лимиты размера вложений (жёсткие, по ТЗ Tier1).
    static let maxImageBytes = 10 * 1024 * 1024
    static let maxGIFBytes = 15 * 1024 * 1024
    static let maxVideoBytes = 100 * 1024 * 1024
    /// Лимит памяти превью (NSCache totalCostLimit ~ 50 МБ).
    static let memoryCostLimit = 50 * 1024 * 1024

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = memoryCostLimit
        cache.countLimit = 300
        return cache
    }()

    private var diskDirectory: URL {
        // Без force unwrap: в песочнице без caches падаем на temporaryDirectory.
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appending(path: "com.lumeo.app.media", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Limits API

    /// Лимит для kind вложения. Превышение → ошибка до шифрования/отправки.
    static func limit(for kind: AttachmentKind) -> Int {
        switch kind {
        case .photo: maxImageBytes
        case .gif: maxGIFBytes
        case .video: maxVideoBytes
        case .voice: 10 * 1024 * 1024
        }
    }

    /// Проверка размера до обработки.
    static func validate(sizeBytes: Int, kind: AttachmentKind) throws {
        let limit = limit(for: kind)
        guard sizeBytes <= limit else { throw MediaCacheError.tooLarge(limitBytes: limit) }
    }

    // MARK: Images

    /// Превью из памяти/диска по id вложения.
    func cachedThumbnail(for id: UUID) -> UIImage? {
        memory.object(forKey: id.uuidString as NSString)
            ?? diskThumbnail(for: id)
    }

    func storeThumbnail(_ image: UIImage, for id: UUID) {
        let cost = Int(image.size.width * image.size.height * 4)
        memory.setObject(image, forKey: id.uuidString as NSString, cost: cost)
        Task.detached(priority: .utility) { [diskDirectory] in
            let url = diskDirectory.appending(path: "\(id.uuidString).thumb", directoryHint: .notDirectory)
            if let data = image.jpegData(compressionQuality: 0.7) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func diskThumbnail(for id: UUID) -> UIImage? {
        let url = diskDirectory.appending(path: "\(id.uuidString).thumb", directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let image = UIImage(data: data)
        if let image {
            memory.setObject(image, forKey: id.uuidString as NSString)
        }
        return image
    }

    // MARK: Maintenance

    /// Размер дискового кэша (для экрана Data в Settings).
    func diskSizeBytes() -> Int {
        let urls = (try? FileManager.default.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return urls.reduce(0) { acc, url in
            acc + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    /// Очистка всего кэша (память + диск).
    func clear() {
        memory.removeAllObjects()
        let urls = (try? FileManager.default.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: [])) ?? []
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }
}
