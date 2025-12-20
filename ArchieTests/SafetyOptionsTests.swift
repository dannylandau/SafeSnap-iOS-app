//
//  SafetyOptionsTests.swift
//  Archie
//
//  Verifies prompt flag mapping for safety options.
//

import XCTest
@testable import Archie

final class SafetyOptionsTests: XCTestCase {

    func test_promptFlags_includeAllToggles() {
        let options = SafetyOptions(includeDogs: true, includeCats: false, includeChildren: true)
        let flags = options.asPromptFlags()

        XCTAssertTrue(flags.contains("includeDogs=true"))
        XCTAssertTrue(flags.contains("includeCats=false"))
        XCTAssertTrue(flags.contains("includeChildren=true"))
    }
}
