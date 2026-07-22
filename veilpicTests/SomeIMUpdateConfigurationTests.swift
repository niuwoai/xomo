import Foundation
import Testing
@testable import musepic

struct SomeIMUpdateConfigurationTests {
    @Test
    func stableAppcastURLMatchesMuchtokenContract() {
        #expect(
            SomeIMUpdateConfiguration.feedURL?.absoluteString ==
                "https://some.im/api/v1/public/app-updates/appcast.xml?app_id=xomo&platform=macos&channel=stable"
        )
    }
}
