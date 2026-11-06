import Testing
@testable import MCPHelpers

@Suite("Screen Recording Status")
struct ScreenRecordingStatusTests {
    @Test func preflightGrantedAndContentAvailable() {
        let status = ScreenRecordingStatus(preflightGranted: true, shareableContentError: nil)
        #expect(status.state == .granted)
        #expect(status.isUsable)
    }

    @Test func preflightDeniedIsNotGranted() {
        let status = ScreenRecordingStatus(preflightGranted: false, shareableContentError: "The user declined TCCs")
        #expect(status.state == .notGranted)
        #expect(!status.isUsable)
    }

    // An SC error alone is not proof of a missing permission (2026-11-06: reported NOT GRANTED while screenshots worked)
    @Test func preflightGrantedButContentErrorIsNotReportedAsDenied() {
        let status = ScreenRecordingStatus(preflightGranted: true, shareableContentError: "SCStreamErrorDomain -3801")
        #expect(status.state == .grantedCheckFailed)
        #expect(status.isUsable)
        #expect(status.summary.contains("SCStreamErrorDomain -3801"))
        #expect(status.summary.contains("listall_screenshot_macos"))
    }

    @Test func summaries() {
        #expect(ScreenRecordingStatus(preflightGranted: true, shareableContentError: nil).summary.hasPrefix("GRANTED"))
        #expect(ScreenRecordingStatus(preflightGranted: false, shareableContentError: nil).summary.hasPrefix("NOT GRANTED"))
    }
}
