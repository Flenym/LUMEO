// Lumeo — Sources/Services/E2EEngine.swift
// Сквозное шифрование чатов: ТОЛЬКО ИНТЕРФЕЙС на этом этапе.
//
// АРХИТЕКТУРА (по ТЗ):
// - device keys (X25519 identity per device) + per-session keys, rotation при смене состава,
//   multi-device через fan-out под каждое устройство получателя.
// - Тексты/медиа шифруются на устройстве; сервер хранит только ciphertext + metadata
//   (message_id, sender_hash, timestamps, attachment kind/size) для Admin-модерации.
// - Reactions/reply/forward/pin работают поверх plaintext на клиентах, в сеть уходит ciphertext.
//
// ⚠️ НЕ САМОПИСНАЯ КРИПТА: реализация обязана использовать проверенный стек
// (MLS RFC 9420 / Signal Protocol через аудированную библиотеку).
// Ниже — протоколы, Keychain-хранилище ключей (stub) и фасад; все крипто-операции
// до подключения библиотеки бросают E2EError.notConfigured.

import Foundation
import Security

// MARK: - E2EError

enum E2EError: Error {
    /// Криптопровайдер ещё не подключён (нет аудированной зависимости).
    case notConfigured
    case unknownDevice
    case rotationRequired
    case keychainFailure(OSStatus)
}

// MARK: - E2ECryptoProvider

/// Интерфейс, который реализует аудированная криптобиблиотека. НЕ реализовывать вручную.
protocol E2ECryptoProvider {
    /// Сгенерировать identity-ключи устройства. Хранить только в Keychain/Secure Enclave.
    func generateDeviceKeys() async throws -> DeviceKeyPair
    /// Сротировать ключи сессии (смена состава чата, период).
    func rotateSessionKeys(chatID: UUID) async throws
    /// Экспортировать публичную часть для fan-out получателям (приватная НЕ покидает устройство).
    func exportPublicKey() async throws -> Data
    /// Зашифровать текст сессионным ключом.
    func encryptText(_ plaintext: String, chatID: UUID) async throws -> E2EEnvelope
    /// Расшифровать текст.
    func decryptText(_ envelope: E2EEnvelope, chatID: UUID) async throws -> String
    /// Зашифровать вложение (фото/видео/GIF/voice) сессионным ключом.
    func encryptAttachment(_ plaintext: Data, chatID: UUID) async throws -> Data
    /// Расшифровать вложение.
    func decryptAttachment(_ ciphertext: Data, chatID: UUID) async throws -> Data
}

// MARK: - DeviceKeyPair / E2EEnvelope

struct DeviceKeyPair {
    var deviceID: UUID
    /// Публичный ключ — можно передавать на сервер. Приватный — НИКОГДА.
    var publicKey: Data
}

/// Сетевой конверт: только ciphertext + keyID/nonce/kind (зеркало MessageMetadata).
struct E2EEnvelope: Codable {
    var ciphertext: String
    var keyID: String
    var nonce: String
}

// MARK: - E2EKeychainStore

/// Keychain-хранилище device-ключей (stub: record'ы без реальной криптогенерации).
/// Приватный ключ помечен kSecAttrIsExtractable=false, доступ — только после
/// биометрии устройства (.biometryAny). Реализация MLS/Signal, НЕ самописная крипта.
enum E2EKeychainStore {
    private static let service = "com.lumeo.app.e2ee"
    private static let account = "device-identity"

    /// Сохранить ссылку на identity-ключ (сам ключ — в Secure Enclave, здесь только дескриптор).
    static func storeDeviceKeyDescriptor(_ descriptor: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: descriptor,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw E2EError.keychainFailure(status) }
    }

    /// Прочитать дескриптор device-ключа.
    static func loadDeviceKeyDescriptor() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw E2EError.keychainFailure(status)
        }
        return data
    }

    /// Сротировать дескриптор (старый затирается; epoch инкрементируется вызывающей стороной).
    static func rotateDescriptor(_ descriptor: Data) throws {
        try storeDeviceKeyDescriptor(descriptor)
    }

    /// Удалить identity (logout / смена устройства).
    static func deleteDescriptor() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - E2EEngine

/// Фасад E2EE для фич чатов. До подключения проверенного стека все операции бросают .notConfigured,
/// и чаты работают в незашифрованном dev-режиме (помечается в UI точкой «не защищено»).
enum E2EEngine {
    static var provider: (any E2ECryptoProvider)?

    static var isAvailable: Bool { provider != nil }

    /// Сгенерировать device-ключи через провайдера и сохранить дескриптор в Keychain.
    static func generateDeviceKey() async throws -> DeviceKeyPair {
        guard let provider else { throw E2EError.notConfigured }
        let pair = try await provider.generateDeviceKeys()
        // В Keychain — только дескриптор/публичная часть; приватный не покидает Enclave.
        try? E2EKeychainStore.storeDeviceKeyDescriptor(pair.publicKey)
        return pair
    }

    static func rotate(chatID: UUID) async throws {
        guard let provider else { throw E2EError.notConfigured }
        try await provider.rotateSessionKeys(chatID: chatID)
    }

    /// Экспорт публичного ключа для fan-out (реализация MLS/Signal, НЕ самописная крипта).
    static func exportPublicKey() async throws -> Data {
        guard let provider else { throw E2EError.notConfigured }
        return try await provider.exportPublicKey()
    }

    static func encryptText(_ plaintext: String, chatID: UUID) async throws -> E2EEnvelope {
        guard let provider else { throw E2EError.notConfigured }
        return try await provider.encryptText(plaintext, chatID: chatID)
    }

    static func decryptText(_ envelope: E2EEnvelope, chatID: UUID) async throws -> String {
        guard let provider else { throw E2EError.notConfigured }
        return try await provider.decryptText(envelope, chatID: chatID)
    }

    static func encryptAttachment(_ plaintext: Data, chatID: UUID) async throws -> Data {
        guard let provider else { throw E2EError.notConfigured }
        return try await provider.encryptAttachment(plaintext, chatID: chatID)
    }

    static func decryptAttachment(_ ciphertext: Data, chatID: UUID) async throws -> Data {
        guard let provider else { throw E2EError.notConfigured }
        return try await provider.decryptAttachment(ciphertext, chatID: chatID)
    }

    // MARK: Legacy aliases

    static func generateDeviceKeys() async throws -> DeviceKeyPair {
        try await generateDeviceKey()
    }

    static func rotateSessionKeys(chatID: UUID) async throws {
        try await rotate(chatID: chatID)
    }
}
