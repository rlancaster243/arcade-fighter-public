import XCTest
@testable import AppLogic

final class FighterSkinTests: XCTestCase {
    func testMirrorMatchGivesSlotOneTheAltSheet() {
        XCTAssertEqual(FighterSkin.sheetName(id: "rook", slot: 0, otherSlotID: "rook"), "rook")
        XCTAssertEqual(FighterSkin.sheetName(id: "rook", slot: 1, otherSlotID: "rook"), "rook_alt")
    }

    func testDifferentFightersKeepTheirOwnSheets() {
        XCTAssertEqual(FighterSkin.sheetName(id: "rook", slot: 1, otherSlotID: "bruno"), "rook")
        XCTAssertEqual(FighterSkin.sheetName(id: "rook", slot: 1, otherSlotID: nil), "rook")
    }

    func testSheetNamesRoutesWholeMatch() {
        XCTAssertEqual(FighterSkin.sheetNames(atlasIDs: ["ilse", "ilse"]), ["ilse", "ilse_alt"])
        XCTAssertEqual(FighterSkin.sheetNames(atlasIDs: ["ilse", "kestrel"]), ["ilse", "kestrel"])
        XCTAssertEqual(FighterSkin.sheetNames(atlasIDs: [nil, nil]), [nil, nil])
        XCTAssertEqual(FighterSkin.sheetNames(atlasIDs: ["ilse", nil]), ["ilse", nil])
    }

    func testBundleIDStripsAltSuffix() {
        XCTAssertEqual(FighterSkin.bundleID(ofSheet: "kestrel_alt"), "kestrel")
        XCTAssertEqual(FighterSkin.bundleID(ofSheet: "kestrel"), "kestrel")
    }
}
