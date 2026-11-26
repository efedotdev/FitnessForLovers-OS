import Foundation
import XCTest
@testable import FitnessForLoversAPIContracts

final class APIContractTests: XCTestCase {
    private let decoder: JSONDecoder = {
        .backendAPIDecoder()
    }()

    func testAuthResponseDecodesFromSuccessEnvelope() throws {
        let json = """
        {
          "success": true,
          "data": {
            "user": {
              "id": "user-1",
              "name": "Efe",
              "email": "user@example.com",
              "avatarUrl": null,
              "createdAt": "2026-01-01T00:00:00.123Z"
            },
            "tokens": {
              "accessToken": "access-token",
              "refreshToken": "refresh-token"
            }
          }
        }
        """

        let envelope = try decoder.decode(APIResponse<AuthResponse>.self, from: Data(json.utf8))

        XCTAssertTrue(envelope.success)
        XCTAssertEqual(envelope.data?.user.name, "Efe")
        XCTAssertEqual(envelope.data?.tokens.accessToken, "access-token")
        XCTAssertEqual(
            try XCTUnwrap(envelope.data?.user.createdAt.timeIntervalSince1970),
            1767225600.123,
            accuracy: 0.001
        )
        XCTAssertNil(envelope.data?.isNewUser)
    }

    func testErrorResponseDecodesWithoutLeakingIntoTypedPayload() throws {
        let json = """
        {
          "success": false,
          "data": null,
          "error": {
            "error": "INVALID_CREDENTIALS",
            "message": "Invalid email or password",
            "statusCode": 401
          }
        }
        """

        let envelope = try decoder.decode(APIResponse<AuthResponse>.self, from: Data(json.utf8))

        XCTAssertFalse(envelope.success)
        XCTAssertNil(envelope.data)
        XCTAssertEqual(envelope.error?.statusCode, 401)
        XCTAssertEqual(envelope.error?.message, "Invalid email or password")
    }

    func testPairingResponseDecodes() throws {
        let json = """
        {
          "id": "pairing-1",
          "user1Id": "user-1",
          "user2Id": "user-2",
          "status": "ACCEPTED",
          "sharingScope": "ACTIVITY_ONLY",
          "customTypes": [],
          "invitedAt": "2026-01-01T00:00:00Z",
          "acceptedAt": "2026-01-02T00:00:00Z",
          "rejectedAt": null,
          "expiresAt": "2026-02-01T00:00:00Z",
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-02T00:00:00Z",
          "user1": {"id":"user-1","name":"Efe","avatarUrl":null,"email":"a@example.com"},
          "user2": {"id":"user-2","name":"Ada","avatarUrl":null,"email":"b@example.com"},
          "partner": {"id":"user-2","name":"Ada","avatarUrl":null,"email":"b@example.com"},
          "isInviter": true
        }
        """

        let pairing = try decoder.decode(PairingResponse.self, from: Data(json.utf8))

        XCTAssertEqual(pairing.status, .accepted)
        XCTAssertEqual(pairing.partner.email, "b@example.com")
        XCTAssertTrue(pairing.isInviter)
    }

    func testGoalResponseDecodes() throws {
        let json = """
        {
          "id": "goal-1",
          "pairingId": "pairing-1",
          "createdById": "user-1",
          "title": "Shared steps",
          "targetValue": 10000,
          "currentValue": 2500,
          "remainingValue": 7500,
          "progressPercentage": 25,
          "completed": false,
          "startDate": "2026-01-01T00:00:00Z",
          "endDate": "2026-01-02T00:00:00Z",
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """

        let goal = try decoder.decode(GoalResponse.self, from: Data(json.utf8))

        XCTAssertEqual(goal.title, "Shared steps")
        XCTAssertEqual(goal.targetValue, 10000)
        XCTAssertEqual(goal.progressPercentage, 25)
        XCTAssertEqual(goal.remainingValue, 7500)
        XCTAssertFalse(goal.completed)
    }

    func testDashboardResponseDecodesWithoutPartnerOrGoals() throws {
        let json = """
        {
          "summary": {
            "date": "2026-01-01",
            "steps": 1200,
            "activeEnergy": 100,
            "distance": 800
          },
          "partner": null,
          "goals": [],
          "sync": {"lastSyncedAt": null, "status": null}
        }
        """

        let dashboard = try decoder.decode(DashboardResponse.self, from: Data(json.utf8))

        XCTAssertEqual(dashboard.summary.steps, 1200)
        XCTAssertNil(dashboard.partner)
        XCTAssertTrue(dashboard.goals.isEmpty)
    }

    func testPartnerSummaryDecodesAggregateValueWrappers() throws {
        let json = """
        {
          "summary": {
            "date": "2026-01-01",
            "sharingScope": "ACTIVITY_ONLY",
            "metrics": [{
              "type": "STEPS",
              "_sum": {"value": 4800},
              "_avg": {"value": 2400},
              "_max": {"value": 3000},
              "_min": {"value": 1800}
            }]
          }
        }
        """

        let response = try decoder.decode(PartnerSummaryResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.summary.metrics.first?.type, .steps)
        XCTAssertEqual(response.summary.metrics.first?.sum?.value, 4800)
    }

    func testEndpointUsesBackendPathWithoutApiPrefix() throws {
        let endpoint = Endpoint(
            path: "/auth/login",
            method: .post,
            queryItems: [URLQueryItem(name: "source", value: "ios")],
            requiresAuth: false
        )

        let url = try XCTUnwrap(endpoint.url(baseURL: "http://localhost:3000"))

        XCTAssertEqual(url.host, "localhost")
        XCTAssertEqual(url.path, "/auth/login")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "ios")
        XCTAssertFalse(url.path.hasPrefix("/api/"))
    }
}
