@testable import Speakable
import XCTest

final class OpenAIClientTests: XCTestCase {
  // MARK: - OpenAIError Tests

  func testOpenAIErrorMissingAPIKeyDescription() {
    let error = OpenAIError.missingAPIKey
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("API Key"))
  }

  func testOpenAIErrorTextTooLongDescription() {
    let error = OpenAIError.textTooLong(length: 5000, maxLength: 4096)
    XCTAssertNotNil(error.errorDescription)
    // String(localized:) applies locale-aware number formatting
    XCTAssertTrue(error.errorDescription!.contains(5000.formatted()))
    XCTAssertTrue(error.errorDescription!.contains(4096.formatted()))
  }

  func testOpenAIErrorAPIErrorDescription() {
    let error = OpenAIError.apiError(statusCode: 401, message: "Invalid API key")
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("401"))
    XCTAssertTrue(error.errorDescription!.contains("Invalid API key"))
  }

  func testOpenAIErrorNetworkErrorDescription() {
    let underlyingError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet"])
    let error = OpenAIError.networkError(underlyingError)
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("Network"))
  }

  // MARK: - OpenAIClient Tests

  func testOpenAIClientSharedInstance() {
    let instance1 = OpenAIClient.shared
    let instance2 = OpenAIClient.shared
    XCTAssertTrue(instance1 === instance2, "OpenAIClient should be a singleton")
  }

  func testGenerateSpeechThrowsWithoutAPIKey() async {
    let settings = SettingsManager.shared
    let originalKey = settings.apiKey

    settings.apiKey = ""

    do {
      _ = try await OpenAIClient.shared.generateSpeech(text: "Hello")
      XCTFail("Should throw missingAPIKey error")
    } catch let error as OpenAIError {
      if case .missingAPIKey = error {
        // Expected
      } else {
        XCTFail("Expected missingAPIKey error, got: \(error)")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }

    // Restore
    settings.apiKey = originalKey
  }

  func testGenerateSpeechThrowsForTextTooLong() async {
    let settings = SettingsManager.shared
    let originalKey = settings.apiKey

    settings.apiKey = "sk-test-key"

    let longText = String(repeating: "a", count: 5000)

    do {
      _ = try await OpenAIClient.shared.generateSpeech(text: longText)
      XCTFail("Should throw textTooLong error")
    } catch let error as OpenAIError {
      if case let .textTooLong(length, maxLength) = error {
        XCTAssertEqual(length, 5000)
        XCTAssertEqual(maxLength, 4096)
      } else {
        XCTFail("Expected textTooLong error, got: \(error)")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }

    // Restore
    settings.apiKey = originalKey
  }
}
