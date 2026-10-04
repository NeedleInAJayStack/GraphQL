// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "GraphQL", path: "../"),
        .package(
            url: "https://github.com/ordo-one/package-benchmark",
            .upToNextMajor(from: "1.4.0")
        ),
        .package(
            url: "https://github.com/apple/swift-profile-recorder",
            .upToNextMinor(from: "0.3.18")
        ),
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "GraphQL", package: "GraphQL"),
                .product(name: "ProfileRecorder", package: "swift-profile-recorder"),
            ],
            path: "Benchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ],
    swiftLanguageVersions: [.v5, .version("6")]
)
