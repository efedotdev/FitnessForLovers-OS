// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessForLoversAPIContracts",
    platforms: [.iOS(.v17)],
    targets: [
        .target(
            name: "FitnessForLoversAPIContracts",
            path: "FitnessForLovers",
            exclude: [
                "ContentView.swift",
                "Extensions",
                "FitnessForLovers.entitlements",
                "FitnessForLoversApp.swift",
                "Resources",
                "Services/APIService.swift",
                "Services/AuthManager.swift",
                "Services/HealthKitService.swift",
                "Services/KeychainHelper.swift",
                "ViewModels",
                "Views"
            ],
            sources: ["Models/APIModels.swift", "Services/Endpoint.swift"]
        ),
        .testTarget(
            name: "FitnessForLoversAPIContractsTests",
            dependencies: ["FitnessForLoversAPIContracts"],
            path: "Tests/FitnessForLoversAPIContractsTests"
        )
    ]
)
