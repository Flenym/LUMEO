// Lumeo Admin — Tests/ModerationTests.swift
// Тесты дедупликации репортов по report_cluster_id + beta-closed + grant-audit.

import XCTest

@testable import LumeoAdmin

// MARK: - ReportClusterTests

final class ReportClusterTests: XCTestCase {
    /// Одинаковые (target + reason) дают один clusterID; регистр/пробелы не влияют.
    func testClusterIDDedupesCaseAndWhitespace() {
        let a = ReportCluster.clusterID(targetHash: "user:x", reason: "Spam invites")
        let b = ReportCluster.clusterID(targetHash: "user:x", reason: "  spam INVITES ")
        XCTAssertEqual(a, b)
    }

    /// Разные причины — разные кластеры.
    func testDifferentReasonsDifferentClusters() {
        let a = ReportCluster.clusterID(targetHash: "user:x", reason: "Spam")
        let b = ReportCluster.clusterID(targetHash: "user:x", reason: "Toxic")
        XCTAssertNotEqual(a, b)
    }

    /// Группировка сортирует по размеру кластера (самые массовые — первые).
    func testGroupedSortsBySize() {
        let cluster = ReportCluster.clusterID(targetHash: "user:spam1", reason: "Spam")
        let reports = [
            ReportItem(clusterID: ReportCluster.clusterID(targetHash: "user:solo", reason: "Other"), reason: "Other", reporterHash: "u1", targetHash: "user:solo"),
            ReportItem(clusterID: cluster, reason: "Spam", reporterHash: "u2", targetHash: "user:spam1"),
            ReportItem(clusterID: cluster, reason: "Spam", reporterHash: "u3", targetHash: "user:spam1"),
        ]
        let grouped = ReportCluster.grouped(reports)
        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped.first?.items.count, 2)
    }

    /// Дедуп: три репорта с одинаковым (target+reason) → один кластер ×3.
    func testDedupThreeSameReasonOneCluster() {
        let cluster = ReportCluster.clusterID(targetHash: "user:spam1", reason: "Spam invites")
        let reports = (1...3).map {
            ReportItem(clusterID: cluster, reason: "Spam invites", reporterHash: "user:r\($0)", targetHash: "user:spam1")
        }
        let grouped = ReportCluster.grouped(reports)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped.first?.items.count, 3)
    }
}

// MARK: - BetaGateTests

final class BetaGateTests: XCTestCase {
    /// Beta закрыта флагом: новых заявок нет, approve запрещён политикой.
    func testBetaClosedFlag() {
        XCTAssertTrue(BetaGate.isBetaClosed, "Beta must stay closed (flag)")
    }
}

// MARK: - EconomyGrantTests

final class EconomyGrantTests: XCTestCase {
    /// Каноническая audit-строка гранта из ТЗ.
    func testGrantAuditLineFormat() {
        XCTAssertEqual(EconomyGrant.canonicalExample, "Admin granted 500 EMBER to @x")
        let line = EconomyGrant.auditLine(admin: "admin:this-device", amount: 500, target: "x")
        XCTAssertTrue(line.contains("granted 500 EMBER to @x"), line)
    }

    /// Revoke пишет «revoked», а не «granted».
    func testRevokeAuditLineFormat() {
        let line = EconomyGrant.auditLine(admin: "admin:this-device", amount: -200, target: "dex")
        XCTAssertTrue(line.contains("revoked 200 EMBER"), line)
    }

    /// Grant entry пишет audit на пользователя.
    func testGrantEntryTargetsUser() {
        let entry = EconomyGrant.entry(admin: "admin:this-device", target: "neo", amount: 500, reason: "compensation")
        XCTAssertEqual(entry.target, "user:neo")
        XCTAssertTrue(entry.action.contains("500"))
    }
}
